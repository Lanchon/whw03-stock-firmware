--
-- 2013 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function GetLocalDevice(ctx)
    local devicelist = require('devicelist')
    local result, output = 'ErrorUnknownDevice', nil

    -- Register the logging callback for this action.
    require('platform').registerLoggingCallback(function(level, message) ctx:serverlog(level, message) end)

    local ipaddr = ctx:remoteaddress()
    if ipaddr then
        local sc = ctx:sysctx()
        result, output = devicelist.getDevices(sc, {})
        if result == 'OK' then
            for i, device in ipairs(output.devices) do
                for j, conn in ipairs(device.connections) do
                    if ipaddr == conn.ipAddress or
                        ipaddr == conn.ipv6Address then
                        return 'OK', {
                            deviceID = device.deviceID
                        }
                    end
                end
            end
            result, output = 'ErrorUnknownDevice', nil
        end
    end
    return result, output
end

local function GetDevices(ctx, input)
    local devicelist = require('devicelist')

    local sc = ctx:sysctx()

    -- Register the logging callback for this action.
    require('platform').registerLoggingCallback(function(level, message) ctx:serverlog(level, message) end)

    return devicelist.getDevices(sc, input, 1)
end

local function GetDevices3(ctx, input)
    local devicelist = require('devicelist')

    local sc = ctx:sysctx()

    -- Register the logging callback for this action.
    require('platform').registerLoggingCallback(function(level, message) ctx:serverlog(level, message) end)

    return devicelist.getDevices(sc, input, 2)
end

local function SetDeviceProperties(ctx, input)
    local devicelist = require('devicelist')

    local sc = ctx:sysctx()
    return devicelist.setDeviceProperties(sc, input)
end

local function DeleteDevice(ctx, input)
    local devicelist = require('devicelist')

    local sc = ctx:sysctx()
    return devicelist.deleteDevice(sc, input.deviceID)
end

local function ClearDeviceList(ctx, input)
    local devicelist = require('devicelist')

    local sc = ctx:sysctx()
    return devicelist.clearDeviceList(sc, input.preserveProperties)
end

local function ClearDeviceList2(ctx, input)
    local devicelist = require('devicelist')

    local sc = ctx:sysctx()

    -- Register the logging callback for this action.
    require('platform').registerLoggingCallback(function(level, message) ctx:serverlog(level, message) end)

    return devicelist.clearDeviceList(sc, input.preserveProperties, 2)
end

return require('libhdklua').loadmodule('jnap_devicelist'), {
    ['http://linksys.com/jnap/devicelist/GetLocalDevice'] = GetLocalDevice,
    ['http://linksys.com/jnap/devicelist/GetDevices'] = GetDevices,
    ['http://linksys.com/jnap/devicelist/GetDevices3'] = GetDevices3,
    ['http://linksys.com/jnap/devicelist/SetDeviceProperties'] = SetDeviceProperties,
    ['http://linksys.com/jnap/devicelist/DeleteDevice'] = DeleteDevice,
    ['http://linksys.com/jnap/devicelist/ClearDeviceList'] = ClearDeviceList,
    ['http://linksys.com/jnap/devicelist/ClearDeviceList2'] = ClearDeviceList2
}
