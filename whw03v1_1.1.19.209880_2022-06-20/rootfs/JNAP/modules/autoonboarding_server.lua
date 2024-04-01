--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: jianxiao $
-- $DateTime: 2018/05/28 00:12:59 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/nodes/autoonboarding/autoonboarding_server.lua#1 $
--

local function GetWiredAutoOnboardingSettings(ctx, input)
    local sc = ctx:sysctx()
    sc:readlock()

    return 'OK', {
        isAutoOnboardingEnabled = sc:get_wired_auto_onboarding_enabled()
    }
end

local function SetWiredAutoOnboardingSettings(ctx, input)
    local sc = ctx:sysctx()
    sc:writelock()

    local currentMode = require('smartmode').getSmartMode(sc)
    if currentMode ~= 'Master' then
        return 'ErrorDeviceNotInMasterMode'
    end
    sc:set_wired_auto_onboarding_enabled(input.isAutoOnboardingEnabled)
    return 'OK'
end

local function GetBluetoothAutoOnboardingSettings(ctx, input)
    local sc = ctx:sysctx()
    sc:readlock()

    return 'OK', {
        isAutoOnboardingEnabled = sc:get_bluetooth_auto_onboarding_enabled()
    }
end

local function SetBluetoothAutoOnboardingSettings(ctx, input)
    local sc = ctx:sysctx()
    sc:writelock()

    local currentMode = require('smartmode').getSmartMode(sc)
    if currentMode ~= 'Master' then
        return 'ErrorDeviceNotInMasterMode'
    end
    sc:set_bluetooth_auto_onboarding_enabled(input.isAutoOnboardingEnabled)
    return 'OK'
end

local function StartBluetoothAutoOnboarding(ctx, input)
    local sc = ctx:sysctx()
    sc:readlock()

    local currentMode = require('smartmode').getSmartMode(sc)
    if currentMode ~= 'Master' then
        return 'ErrorDeviceNotInMasterMode'
    end
    sc:start_bluetooth_auto_onboarding()
    return 'OK'
end

local function GetBluetoothAutoOnboardingStatus(ctx, input)
    local sc = ctx:sysctx()
    sc:readlock()

    return 'OK', {
        autoOnboardingStatus = sc:get_bluetooth_auto_onboarding_status()
    }
end


return require('libhdklua').loadmodule('jnap_autoonboarding'), {
    ['http://linksys.com/jnap/nodes/autoonboarding/GetWiredAutoOnboardingSettings'] = GetWiredAutoOnboardingSettings,
    ['http://linksys.com/jnap/nodes/autoonboarding/SetWiredAutoOnboardingSettings'] = SetWiredAutoOnboardingSettings,
    ['http://linksys.com/jnap/nodes/autoonboarding/GetBluetoothAutoOnboardingSettings'] = GetBluetoothAutoOnboardingSettings,
    ['http://linksys.com/jnap/nodes/autoonboarding/SetBluetoothAutoOnboardingSettings'] = SetBluetoothAutoOnboardingSettings,
    ['http://linksys.com/jnap/nodes/autoonboarding/StartBluetoothAutoOnboarding'] = StartBluetoothAutoOnboarding,
    ['http://linksys.com/jnap/nodes/autoonboarding/GetBluetoothAutoOnboardingStatus'] = GetBluetoothAutoOnboardingStatus
}
