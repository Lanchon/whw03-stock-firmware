--
-- 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function GetFirmwareUpdateStatus(ctx)
    local nodesfwupdate = require('nodes_firmwareupdate')

    local sc = ctx:sysctx()
    local output = nodesfwupdate.getFirmwareUpdateStatus(sc)
    return 'OK', output
end

local function UpdateFirmwareNow(ctx, input)
    local firmwareupdate = require('firmwareupdate')

    local sc = ctx:sysctx()
    local error = firmwareupdate.updateNow(sc, input.onlyCheck, input.updateServerURL)
    return error or 'OK'
end

return require('libhdklua').loadmodule('jnap_nodes_firmwareupdate'), {
    ['http://linksys.com/jnap/nodes/firmwareupdate/GetFirmwareUpdateStatus'] = GetFirmwareUpdateStatus,
    ['http://linksys.com/jnap/nodes/firmwareupdate/UpdateFirmwareNow'] = UpdateFirmwareNow,
}
