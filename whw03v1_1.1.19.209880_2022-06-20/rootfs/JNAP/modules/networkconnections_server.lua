--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hesia $
-- $DateTime: 2019/10/09 16:05:17 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/networkconnections/networkconnections_server.lua#2 $
--

local function GetNetworkConnections(ctx, input)
    local networkconnections = require('networkconnections')

    local sc = ctx:sysctx()

    local connections = networkconnections.getNetworkConnections(sc, input.macAddresses, false)

    -- Remove the mode member from the wireless connections. It is not expected in the output.
    for _, connection in ipairs(connections) do
        if connection.wireless then
            connection.wireless.mode = nil
        end
    end
    return 'OK', {
        connections = connections
    }
end

local function GetNetworkConnections2(ctx, input)
    local networkconnections = require('networkconnections')

    local sc = ctx:sysctx()

    local connections = networkconnections.getNetworkConnections(sc, input.macAddresses, true)

    -- Remove the mode member from the wireless connections. It is not expected in the output.
    for _, connection in ipairs(connections) do
        if connection.wireless then
            connection.wireless.mode = nil
        end
    end
    return 'OK', {
        connections = connections
    }
end

return require('libhdklua').loadmodule('jnap_networkconnections'), {
    ['http://linksys.com/jnap/networkconnections/GetNetworkConnections'] = GetNetworkConnections,
    ['http://linksys.com/jnap/networkconnections/GetNetworkConnections2'] = GetNetworkConnections2
}
