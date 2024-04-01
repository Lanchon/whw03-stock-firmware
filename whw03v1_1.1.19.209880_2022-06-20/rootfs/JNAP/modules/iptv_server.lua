--
-- 2021 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local iptv = require('iptv')

local function GetIPTVSettings(ctx)
    local sc = ctx:sysctx()

    return 'OK', iptv.getIPTVSettings(sc)
end

local function SetIPTVSettings(ctx, input)
    local sc = ctx:sysctx()

    local err = iptv.setIPTVSettings(sc, input)
    return err or 'OK'
end

return require('libhdklua').loadmodule('jnap_iptv'), {
    ['http://linksys.com/jnap/iptv/GetIPTVSettings'] = GetIPTVSettings,
    ['http://linksys.com/jnap/iptv/SetIPTVSettings'] = SetIPTVSettings
}
