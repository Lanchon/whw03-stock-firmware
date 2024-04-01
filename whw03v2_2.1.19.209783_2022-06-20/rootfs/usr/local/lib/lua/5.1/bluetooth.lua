--
-- 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2020/10/29 22:44:11 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/nodes/bluetooth.lua#5 $
--

-- smartconnect.lua - library to access the smartconnect settings.

local hdk = require('libhdklua')
local platform = require('platform')

local _M = {}   --create the module

_M.CENTRAL_CMD = '/usr/bin/btsetup_central'
_M.RUN_CENTRAL_CMD_SYNC = '/usr/bin/btsetup_central %s'
_M.RUN_CENTRAL_CMD = '/etc/init.d/run_central.sh %s &'
_M.RUN_CENTRAL2_CMD = '/etc/init.d/run_central2.sh %s &'
_M.CENTRAL_CMD_RESULT = '/tmp/central.txt'
_M.PS_CMD = 'ps'


local function btRunCentralCommand(option, value)

    assert(option)

    local requestId
    local command = option

    if value then
        command = command..' '..value
    end

    local file = io.popen(_M.RUN_CENTRAL_CMD:format(command))
    if file then
        requestId = file:read()
        file:close()
    else
        return nil
    end

    return requestId
end

local function btRunCentralCommand2(option, value)

    assert(option)

    local requestId
    local command = option

    if value then
        command = command..' '..value
    end

    local file = io.popen(_M.RUN_CENTRAL2_CMD:format(command))
    if file then
        requestId = file:read()
        file:close()
    else
        return nil
    end

    return requestId
end


local function btRunCentralCommandSync(option)

    assert(option)

    local output = {}
    local table
    local jsonData
    local json = require('libhdkjsonlua')

    local file = io.popen(_M.RUN_CENTRAL_CMD_SYNC:format(option))
    if file then
        jsonData = file:read('*a')
        file:close()

        -- Parsing result
        table = json.parse(jsonData)
        if not table then
            platform.logMessage(platform.LOG_ERROR, ('Failed parsing JSON data\n'))
            return 'error_get_result_fail'
        end

        if table.result == 'error_bt' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred\n'):format(table.result))
            return 'error_get_result_fail'
        end

        if table.result == 'error_jnap_req_fail' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred\n'):format(table.result))
            return 'error_get_result_fail'
        end

        if table.result == 'error_jnap_unknown_action' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'error_jnap_unknown_action'
        end

        if table.result == 'error_not_connected' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred\n'):format(table.result))
            return 'ErrorBTNotConnected'
        end

        if table.result == 'error_conn_lost' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred\n'):format(table.result))
            return 'ErrorBTConnectionLost'
        end

        if table.result == 'error_notify_timeout' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred\n'):format(table.result))
            return 'ErrorBTPeripheralNotRespond'
        end

        if table.result == 'error_command_fail' or table.result == 'bt_api_fail' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred\n'):format(table.result))
            return 'ErrorBTCommandFailed'
        end

        if table.result == 'error_notify_enable_fail'
            or table.result == 'error_gatt_read_fail'
            or table.result == 'error_gatt_write_fail' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred\n'):format(table.result))
            return 'ErrorBTCommunicationFailed'
        end

       output = table
    end

    return nil, output
end

local function btScanUnconfigured(duration)
    return btRunCentralCommand('-d', duration)
end

local function btScanUnconfigured2(duration)
    return btRunCentralCommand2('-d', duration)
end

local function btScanBackhaulDownSlave(duration)
    return btRunCentralCommand('-D', duration)
end

local function btScanBackhaulDownSlave2(duration)
    return btRunCentralCommand2('-D', duration)
end

local function btConnect(address)
    return btRunCentralCommand('-c', address)
end

local function btConnect2(address)
    return btRunCentralCommand2('-c', address)
end

local function btDisconnect()
    return btRunCentralCommand('-t', nil)
end

local function btDisconnect2()
    return btRunCentralCommand2('-t', nil)
end

--
-- Check if mode is Central.
--
-- output = boolean
--
function _M.isCentral(mode)
    if mode == 2 then
        return true
    end

    return false
end

--
-- Get the status of ble central
--
-- output = STRING
--
function _M.btCheckCentralWorking()

    -- Check to see if ble central is running
    local file = io.popen(_M.PS_CMD)
    if file then
        for line in file:lines() do
            if line:match('.*%s'.._M.CENTRAL_CMD..'%s*') then
                file:close()
                return true
            end
        end
        file:close()
    end

    return false
