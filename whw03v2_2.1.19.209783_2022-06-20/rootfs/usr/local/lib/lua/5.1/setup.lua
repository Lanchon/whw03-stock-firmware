--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hesia $
-- $DateTime: 2019/10/09 16:05:17 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/nodes/setup.lua#4 $
--

-- setup.lua - library to access the setup settings.

local platform = require('platform')
local wirelessap = require('wirelessap')
local hdk = require('libhdklua')
local json = require('libhdkjsonlua')
local lfs = require('lfs')
local util = require('util')
local nodes_util = require('nodes_util')

local _M = {}   --create the module

_M.CMD_START_PUB_PRESETUP = '/etc/init.d/run_start_presetup.sh %s'
_M.CMD_STOP_PUB_PRESETUP = '/etc/init.d/run_stop_presetup.sh'

-- Extend wirelessap's radio profiles with the prefix published by mosquitto
wirelessap.RADIO_PROFILES[wirelessap.RADIO_ID_2GHZ].prefix = 'userAp2G'
wirelessap.RADIO_PROFILES[wirelessap.RADIO_ID_5GHZ].prefix = 'userAp5GL'
wirelessap.RADIO_PROFILES[wirelessap.RADIO_ID_5GHZ_2].prefix = 'userAp5GH'

--
-- Get SmartConnect wireless settings for the specified band (2.4GHz or 5GHz)
--
-- input = CONTEXT,
--     band = STRING
--
-- output = {
--     band = STRING,
--     ssid = STRING,
--     passphase = STRING,
--     security = STRING
-- }
--
--
function _M.getSimpleWiFiSettings(sc, band)
    sc:readlock()

    return {
        band = band,
        ssid = sc:get_smartconnect_wifi_ssid(band),
        passphrase = sc:get_smartconnect_wifi_passphrase(band),
        security = wirelessap.parseWirelessSecurity(sc:get_smartconnect_wifi_security_mode(band))
    }
end

--
-- Set SmartConnect wireless settings for the specified band (2.4GHz or 5GHz)
--
-- input = CONTEXT,
--     band = STRING,
--     ssid = STRING,
--     passphase = STRING,
--     security = STRING
--
-- output = NIL_OR_ONE_OF(
--     'ErrorInvalidSSID',
--     'ErrorInvalidPassphrase',
--     'ErrorUnsupportedSecurity'
-- )
--
function _M.setSimpleWiFiSettings(sc, settings)
    sc:writelock()

    if (not sc:is_smartconnect_wifi_ready()) then
       return '_ErrorNotReady'
    end
    if #settings ~= 2 then
        return 'ErrorMissingSimpleWiFiSettings'
    end
    if settings[1].band == settings[2].band then
        return 'ErrorDuplicateBandSimpleWiFiSettings'
    end

    for index, setting in ipairs(settings) do
        if not wirelessap.isValidSSID(setting.ssid) then
            return 'ErrorInvalidSSID'
        end
        if not (wirelessap.isValidWPAPassphrase(setting.passphrase)) then
            return 'ErrorInvalidPassphrase'
        end
        sc:set_smartconnect_wifi_ssid(setting.band, setting.ssid)
        sc:set_smartconnect_wifi_passphrase(setting.band, setting.passphrase)
        sc:set_smartconnect_wifi_security_mode(setting.band, wirelessap.serializeWirelessSecurity(setting.security))
    end
end

--
-- Adds the radio to the radios object
--
-- input =
--     radios = ARRAY_OF({
--         radioID = STRING,
--         band = STRING,
--         channel = STRING
--     }),
--     bssid = STRING,
--     radioId = STRING,
--     band = STRING,
--     channel = STRING
--
--
local function insertRadio(radios, bssid, radioId, band, channel)
    -- Check if bssid exist, this is to support dual-band and tri-band devices
    if bssid and bssid ~= '' then
        local radio = {}
        radio.radioID = radioId
        radio.band = band
        -- In case we can't determine the selected channel, we'll manually set it to 0 (NODES-6429).
        if channel and channel ~= '' and tonumber(channel) then
            radio.channel = tonumber(channel)
        else
            radio.channel = 0
        end
        table.insert(radios, radio)
    end
end

--
-- Retrieves radio info from the status file and insert it to the table
--
-- input =
--     nodes = ARRAY_OF({
--         deviceID = UUID,
--         channels = ARRAY_OF({
--             radioID = STRING,
--             band = STRING,
--             channel = STRING
--         })
--     }),
--     nodeDir = STRING
--
--
local function retrieveRadiosForNode(nodes, nodeDir)
    if util.isPathADirectory(nodeDir) then
        local node = {}
        local file = io.open(nodeDir..'/status')
        if (file) then
            local content = file:read('*a')
            file:close()
            local parsedContent, err = json.parse(content)
            if err == nil and parsedContent and parsedContent.type and parsedContent.type == 'status' then
                if parsedContent.uuid and parsedContent.uuid ~= '' then
                    node.deviceID = hdk.uuid(parsedContent.uuid)
                    node.channels = {}
                    -- get information for each radio
                    for id, values in pairs(wirelessap.RADIO_PROFILES) do
                        insertRadio(node.channels, parsedContent.data[values.prefix..'_bssid'], id, values.band, parsedContent.data[values.prefix..'_channel'])
                    end
                    table.insert(nodes, node)
                end
            end
        end
    end
