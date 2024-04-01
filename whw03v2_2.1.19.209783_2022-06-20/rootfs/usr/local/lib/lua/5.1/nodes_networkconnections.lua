--
-- 2018 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2020/10/29 22:44:11 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/nodes/nodes_networkconnections.lua#3 $
--

-- nodes_networkconnections.lua - library to get network connections state from Nodes.

local hdk = require('libhdklua')
local platform = require('platform')
local wirelessap = require('wirelessap')

local _M = {} -- create the module

_M.INTERFACE_TO_VAP_MAPPINGS = {}

--
-- NOTE: This is a one-time only, hard-coded mapping to resolve BOBCAT-317.
-- It maps the user/guest VAP interfaces to respective radio IDs, for all currently existing mesh routers (05/04/2020).
-- The forward functionality, added in conjunction with this mapping, uses the WLAN logical interface (wl0|wl1|wl2)
-- to get the radio ID for a wireless connection. So this map need not be maintained.
--
_M.INTERFACE_TO_RADIO_ID = {
    ['ath0']  = wirelessap.RADIO_ID_2GHZ,   -- User VAP 2.4GHz
    ['ath2']  = wirelessap.RADIO_ID_2GHZ,   -- Guest VAP 2.4GHz
    ['ath1']  = wirelessap.RADIO_ID_5GHZ,   -- User VAP 5GHz low
    ['ath3']  = wirelessap.RADIO_ID_5GHZ,   -- Guest VAP 5GHz low
    ['ath10'] = wirelessap.RADIO_ID_5GHZ_2, -- User VAP 5GHz high
    ['ath6']  = wirelessap.RADIO_ID_5GHZ_2, -- Guest VAP 5GHz high
    -- Bobcat only VAPs
    ['wl1.1'] = wirelessap.RADIO_ID_2GHZ,   -- User VAP 2.4GHz
    ['wl1.2'] = wirelessap.RADIO_ID_2GHZ,   -- Guest VAP 2.4GHz
    ['wl0.1'] = wirelessap.RADIO_ID_5GHZ,   -- User VAP 5GHz
    ['wl0.2'] = wirelessap.RADIO_ID_5GHZ    -- Guest VAP 5GHz
}

function _M.getWirelessStationList(sc)
    clutil = require('nodes.util.client')
    return clutil.get_wlan_client_list(sc)
end

--
-- Get the radioID for an interface
--
local function mapInterfaceToRadioID(sc, interface)
    -- Helper function to retrieve the VAP name from apName and isGuest
    local function addToMappingsHelper(sc, radioID, apName, isGuest)
        local vapName = sc:get_wifi_virtual_ap_name(apName, isGuest)
        -- Make sure the vapName exists in the syscfg and it's not an empty string
        if vapName and vapName ~= '' then
             _M.INTERFACE_TO_VAP_MAPPINGS[vapName] = radioID
        end
    end

    -- If there's no mapping, then we create a new one.
    if #_M.INTERFACE_TO_VAP_MAPPINGS == 0 then
        for radioID, profile in pairs(wirelessap.RADIO_PROFILES) do
            addToMappingsHelper(sc, radioID, profile.apName, false)
            addToMappingsHelper(sc, radioID, profile.apName, true)
            -- Velop Jr only has 1 5GHz radio, therefore we need to manually add the mappings for the 2nd one. (VELOPJR-307)
            if not sc:get_wifi_devices():find('wl2', 1, true) then
                _M.INTERFACE_TO_VAP_MAPPINGS['ath6'] = wirelessap.RADIO_ID_5GHZ_2
                _M.INTERFACE_TO_VAP_MAPPINGS['ath10'] = wirelessap.RADIO_ID_5GHZ_2
            end
        end
    end

    return _M.INTERFACE_TO_VAP_MAPPINGS[interface]
end

