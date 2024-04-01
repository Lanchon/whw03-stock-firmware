--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--
local function GetClientDeviceInfo(ctx, input)
    local smc = require('smartconnect_client')
    local sc = ctx:sysctx()

    local output = smc.getClientDeviceInfo(sc)
    return 'OK', output
end

local function StartSmartConnectClient(ctx, input)
    local smc = require('smartconnect_client')
    local sc = ctx:sysctx()

    local error = smc.startSmartConnectClient(sc, input)
    return error or 'OK'
end

local function Detach(ctx, input)
    local smc = require('smartconnect_client')
    local sc = ctx:sysctx()

    local error = smc.detach(sc)
    return error or 'OK'
end

return require('libhdklua').loadmodule('jnap_smartconnect_client'), {
    ['http://linksys.com/jnap/smartconnect/GetClientDeviceInfo'] = GetClientDeviceInfo,
    ['http://linksys.com/jnap/smartconnect/StartSmartConnectClient'] = StartSmartConnectClient,
    ['http://linksys.com/jnap/smartconnect/Detach'] = Detach
}
