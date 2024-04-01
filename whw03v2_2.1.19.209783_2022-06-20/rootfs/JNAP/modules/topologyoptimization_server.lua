--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local topopt = require('topologyoptimization')

local function GetTopologyOptimizationSettings(ctx, input)
    local sc = ctx:sysctx()

    return 'OK', topopt.getTopologyOptimizationSettings(sc, 1)
end

local function SetTopologyOptimizationSettings(ctx, input)
    local sc = ctx:sysctx()

    local err = topopt.setTopologyOptimizationSettings(sc, input, 1)

    return err or 'OK'
end

local function GetTopologyOptimizationSettings2(ctx, input)
    local sc = ctx:sysctx()

    return 'OK', topopt.getTopologyOptimizationSettings(sc, 2)
end

local function SetTopologyOptimizationSettings2(ctx, input)
    local sc = ctx:sysctx()

    local err = topopt.setTopologyOptimizationSettings(sc, input, 2)

    return err or 'OK'
end


return require('libhdklua').loadmodule('jnap_topologyoptimization'), {
    ['http://linksys.com/jnap/nodes/topologyoptimization/GetTopologyOptimizationSettings'] = GetTopologyOptimizationSettings,
    ['http://linksys.com/jnap/nodes/topologyoptimization/SetTopologyOptimizationSettings'] = SetTopologyOptimizationSettings,
    ['http://linksys.com/jnap/nodes/topologyoptimization/GetTopologyOptimizationSettings2'] = GetTopologyOptimizationSettings2,
    ['http://linksys.com/jnap/nodes/topologyoptimization/SetTopologyOptimizationSettings2'] = SetTopologyOptimizationSettings2
}
