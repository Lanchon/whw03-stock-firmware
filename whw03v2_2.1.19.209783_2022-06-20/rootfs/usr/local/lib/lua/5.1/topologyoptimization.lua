--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$ -- $Id$
--

-- topologyoptimization.lua - library to configure the network topology optimization settings.

local _M = {} -- create the module


function _M.getTopologyOptimizationSettings(sc, version)
    sc:readlock()

    local isNodeSteeringEnabled
    if (version > 1) then
        isNodeSteeringEnabled = sc:get_node_steering_enabled()
    end
    return {
        isClientSteeringEnabled = sc:get_client_steering_enabled(),
        isNodeSteeringEnabled = isNodeSteeringEnabled
    }
end

function _M.setTopologyOptimizationSettings(sc, input, version)
    sc:writelock()

    local currentMode = require('smartmode').getSmartMode(sc)
    if currentMode ~= 'Master' then
        return 'ErrorDeviceNotInMasterMode'
    end
    sc:set_client_steering_enabled(input.isClientSteeringEnabled)
    if (version > 1) then
        sc:set_node_steering_enabled(input.isNodeSteeringEnabled)
    end
end

return _M -- return the module
