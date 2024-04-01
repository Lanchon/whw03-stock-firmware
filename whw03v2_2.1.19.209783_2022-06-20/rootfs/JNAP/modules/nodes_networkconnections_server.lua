--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: jianxiao $
-- $DateTime: 2018/05/28 00:12:59 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/nodes/networkconnections/nodes_networkconnections_server.lua#1 $
--

local function RefreshNodesWirelessNetworkConnections(ctx)
    local nodes_networkconnections = require('nodes_networkconnections')

    local sc = ctx:sysctx()
    local error = nodes_networkconnections.refreshNodesWirelessNetworkConnections(sc)
    return error or 'OK'
end

local function GetNodesWirelessNetworkConnections(ctx, input)
    local nodes_networkconnections = require('nodes_networkconnections')

    local sc = ctx:sysctx()
    local retVal = nodes_networkconnections.getNodesNetworkConnections(sc, input.deviceIDs, input.macAddresses)

    return 'OK', retVal
end

return require('libhdklua').loadmodule('jnap_nodes_networkconnections'), {
    ['http://linksys.com/jnap/nodes/networkconnections/RefreshNodesWirelessNetworkConnections'] = RefreshNodesWirelessNetworkConnections,
    ['http://linksys.com/jnap/nodes/networkconnections/GetNodesWirelessNetworkConnections'] = GetNodesWirelessNetworkConnections,
}