end

function _M.btGetSmartConnectPIN()
    return btRunCentralCommand('-p', nil)
end

function _M.btGetSmartConnectPIN2()
    return btRunCentralCommand2('-p', nil)
end

function _M.btGetSmartConnectStatus(pin)
    return btRunCentralCommand('-s', pin)
end

function _M.btGetSmartConnectStatus2(pin)
    return btRunCentralCommand2('-s', pin)
end

function _M.btStartSmartConnectClient(setupap)
    return btRunCentralCommand('-S', setupap)
end

function _M.btStartSmartConnectClient2(setupap)
    return btRunCentralCommand2('-S', setupap)
end

function _M.btGetSlaveSetupStatus(sc, uuid)
    sc:readlock()

    local opt = '-g -U %s -J %s'
    local nodes_util = require('nodes_util')

    -- If the Slave node hasn't come on-line,
    -- then the Master admin password hasn't been sync'd to it,
    -- so use the default admin password for JNAP authorization.
    -- Otherwise, use the Master admin password.
    local adminUsername = sc:get_admin_username()
    local adminPassword = platform.DEFAULT_ADMIN_PASSWORD
    if nodes_util.isSlaveOnline(sc, uuid) then
        adminPassword = sc:get_admin_password_raw()
    end
    -- Create the basic auth string for the JNAP request
    local cmd = ('echo -n "%s:%s" | base64'):format(adminUsername, adminPassword)
    local auth = io.popen(cmd):read('*a')

    local error, output = btRunCentralCommandSync(opt:format(uuid, auth))

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTGetSlaveSetupStatusFailed'
    end

    return error, output
end

function _M.btGetSlaveSetupStatus2(uuid)
    return btRunCentralCommand2('-g', uuid)
end

function _M.btGetVersionInfo2(uuid)
    return btRunCentralCommand2('-V', uuid)
end

function _M.btGetDeviceMode()
    return btRunCentralCommand('-m', nil)
end

function _M.btGetDeviceID(mac)
    local opt = '-i '..mac
    local error, output = btRunCentralCommandSync(opt)

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTGetDeviceIDFailed'
    end

    return error, output
end

--
-- Get the status of a request for discovering unconfigured nodes.
--
-- input = STRING
--
-- output = STRING
--
function btGetRequestStatus(requestId)
    local status = 'Invalid'
    local pid = string.gsub(requestId, '_.*', '')

    -- Check to see if the request is running
    local file = io.popen('ps')
    if file then
        for line in file:lines() do
            if line:match('^%s*'..pid..'%s.*') then
                status = 'Running'
                break
            end
        end
        file:close()
    end

    -- If the request is not running, then check for the output file(s)
    if (status ~= 'Running') then
        file = io.open(_M.CENTRAL_CMD_RESULT..'.'..requestId)
        if file then
            status= 'Complete'
            file:close()
        end
    end

    return status
end

function _M.btGetResult(input)
    local output = {}
    local table
    local jsonData
    local json = require('libhdkjsonlua')

    local reqStatus = btGetRequestStatus(input.requestId)

    if reqStatus == 'Invalid' then
        return 'ErrorInvalidBTRequestId'
    elseif reqStatus == 'Running' then
        return 'ErrorBTDataNotReady'
    end

    --
    -- Generate the result table
    --
    local file = io.open(_M.CENTRAL_CMD_RESULT..'.'..input.requestId)
    if file then
        jsonData = file:read('*a')
        file:close()

        -- Parsing result
        table = json.parse(jsonData)
        if not table then
            platform.logMessage(platform.LOG_ERROR, ('Failed parsing JSON data : %s\n'):format(input.requestId))
            return 'error_get_result_fail'
        end

        if table.result == 'error_bt' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.requestId))
            return 'error_get_result_fail'
        end

        if table.result == 'error_jnap_req_fail' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.requestId))
            return 'error_get_result_fail'
        end

        if table.result == 'error_jnap_unknown_action' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'error_jnap_unknown_action'
        end

        if table.result == 'error_not_connected' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.requestId))
            return 'ErrorBTNotConnected'
        end

        if table.result == 'error_conn_lost' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.requestId))
            return 'ErrorBTConnectionLost'
        end

        if table.result == 'error_notify_timeout' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.requestId))
            return 'ErrorBTPeripheralNotRespond'
        end

        if table.result == 'error_command_fail' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.requestId))
            return 'ErrorBTCommandFailed'
        end

        if table.result == 'error_notify_enable_fail'
            or table.result == 'error_gatt_read_fail'
            or table.result == 'error_gatt_write_fail' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.requestId))
            return 'ErrorBTCommunicationFailed'
        end

       output = table
    end

    return nil, output
