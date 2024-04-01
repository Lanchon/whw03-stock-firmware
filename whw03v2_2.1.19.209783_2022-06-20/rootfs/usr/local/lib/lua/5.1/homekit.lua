--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2020/10/29 22:44:11 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/homekit.lua#1 $
--

-- homekit.lua - library to configure homekit state.


local hdk = require('libhdklua')
local platform = require('platform')

local _M = {} -- create the module

_M.GENERATE_PAYLOAD_TIMEOUT = 10
_M.GENERATE_OWNERSHIP_TOKEN_TIMEOUT = 10
_M.WIFI_ROUTER_PID_FILE = '/var/run/WiFiRouter.pid'

--
-- Trigger the setup payload generation.
--
-- input = CONTEXT, {
--     setupCode = STRING,
--     softwareToken = STRING,
--     softwareTokenUUID = UUID
-- }
--
-- output = NIL_OR_ONE_OF(
--     'ErrorInvalidSetupCode',
--     'ErrorServiceIsEnabled'
-- )
--
function _M.generateSetupPayload(sc, input)
    sc:writelock()

    if not input.setupCode:match('^%d%d%d%-%d%d%-%d%d%d$') then
        return 'ErrorInvalidSetupCode'
    end

    if sc:get_homekit_enabled() then
        return 'ErrorServiceIsEnabled'
    end

    sc:set_homekit_setup_code(input.setupCode)
    sc:set_homekit_software_token(input.softwareToken)
    sc:set_homekit_software_token_uuid(string.upper(tostring(input.softwareTokenUUID)))
    sc:set_homekit_setup_payload()
    sc:generate_homekit_setup_payload()
end

--
-- Get the generated setup payload.
--
-- input = CONTEXT
--
-- output = {
--     setupPayload = STRING
-- }
--
function _M.getSetupPayload(sc)
    sc:readlock()

    return {
        setupPayload = sc:get_homekit_setup_payload()
    }
end

--
-- Trigger the proof of ownership generation.
--
-- input = CONTEXT
--
-- output = NIL_OR_ONE_OF(
--     'ErrorServiceIsDisabled'
-- )
--
function _M.generateProofOfOwnershipToken(sc)
    sc:writelock()

    if not sc:get_homekit_enabled() then
        return 'ErrorServiceIsDisabled'
    end

    sc:set_homekit_ownership_token()
    sc:generate_homekit_ownership_token()
end

--
-- Get the generated proof of ownership.
--
-- input = CONTEXT
--
-- output = {
--     proofOfOwnership = STRING
-- }
--
function _M.getProofOfOwnershipToken(sc)
    sc:readlock()

    return {
        proofOfOwnershipToken = sc:get_homekit_ownership_token()
    }
end

--
-- Get the HomeKit settings.
--
-- input = CONTEXT
--
-- output = {
--     isEnabled = DATETIME,
--     isPaired = STRING
-- }
--
function _M.getHomeKitSettings(sc)
    sc:readlock()

    return {
        isEnabled = sc:get_homekit_enabled(),
        isPaired = sc:get_homekit_ispaired()
    }
end

--
-- Set the HomeKit settings.
--
-- input = CONTEXT, {
--     isEnabled = BOOLEAN
-- }
--
function _M.setHomeKitSettings(sc, input)
    sc:writelock()
    sc:set_homekit_enabled(input.isEnabled)
end

--
-- Unpair the router from HomeKit.
--
-- input = CONTEXT
--
function _M.unpairHomeKitRouter(sc)
    sc:writelock()
    if not sc:get_homekit_enabled() then
        return 'ErrorServiceIsDisabled'
    end
    if not sc:get_homekit_ispaired() then
        return 'ErrorRouterNotPaired'
    end
    local file = io.open(_M.WIFI_ROUTER_PID_FILE, 'r')
    if not file then
        return 'ErrorServiceNotRunning'
    end
    local pid = file:read()
    file:close()
    if not platform.isProcessRunning(tonumber(pid)) then
        return 'ErrorServiceNotRunning'
    end
    sc:unpair_homekit_router()
end

return _M -- return the module