--
-- Get information about the active layer 2 network connections
-- on all Node devices.
--
-- input = CONTEXT, OPTIONAL(ARRAY_OF(MACADDRESS))
--
-- output =
--     lastTriggered = DATETIME,
--     nodeWirelessConnections =  ARRAY_OF({
--         deviceID = UUID,
--         connections = ARRAY_OF({
--             macAddress = MACADDRESS,
--             negotiatedMbps = NUMBER,
--             timestamp = DATETIME,
--             wireless = OPTIONAL({
--                 bssid = MACADDRESS,
--                 isGuest = BOOLEAN,
--                 radioID = STRING,
--                 band = STRING,
--                 signalDecibels = NUMBER
--             })
--         })
--     })
--
function _M.getNodesNetworkConnections(sc, includeNodeList, includeMACList)
    sc:readlock()
    local lastTriggered = nil
    local timestamp = sc:get_refresh_wifi_signal_strength_timestamp()
    if timestamp and timestamp ~= '' then
        lastTriggered = hdk.datetime(tonumber(timestamp))
    end

    -- filter Node by deviceID
    local nodeFilterSet
    if includeNodeList then
        nodeFilterSet = {}
        for i, uuid in ipairs(includeNodeList) do
            -- User types can't be used as keys in a table
            nodeFilterSet[tostring(uuid)] = uuid
        end
    end

    -- filter connection by MAC address
    local macFilterSet
    if includeMACList then
        macFilterSet = {}
        for i, mac in ipairs(includeMACList) do
            -- User types can't be used as keys in a table
            macFilterSet[tostring(mac)] = mac
        end
    end

    -- check is nil or empty string
    local function isNilOrEmptyString(value)
        return value == nil or (type(value) == "string" and value == "")
    end

    local function getRadioID(wlInterface)
        for radioID, profile in pairs(wirelessap.RADIO_PROFILES) do
            if profile.apName == wlInterface then
                return radioID
            end
        end
    end

    local nodeWirelessConnections = {}
    for strDeviceID, list in pairs(_M.getWirelessStationList(sc)) do
        if not nodeFilterSet or nodeFilterSet[strDeviceID:lower()] then
            local connections = {}
            for mac, sta in pairs(list) do
                if not isNilOrEmptyString(mac) and not isNilOrEmptyString(sta.status) and
                        not isNilOrEmptyString(sta.phyrate) and not isNilOrEmptyString(sta.timestamp) and
                        not isNilOrEmptyString(sta.ap_bssid) and not isNilOrEmptyString(sta.guest) and
                        not isNilOrEmptyString(sta.interface) and not isNilOrEmptyString(sta.band) and
                        not isNilOrEmptyString(sta.rssi) then
                    if sta.status == 'connected' then
                        if not macFilterSet or macFilterSet[mac:upper()] then
                            local radioID
                            -- If the wl_interface field exists in the connection data, then
                            -- get the respective radio ID from the wirelessap module
                            if sta.wl_interface then
                                radioID = getRadioID(sta.wl_interface)
                            else -- Use the hard-coded mapping (backwards compatibility)
                                radioID = _M.INTERFACE_TO_RADIO_ID[sta.interface]
                            end
                            local connection = {
                                macAddress = hdk.macaddress(mac),
                                negotiatedMbps = tonumber(string.match(sta.phyrate, '%d+')),
                                timestamp = hdk.datetime(sta.timestamp),
                                wireless = {
                                    bssid = hdk.macaddress(sta.ap_bssid),
                                    isGuest = sta.guest,
                                    radioID = radioID or 'Unknown',
                                    band = sta.band == '5G' and '5GHz' or '2.4GHz',
                                    signalDecibels = tonumber(sta.rssi)
                                }
                            }
                            table.insert(connections, connection)
                        end
                    end
                end
            end
            local nodeWirelessConnection = {
                deviceID = hdk.uuid(strDeviceID),
                connections = connections
            }
            table.insert(nodeWirelessConnections, nodeWirelessConnection)
        end
    end

    return {
        lastTriggered = lastTriggered,
        nodeWirelessConnections = nodeWirelessConnections
    }
end

--
-- Trigger the Master to collect wireless connection information
-- from the Slaves and itself
--
-- input = CONTEXT
--
-- output = NIL_OR('ErrorDeviceNotInMasterMode')
--
function _M.refreshNodesWirelessNetworkConnections(sc)
    sc:writelock()
    local smart_mode = sc:get_smartmode()
    if smart_mode ~= 2 then
        return 'ErrorDeviceNotInMasterMode'
    end

    sc:set_refresh_wifi_signal_strength_timestamp(os.time())
    sc:set_refresh_wifi_signal_strength()
end

return _M -- return the module
