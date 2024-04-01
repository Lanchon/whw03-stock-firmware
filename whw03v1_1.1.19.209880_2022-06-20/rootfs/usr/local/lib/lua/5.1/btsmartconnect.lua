--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

-- btsmartconnect.lua - library to access the smartconnect settings.

local bluetooth = require('bluetooth')

local _M = {}   --create the module

_M.unittest = {} -- unit test override data store

--
-- Request getting smart connect PIN from unconfigured node.
--
-- output = STRING
--
function _M.btRequestGetSmartConnectPIN(sc)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if bluetooth.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local status = sc:get_btgetsmartconnectpin_status()
    if status == 'Running' then
        return 'ErrorBTGetSmartConnectPINRequestIsAlreadyInProgress'
    end

    local ret = bluetooth.btGetSmartConnectPIN2()
    if not ret then
        return 'ErrorBTRequestFailed'
    end

    return nil
end


--
-- Get the result of a request for getting smart connec PIN.
--
-- output = STRING
--
function _M.btGetSmartConnectPINResult(sc)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    local output = { isRunning = false }
    local status = sc:get_btgetsmartconnectpin_status()
    if status == 'Running' then
        output.isRunning = true
        return nil, output
    end

    local input = { request = 'getsmartconnectpin' }
    local error, data = bluetooth.btGetResult2(input)
    if error then
        if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
            error = 'ErrorBTGetSmartConnectPINRequestFailed'
        end
        output = nil
        return error, output
    end

    -- BTRequestGetSmartConnectPIN was not triggered.
    if not data then
        output.isRunning = false
        return nil, output
    end

    output.isRunning = false
    output.pin = data.pin

    return nil, output
end


--
-- Request getting status of smart connect from unconfigured node.
--
-- input = STRING
--
-- output = STRING
--
function _M.btRequestGetSmartConnectStatus(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if bluetooth.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local status = sc:get_btgetsmartconnectstatus_status()
    if status == 'Running' then
        return 'ErrorBTGetSmartConnectStatusRequestIsAlreadyInProgress'
    end

    local ret = bluetooth.btGetSmartConnectStatus2(input.pin)
    if not ret then
        return 'ErrorBTRequestFailed'
    end

    return nil
end


--
-- Get the result of a request for getting status of smart connec.
--
-- input = STRING
--
-- data = STRING
--
function _M.btGetSmartConnectStatusResult(sc)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    local output = { isRunning = false }
    local status = sc:get_btgetsmartconnectstatus_status()
    if status == 'Running' then
        output.isRunning = true
        return nil, output
    end

    local input = { request = 'getsmartconnectstatus' }
    local error, data = bluetooth.btGetResult2(input)
    local status = 'Failed'

    if error then
        if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
            error = 'ErrorBTGetSmartConnectStatusRequestFailed'
        end
        output = nil
        return error, output
    end

    -- BTRequestGetSmartConnectStatus was not triggered.
    if not data then
        output.isRunning = false
        return nil, output
    end

    if data.status ~= 'READY' and data.status ~= 'DONE' then
        status = 'Connecting'
    elseif data.status == 'DONE' then
        status = 'Success'
    elseif data.status == 'ERROR' then
        status = 'Failed'
    end

    output.isRunning = false
    output.status = status

    return nil, output
end


--
-- Request starting the smart connect client to unconfigured node.
--
-- input = STRING
--
-- output = STRING
--
function _M.btRequestStartSmartConnectClient(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if bluetooth.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local status = sc:get_btstartsmartconnectclient_status()
    if status == 'Running' then
        return 'ErrorBTStartSmartConnectClientRequestIsAlreadyInProgress'
    end

    local ret = bluetooth.btStartSmartConnectClient2(input.setupAP)
    if not ret then
        return 'ErrorBTRequestFailed'
    end

    return nil
end


--
-- Get the result of a request for getting status of smart connect.
--
-- input = STRING
--
--
function _M.btGetStartSmartConnectClientResult(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    local output = { isRunning = false }
    local status = sc:get_btstartsmartconnectclient_status()
    if status == 'Running' then
        output.isRunning = true
        return nil, output
    end

    local input = { request = 'startsmartconnectclient' }
    local error, data = bluetooth.btGetResult2(input)
    if error then
        if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
            error = 'ErrorBTStartSmartConnectClientRequestFailed'
        end
        output = nil
        return error, output
    end

    -- BTRequestStartSmartConnectClient was not triggered.
    if not data then
        output.isRunning = false
        return nil, output
    end

    output.isRunning = false

    return nil, output
end

--
-- Request getting the slave setup status to unconfigured node.
--
-- input = STRING
--
-- output = STRING
--
function _M.btRequestGetSlaveSetupStatus(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if bluetooth.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local status = sc:get_btgetslavesetupstatus_status()
    if status == 'Running' then
        return 'ErrorBTGetSlaveSetupStatusRequestIsAlreadyInProgress'
    end

    local ret = bluetooth.btGetSlaveSetupStatus2(tostring(input.deviceID))
    if not ret then
        return 'ErrorBTRequestFailed'
    end

    return nil
end


--
-- Get the result of a request for getting status of smart connect.
--
-- input = STRING
--
--
function _M.btGetSlaveSetupStatusResult(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    local output = { isRunning = false }
    local status = sc:get_btgetslavesetupstatus_status()
    if status == 'Running' then
        output.isRunning = true
        return nil, output
    end

    local input = { request = 'getslavesetupstatus' }
    local error, data = bluetooth.btGetResult2(input)

    if error then
        if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
            error = 'ErrorBTGetSlaveSetupStatusRequestFailed'
        end
        output = nil
        return error, output
    end

    -- BTRequestGetSlaveSetupStatus was not triggered.
    if not data then
        output.isRunning = false
        return nil, output
    end

    if data.slaveSetupState then
        output.slaveSetupState = data.slaveSetupState
    end

    if data.slaveSetupProgress then
        output.slaveSetupProgress = data.slaveSetupProgress
    end

    output.isRunning = false

    return nil, output
end

--
-- Request getting the version info to unconfigured node.
--
-- input = STRING
--
-- output = STRING
--
function _M.btRequestGetVersionInfo(sc)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if bluetooth.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local status = sc:get_btgetversioninfo_status()
    if status == 'Running' then
        return 'ErrorBTGetVersionInfoRequestIsAlreadyInProgress'
    end

    local ret = bluetooth.btGetVersionInfo2()
    if not ret then
        return 'ErrorBTRequestFailed'
    end

    return nil
end

--
-- Get the result of a request for getting version info.
--
-- input = STRING
--
--
function _M.btGetVersionInfoResult(sc)
    sc:readlock()

    local mode = sc:get_smartmode()
    if not bluetooth.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    local output = { isRunning = false }
    local status = sc:get_btgetversioninfo_status()
    if status == 'Running' then
        output.isRunning = true
        return nil, output
    end

    local input = { request = 'getversioninfo' }
    local error, data = bluetooth.btGetResult2(input)

    if error then
        if error == 'error_get_result_fail' then
            error = 'ErrorBTGetVersionInfoRequestFailed'
        elseif error == 'error_jnap_unknown_action' then
            error = 'ErrorUnknownActionFromBT'
        end
        output = nil
        return error, output
    end

    -- BTRequestGetVersionInfo was not triggered.
    if not data then
        output.isRunning = false
        return nil, output
    end

    output.isRunning = false
    output.modelNumber = data.modelNumber
    output.hardwareVersion = data.hardwareVersion

    return nil, output
end

return _M   -- return the module.
