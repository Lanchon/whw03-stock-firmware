--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local lfs = require('lfs')
local device = require('device')
local json = require('libhdkjsonlua')
local hdk = require('libhdklua')
local util = require('util')

local _M = {}   --create the module

_M.unittest = {} -- unit test override data store

_M.SURVEY_RESULT_PATH = '/tmp/sc_data'
_M.DISCOVERED_APS = '/tmp/sc_data/discovered_aps'
_M.CMD_GET_SURVEY_RESULT = '/etc/init.d/service_wifi/smart_connect_get_survey_result.sh'

function _M.requestSmartConnectSurvey(sc)
    sc:writelock()

    -- If the device is a Node, it must be in master mode.
    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    local master_search_status = sc:get_smartconnect_search_client_status()
    if master_search_status == 'RUNNING' then
        return 'ErrorRequestSmartConnectSurveyAlreadyRunning'
    end

    local connect_client_status = sc:get_smartconnect_connect_client_status()
    if connect_client_status == 'RUNNING' then
        return 'ErrorRequestOnboardSmartConnectClientAlreadyRunning'
    end

    local get_survey_result_status = sc:get_smartconnect_get_survey_result_status()
    if get_survey_result_status == 'RUNNING' then
        return 'ErrorGetSmartConnectSurveyResultAlreadyRunning'
    end

    sc:set_smartconnect_search_client_timestamp(os.time())
    sc:set_smartconnect_search_client()
    sc:set_smartconnect_search_client_status('RUNNING')
end

local function getClientDeviceInfo(bssid)
    local devinfo
    local fullpath = _M.SURVEY_RESULT_PATH..'/'..bssid..'.info'
    local file, err = io.open(fullpath, 'r')
    if file then
        local raw_data = file:read('*all')
        local devinfo_data, err = json.parse(raw_data)
        if devinfo_data then
            devinfo = {}
            devinfo.bssid = hdk.macaddress(bssid)
            devinfo.serial = devinfo_data.output.serialNumber
            devinfo.vendor = devinfo_data.output.vendor
            devinfo.model = devinfo_data.output.model
            devinfo.description = devinfo_data.output.description
        end
        file:close()
    end

    return devinfo
end

function _M.getSmartConnectSurveyResult(sc)
    -- Ensure no lock is held when making this call, as it is blocking
    assert(not sc:isreadlocked() and not sc:iswritelocked(), 'must not hold the sysctx lock when calling getSmartConnectSurveyResult')

    local sysctx = require('libsysctxlua')

    -- Create a local sysctx to read from so we can rollback to
    -- release the lock before invoking the time-consuming WiFi process.
    local ownedsc = _M.unittest.ctx and _M.unittest.ctx:sysctx() or sysctx.new()
    ownedsc:readlock()

    -- If the device is a Node, it must be in master mode.
    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(ownedsc) then
        ownedsc:rollback()  -- release the lock
        return 'ErrorDeviceNotInMasterMode'
    end

    local output = {}

    output.lastTriggered = nil
    output.isRunning = false
    output.smartConnectClientsList = {}

    local timestamp = ownedsc:get_smartconnect_search_client_timestamp()
    if timestamp and timestamp ~= '' then
        output.lastTriggered = hdk.datetime(tonumber(timestamp))
    else
        ownedsc:rollback()  -- release the lock
        return nil, output
    end

    local master_search_status = ownedsc:get_smartconnect_search_client_status()
    if master_search_status == 'RUNNING' then
        ownedsc:rollback()  -- release the lock
        output.isRunning = true
        return nil, output
    end

    local get_survey_result_status = ownedsc:get_smartconnect_get_survey_result_status()
    if get_survey_result_status == 'RUNNING' then
        ownedsc:rollback()  -- release the lock
        return 'ErrorGetSmartConnectSurveyResultAlreadyRunning'
    end

    -- Roll back the local sysctx context before invoking the WiFi process
    ownedsc:rollback()

    os.execute(_M.CMD_GET_SURVEY_RESULT..' get_all'..' > /dev/null')

    sc:readlock()
    local survey_result_status = sc:get_smartconnect_get_survey_result_status()
    if survey_result_status == 'NoMoreClient' or survey_result_status == 'NoSortedList' then
        return nil, output
    end

    local file, err = io.open(_M.DISCOVERED_APS, 'r')
    if file then
        local raw_data = file:read('*all')
        local aps, err = json.parse(raw_data)
        if aps then
            local curr_dev = 1
            while aps.count >= curr_dev do
                local bssid = aps.APs[curr_dev].mac
                local devinfo = getClientDeviceInfo(bssid)
                table.insert(output.smartConnectClientsList, devinfo)
                curr_dev = curr_dev + 1
            end
        end
        file:close()
    end

    return nil, output
end

