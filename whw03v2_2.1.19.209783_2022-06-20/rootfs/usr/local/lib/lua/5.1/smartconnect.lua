--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2020/10/29 22:44:11 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/nodes/smartconnect.lua#12 $
--

-- smartconnect.lua - library to access the smartconnect settings.

local platform = require('platform')
local wirelessap = require('wirelessap')
local bluetooth = require('bluetooth')

local _M = {}   --create the module

_M.unittest = {} -- unit test override data store

_M.WIFI_STATUS = 'wifi-status'
_M.SMART_CONNECT_SETUP_STATUS = 'smart_connect::setup_status'
_M.SMART_CONNECT_SETUP_LASTERROR = 'smart_connect::setup_lasterror'
_M.SMART_CONNECT_PIN = 'smart_connect::pin'
_M.BACKHAUL_STATUS = 'backhaul::status'
_M.BACKHAUL_INTF = 'backhaul::intf'
_M.BACKHAUL_PREFERRED_BSSID = 'backhaul::preferred_bssid'
_M.BACKHAUL_L3_PERF = 'backhaul::l3_perf'

_M.SETUP_STAGE = 'setup::stage'
_M.SETUP_PROGRESS = 'setup::progress'

function _M.getSetupAP(sc)
    sc:readlock()

    local setup_ap = sc:get_setup_ap()

    if setup_ap == nil or setup_ap == '' then
        return 'ErrorNonExistentSetupAP', nil
    end

    return nil, {
        setupAP = setup_ap
    }
end

-- return values : error, output
function _M.getSmartConnectPIN(sc)
    sc:readlock()

    local smc_pin = sc:get_smartconnect_pin()

    if smc_pin == nil or smc_pin == '' then
        return 'ErrorNonExistentPIN', nil
    end

    return nil, {
        pin = smc_pin
    }
end

function _M.startSmartConnectServer(sc, settings, version)
    sc:writelock()

    local smart_mode = sc:get_smartmode()
    if smart_mode ~= 2 then
        if version and version > 1 then
            return 'ErrorDeviceNotInMasterMode'
        else
            return 'ErrorUnsupportedMode'
        end
    end

    local setup_status = sc:getevent(_M.SMART_CONNECT_SETUP_STATUS)
    if setup_status ~= 'READY' then
        return 'ErrorSetupAlreadyInProgress'
    end

    local wifi_status = sc:get_wifi_status()
    if wifi_status ~= 'started' then
        return '_ErrorNotReady'
    end

    local deviceID = settings.deviceID and tostring(settings.deviceID):upper()
    sc:set_smartconnect_server(settings.pin, deviceID, settings.wiredEnabled)
end

function _M.startSmartConnectClient(sc, settings)
    sc:writelock()

    local smart_mode = sc:get_smartmode()

    -- Master and Slave mode is not support.
    if smart_mode ~= 0 then
        return 'ErrorUnsupportedMode'
    end

    local wifi_status = sc:getevent(_M.WIFI_STATUS)
    local setup_status = sc:getevent(_M.SMART_CONNECT_SETUP_STATUS)

    if settings.wiredEnabled == true then
        if setup_status == 'READY' then
            sc:setevent(_M.SMART_CONNECT_SETUP_LASTERROR, '')
            sc:set_smartconnect_client(settings.wiredEnabled, settings.setupAP)
        else
            if setup_status == 'START' or setup_status == 'TEMP-AUTH' or setup_status == 'AUTH' or setup_status == 'DONE' then
                return 'ErrorSetupAlreadyInProgress'
            end
        end
    else
        if setup_status == 'READY' and wifi_status == 'started' then
            sc:setevent(_M.SMART_CONNECT_SETUP_LASTERROR, '')
            sc:set_smartconnect_client(settings.wiredEnabled, settings.setupAP)
        else
            if setup_status == 'START' or setup_status == 'TEMP-AUTH' or setup_status == 'AUTH' or setup_status == 'DONE' then
                return 'ErrorSetupAlreadyInProgress'
            else
                return '_ErrorNotReady'
            end
        end
    end
