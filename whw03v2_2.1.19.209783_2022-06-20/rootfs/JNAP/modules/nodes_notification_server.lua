--
-- 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function GetNotificationSystemSettings(ctx)
    local sc = ctx:sysctx()
    sc:readlock()
    return 'OK', {
        isNotificationSystemEnabled = sc:get_nodes_notification_system_enabled()
    }
end

local function SetNotificationSystemSettings(ctx, input)
    local sc = ctx:sysctx()
    sc:writelock()
    sc:set_nodes_notification_system_enabled(input.isNotificationSystemEnabled)

    return 'OK'
end

return require('libhdklua').loadmodule('jnap_nodes_notification'), {
    ['http://linksys.com/jnap/nodes/notification/GetNotificationSystemSettings'] = GetNotificationSystemSettings,
    ['http://linksys.com/jnap/nodes/notification/SetNotificationSystemSettings'] = SetNotificationSystemSettings
}