function _M.getSmartConnectNextResult(sc)
    -- Ensure no lock is held when making this call, as it is blocking
    assert(not sc:isreadlocked() and not sc:iswritelocked(), 'must not hold the sysctx lock when calling getSmartConnectNextResult')

    local sysctx = require('libsysctxlua')

    -- Create a local sysctx to read from so we can rollback to
    -- release the lock before invoking the time-consuming WiFi process.
    local ownedsc = _M.unittest.ctx and _M.unittest.ctx:sysctx() or sysctx.new()
    ownedsc:readlock()

    -- If the device is a Node, it must be in master mode.
    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(ownedsc) then
        ownedsc:rollback()  -- release the lock
        return 'ErrorDeviceNotInMasterMode'
    end

    local output = {}

    output.lastTriggered = nil
    output.isRunning = false

    local timestamp = ownedsc:get_smartconnect_search_client_timestamp()
    if timestamp and timestamp ~= '' then
        output.lastTriggered = hdk.datetime(tonumber(timestamp))
    else
        ownedsc:rollback()  -- release the lock
        return nil, output
    end

    local master_search_status = ownedsc:get_smartconnect_search_client_status()
    if master_search_status == 'RUNNING' then
        ownedsc:rollback()  -- release the lock
        output.isRunning = true
        return nil, output
    end

    local survey_result_status = ownedsc:get_smartconnect_get_survey_result_status()
    if survey_result_status == 'RUNNING' then
        ownedsc:rollback()  -- release the lock
        return 'ErrorGetSmartConnectSurveyResultAlreadyRunning'
    end

    -- Roll back the local sysctx context before invoking the WiFi process
    -- unless running a unittest, where we need to preserve the state for
    -- subsequent reads.
    if not _M.unittest.ctx then
        ownedsc:rollback()
    end

    os.execute(_M.CMD_GET_SURVEY_RESULT..' get_next'..' > /dev/null')
    local survey_result_status = sc:get_smartconnect_get_survey_result_status()
    if survey_result_status == 'NoMoreClient' or survey_result_status == 'NoSortedList' then
        return nil, output
    end

    sc:readlock()
    local curr_dev = tonumber(sc:get_smartconnect_current_device())
    local file, err = io.open(_M.DISCOVERED_APS, 'r')
    if file then
        local raw_data = file:read('*all')
        local aps, err = json.parse(raw_data)
        if aps then
            if aps.count >= curr_dev then
                local bssid = aps.APs[curr_dev].mac
                local devinfo = getClientDeviceInfo(bssid)
                output.smartConnectClientInfo = devinfo
            end
        end
        file:close()
    end

    return nil, output
end

function _M.requestOnboardSmartConnectClient(sc, input)
    sc:writelock()

    -- If the device is a Node, it must be in master mode.
    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    local connect_client_status = sc:get_smartconnect_connect_client_status()
    if connect_client_status == 'RUNNING' or connect_client_status == 'ONBOARDING' then
        return 'ErrorRequestOnboardSmartConnectClientAlreadyRunning'
    end

    local master_search_status = sc:get_smartconnect_search_client_status()
    if master_search_status == 'RUNNING' then
        return 'ErrorRequestSmartConnectSurveyAlreadyRunning'
    end

    local get_survey_result_status = sc:get_smartconnect_get_survey_result_status()
    if get_survey_result_status == 'RUNNING' then
        return 'ErrorGetSmartConnectSurveyResultAlreadyRunning'
    end

    sc:set_smartconnect_connect_client_timestamp(os.time())
    sc:set_smartconnect_connect_client(tostring(input.bssid))
    sc:set_smartconnect_connect_client_status('RUNNING')
end

function _M.getOnboardSmartConnectClientStatus(sc)
    sc:readlock()

    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    local output = {}

    output.lastTriggered = nil
    output.isRunning = false
    output.bssid = nil
    output.status = nil

    local timestamp = sc:get_smartconnect_connect_client_timestamp()
    if timestamp and timestamp ~= '' then
        output.lastTriggered = hdk.datetime(tonumber(timestamp))
    else
        return nil, output
    end

    output.bssid = hdk.macaddress(sc:get_smartconnect_connect_client())
    local connect_client_status = sc:get_smartconnect_connect_client_status()
    if connect_client_status == 'RUNNING' or connect_client_status == 'ONBOARDING' then
        output.isRunning = true
        return nil, output
    end

    if connect_client_status == 'OK' then
        output.status = 'Success'
    elseif connect_client_status == 'ErrorConnectBSSID' or connect_client_status == 'ErrorNotExistBSSID' then
        output.status = 'CannotConnectBSSIDError'
    elseif connect_client_status == 'ErrorFailedGetIP' then
        output.status = 'CannotGetIPAddressError'
    elseif connect_client_status == 'ErrorFailedRequest' then
        output.status = 'RequestStartSmartConnectClientError'
    elseif connect_client_status == 'ErrorFailedStartSmartConnectServer' then
        output.status = 'FailedStartSmartConnectServerError'
    elseif connect_client_status == 'ErrorSetupAlreadyInProgress' then
        output.status = 'SmartConnectSetupInProgressError'
    elseif connect_client_status == 'SmartConnectSetupTimeout' then
        output.status = 'SmartConnectSetupTimeoutError'
    end

    return nil, output
end


return _M   -- return the module.
