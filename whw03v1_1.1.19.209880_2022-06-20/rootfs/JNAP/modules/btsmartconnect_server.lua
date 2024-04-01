--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function BTRequestGetSmartConnectPIN(ctx)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()

    local error = btsmc.btRequestGetSmartConnectPIN(sc)

    return error or 'OK'
end

local function BTGetSmartConnectPINResult(ctx)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()
    local output = nil

    local error, output = btsmc.btGetSmartConnectPINResult(sc)

    return error or 'OK', output
end

local function BTRequestGetSmartConnectStatus(ctx, input)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()

    local error = btsmc.btRequestGetSmartConnectStatus(sc, input)

    return error or 'OK'
end

local function BTGetSmartConnectStatusResult(ctx)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = btsmc.btGetSmartConnectStatusResult(sc)
    if not error then
        output = data
    end

    return error or 'OK', output
end


local function BTRequestStartSmartConnectClient(ctx, input)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()

    local error = btsmc.btRequestStartSmartConnectClient(sc, input)

    return error or 'OK'
end

local function BTGetStartSmartConnectClientResult(ctx, input)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = btsmc.btGetStartSmartConnectClientResult(sc, input)
    if not error then
        output = data
    end

    return error or 'OK', output
end

local function BTRequestGetSlaveSetupStatus(ctx, input)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()

    local error = btsmc.btRequestGetSlaveSetupStatus(sc, input)

    return error or 'OK'
end

local function BTGetSlaveSetupStatusResult(ctx, input)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()

    local error, data = btsmc.btGetSlaveSetupStatusResult(sc, input)
    if not error then
        output = data
    else
        output = nil
    end

    return error or 'OK', output
end

local function BTRequestGetVersionInfo(ctx)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()

    local error = btsmc.btRequestGetVersionInfo(sc)

    return error or 'OK'
end

local function BTGetVersionInfoResult(ctx)
    local btsmc = require('btsmartconnect')
    local sc = ctx:sysctx()

    local error, data = btsmc.btGetVersionInfoResult(sc)
    if not error then
        output = data
    else
        output = nil
    end

    return error or 'OK', output
end

return require('libhdklua').loadmodule('jnap_btsmartconnect'), {
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTRequestGetSmartConnectPIN'] = BTRequestGetSmartConnectPIN,
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTGetSmartConnectPINResult'] = BTGetSmartConnectPINResult,
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTRequestGetSmartConnectStatus'] = BTRequestGetSmartConnectStatus,
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTGetSmartConnectStatusResult'] = BTGetSmartConnectStatusResult,
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTRequestStartSmartConnectClient'] = BTRequestStartSmartConnectClient,
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTGetStartSmartConnectClientResult'] = BTGetStartSmartConnectClientResult,
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTRequestGetSlaveSetupStatus'] = BTRequestGetSlaveSetupStatus,
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTGetSlaveSetupStatusResult'] = BTGetSlaveSetupStatusResult,
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTRequestGetVersionInfo'] = BTRequestGetVersionInfo,
    ['http://linksys.com/jnap/nodes/btsmartconnect/BTGetVersionInfoResult'] = BTGetVersionInfoResult
}
