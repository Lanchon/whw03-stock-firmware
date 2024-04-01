--
-- 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function BTRequestScanUnconfigured(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()

    local error, requestId = bt.btRequestScanUnconfigured(sc, input)
    if not error then
        output = { requestId = requestId }
    else
        output = nil
    end

    return error or 'OK', output
end

local function BTRequestScanUnconfigured2(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()

    local error = bt.btRequestScanUnconfigured2(sc, input)

    return error or 'OK'
end

local function BTGetScanResult(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = bt.btGetScanResult(sc, input)
    if not error then
        output = { discovery = data }
    end

    return error or 'OK', output
end

local function BTGetScanUnconfiguredResult2(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = bt.btGetScanUnconfiguredResult2(sc, input)
    if not error then
        output = data
    end

    return error or 'OK', output
end

local function BTRequestConnect(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()

    local error, requestId = bt.btRequestConnect(sc, input)
    if not error then
        output = { requestId = requestId }
    else
        output = nil
    end

    return error or 'OK', output
end

local function BTRequestConnect2(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()

    local error = bt.btRequestConnect2(sc, input)

    return error or 'OK'
end

local function BTGetConnectResult(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = bt.btGetConnectResult(sc, input)
    if not error then
        output = { status = data }
    end

    return error or 'OK', output
end

local function BTGetConnectResult2(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = bt.btGetConnectResult2(sc, input)
    if not error then
        output = data
    end

    return error or 'OK', output
end


local function BTRequestDisconnect(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()

    local error, requestId = bt.btRequestDisconnect(sc)
    if not error then
        output = { requestId = requestId }
    else
        output = nil
    end

    return error or 'OK', output
end

local function BTRequestDisconnect2(ctx)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()

    local error = bt.btRequestDisconnect2(sc)

    return error or 'OK'
end


local function BTGetDisconnectResult(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = bt.btGetDisconnectResult(sc, input)
    if not error then
        output = { status = data }
    end

    return error or 'OK', output
end


local function BTGetDisconnectResult2(ctx)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = bt.btGetDisconnectResult2(sc)
    if not error then
        output = data
    end

    return error or 'OK', output
end


local function BTRequestScanBackhaulDownSlave(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()

    local error, requestId = bt.btRequestScanBackhaulDownSlave(sc, input)
    if not error then
        output = { requestId = requestId }
    else
        output = nil
    end

    return error or 'OK', output
end


local function BTRequestScanBackhaulDownSlave2(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()

    local error = bt.btRequestScanBackhaulDownSlave2(sc, input)

    return error or 'OK'
end


local function BTGetScanBackhaulDownSlaveResult(ctx, input)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = bt.btGetScanBackhaulDownSlaveResult(sc, input)
    if not error then
        output = { discovery = data }
    end

    return error or 'OK', output
end


local function BTGetScanBackhaulDownSlaveResult2(ctx)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()
    local output = nil

    local error, data = bt.btGetScanBackhaulDownSlaveResult2(sc)
    if not error then
        output = data
    end

    return error or 'OK', output
end


local function BTReboot(ctx)
    local bt = require('bluetooth')
    local sc = ctx:sysctx()
    local output = nil

    local error = bt.btReboot(sc)
    if error then
        return error
    end

    return 'OK'
end


return require('libhdklua').loadmodule('jnap_bluetooth'), {
    ['http://linksys.com/jnap/nodes/bluetooth/BTRequestScanUnconfigured'] = BTRequestScanUnconfigured,
    ['http://linksys.com/jnap/nodes/bluetooth/BTGetScanUnconfiguredResult2'] = BTGetScanUnconfiguredResult2,
    ['http://linksys.com/jnap/nodes/bluetooth/BTGetScanResult'] = BTGetScanResult,
    ['http://linksys.com/jnap/nodes/bluetooth/BTRequestScanUnconfigured2'] = BTRequestScanUnconfigured2,
    ['http://linksys.com/jnap/nodes/bluetooth/BTRequestConnect'] = BTRequestConnect,
    ['http://linksys.com/jnap/nodes/bluetooth/BTRequestConnect2'] = BTRequestConnect2,
    ['http://linksys.com/jnap/nodes/bluetooth/BTGetConnectResult'] = BTGetConnectResult,
    ['http://linksys.com/jnap/nodes/bluetooth/BTGetConnectResult2'] = BTGetConnectResult2,
    ['http://linksys.com/jnap/nodes/bluetooth/BTRequestDisconnect'] = BTRequestDisconnect,
    ['http://linksys.com/jnap/nodes/bluetooth/BTRequestDisconnect2'] = BTRequestDisconnect2,
    ['http://linksys.com/jnap/nodes/bluetooth/BTGetDisconnectResult'] = BTGetDisconnectResult,
    ['http://linksys.com/jnap/nodes/bluetooth/BTGetDisconnectResult2'] = BTGetDisconnectResult2,
    ['http://linksys.com/jnap/nodes/bluetooth/BTRequestScanBackhaulDownSlave'] = BTRequestScanBackhaulDownSlave,
    ['http://linksys.com/jnap/nodes/bluetooth/BTRequestScanBackhaulDownSlave2'] = BTRequestScanBackhaulDownSlave2,
    ['http://linksys.com/jnap/nodes/bluetooth/BTGetScanBackhaulDownSlaveResult'] = BTGetScanBackhaulDownSlaveResult,
    ['http://linksys.com/jnap/nodes/bluetooth/BTGetScanBackhaulDownSlaveResult2'] = BTGetScanBackhaulDownSlaveResult2,
    ['http://linksys.com/jnap/nodes/bluetooth/BTReboot'] = BTReboot
}
