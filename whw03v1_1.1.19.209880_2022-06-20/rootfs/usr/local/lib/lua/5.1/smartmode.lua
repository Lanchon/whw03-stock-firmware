--
-- 2018 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: jianxiao $
-- $DateTime: 2018/05/30 20:20:15 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/nodes/smartmode.lua#2 $
--

-- smartmode.lua - library to access the smartmode settings.

local platform = require('platform')
local bluetooth = require('bluetooth')

local _M = {}   --create the module

_M.SMART_CONNECT_SETUP_STATUS = 'smart_connect::setup_status'

local SMART_MODES = { [1] = 'Slave', [2] = 'Master' }

local function isValidParameter(mode)
    if mode == 'Unconfigured' or mode == 'Slave' or mode == 'Master' then
        return true
    else
        return false
    end
end

function _M.isSupportedMode(sc, mode)
    sc:readlock()

    local modeLimit = sc:get_smartmode_limit()
    if (modeLimit == 0) or (SMART_MODES[modeLimit] == mode) then
        return true
    end

    return false
end

function _M.getSmartMode(sc)
    sc:readlock()

    local smart_mode = sc:get_smartmode()

    if smart_mode == 2 then
        return 'Master'
    elseif smart_mode == 1 then
        return 'Slave'
    else
        return 'Unconfigured'
    end
end

function _M.setSmartMode(sc, mode)
    local device = require('device')
    sc:writelock()

    if (not sc:is_smartconnect_wifi_ready()) then
       return "_ErrorNotReady"
    end

    if not isValidParameter(mode) then
        return 'ErrorChangeMode'
    end

    if not _M.isSupportedMode(sc, mode) then
        return 'ErrorUnsupportedMode'
    end

    local smart_mode = sc:get_smartmode()

    if smart_mode == 2 and mode == 'Master' then
        return 'ErrorAlreadyMaster'
    elseif smart_mode == 1 and mode == 'Slave' then
        return 'ErrorAlreadySlave'
    end

    if smart_mode == 2 and mode == 'Slave' then
        return 'ErrorNeedToFactoryReset'
    elseif smart_mode == 1 and mode == 'Master' then
        return 'ErrorNeedToFactoryReset'
    end

    if smart_mode == 0 then
        if mode == 'Master' then
            sc:set_smartmode(2)
        elseif mode == 'Slave' then
            return 'ErrorChangeMode'
        end
    end
end

function _M.btRequestGetDeviceMode(sc)
    sc:writelock()

    local smart_mode = sc:get_smartmode()

    if not bluetooth.isCentral(smart_mode) then
        return 'ErrorBTUnsupportedMode', nil
    end

    if bluetooth.btCheckCentralWorking() then
        return 'ErrorBTCentralAlreadyWorking'
    end

    local requestId = bluetooth.btGetDeviceMode()
    if not requestId then
        return 'ErrorBTRequestFailed'
    end

    return nil, requestId
end

function _M.btGetDeviceModeResult(sc, input)
    sc:writelock()

    local smart_mode = sc:get_smartmode()

    if not bluetooth.isCentral(smart_mode) then
        return 'ErrorBTUnsupportedMode', nil
    end

    local error, data = bluetooth.btGetResult(input)

    if error == 'error_get_result_fail' or error == 'error_jnap_unknown_action' then
        error = 'ErrorBTGetDeviceModeRequestFailed'
    end

    if error then
        return error, nil
    end

    return nil, data.mode
end

function _M.getSupportedSmartModes(sc)
    sc:readlock()

    local modeLimit = sc:get_smartmode_limit()

    -- If there's a mode limit, then return the respective mode
    -- Otherwise, return all modes (no limit)
    if SMART_MODES[modeLimit] then
        return { SMART_MODES[modeLimit] }
    else
        return SMART_MODES
    end
end


return _M   -- return the module.
