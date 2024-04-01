--
-- 2018 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

-- diagnostics.lua - library to run diagnostic utilites.

local platform = require('platform')
local hdk = require('libhdklua')
local util = require('util')

local _M = {} -- create the module

_M.unittest = {} -- unit test override data store

_M.PUBLISH_UPLOAD_MSG = "/usr/sbin/pub_upload_sysinfo %s"
_M.BACKHAUL_REPORT_CMD = 'bh_report -j'
_M.NEIGHBOR_REPORT_CMD = 'nb_report -j'
_M.SITE_SURVEY_DIR = '/tmp/client_sitesurveys'
_M.REFRESH_BACKHAUL_CMD = 'refresh_bh_perf %s'


--
-- Generate Sysinfo diagnostics data and upload it to the Linksys cloud.
--
-- input = CONTEXT, {
--      uploadRequestUUID = OPTIONAL(UUID)
-- }
--
-- output = {
--      uploadRequestUUID = OPTIONAL(UUID)
-- }
--
--
function _M.uploadSysinfoData(sc, input)
    sc:readlock()
    if (sc:get_wan_connection_status() ~= 'started') then
        return 'ErrorNoWANConnection'
    end

    local requestId = input.uploadRequestUUID
    if (not requestId) then
        requestId = hdk.uuid(platform.getUUID())
    end

    -- Publish a MQTT message to tell the slave nodes to upload Sysinfo data
    local rc = os.execute(_M.PUBLISH_UPLOAD_MSG:format(tostring(requestId)))
    if (rc ~= 0) then
        platform.logMessage(platform.LOG_ERROR, ('Failed publishing Sysinfo upload command (%d)'):format(rc))
    end

    -- Set a local event to trigger the Sysinfo upload on this (master) node
    sc:setevent("sysinfo::upload", tostring(requestId))

    return nil, input.uploadRequestUUID and {} or { uploadRequestUUID = requestId }
end

function _M.getBackhaulDeviceInfo(sc)
    sc:readlock()
    if sc:get_smartmode() ~= 2 then
        return 'ErrorDeviceNotInMasterMode'
    end
    local reportJSON = util.chomp(io.popen(_M.BACKHAUL_REPORT_CMD):read("*a"))
    local reportTable = require('libhdkjsonlua').parse(reportJSON)
    local reportDevices = reportTable.bh_report
    local bhDeviceInfo = {}
    if reportDevices then
        for i = 1, #reportDevices do
            local connectionType
            local wirelessConnInfo = nil
            if reportDevices[i].channel == "wired" then
                connectionType = "Wired"
            else
                connectionType = "Wireless"
                wirelessConnInfo = {
                    radioID = reportDevices[i].interface,
                    channel = tonumber(reportDevices[i].channel),
                    apRSSI = tonumber(reportDevices[i].rssi_ap),
                    apBSSID = hdk.macaddress(reportDevices[i].ap_bssid),
                    stationRSSI = tonumber(reportDevices[i].rssi_sta),
                    stationBSSID = hdk.macaddress(reportDevices[i].sta_bssid)
                }
            end
            local parentIP = reportDevices[i].parent_ip
            if parentIP == 'Unknown' then
                parentIP = '0.0.0.0'
            end
            local device = {
                deviceUUID = hdk.uuid(reportDevices[i].uuid),
                ipAddress = hdk.ipaddress(reportDevices[i].ip),
                parentIPAddress = hdk.ipaddress(parentIP),
                connectionType = connectionType,
                wirelessConnectionInfo = wirelessConnInfo,
                speedMbps = tostring(reportDevices[i].speed),
                timestamp = reportDevices[i].timestamp,
                refreshSlaveLastError = sc:get_slave_backhaul_refresh_error(reportDevices[i].uuid)
            }
            table.insert(bhDeviceInfo, i, device)
        end
    end
    return nil, { backhaulDevices = bhDeviceInfo }
end

