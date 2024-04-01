#!/usr/bin/lua

--
-- 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

-- nodes_notificationevents.lua - script to execute notification events generated
-- in the JNAP services layer on the Nodes platform.

local util = require('util')
local platform = require('platform')
local sysctx = require('libsysctxlua')
local notification = require('notification')
local SERVICE_NAME = 'nodes_notificationevents'

local sc = sysctx.new()
sc:readlock()

-- Only process events if the notification system is enabled
if not sc:get_nodes_notification_system_enabled() then
    return
end
sc:rollback()

local eventName, eventValue = arg[1], arg[2] or ''

local logFile
local logPath = os.getenv('NOTIFICATION_EVENTS_LOG_PATH')
if logPath then
    logFile = io.open(logPath, 'a+')
end

local function log(level, message)
    if logFile then
        logFile:write(level..': '..message)
        logFile:write('\n')
    else
        os.execute(('logger -s -t %s "%s: %s"'):format(SERVICE_NAME, level, message))
    end
end

platform.registerLoggingCallback(log)

log(platform.LOG_INFO, string.format('Received event %s with value: %s', eventName, eventValue))

local function notifyAdminPasswordChange()
    local error

    sc:readlock()
    -- Only send the notification from a Master node, when a user changed the password
    if (sc:get_smartmode() == 2) and (sc:get_node_user_set_admin_password() == 'true') then
        sc:rollback()
        log(platform.LOG_INFO, 'Sending notification event ADMIN_PASSWORD_CHANGE')
        error = notification.eventNotification(sc, 'ADMIN_PASSWORD_CHANGE')
    else
        sc:rollback() -- release the lock
    end

    assert(not error, error)
end

local function notifyShieldStatusChange(status)
    local error
    local cfgName = 'shield::notify_status'

    sc:writelock()
    local prevStatus = sc:get(cfgName)

    -- If the status has changed, then send a notifcation to the cloud
    if (prevStatus ~= status) then
        sc:set(cfgName, status)
        sc:commit()
        local payload = {
            provider = 'TREND_MICRO',
            status = (status == 'active' and '1' or '0'),
            note = sc:getevent('TrendMicroNodes-errinfo')
        }
        log(platform.LOG_INFO, string.format('Sending notification event SERVICE_STATUS_CHANGE', status))
        error = notification.eventNotification(sc, 'SERVICE_STATUS_CHANGE', payload)
    else
        sc:rollback()
    end

    assert(not error, error)
end

--
-- Add your event handler here
--
-- The handler will be called with the event value (or '') as the only parameter.
--
local handlers = {
    ['http_admin_password'] = notifyAdminPasswordChange,
    ['shield::subscription_status'] = notifyShieldStatusChange
}


local handler = handlers[eventName]
if handler then
    local success, error = pcall(handler, eventValue)
    if success then
        log(platform.LOG_INFO, string.format('Handled event %s.', eventName))
    else
        log(platform.LOG_ERROR, string.format('Handler for event %s failed (%s).', eventName, error))
    end
else
    log(platform.LOG_ERROR, string.format('No handler found for event %s.', eventName))
end

if logFile then
    logFile:close()
end
