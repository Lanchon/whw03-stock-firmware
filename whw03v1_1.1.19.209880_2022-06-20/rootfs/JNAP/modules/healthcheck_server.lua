--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hesia $
-- $DateTime: 2019/10/09 16:05:17 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/healthcheck/healthcheck_server.lua#1 $
--

local function GetSupportedHealthCheckModules(ctx)
    local ht = require('healthcheck')

    local output = ht.getSupportedHealthCheckModules()

    return 'OK', output
end

local function RunHealthCheck(ctx, input)
    local ht = require('healthcheck')
    local sc = ctx:sysctx()

    local error, output = ht.runHealthCheckModule(sc, input)

    return error or 'OK', output
end

local function StopHealthCheck(ctx)
    local ht = require('healthcheck')
    local sc = ctx:sysctx()

    ht.stopHealthCheckModules(sc)

    return 'OK'
end

local function GetHealthCheckStatus(ctx)
    local ht = require('healthcheck')
    local sc = ctx:sysctx()

    local output = ht.getHealthCheckStatus(sc)

    return 'OK', output
end

local function GetHealthCheckResults(ctx, input)
    local ht = require('healthcheck')

    local error, output = ht.getHealthCheckResults(input)

    return error or 'OK', output
end

local function ClearHealthCheckHistory(ctx)
    local ht = require('healthcheck')

    ht.clearHealthCheckHistory()

    return 'OK'
end

return require('libhdklua').loadmodule('jnap_healthcheck'), {
    ['http://linksys.com/jnap/healthcheck/GetSupportedHealthCheckModules'] = GetSupportedHealthCheckModules,
    ['http://linksys.com/jnap/healthcheck/RunHealthCheck'] = RunHealthCheck,
    ['http://linksys.com/jnap/healthcheck/StopHealthCheck'] = StopHealthCheck,
    ['http://linksys.com/jnap/healthcheck/GetHealthCheckStatus'] = GetHealthCheckStatus,
    ['http://linksys.com/jnap/healthcheck/GetHealthCheckResults'] = GetHealthCheckResults,
    ['http://linksys.com/jnap/healthcheck/ClearHealthCheckHistory'] = ClearHealthCheckHistory
}