end

function _M.getSmartConnectStatus(sc, input)
    sc:readlock()

    local database = require('database')

    -- Master and Slave are differently working on SmartConnect setup progress.
    -- While smartconnect setup is in-progress, App can connect to the Slave and Master by using JNAP action.
    -- After finishing the smartconnect setup, App can not connect to the Slave node while setup progress,
    -- because slave's wifi has a Master's SSID.
    -- But BLE setup mode is a little bit different than JNAP over wifi, App can be access the slave node over BLE.
    -- So this action supports two mode(Master, Slave) to get the status of setup progress.

    local status = 'Ready'
    local pin = input.pin;
    local smart_mode = sc:get_smartmode()
    local setup_status = sc:getevent(_M.SMART_CONNECT_SETUP_STATUS)

    if smart_mode == 0 or smart_mode == 1 then
        -- In Unconfigureed or slave node, the setup_status can have a following values :
        -- 'READY', 'START', 'TEMP-AUTH', 'AUTH', 'DONE', 'ERROR'.
        if database.isUserWifiExistInSlave() then
            status = 'Success'
        else
            if setup_status ~= 'READY' and setup_status ~= 'DONE' then
                status = 'Connecting'
            elseif setup_status == 'DONE' then
                status = 'Success'
            elseif setup_status == 'ERROR' then
                status = 'Failed'
            end
        end
    elseif smart_mode == 2 then
        -- In master node
        local pin_status = sc:getevent(_M.SMART_CONNECT_PIN.."_"..pin)
        -- Check if the input PIN is in progress or not.
        if pin_status == 'config_done' then
            status = 'Success'
        elseif not pin_status or pin_status == '' then
            status = 'Ready'
        elseif pin_status == 'setup_ready' or pin_status == 'setup_done' or pin_status == 'preauth_done' then
            -- Setup is in progress, so return 'Connecting'
            status = 'Connecting'
        else
            status = 'Failed'
        end
    end

    return {
        status = status
    }
end


--
-- Request getting smart connect PIN from unconfigured node.
--
-- output = STRING
--
function _M.btRequestGetSmartConnectPIN(sc)
    sc:writelock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if bluetooth.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local requestId = bluetooth.btGetSmartConnectPIN()
    if not requestId then
        return 'ErrorBTRequestFailed'
    end

    return nil, requestId
end


--
-- Get the result of a request for getting smart connec PIN.
--
-- input = STRING
--
-- output = STRING
--
function _M.btGetSmartConnectPinResult(sc, input)
    sc:writelock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    local error, data = bluetooth.btGetResult(input)

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTGetSmartConnectPINRequestFailed'
    end

    if error then
        return error, nil
    end

    return nil, data.pin
end


--
-- Request getting status of smart connect from unconfigured node.
--
-- output = STRING
--
function _M.btRequestGetSmartConnectStatus(sc, input)
    sc:writelock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if bluetooth.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local requestId = bluetooth.btGetSmartConnectStatus(input.pin)
    if not requestId then
        return 'ErrorBTRequestFailed'
    end

    return nil, requestId
end


--
-- Get the result of a request for getting status of smart connec.
--
-- input = STRING
--
-- data = STRING
--
function _M.btGetSmartConnectStatusResult(sc, input)
    sc:writelock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    local error, data = bluetooth.btGetResult(input)
    local status = 'Failed'

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTGetSmartConnectStatusRequestFailed'
    end

    if error then
        return error, nil
    end

    if data.status ~= 'READY' and data.status ~= 'DONE' then
        status = 'Connecting'
    elseif data.status == 'DONE' then
        status = 'Success'
    elseif data.status == 'ERROR' then
        status = 'Failed'
    end

    return nil, status