end

--
-- Gets channel information of all nodes
--
-- output = ARRAY_OF({
--     deviceID = UUID,
--     channels = ARRAY_OF({
--         radioID = STRING,
--         band = STRING,
--         channel = NUMBER
--     })
-- })
--
function _M.getSelectedChannels(sc)
    sc:readlock()
    local retVal = {}
    retVal.isRunning = sc:get_wifi_auto_channel_status() == 'running' and true or false
    if not retVal.isRunning and nodes_util.isNodeAMaster(sc) then
        retVal.selectedChannels = {}
        local subscriberFilePrefix = nodes_util.getSubscriberFilePrefix(sc)

        -- Get master's WLAN status
        local masterDir = util.concatPaths({
            subscriberFilePrefix,
            nodes_util.MSG_WIRELESS_DIR,
            'master'
        })
        retrieveRadiosForNode(retVal.selectedChannels, masterDir)

        -- Iterate and get each online slave's wlan status
        local onlineSlaveUUIDs = nodes_util.getOnlineSlaveUUIDs(sc)
        for i, uuid in ipairs(onlineSlaveUUIDs) do
            local slaveDir = util.concatPaths({
                subscriberFilePrefix,
                nodes_util.MSG_WIRELESS_DIR,
                uuid
            })
            retrieveRadiosForNode(retVal.selectedChannels, slaveDir)
        end
    end

    return retVal
end

--
-- Returns UUIDs of online slaves
--
-- input = CONTEXT
--
-- output = ARRAY_OF(UUID)
--
function _M.getConnectedNodesDeviceID(sc)
    sc:readlock()

    if not nodes_util.isNodeAMaster(sc) then
        return 'ErrorUnsupportedMode' -- should've been more descriptive and use 'ErrorDeviceNotInMasterMode'
    end

    local uuids = nodes_util.getOnlineSlaveUUIDs(sc)
    -- convert an array of string into an array of uuid object
    local retVal = {}
    for i, uuid in ipairs(uuids) do
        table.insert(retVal, hdk.uuid(uuid))
    end
    return 'OK', {
        deviceIDs = retVal
    }
end

--
-- Triggers auto-channel selection on all Nodes.
--
-- input = CONTEXT
--
function _M.startAutoChannelSelection(sc)
    sc:writelock()
    if sc:get_wifi_auto_channel_status() == 'running' then
        return 'ErrorAutoChannelSelectionAlreadyInProgress'
    end
    sc:set_wifi_auto_channel_start()
end

--
-- Convert a string to a Title Case. Taken from: http://lua-users.org/wiki/StringRecipes
--
local function convertToTitleCase(str)
    local function titleCaseHelper(first, rest)
        return first:upper()..rest:lower()
    end
    return str:gsub("(%a)([%w_']*)", titleCaseHelper)
end

