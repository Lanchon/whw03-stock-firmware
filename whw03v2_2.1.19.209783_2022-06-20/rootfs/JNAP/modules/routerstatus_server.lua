--
-- 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function SetHeartbeatInterval(ctx, input)
    local routerstatus = require('routerstatus')
    local sc = ctx:sysctx()

    local error = routerstatus.setHeartbeatInterval(sc, input)

    return error or 'OK'
end

local function GetHeartbeatInterval(ctx, input)
    local routerstatus = require('routerstatus')
    local sc = ctx:sysctx()

    return 'OK', {
        heartbeatInterval = routerstatus.getHeartbeatInterval(sc)
    }
end

return require('libhdklua').loadmodule('jnap_routerstatus'), {
    ['http://linksys.com/jnap/routerstatus/GetHeartbeatInterval'] = GetHeartbeatInterval,
    ['http://linksys.com/jnap/routerstatus/SetHeartbeatInterval'] = SetHeartbeatInterval
}
