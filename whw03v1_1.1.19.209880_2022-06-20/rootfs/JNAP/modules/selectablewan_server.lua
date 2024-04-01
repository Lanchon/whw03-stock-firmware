--
-- 2018 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hesia $
-- $DateTime: 2018/08/17 15:37:48 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/nodes/selectablewan/selectablewan_server.lua#1 $
--

local function GetPortConnectionStatus(ctx)
    local sc = ctx:sysctx()
    sc:readlock()
    local output = {}

    local portStatus = sc:get_port_connection_status()
    for i, v in pairs(portStatus) do
       local status = {
          portId = i,
          connectionState = v
       }
       table.insert(output, status)
    end

    return 'OK', {
        portConnectionStatus = output
    }
end

local function GetWANPort(ctx, input)
    local sc = ctx:sysctx()
    sc:readlock()

    return 'OK', {
        portId = sc:get_wan_port()
    }
end

local function SetWANPort(ctx, input)
    local sc = ctx:sysctx()
    sc:writelock()

    if (input.portId < 0) or (input.portId > (sc:get_num_ethernet_ports() - 1)) then
        return 'ErrorInvalidPortId'
    end
    sc:set_wan_port(input.portId)

    return 'OK'
end

return require('libhdklua').loadmodule('jnap_selectablewan'), {
    ['http://linksys.com/jnap/nodes/setup/GetPortConnectionStatus'] = GetPortConnectionStatus,
    ['http://linksys.com/jnap/nodes/setup/GetWANPort'] = GetWANPort,
    ['http://linksys.com/jnap/nodes/setup/SetWANPort'] = SetWANPort
}