end


--
-- Request starting the smart connect client to unconfigured node.
--
-- input = STRING
--
-- output = STRING
--
function _M.btRequestStartSmartConnectClient(sc, input)
    sc:writelock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if bluetooth.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local requestId = bluetooth.btStartSmartConnectClient(input.setupAP)
    if not requestId then
        return 'ErrorBTRequestFailed'
    end

    return nil, requestId
end


--
-- Get the result of a request for getting status of smart connect.
--
-- input = STRING
--
--
function _M.btGetStartSmartConnectClientResult(sc, input)
    sc:writelock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    local error = bluetooth.btGetResult(input)

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTStartSmartConnectClientRequestFailed'
    end

    return error or nil
end

function getOnboardingStatus(sc)
    local setup_status = sc:getevent(_M.SMART_CONNECT_SETUP_STATUS)
    local setup_lasterror = sc:getevent(_M.SMART_CONNECT_SETUP_LASTERROR)

    local state, progress

    if setup_status == 'READY' then
        state, progress = 'Idle', ''
    elseif setup_status == 'DONE' then
        state, progress = 'Onboarding', 'Success'
    else
        if setup_lasterror == 'SETUPAP_ERROR' or setup_lasterror == 'CFGSETTING_ERROR' or setup_lasterror == 'PRE-AUTH_ERROR' or setup_lasterror == 'AUTH_ERROR' then
            state, progress = 'Onboarding', 'Failed'
        else
            state, progress = 'Onboarding', 'Running'
        end
    end

    -- TODO: We shouldn't set any sysevent on a Get action
    -- Faking a state should be avoided.
    if state == 'Idle' or state == 'Onboarding' then
        sc:setevent(_M.SETUP_STAGE, state)
        sc:setevent(_M.SETUP_PROGRESS, progress)
    end

    return state, progress
end

function getConnectivityOptimization(sc)
    local backhaul_status = sc:getevent(_M.BACKHAUL_STATUS)
    local backhaul_intf = sc:getevent(_M.BACKHAUL_INTF)
    local backhaul_bssid = sc:getevent(_M.BACKHAUL_PREFERRED_BSSID)

    local state, progress

    if backhaul_status == 'down' then
        if backhaul_bssid and backhaul_bssid ~= '' then
            state, progress = 'ConnectivityOptimization', 'Running'
        else
            state, progress = 'ConnectivityOptimization', 'NotStarted'
        end
    elseif backhaul_status == 'up' and backhaul_intf and backhaul_intf ~= '' then
        state, progress = 'ConnectivityOptimization', 'Success'
    end

    -- TODO: We shouldn't set any sysevent on a Get action
    -- Faking a state should be avoided.
    if state == 'ConnectivityOptimization' and progress ~= 'NotStarted' then
        sc:setevent(_M.SETUP_STAGE, state)
        sc:setevent(_M.SETUP_PROGRESS, progress)
    end

    return state, progress
end

function getBackhaulPerformance(sc)
    local backhaul_l3perf = sc:getevent(_M.BACKHAUL_L3_PERF)

    local state, progress

    local setup_stage = sc:getevent(_M.SETUP_STAGE)
    local setup_progress = sc:getevent(_M.SETUP_PROGRESS)

    if backhaul_l3perf and backhaul_l3perf ~= '' then
        state, progress = 'BackhaulPerformance', 'Success'
    else
        if setup_stage == 'ConnectivityOptimization' and setup_progress == 'Success' then
            state, progress = 'BackhaulPerformance', 'NotStarted'
        elseif setup_stage == 'BackhaulPerformance' and (setup_progress == 'NotStarted' or setup_progress == 'Running') then
            state, progress = 'BackhaulPerformance', 'Running'
        end
    end

    -- TODO: We shouldn't set any sysevent on a Get action
    -- Faking a state should be avoided.
    if state == 'BackhaulPerformance' then
        sc:setevent(_M.SETUP_STAGE, state)
        sc:setevent(_M.SETUP_PROGRESS, progress)
    end

    return state, progress
