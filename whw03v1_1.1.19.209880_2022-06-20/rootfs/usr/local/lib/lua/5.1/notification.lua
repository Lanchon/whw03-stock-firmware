--
-- 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

-- notification.lua - library to configure notifications.

local hdk = require('libhdklua')
local platform = require('platform')

local _M = {} -- create the module

local DEVICE_NOTIFY_PROPERTY_NAME = 'urn:linksys-com:device_notify'


local function clearDeviceNotificationList(tdb)
    -- Go through each device and set its dev:notify property to false if it has one
    local devices = tdb:getAllDevices().devices
    for _, device in pairs(devices) do
        if device.properties then
            for _, property in pairs(device.properties) do
                if property.name == DEVICE_NOTIFY_PROPERTY_NAME then
                   property.value = 'false'
                   tdb:setDevice(device, 0)
                end
            end
        end
    end
end

local function getDeviceNotificationList(tdb)
    local deviceIDs = {}

    -- Build up an array of all currently enabled deviceIDs
    local devices = tdb:getAllDevices().devices
    for _, device in pairs(devices) do
        if device.properties then
            for _, property in pairs(device.properties) do
                if property.name == DEVICE_NOTIFY_PROPERTY_NAME and property.value == 'true' then
                    table.insert(deviceIDs, device.deviceID)
                end
            end
        end
    end
    return #deviceIDs > 0 and deviceIDs or nil
end

local function setDeviceNotificationList(tdb, deviceIDs)
   for _, deviceID in pairs(deviceIDs) do
      local device = tdb:getDevice(deviceID)
      if not device then
         return 'ErrorUnknownDevice'
      end

      -- Create the properties table if it does not exist
      if not device.properties then
          device.properties = {}
      end

      local found = false

      -- Set dev:notify property to true if it exists
      for _, property in pairs(device.properties) do
          if property.name == DEVICE_NOTIFY_PROPERTY_NAME then
              property.value = 'true'
              found = true
          end
      end

      -- If dev:notify property does not exist, add it to the properties table
      if not found then
          table.insert(device.properties, { name = DEVICE_NOTIFY_PROPERTY_NAME, value = 'true' })
      end

      -- Now update the device
      tdb:setDevice(device, 0)
   end
end

--
-- Notify the given device online/offline status change.
--
-- input = CONTEXT, STRING, BOOLEAN
--
function _M.deviceNotification(sc, deviceID, isOnline)
    -- Ensure no lock is held when making this call as it is blocking
    assert(not sc:isreadlocked() and not sc:iswritelocked(), 'must not hold the sysctx lock when calling deviceNotification')
    -- Create our own context for reading data, so we can release it before making cloud call
    local ownedsc = require('libsysctxlua').new()
    local tdb = require('libtopodblua').db(ownedsc)
    if not tdb:readLock() then
        error('failed to acquire read lock')
    end

    -- First off, check to see if notications are enabled
    if not ownedsc:get_device_notification_enabled() then
        return 'ErrorDeviceNotificationDisabled'
    end

    -- Next, see if notifications are enabled for this specific device
    deviceID = hdk.uuid(deviceID)
    local deviceIDs = getDeviceNotificationList(tdb)
    if deviceIDs then
        local found = false
        for _, dID in pairs(deviceIDs) do
           if dID == deviceID then
               found = true
               break
           end
        end
        if not found then
            return 'ErrorDeviceNotificationDisabledForDevice'
        end
    end

    -- Check the device's current online status
    local device = tdb:getDevice(deviceID)
    if not device then
        return 'ErrorUnknownDevice'
    end

    local host = require('device').getCloudHost(ownedsc)
    local networkID = ownedsc:get_xrac_owned_network_id()
    local networkPassword = ownedsc:get_xrac_owned_network_password()
    local eventTime = platform.getCurrentLocalTime(ownedsc)
    local verifyHost = require('device').getVerifyCloudHost(ownedsc)

    -- Release the lock before calling the cloud
    ownedsc:rollback()

    -- Only fire the notification if the device still has the same online status
    local onlineStatus = #device.connections > 0 and true or false
    if onlineStatus == isOnline then
        local error = require('cloud').createEvent(
            host,
            networkID,
            networkPassword,
            tostring(deviceID),
            isOnline and 'DEVICE_JOINED_NETWORK' or 'DEVICE_LEFT_NETWORK',
            eventTime,
            verifyHost)
        if error then
            return error
        end
    else
        return 'ErrorInconsistentOnlineStatus'
    end