--
-- Get wireless connection info of specific nodes.
--
-- input = CONTEXT, {
--     deviceIDs = ARRAY_OF(UUID)
-- }
--
-- output = {} or ARRAY_OF({
--     deviceID = UUID,
--     connType = ConnectionType,
--     phyRate = NUMBER,
--     latency = NUMBER,
--     rssi = NUMBER,
--     bandwidth = NUMBER
-- })
--
function _M.getNodesWirelessConnectionInfo(sc, deviceIDs)
    local arrayOfSlaveConnectionInfo = {}
    sc:readlock()
    local backhaulDirectory = util.concatPaths({
        nodes_util.getSubscriberFilePrefix(sc),
        nodes_util.MSG_BACKHAUL_DIR,
    })

    for _, deviceID in pairs(deviceIDs) do
        local slaveConnectionInfo = {}
        local slaveDeviceID = tostring(deviceID):upper()
        local statusFilePath = util.concatPaths({
            backhaulDirectory,
            slaveDeviceID,
            'status'
        })
        local statusPerformanceFilePath = statusFilePath..'.performance'
        local statusShutdownFilePath = statusFilePath..'.shutdown'

        local statusTS = lfs.attributes(statusFilePath, 'modification') or 0
        local performanceTS = lfs.attributes(statusPerformanceFilePath, 'modification') or 0
        local shutdownTS = lfs.attributes(statusShutdownFilePath, 'modification') or 0

        if util.isPathAFile(statusFilePath) and
                util.isPathAFile(statusPerformanceFilePath) and
                statusTS > shutdownTS and performanceTS > shutdownTS then
            slaveConnectionInfo.deviceID = deviceID
            -- read and parse layer2 data
            local statusFile = io.open(statusFilePath)
            if (statusFile) then
                local content = statusFile:read('*a')
                statusFile:close()
                local parsedContent, err = json.parse(content)
                if err == nil and parsedContent and parsedContent.type and parsedContent.type == 'status' then
                    slaveConnectionInfo.connType = convertToTitleCase(parsedContent.data.type)
                    local phyRate, unit = parsedContent.data.phyRate:match('(%d+.?%d*)%s+(%S)b/s')
                    slaveConnectionInfo.phyRate = tonumber(phyRate)
                    if unit == 'G' and slaveConnectionInfo.phyRate then
                        slaveConnectionInfo.phyRate = slaveConnectionInfo.phyRate * 1000
                    end
                    slaveConnectionInfo.rssi = tonumber(parsedContent.data.rssi)
                end
            end

             -- read and parse layer3 data
            local statusPerformanceFile = io.open(statusPerformanceFilePath)
            if (statusPerformanceFile) then
                local content = statusPerformanceFile:read('*a')
                statusPerformanceFile:close()
                local parsedContent, err = json.parse(content)
                if err == nil and parsedContent and parsedContent.type and parsedContent.type == 'status' then
                    slaveConnectionInfo.bandwidth = tonumber(parsedContent.data.rate)
                    slaveConnectionInfo.latency = tonumber(parsedContent.data.delay)
                end
            end

            -- check all fields are valid, then insert to table
            if slaveConnectionInfo.deviceID and slaveConnectionInfo.connType and slaveConnectionInfo.phyRate and
                    slaveConnectionInfo.rssi and slaveConnectionInfo.latency and slaveConnectionInfo.bandwidth then
                table.insert(arrayOfSlaveConnectionInfo, slaveConnectionInfo)
            end
        end
    end

    return arrayOfSlaveConnectionInfo
end

function _M.getUnconfiguredWiredNodes(sc)
    local conf_me_dir = util.concatPaths({
        nodes_util.getSubscriberFilePrefix(sc),
        nodes_util.MSG_CONFIGME_DIR
    })
    local list = {}

    if util.isPathADirectory(conf_me_dir) then
        for dir in lfs.dir(conf_me_dir) do
            if dir ~= '.' and dir ~= '..' then
                -- This should be the parent directory containing the status file
                local full_dir = util.concatPaths({
                    conf_me_dir,
                    dir
                })
                if util.isPathADirectory(full_dir) then
                    local status_file = util.concatPaths({
                        full_dir,
                        'status'
                    })
                    if util.isPathAFile(status_file) then
                        local file, err = io.open(status_file, 'r')
                        if file then
                            local raw_data = file:read('*all')
                            local cooked_data, err = json.parse(raw_data)
                            if cooked_data then
                                local status = cooked_data.data.status
                                if status == 'unconfigured' then
                                    table.insert(list, {
                                        deviceID = hdk.uuid(cooked_data.uuid),
                                        pin =  cooked_data.data.pin,
                                        macAddress = hdk.macaddress(cooked_data.data.bt_mac)
                                    })
                                end
                            end
                            file:close()
                        end
                    end
                end
            end
        end
    end
    return list
end

function _M.getDeviceID(sc, input)
    local device = require('device')
    local bluetooth = require('bluetooth')

    sc:readlock()

    if input.macAddress and not nodes_util.isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    if not input.macAddress then
        return nil, {
            deviceID = hdk.uuid(device.getUUID(sc))
        }
    else
        -- If mac address matches the currently connected BT peer,
        -- then perform a GetDeviceID() over BT and return that.
        local error, data = bluetooth.btGetDeviceID(tostring(input.macAddress))
        if not error then
            return nil, {
                deviceID = hdk.uuid(data.deviceID)
            }
        else
            return error, nil
        end
    end
end

function _M.startWiredBlinkingNode(sc, input)
    sc:readlock()
    if not nodes_util.isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    local id = tostring(input.deviceID):upper()
    local conf_me_dir = util.concatPaths({
        nodes_util.getSubscriberFilePrefix(sc),
        nodes_util.MSG_CONFIGME_DIR
    })
    if util.isPathADirectory(conf_me_dir) then
        for dir in lfs.dir(conf_me_dir) do
            if id == dir then
                local rc = os.execute(_M.CMD_START_PUB_PRESETUP:format(id))
                if rc ~= 0 then
                    platform.logMessage(platform.LOG_ERROR, ('Failed to publish start-presetup command (%d)'):format(rc))
                end
                return nil
            end
        end
    end

    return 'ErrorUnknownDevice'
end

function _M.stopWiredBlinkingNode(sc)
    sc:readlock()
    if not nodes_util.isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    local rc = os.execute(_M.CMD_STOP_PUB_PRESETUP)
    if rc ~= 0 then
        platform.logMessage(platform.LOG_ERROR, ('Failed to publish stop-presetup command (%d)'):format(rc))
    end

    return nil
end

return _M   -- return the module.
