--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hesia $
-- $DateTime: 2019/10/09 16:05:17 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/nodes/setup/setup_server.lua#4 $
--

local function SetAdminPassword(ctx, input)
    if ctx:isremotecall() then
        return 'ErrorDisallowedRemoteCall'
    end

    local device = require('device')
    local platform = require('platform')
    local sc = ctx:sysctx()

    local error, output = device.verifyRouterResetCode(sc, input.resetCode)
    if error then
        return error, output
    end

    -- Register the logging callback for this call.
    platform.registerLoggingCallback(function(level, message) ctx:serverlog(level, message) end)

    error = device.setAdminPassword2(sc, input, true)
    return error or 'OK', {
        isResetCodeValid = true
    }
end

-- This call doesn't require authentication and is not transaction safe
local function VerifyRouterResetCode(ctx, input)
    if ctx:isremotecall() then
        return 'ErrorDisallowedRemoteCall'
    end

    local device = require('device')
    local sc = ctx:sysctx()

    local error, output = device.verifyRouterResetCode(sc, input.resetCode)
    if error then
        return error, output
    end

    return 'OK', {
        isResetCodeValid = true
    }
end

local function IsAdminPasswordSetByUser(ctx)
    local sc = ctx:sysctx()
    local device = require('device')

    return 'OK', {
        isAdminPasswordSetByUser = device.isAdminPasswordSetByUser(sc)
    }
end

local function GetSerialNumber(ctx)
    local device = require('device')

    local sc = ctx:sysctx()
    return 'OK', {
        serialNumber = device.getSerialNumber(sc)
    }
end