end

function _M.getSlaveSetupStatus(sc, input)
    sc:readlock()
    local hdk = require('libhdklua')
    local device = require('device')

    local smart_mode = sc:get_smartmode()

    local onboarding, ob_progress
    local connectivity, cn_progress
    local backhaulperf, bh_progress
    local slaveSetupStatus = {}
    local deviceID

    -- If a device is Master node.
    if smart_mode == 2 then
        if input.deviceID == nil then
            return 'ErrorMissingDeviceID'
        else
            return bluetooth.btGetSlaveSetupStatus(sc, tostring(input.deviceID))
        end
    else
        -- If a device is Unconfigured or Slave node.
        if input.deviceID ~= nil then
            deviceID = hdk.uuid(device.getUUID(sc))
            if input.deviceID ~= deviceID then
                return 'ErrorUnknownDevice'
            end
        end

        local setup_stage = sc:getevent(_M.SETUP_STAGE)
        local setup_progress = sc:getevent(_M.SETUP_PROGRESS)
        local setup_lasterror = sc:getevent(_M.SMART_CONNECT_SETUP_LASTERROR)

        slaveSetupStatus.slaveSetupLastError = (setup_lasterror and setup_lasterror ~= '') and setup_lasterror or nil

        -- First off, check if the Backhaul is complete or backhaul performance is reday to run or running.
        backhaulperf, bh_progress = getBackhaulPerformance(sc)
        if backhaulperf == 'BackhaulPerformance' then
            slaveSetupStatus['slaveSetupState'] = backhaulperf
            slaveSetupStatus['slaveSetupProgress'] = bh_progress
            return nil, slaveSetupStatus
        end

        onboarding, ob_progress = getOnboardingStatus(sc)
        slaveSetupStatus['slaveSetupState'] = onboarding
        if ob_progress ~= '' then
            slaveSetupStatus['slaveSetupProgress'] = ob_progress
        end

        -- If backhaul is ready to run or running, backhaul status is returned.
        -- If backhaul is not ready (NotStarted), Onboarding(SmartConnect) status is returned.
        connectivity, cn_progress = getConnectivityOptimization(sc)
        if connectivity == 'ConnectivityOptimization' and cn_progress ~= 'NotStarted' then
            slaveSetupStatus['slaveSetupState'] = connectivity
            slaveSetupStatus['slaveSetupProgress'] = cn_progress
        end

        return nil, slaveSetupStatus
    end
end

function _M.getSlaveSetupStatus2(sc, input)
    sc:readlock()
    local hdk = require('libhdklua')
    local device = require('device')

    local smart_mode = sc:get_smartmode()

    local onboarding, ob_progress
    local connectivity, cn_progress
    local backhaulperf, bh_progress
    local slaveSetupStatus = {}
    local deviceID

    -- If a device is Master node.
    if smart_mode == 2 then
        return 'ErrorUnsupportedMode'
    else
        local setup_stage = sc:getevent(_M.SETUP_STAGE)
        local setup_progress = sc:getevent(_M.SETUP_PROGRESS)
        local setup_lasterror = sc:getevent(_M.SMART_CONNECT_SETUP_LASTERROR)

        slaveSetupStatus.slaveSetupLastError = (setup_lasterror and setup_lasterror ~= '') and setup_lasterror or nil

        -- First off, check if the Backhaul is complete or backhaul performance is reday to run or running.
        backhaulperf, bh_progress = getBackhaulPerformance(sc)
        if backhaulperf == 'BackhaulPerformance' then
            slaveSetupStatus['slaveSetupState'] = backhaulperf
            slaveSetupStatus['slaveSetupProgress'] = bh_progress
            return nil, slaveSetupStatus
        end

        onboarding, ob_progress = getOnboardingStatus(sc)
        slaveSetupStatus['slaveSetupState'] = onboarding
        if ob_progress ~= '' then
            slaveSetupStatus['slaveSetupProgress'] = ob_progress
        end

        -- If backhaul is ready to run or running, backhaul status is returned.
        -- If backhaul is not ready (NotStarted), Onboarding(SmartConnect) status is returned.
        connectivity, cn_progress = getConnectivityOptimization(sc)
        if connectivity == 'ConnectivityOptimization' and cn_progress ~= 'NotStarted' then
            slaveSetupStatus['slaveSetupState'] = connectivity
            slaveSetupStatus['slaveSetupProgress'] = cn_progress
        end

        return nil, slaveSetupStatus
    end