end

--
-- Notify that a given system event has occurred.
--
-- input = CONTEXT, STRING, [OPTIONAL]TABLE
--
function _M.eventNotification(sc, eventType, payload)
    -- Ensure no lock is held when making this call as it is blocking
    assert(not sc:isreadlocked() and not sc:iswritelocked(), 'must not hold the sysctx lock when calling eventNotification')

    local device = require('device')
    local ownedsc = require('libsysctxlua').new()
    ownedsc:readlock()

    local deviceID = ownedsc:get_device_uuid()
    local host = device.getCloudHost(ownedsc)
    local networkID = ownedsc:get_xrac_owned_network_id()
    local networkPassword = ownedsc:get_xrac_owned_network_password()
    local eventTime = platform.getCurrentLocalTime(ownedsc)
    local verifyHost = device.getVerifyCloudHost(ownedsc)

    -- Release the lock before calling the cloud
    ownedsc:rollback()

    local error = require('cloud').createEvent(
        host,
        networkID,
        networkPassword,
        deviceID,
        eventType,
        eventTime,
        verifyHost,
        payload and require('libhdkjsonlua').stringify(payload))

    if error then
        return error
    end
end

--
-- Get the device notification settings.
--
-- input = CONTEXT
--
-- output = {
--     isEnabled = BOOLEAN,
--     deviceIDs = ARRAY_OF(UUID)
-- }
--
function _M.getDeviceNotificationSettings(sc)
    local tdb = require('libtopodblua').db(sc)
    if not tdb:readLock() then
        error('failed to acquire read lock')
    end
    return {
        isEnabled = sc:get_device_notification_enabled(),
        deviceIDs = getDeviceNotificationList(tdb)
    }
end

--
-- Set the device notification settings.
--
-- input = CONTEXT, {
--     isEnabled = BOOLEAN,
--     deviceIDs = ARRAY_OF(UUID)
-- }
--
function _M.setDeviceNotificationSettings(sc, settings)
    local function deviceNotificationListsEqual(list1, list2)
        if list1 and list2 and #list1 == #list2 then
            table.sort(list1)
            table.sort(list2)
            for i in ipairs(list1) do
                if list1[i] ~= list2[i] then
                    return false
                end
            end
            return true
        end
        return false
    end

    -- Return luaerror('')
    local tdb = require('libtopodblua').db(sc)
    if not tdb:writeLock() then
        error('failed to acquire write lock')
    end

    local currentDeviceNotifications = getDeviceNotificationList(tdb)
    if settings.isDeviceNotificationEnabled then
        -- If we're enabling notifications, then update the list of device IDs to notify
        if not deviceNotificationListsEqual(currentDeviceNotifications, settings.deviceIDs) then
            clearDeviceNotificationList(tdb)
            if settings.deviceIDs then
                local error = setDeviceNotificationList(tdb, settings.deviceIDs)
                if error then
                    return error
                end
            end
        end
    else
        -- If we're disabling, clear out individual notifications if any are set
        if currentDeviceNotifications and #currentDeviceNotifications > 0 then
            clearDeviceNotificationList(tdb)
        end
    end

    deviceNotificationConfigured = sc:set_device_notification_enabled(settings.isDeviceNotificationEnabled) or deviceNotificationConfigured
end

return _M -- return the module
