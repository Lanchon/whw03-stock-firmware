--
-- 2018 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function GetSetupAP(ctx)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error, output = smc.getSetupAP(sc)
    return error or 'OK', output
end

local function GetSmartConnectPIN(ctx)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error, output = smc.getSmartConnectPIN(sc)
    return error or 'OK', output
end

local function StartSmartConnectServer(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error = smc.startSmartConnectServer(sc, input)
    return error or 'OK'
end

local function StartSmartConnectServer2(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error = smc.startSmartConnectServer(sc, input, 2)
    return error or 'OK'
end

local function StartSmartConnectClient(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error = smc.startSmartConnectClient(sc, input)
    return error or 'OK'
end

local function GetSmartConnectStatus(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local output = smc.getSmartConnectStatus(sc, input)
    return 'OK', output
end

local function BTRequestGetSmartConnectPIN(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()
    local output

    local error, requestId = smc.btRequestGetSmartConnectPIN(sc)
    if not error then
        output = { requestId = requestId }
    else
        output = nil
    end

    return error or 'OK', output
end

local function BTGetSmartConnectPINResult(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = smc.btGetSmartConnectPinResult(sc, input)
    if not error then
        output = { pin = data }
    end

    return error or 'OK', output
end

local function BTRequestGetSmartConnectStatus(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()
    local output

    local error, requestId = smc.btRequestGetSmartConnectStatus(sc, input)
    if not error then
        output = { requestId = requestId }
    else
        output = nil
    end

    return error or 'OK', output
end

local function BTGetSmartConnectStatusResult(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = smc.btGetSmartConnectStatusResult(sc, input)
    if not error then
        output = { status = data }
    end

    return error or 'OK', output
end


local function BTRequestStartSmartConnectClient(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()
    local output

    local error, requestId = smc.btRequestStartSmartConnectClient(sc, input)
    if not error then
        output = { requestId = requestId }
    else
        output = nil
    end

    return error or 'OK', output
end

local function BTGetStartSmartConnectClientResult(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error = smc.btGetStartSmartConnectClientResult(sc, input)

    return error or 'OK'
end

local function GetSlaveSetupStatus(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error, output = smc.getSlaveSetupStatus(sc, input)

    return error or 'OK', output
end

local function GetSlaveSetupStatus2(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error, output = smc.getSlaveSetupStatus2(sc, input)

    return error or 'OK', output
end

local function SmartConnectConfigure(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error, output = smc.smartConnectConfigure(sc, input)

    return error or 'OK'
end

local function GetOnboardingStatus(ctx, input)
    local smc = require('smartconnect')
    local sc = ctx:sysctx()

    local error, output = smc.getOnboardingStatus(sc, input)

    return error or 'OK', output
end


return require('libhdklua').loadmodule('jnap_smartconnect'), {
    ['http://linksys.com/jnap/nodes/smartconnect/GetSetupAP'] = GetSetupAP,
    ['http://linksys.com/jnap/nodes/smartconnect/GetSmartConnectPIN'] = GetSmartConnectPIN,
    ['http://linksys.com/jnap/nodes/smartconnect/StartSmartConnectServer'] = StartSmartConnectServer,
    ['http://linksys.com/jnap/nodes/smartconnect/StartSmartConnectServer2'] = StartSmartConnectServer2,
    ['http://linksys.com/jnap/nodes/smartconnect/StartSmartConnectClient'] = StartSmartConnectClient,
    ['http://linksys.com/jnap/nodes/smartconnect/GetSmartConnectStatus'] = GetSmartConnectStatus,
    ['http://linksys.com/jnap/nodes/smartconnect/GetSlaveSetupStatus'] = GetSlaveSetupStatus,
    ['http://linksys.com/jnap/nodes/smartconnect/SmartConnectConfigure'] = SmartConnectConfigure,
    ['http://linksys.com/jnap/nodes/smartconnect/BTRequestGetSmartConnectPIN'] = BTRequestGetSmartConnectPIN,
    ['http://linksys.com/jnap/nodes/smartconnect/BTGetSmartConnectPINResult'] = BTGetSmartConnectPINResult,
    ['http://linksys.com/jnap/nodes/smartconnect/BTRequestGetSmartConnectStatus'] = BTRequestGetSmartConnectStatus,
    ['http://linksys.com/jnap/nodes/smartconnect/BTGetSmartConnectStatusResult'] = BTGetSmartConnectStatusResult,
    ['http://linksys.com/jnap/nodes/smartconnect/BTRequestStartSmartConnectClient'] = BTRequestStartSmartConnectClient,
    ['http://linksys.com/jnap/nodes/smartconnect/BTGetStartSmartConnectClientResult'] = BTGetStartSmartConnectClientResult,
    ['http://linksys.com/jnap/nodes/smartconnect/GetSlaveSetupStatus2'] = GetSlaveSetupStatus2,
    ['http://linksys.com/jnap/nodes/smartconnect/GetOnboardingStatus'] = GetOnboardingStatus
}