local function StartCloudProvisioning(ctx, input)
    local sc = ctx:sysctx()
    sc:writelock()
    local provisionId = sc:get_cloud_provision_id()

    -- If we have a provision Id, then process is already running
    if (#provisionId > 0) then
        return 'ErrorCloudProvisionAlreadyRunning'
    end
    if (sc:get_wan_connection_status() ~= 'started') then
        return 'ErrorNoWANConnection'
    end
    local token = sc:get_linksys_token()
    if (#token == 0) then
        return 'ErrorDeviceNotRegistered'
    end
    sc:set_cloud_provision_id(input.provisionId)

    return 'OK'
end

local function GetSelectedChannels(ctx)
    local setup = require('setup')
    local sc = ctx:sysctx()

    return 'OK', setup.getSelectedChannels(sc)
end

local function StartAutoChannelSelection(ctx)
    local setup = require('setup')

    local sc = ctx:sysctx()
    local error = setup.startAutoChannelSelection(sc)
    return error or 'OK'
end

local function GetSimpleWiFiSettings(ctx, input)
    local setup = require('setup')
    local sc = ctx:sysctx()
    local output = {}

    output.simpleWiFiSettings = { setup.getSimpleWiFiSettings(sc, '2.4GHz'), setup.getSimpleWiFiSettings(sc, '5GHz') }

    return 'OK', output
end

local function SetSimpleWiFiSettings(ctx, input)
    local setup = require('setup')
    local sc = ctx:sysctx()

    local error = setup.setSimpleWiFiSettings(sc, input.simpleWiFiSettings)
    return error or 'OK'
end

local function GetNodesWirelessConnectionInfo(ctx, input)
    local setup = require('setup')
    local smd = require('smartmode')
    local sc = ctx:sysctx()

    local currentMode = smd.getSmartMode(sc)

    if currentMode == 'Unconfigured' or currentMode == 'Slave' then
        return 'ErrorUnsupportedMode'
    end

    return 'OK', {
        nodesWirelessConnectionInfo = setup.getNodesWirelessConnectionInfo(sc, input.deviceIDs)
    }
end

local function GetMACAddress(ctx)
    local device = require('device')
    local hdk = require('libhdklua')

    local sc = ctx:sysctx()
    return 'OK', {
        macAddress = hdk.macaddress(device.getMACAddress(sc))
    }
end

local function GetDeviceID(ctx, input)
    local setup = require('setup')
    local sc = ctx:sysctx()

    local error, output = setup.getDeviceID(sc, input)

    return error or 'OK', output
end

local function GetConnectedNodesDeviceID(ctx)
    local setup = require('setup')
    local sc = ctx:sysctx()

    local error, output = setup.getConnectedNodesDeviceID(sc)

    return error or 'OK', output
end

local function GetWANDetectionStatus(ctx)
    local router = require('router')
    local sc = ctx:sysctx()
    sc:readlock()

    local wanStatus = router.getWANStatus3(sc)
    local wanIPv6Connection = wanStatus.wanIPv6Connection
    return 'OK', {
        isDetectingWANType = (sc:get_wan_detection_status() == 'detecting') and true or false,
        detectedWANType = sc:get_detected_wan_type(),
        wanStatus = wanStatus.wanStatus,
        wanIPv6Status = wanStatus.wanIPv6Status,
        wanIPv6Type = wanIPv6Connection and wanIPv6Connection.wanType
    }
end

local function GetUnconfiguredWiredNodes(ctx)
    local setup = require('setup')
    local nodes_util = require('nodes_util')
    local sc = ctx:sysctx()
    local output = nil

    if not nodes_util.isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    return 'OK', {
        devices = setup.getUnconfiguredWiredNodes(sc)
    }
end

local function GetInternetConnectionStatus(ctx)
    local sc = ctx:sysctx()
    sc:readlock()

    local connStatus = 'NoPortConnected'
    local portStatus = sc:get_port_connection_status()

    for _, state in pairs(portStatus) do
        if state == "Connected" then
            if sc:get_wan_connection_status() == "started" then
                if sc:get_icc_internet_state() == 'up' then
                    connStatus = 'InternetConnected'
                    break
                else
                    connStatus = 'NoInternetConnection'
                    break
                end
            else
                connStatus = 'NoWANConnection'
                break
            end
        end
    end

    return 'OK', {
        connectionStatus = connStatus
    }
end

local function StartWiredBlinkingNode(ctx, input)
    local setup = require('setup')
    local sc = ctx:sysctx()
    local platform = require('platform')

    -- Register the logging callback for this call.
    platform.registerLoggingCallback(function(level, message) ctx:serverlog(level, message) end)

    local error = setup.startWiredBlinkingNode(sc, input)

    return error or 'OK'
end

local function StopWiredBlinkingNode(ctx)
    local setup = require('setup')
    local sc = ctx:sysctx()
    local platform = require('platform')

    -- Register the logging callback for this call.
    platform.registerLoggingCallback(function(level, message) ctx:serverlog(level, message) end)

    local error = setup.stopWiredBlinkingNode(sc)

    return error or 'OK'
end

local function GetVersionInfo(ctx)
    local sc = ctx:sysctx()
    sc:readlock()

    return 'OK', {
        modelNumber = require('device').getModelNumber(sc),
        hardwareVersion = tonumber(sc:get_hardware_revision())
    }
end

local function GetWANConnectionInfo(ctx)
    local sc = ctx:sysctx()
    sc:readlock()

    local wanStatus = require('router').getWANStatus(sc, 3)

    return 'OK', {
        wanConnection = wanStatus.wanConnection
    }
end


return require('libhdklua').loadmodule('jnap_setup'), {
    ['http://linksys.com/jnap/nodes/setup/SetAdminPassword'] = SetAdminPassword,
    ['http://linksys.com/jnap/nodes/setup/VerifyRouterResetCode'] = VerifyRouterResetCode,
    ['http://linksys.com/jnap/nodes/setup/IsAdminPasswordSetByUser'] = IsAdminPasswordSetByUser,
    ['http://linksys.com/jnap/nodes/setup/GetSimpleWiFiSettings'] = GetSimpleWiFiSettings,
    ['http://linksys.com/jnap/nodes/setup/SetSimpleWiFiSettings'] = SetSimpleWiFiSettings,
    ['http://linksys.com/jnap/nodes/setup/GetSerialNumber'] = GetSerialNumber,
    ['http://linksys.com/jnap/nodes/setup/GetMACAddress'] = GetMACAddress,
    ['http://linksys.com/jnap/nodes/setup/GetDeviceID'] = GetDeviceID,
    ['http://linksys.com/jnap/nodes/setup/StartCloudProvisioning'] = StartCloudProvisioning,
    ['http://linksys.com/jnap/nodes/setup/GetSelectedChannels'] = GetSelectedChannels,
    ['http://linksys.com/jnap/nodes/setup/StartAutoChannelSelection'] = StartAutoChannelSelection,
    ['http://linksys.com/jnap/nodes/setup/GetNodesWirelessConnectionInfo'] = GetNodesWirelessConnectionInfo,
    ['http://linksys.com/jnap/nodes/setup/GetConnectedNodesDeviceID'] = GetConnectedNodesDeviceID,
    ['http://linksys.com/jnap/nodes/setup/GetWANDetectionStatus'] = GetWANDetectionStatus,
    ['http://linksys.com/jnap/nodes/setup/GetUnconfiguredWiredNodes'] = GetUnconfiguredWiredNodes,
    ['http://linksys.com/jnap/nodes/setup/GetInternetConnectionStatus'] = GetInternetConnectionStatus,
    ['http://linksys.com/jnap/nodes/setup/StartWiredBlinkingNode'] = StartWiredBlinkingNode,
    ['http://linksys.com/jnap/nodes/setup/StopWiredBlinkingNode'] = StopWiredBlinkingNode,
    ['http://linksys.com/jnap/nodes/setup/GetVersionInfo'] = GetVersionInfo,
    ['http://linksys.com/jnap/nodes/setup/GetWANConnectionInfo'] = GetWANConnectionInfo
}