end

function _M.smartConnectConfigure(sc, input)
    sc:writelock()
    local hdk = require('libhdklua')

    local smart_mode = sc:get_smartmode()

    if smart_mode ~= 0 then
        return 'ErrorDeviceNotInUnconfiguredMode'
    end

    if not (require('smartmode').isSupportedMode(sc, 'Slave')) then
        return 'ErrorUnsupportedMode'
    end

    -- If a device is Unconfigured.
    sc:set_smartconnect_configured_ssid(input.configApSsid);
    sc:set_smartconnect_configured_passphrase(input.configApPassphrase);
    sc:set_smartconnect_auth_login(input.srpLogin);
    sc:set_smartconnect_auth_pass(input.srpPassword);
    sc:set_smartmode(1)
    sc:set_bridge_mode_wo_reboot(1)
    sc:set_wifibridge_mode_wo_event(2)
    -- Configure smartconnect data to the smartconnect client database.
    -- TODO: If we want to make this action xsafe, then we need another way of doing these os.execute() commands.
    os.execute('smcdb_cli create')
    os.execute('smcdb_cli update -s '..input.configApSsid..' -p '..input.configApPassphrase..' -l '..input.srpLogin..' -a '..input.srpPassword)
    sc:set_smartconnect_setup_restart()
    return nil
end

function _M.getOnboardingStatus(sc, input)
    sc:readlock()

    if sc:get_smartmode() ~= 2 then
        return 'ErrorDeviceNotInMasterMode'
    end
    local status, wifiConnInfo
    local deviceID = tostring(input.deviceID):upper()
    local setupStatus = sc:get_smartconnect_setup_status(deviceID)
    local json = require('libhdkjsonlua')
    local hdk = require('libhdklua')

    if not setupStatus or setupStatus == '' then
        status = 'Unknown'
    elseif setupStatus == 'config_done' then
        status = 'Success'
    elseif setupStatus == 'setup_ready' or setupStatus == 'setup_done' or setupStatus == 'preauth_done' then
        -- Smart connect setup is in progress
        status = 'Running'
    else
        status = 'Failed'
    end

    local nodes_util = require('nodes_util')
    local path = require('util').concatPaths({
        nodes_util.getSubscriberFilePrefix(sc),
        nodes_util.MSG_SMARTCONNECT_DIR
    })
    local cmd = string.format('find %s -name client_conn_info 2>/dev/null', path)
    local connInfoFile = require('util').chomp(io.popen(cmd):read('*a'))
    local fh = io.open(connInfoFile)
    if fh then
        local data = json.parse(fh:read('*a'))
        fh:close()
        wifiConnInfo = data and {
            apDeviceID = hdk.uuid(data.apDeviceID),
            txRateMbps = tonumber(data.txRate),
            rxRateMbps = tonumber(data.rxRate),
            signalStrength = tonumber(data.signalStrength),
            idleTimeSeconds = tonumber(data.idleTime),
        }
    end

    return nil, {
        onboardingStatus = status,
        wirelessConnectionInfo = wifiConnInfo,
        onboardingError = sc:get_smartconnect_setup_error(deviceID)
    }
end

return _M   -- return the module.