end

function _M.btGetResult2(input)
    local output = {}
    local table
    local jsonData
    local json = require('libhdkjsonlua')

    --
    -- Generate the result table
    --
    local file = io.open(_M.CENTRAL_CMD_RESULT..'.'..input.request)
    if file then
        jsonData = file:read('*a')
        file:close()
        os.remove(_M.CENTRAL_CMD_RESULT..'.'..input.request)

        -- Parsing result
        table = json.parse(jsonData)
        if not table then
            platform.logMessage(platform.LOG_ERROR, ('Failed parsing JSON data : %s\n'):format(input.request))
            return 'error_get_result_fail'
        end

        if table.result == 'error_bt' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'error_get_result_fail'
        end

        if table.result == 'error_jnap_req_fail' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'error_get_result_fail'
        end

        if table.result == 'error_jnap_unknown_action' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'error_jnap_unknown_action'
        end

        if table.result == 'error_not_connected' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'ErrorBTNotConnected'
        end

        if table.result == 'error_conn_lost' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'ErrorBTConnectionLost'
        end

        if table.result == 'error_notify_timeout' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'ErrorBTPeripheralNotRespond'
        end

        if table.result == 'error_command_fail' or table.result == 'bt_api_fail' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'ErrorBTCommandFailed'
        end

        if table.result == 'error_notify_enable_fail'
            or table.result == 'error_gatt_read_fail'
            or table.result == 'error_gatt_write_fail' then
            platform.logMessage(platform.LOG_ERROR, ('JNAP error(%s) occurred : %s\n'):format(table.result, input.request))
            return 'ErrorBTCommunicationFailed'
        end

        output = table
    else
        output = nil
    end

    return nil, output
end

