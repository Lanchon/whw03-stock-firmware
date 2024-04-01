--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hesia $
-- $DateTime: 2019/10/09 16:05:17 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/devicepreauthorization.lua#2 $
--

local device = require('device')
local hdk = require('libhdklua')
local util = require('util')

local _M = {}   --create the module

_M.unittest = {} -- unit test override data store

_M.ONBOARD_WIFI_PREAUTH_CMD = '/usr/local/lib/lua/5.1/onboard_wifi_preauth.lua &'

function _M.addPreauthorizedDevices(sc, input)
    sc:writelock()

    -- If the device is a Node, it must be in master mode.
    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    for i = 1, #input.deviceIDs do
        -- A device ID cannot be an empty string
        if #input.deviceIDs[i] == 0 then
            return 'ErrorInvalidDeviceID'
        end
        sc:add_preauthorized_device(input.deviceIDs[i])
    end
end

function _M.getPreauthorizedDevices(sc)
    sc:readlock()

    -- If the device is a Node, it must be in master mode.
    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    return nil, { deviceIDs = sc:get_preauthorized_devices() }
end

function _M.onboardWiFiPreauthorizedDevices(sc, input)
    sc:writelock()

    -- If the device is a Node, it must be in master mode.
    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    -- Check for preauthorized devices
    if #sc:get_preauthorized_devices() == 0 then
        return 'ErrorNoPreauthorizedDevices'
    end

    if sc:get_onboard_wifi_preauth_status() == 'Running' then
        return 'ErrorOnboardWiFiPreauthorizedAlreadyRunning'
    end

    sc:set_onboard_wifi_preauth_errinfo('')
    os.execute(_M.ONBOARD_WIFI_PREAUTH_CMD)
    sc:set_onboard_wifi_preauth_timestamp(_M.unittest.timestamp or os.time())
    sc:set_onboard_wifi_preauth_status('Running')
end

function _M.getOnboardWiFiPreauthorizedStatus(sc)
    sc:readlock()

    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end

    local output = {}
    output.isRunning = false

    local status = sc:get_onboard_wifi_preauth_status()
    if status == 'Running' then
        output.isRunning = true
    elseif status ~= '' then
        output.status = status
        if status == 'Error' then
            output.errorInfo = {}
            local errorDescription = sc:get_onboard_wifi_preauth_errinfo()
            local deviceErrors = {}
            local devices = sc:get_preauthorized_devices()
            for i = 1, #devices do
                local errInfo = sc:get_onboard_preauth_device_errinfo(devices[i])
                if #errInfo > 0 then
                    table.insert(deviceErrors, { deviceID = devices[i], errorDescription = errInfo })
                end
            end
            output.errorInfo = { errorDescription = errorDescription, deviceErrors = deviceErrors }
        end
    end

    local timestamp = sc:get_onboard_wifi_preauth_timestamp()
    if timestamp ~= '' then
        output.lastTriggered = hdk.datetime(tonumber(timestamp))
    end

    return nil, output
end


return _M   -- return the module.
