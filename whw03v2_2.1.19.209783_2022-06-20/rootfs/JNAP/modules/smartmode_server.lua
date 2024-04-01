--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: jianxiao $
-- $DateTime: 2018/05/30 20:20:15 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/nodes/smartmode/smartmode_server.lua#2 $
--

local function GetDeviceMode(ctx)
    local smd = require('smartmode')
    local sc = ctx:sysctx()

    return 'OK', {
        mode = smd.getSmartMode(sc)
    }
end

local function SetDeviceMode(ctx, input)
    local smd = require('smartmode')
    local sc = ctx:sysctx()

    local error = smd.setSmartMode(sc, input.mode)
    return error or 'OK'
end

local function BTRequestGetDeviceMode(ctx)
    local smc = require('smartmode')
    local sc = ctx:sysctx()

    local error, requestId = smc.btRequestGetDeviceMode(sc)
    if not error then
        output = { requestId = requestId }
    else
        output = nil
    end

    return error or 'OK', output
end

local function BTGetDeviceModeResult(ctx, input)
    local smc = require('smartmode')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = smc.btGetDeviceModeResult(sc, input)
    if not error then
        output = { mode = data }
    end

    return error or 'OK', output
end

local function GetSupportedDeviceModes(ctx)
    local smd = require('smartmode')
    local sc = ctx:sysctx()

    return 'OK', {
        supportedModes = smd.getSupportedSmartModes(sc)
    }
end


return require('libhdklua').loadmodule('jnap_smartmode'), {
    ['http://linksys.com/jnap/nodes/smartmode/GetDeviceMode'] = GetDeviceMode,
    ['http://linksys.com/jnap/nodes/smartmode/SetDeviceMode'] = SetDeviceMode,
    ['http://linksys.com/jnap/nodes/smartmode/BTRequestGetDeviceMode'] = BTRequestGetDeviceMode,
    ['http://linksys.com/jnap/nodes/smartmode/BTGetDeviceModeResult'] = BTGetDeviceModeResult,
    ['http://linksys.com/jnap/nodes/smartmode/GetSupportedDeviceModes'] = GetSupportedDeviceModes
}