--
-- Request finding unconfigured nodes for duration
--
-- input = CONTEXT,
--     duration = STRING
--
-- output = STRING
--
function _M.btRequestScanUnconfigured(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if not input.duration or input.duration < 0  or input.duration > 30 then
        return 'ErrorInvalidDuration'
    end

    if _M.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local requestId = btScanUnconfigured(tostring(input.duration))
    if not requestId then
        return 'ErrorBTRequestFailed'
    end

    return nil, requestId
end

--
-- Request finding unconfigured nodes for duration
--
-- input = CONTEXT,
--     duration = STRING
--
-- output = STRING
--
function _M.btRequestScanUnconfigured2(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if not input.duration or input.duration < 0  or input.duration > 30 then
        return 'ErrorInvalidDuration'
    end

    if _M.btCheckCentralWorking() then
        -- own process or other process is working.
        return 'ErrorBTCentralAlreadyWorking'
    end

    local status = sc:get_btscanunconfigured_status()
    if status == 'Running' then
        return 'ErrorBTScanUnconfigured2RequestIsAlreadyInProgress'
    end

    local ret = btScanUnconfigured2(tostring(input.duration))
    if not ret then
        return 'ErrorBTRequestFailed'
    end

    return nil
end

--
-- Get the result of a request for discovering unconfigured nodes.
--
-- input = STRING
--
-- output = BTDiscoveryData[]
--
function _M.btGetScanResult(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode', nil
    end

    local error, data = _M.btGetResult(input)

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTScanRequestFailed'
    end

    if error then
        return error, nil
    end

    -- Change mac address string to MACAddress object
    local output = {}
    for k, v in pairs(data.discovery) do
        local device = {}
        device.name = v.name
        device.macAddress = hdk.macaddress(v.macAddress)
        if v.modeLimit then
            device.modeLimit = v.modeLimit
        end
        device.rssi = v.rssi
        table.insert(output, device)
    end

    return nil, output
end


--
-- Get the result of a request for discovering unconfigured nodes.
--
-- input = STRING
--
-- output = BTDiscoveryData[]
--
function _M.btGetScanUnconfiguredResult2(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode', nil
    end

    local output = { isRunning = false }
    local status = sc:get_btscanunconfigured_status()
    if status == 'Running' then
        output.isRunning = true
        return nil, output
    end

    local input = { request = "scanunconfigured" }
    local error, data = _M.btGetResult2(input)
    if error then
        if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
            error = 'ErrorBTScanUnconfigured2RequestFailed'
        end
        output = nil
        return error, output
    end

    -- BTRequestScanUnconfigured2 was not triggered.
    if not data then
        output.isRunning = false
        return nil, output
    end

    -- Change mac address string to MACAddress object
    local discovery = {}
    for k, v in pairs(data.discovery) do
        local device = {}
        device.name = v.name
        device.macAddress = hdk.macaddress(v.macAddress)
        if v.modeLimit then
            device.modeLimit = v.modeLimit
        end
        device.rssi = v.rssi
        table.insert(discovery, device)
    end

    output.isRunning = false
    output.discovery = discovery

    return nil, output
end


--
-- Request connection to unconfigured nodes
--
-- input = CONTEXT,
--     macAddress = MACAddress
--
-- output = STRING
--
function _M.btRequestConnect(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if _M.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local requestId = btConnect(tostring(input.macAddress))
    if not requestId then
        return 'ErrorBTRequestFailed'
    end

    return nil, requestId
end

--
-- Request connection to unconfigured nodes
--
-- input = CONTEXT,
--     macAddress = MACAddress
--
-- output = STRING
--
function _M.btRequestConnect2(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if _M.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local status = sc:get_btconnect_status()
    if status == 'Running' then
        return 'ErrorBTConnect2RequestIsAlreadyInProgress'
    end

    local ret = btConnect2(tostring(input.macAddress))
    if not ret then
        return 'ErrorBTRequestFailed'
    end

    return nil
end

--
-- Get the result of a request for connecting to unconfigured node.
--
-- input = STRING
--
-- output = BTConnectionStatus
--
function _M.btGetConnectResult(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode', nil
    end

    local error, data = _M.btGetResult(input)
    local status = nil

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTConnectRequestFailed'
    end

    if error then
        return error, nil
    end

    return nil, data.status
end

--
-- Get the result of a request for connecting to unconfigured node.
--
-- input = STRING
--
-- output = BTConnectionStatus
--
function _M.btGetConnectResult2(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode', nil
    end

    local output = { isRunning = false }
    local status = sc:get_btconnect_status()
    if status == 'Running' then
        output.isRunning = true
        return nil, output
    end


    local input = { request = 'connect' }
    local error, data = _M.btGetResult2(input)
    if error then
        if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
            error = 'ErrorBTConnect2RequestFailed'
        end
        output = nil
        return error, output
    end

    -- BTRequestConnect2 was not triggered.
    if not data then
        output.isRunning = false
        return nil, output
    end

    output.isRunning = false
    output.status = data.status

    return nil, output
end


--
-- Request disconnection from unconfigured nodes
--
-- output = STRING
--
function _M.btRequestDisconnect(sc)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if _M.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local requestId = btDisconnect()
    if not requestId then
        return 'ErrorBTRequestFailed'
    end

    return nil, requestId
end

--
-- Request disconnection from unconfigured nodes
--
-- output = STRING
--
function _M.btRequestDisconnect2(sc)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode'
    end

    if _M.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local status = sc:get_btdisconnect_status()
    if status == 'Running' then
        return 'ErrorBTDisconnect2RequestIsAlreadyInProgress'
    end

    local ret = btDisconnect2()
    if not ret then
        return 'ErrorBTRequestFailed'
    end

    return nil
end

--
-- Get the result of a request for disconnecting to unconfigured node.
--
-- input = STRING
--
-- output = BTConnectionStatus
--
function _M.btGetDisconnectResult(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode', nil
    end

    local error, data = _M.btGetResult(input)

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTDisconnectRequestFailed'
    elseif error == 'error_not_connected' then
        error = 'ErrorBTNotConnected'
    end

    if error then
        return error, nil
    end

    return nil, data.status
end

--
-- Get the result of a request for disconnecting to unconfigured node.
--
-- input = STRING
--
-- output = BTConnectionStatus
--
function _M.btGetDisconnectResult2(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTUnsupportedMode', nil
    end

    output = { isRunning = false }
    local status = sc:get_btdisconnect_status()
    if status == 'Running' then
        output.isRunning = true
        return nil, output
    end

    local input = { request = 'disconnect' }
    local error, data = _M.btGetResult2(input)

    if error then
        if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
            error = 'ErrorBTDisconnect2RequestFailed'
        end
        output = nil
        return error, output
    end

    -- BTRequestDisconnect2 was not triggered.
    if not data then
        output.isRunning = false
        return nil, output
    end

    output.isRunning = false
    output.status = data.status

    return nil, output
end


--
-- Request finding Slaves backhaul is down for duration
--
-- input = CONTEXT,
--     duration = STRING
--
-- output = STRING
--
function _M.btRequestScanBackhaulDownSlave(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTNotInMasterMode'
    end

    if not input.duration or input.duration < 0  or input.duration > 30 then
        return 'ErrorInvalidDuration'
    end

    if _M.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local requestId = btScanBackhaulDownSlave(tostring(input.duration))
    if not requestId then
        return 'ErrorBTRequestFailed'
    end

    return nil, requestId
end

--
-- Request finding Slaves backhaul is down for duration
--
-- input = CONTEXT,
--     duration = STRING
--
-- output = STRING
--
function _M.btRequestScanBackhaulDownSlave2(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTNotInMasterMode'
    end

    if not input.duration or input.duration < 0  or input.duration > 30 then
        return 'ErrorInvalidDuration'
    end

    if _M.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local status = sc:get_btscanbackhauldownslave_status()
    if status == 'Running' then
        return 'ErrorBTScanBackhaulDownSlave2RequestIsAlreadyInProgress'
    end

    local ret = btScanBackhaulDownSlave2(tostring(input.duration))
    if not ret then
        return 'ErrorBTRequestFailed'
    end

    return nil
end



--
-- Get the result of a request for discovering Slaves backhaul is down.
--
-- input = STRING
--
-- output = BTDiscoveryData[]
--
function _M.btGetScanBackhaulDownSlaveResult(sc, input)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTNotInMasterMode'
    end

    local error, data = _M.btGetResult(input)

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTScanRequestFailed'
    end

    if error then
        return error, nil
    end

    -- Change mac address string to MACAddress object
    local output = {}
    for k, v in pairs(data.discovery) do
        local device = {}
        device.name = v.name
        device.macAddress = hdk.macaddress(v.macAddress)
        if v.modeLimit then
            device.modeLimit = v.modeLimit
        end
        device.rssi = v.rssi
        table.insert(output, device)
    end

    return nil, output
end

--
-- Get the result of a request for discovering Slaves backhaul is down.
--
-- input = STRING
--
-- output = BTDiscoveryData[]
--
function _M.btGetScanBackhaulDownSlaveResult2(sc)
    sc:readlock()

    local mode = sc:get_smartmode()

    if not _M.isCentral(mode) then
        return 'ErrorBTNotInMasterMode'
    end

    output = { isRunning = false }
    local status = sc:get_btscanbackhauldownslave_status()
    if status == 'Running' then
        output.isRunning = true
        return nil, output
    end


    local input = { request = 'scanbackhauldownslave' }
    local error, data = _M.btGetResult2(input)

    if error then
        if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
            error = 'ErrorBTScanBackhaulDownSlave2RequestFailed'
        end
        output = nil
        return error, output
    end

    -- BTRequestScanBackhaulDownSlave2 was not triggered.
    if not data then
        output.isRunning = false
        return nil, output
    end

    -- Change mac address string to MACAddress object
    local discovery = {}
    for k, v in pairs(data.discovery) do
        local device = {}
        device.name = v.name
        device.macAddress = hdk.macaddress(v.macAddress)
        if v.modeLimit then
            device.modeLimit = v.modeLimit
        end
        device.rssi = v.rssi
        table.insert(discovery, device)
    end

    output.isRunning = false
    output.discovery = discovery

    return nil, output
end



function _M.btReboot(sc)
    local ownedsc = require('libsysctxlua').new()
    ownedsc:readlock()
    local mode = ownedsc:get_smartmode()
    -- We're done reading the sysctx context, so release the lock
    ownedsc:rollback()

    if not _M.isCentral(mode) then
        return 'ErrorBTNotInMasterMode', nil
    end

    local opt = '-r'
    local error, output = btRunCentralCommandSync(opt)
    if error then
        return 'ErrorBTRequestFailed'
    end

    return nil, output
end


return _M   -- return the module.
