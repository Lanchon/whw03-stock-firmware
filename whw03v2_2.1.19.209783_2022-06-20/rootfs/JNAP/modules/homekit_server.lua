--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2020/10/29 22:44:11 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/homekit/homekit_server.lua#1 $
--

local function GenerateSetupPayload(ctx, input)
    local homekit = require('homekit')

    local sc = ctx:sysctx()
    local error = homekit.generateSetupPayload(sc, input)
    return error or 'OK'
end

local function GetSetupPayload(ctx, input)
    local homekit = require('homekit')

    local sc = ctx:sysctx()
    local output = homekit.getSetupPayload(sc)
    return 'OK', output
end

local function GenerateProofOfOwnershipToken(ctx, input)
    local homekit = require('homekit')

    local sc = ctx:sysctx()
    local error = homekit.generateProofOfOwnershipToken(sc)
    return error or 'OK'
end

local function GetProofOfOwnershipToken(ctx)
    local homekit = require('homekit')

    local sc = ctx:sysctx()
    local output = homekit.getProofOfOwnershipToken(sc)
    return 'OK', output
end

local function GetHomeKitSettings(ctx, input)
    local homekit = require('homekit')

    local sc = ctx:sysctx()
    local output = homekit.getHomeKitSettings(sc)
    return 'OK', output
end

local function SetHomeKitSettings(ctx, input)
    local homekit = require('homekit')

    local sc = ctx:sysctx()
    local error = homekit.setHomeKitSettings(sc, input)
    return error or 'OK'
end

local function UnpairHomeKitRouter(ctx, input)
    local homekit = require('homekit')

    local sc = ctx:sysctx()
    local error = homekit.unpairHomeKitRouter(sc, input)
    return error or 'OK'
end

return require('libhdklua').loadmodule('jnap_homekit'), {
    ['http://linksys.com/jnap/homekit/GenerateSetupPayload'] = GenerateSetupPayload,
    ['http://linksys.com/jnap/homekit/GetSetupPayload'] = GetSetupPayload,

    ['http://linksys.com/jnap/homekit/GenerateProofOfOwnershipToken'] = GenerateProofOfOwnershipToken,
    ['http://linksys.com/jnap/homekit/GetProofOfOwnershipToken'] = GetProofOfOwnershipToken,

    ['http://linksys.com/jnap/homekit/GetHomeKitSettings'] = GetHomeKitSettings,
    ['http://linksys.com/jnap/homekit/SetHomeKitSettings'] = SetHomeKitSettings,

    ['http://linksys.com/jnap/homekit/UnpairHomeKitRouter'] = UnpairHomeKitRouter
}
