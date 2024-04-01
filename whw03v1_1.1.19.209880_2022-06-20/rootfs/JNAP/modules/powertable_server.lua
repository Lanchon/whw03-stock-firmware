--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: jianxiao $
-- $DateTime: 2018/05/28 00:12:59 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/powertable/powertable_server.lua#1 $
--


local function GetPowerTableSettings(ctx)
    local powertable = require('powertable')
    local sc = ctx:sysctx()

    return 'OK', powertable.getPowerTableSettings(sc)
end

local function SetPowerTableSettings(ctx, input)
    local powertable = require('powertable')
    local sc = ctx:sysctx()

    local error = powertable.setPowerTableSettings(sc, input.country)
    return error or 'OK'
end

return require('libhdklua').loadmodule('jnap_powertable'), {
    ['http://linksys.com/jnap/powertable/GetPowerTableSettings'] = GetPowerTableSettings,
    ['http://linksys.com/jnap/powertable/SetPowerTableSettings'] = SetPowerTableSettings,
}