function _M.getNodeNeighborDevices(sc)
    sc:readlock()
    if sc:get_smartmode() ~= 2 then
        return 'ErrorDeviceNotInMasterMode'
    end
    local reportJSON = util.chomp(io.popen(_M.NEIGHBOR_REPORT_CMD):read("*a"))
    local reportTable = require('libhdkjsonlua').parse(reportJSON)
    local reportNeighbors = reportTable.neighbors
    local nodeNeighborDevices = {}
    if reportNeighbors then
        for i = 1, #reportNeighbors do
            local uuid = hdk.uuid(reportNeighbors[i].uuid)
            local mode = reportNeighbors[i].data.mode
            local neighborData = reportNeighbors[i].data.neighbor
            local neighbors = {}
            if neighborData then
                for j = 1, #neighborData do
                    local neighbor = {
                        macAddress = hdk.macaddress(neighborData[j].bssid),
                        channel = tonumber(neighborData[j].channel),
                        ssid = tostring(neighborData[j].ssid),
                        rssi = tonumber(neighborData[j].rssi)
                    }
                    table.insert(neighbors, j, neighbor)
                end
            end
            table.insert(nodeNeighborDevices, i, {
                deviceUUID = uuid,
                nodeMode = mode:gsub("^%l", string.upper),
                neighborNodes = neighbors
            })
        end
    end
    return nil, { nodeNeighborDevices = nodeNeighborDevices }
end

function _M.setWiFiClientSiteSurveyInfo(sc, input)
    sc:writelock()
    if sc:get_smartmode() ~= 2 then
        return 'ErrorDeviceNotInMasterMode'
    end
    local json = require('libhdkjsonlua')
    local lfs = require('lfs')

    if lfs.attributes(_M.SITE_SURVEY_DIR, 'mode') ~= 'directory' then
        lfs.mkdir(_M.SITE_SURVEY_DIR)
    end
    local pid = _M.unittest.pid or sc:get_process_id()
    local currentTime = _M.unittest.currentTime or os.time()

    -- Convert the input data to json, and write it to file.
    input.clientMACAddress= tostring(input.clientMACAddress)
    for i = 1, #input.discoveredAPs do
        input.discoveredAPs[i].macAddress = tostring(input.discoveredAPs[i].macAddress)
    end
    local fileName = string.format('%s/%s.%x.%x', _M.SITE_SURVEY_DIR, tostring(input.clientMACAddress), currentTime, pid)
    local f = io.open(fileName, 'w')
    if f then
        f:write(json.stringify(input))
        f:close()
    end
    -- Set an event to notify the system of the new site survey info.
    sc:set_wifi_client_site_survey(fileName)
end

function _M.getSlaveBackhaulStatus(sc, input)
    sc:readlock()

    if sc:get_smartmode() ~= 2 then
        return 'ErrorDeviceNotInMasterMode'
    end

    local statusMap = {
        ['unknown'] = 'Unknown',
        ['connected'] = 'Connected',
        ['disconnected'] = 'NotConnected',
        ['not_slave'] = 'NotSlaveNode'
    }

    local bh = _M.unittest.backhaul or require('nodes.backhaul')
    local success, value = bh.backhaul_status(tostring(input.deviceUUID):upper())
    if not success then
        platform.logMessage(platform.LOG_ERROR, ('backhaul_status() call failed: %s'):format(value))
        return 'ErrorGettingBackhaulStatus'
    end

    return nil, {
        backhaulStatus = statusMap[value.state],
        speedMbps = value.speed and tostring(value.speed)
    }
end

function _M.refreshSlaveBackhaulData(sc, input)
    sc:readlock()

    if sc:get_smartmode() ~= 2 then
        return 'ErrorDeviceNotInMasterMode'
    end
    local smartConnectStatus = sc:get_smartconnect_status()
    if #smartConnectStatus > 0 and smartConnectStatus ~= 'READY' then
        return 'ErrorSetupInProgress'
    end

    -- If we're refreshing data for a single slave node
    -- then run synchronously and check for a returned error
    if input.deviceUUID then
        local param = '-i '.. tostring(input.deviceUUID):upper()
        local errorResult = util.chomp(io.popen(_M.REFRESH_BACKHAUL_CMD:format(param)):read('*a'))
        if (#errorResult > 0) then
            return errorResult
        end
    else
        -- We're refreshing data for all slave nodes, so launch the command in the background
        os.execute(_M.REFRESH_BACKHAUL_CMD:format('&'))
    end
end


return _M -- return the module
