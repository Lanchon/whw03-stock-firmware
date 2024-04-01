#!/usr/bin/lua

--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

-- onboard_wifi_preauth.lua - script to handle WiFi onboarding of preuathorized devices

local SERVICE_NAME = 'onboard_wifi_preauth'
local LOCK_PATH = '/tmp/'..SERVICE_NAME

local platform = require('platform')
local sysctx = require('libsysctxlua')
local lfs = require('lfs')
local xconnect = require('xconnect')

local preauthDevices
local errorOccurred = false
local procStatus = 'starting'

local function log(level, message)
    os.execute(('logger -s -t %s %s: %s'):format(SERVICE_NAME, level, message))
end

platform.registerLoggingCallback(log)

----------------------------------------

local function setStatus(status, logIt)
    procStatus = status
    if logIt then
        platform.logMessage(platform.LOG_INFO, status)
    end
end

----------------------------------------

local function setErrorStatus(sc, error, device)
    if error then
        errorOccurred = true
        local msg = string.format('Failed %s with error: %s', procStatus, error)
        platform.logMessage(platform.LOG_ERROR, msg)
        sc:writelock()
        if device then
            sc:set_onboard_wifi_preauth_errinfo('Failed onboarding device')
            sc:set_onboard_preauth_device_errinfo(device.serial, error)
        else
            sc:set_onboard_wifi_preauth_errinfo(msg)
        end
        sc:commit()
    end
end

----------------------------------------

local function discoverDevices(sc)
    local output

    setStatus('discovering devices', true)
    sc:writelock()
    local error = xconnect.requestSmartConnectSurvey(sc)
    if error then
        sc:rollback()
    else
        sc:commit()
        local isRunning = true
        while not error and isRunning do
            os.execute('sleep 1')
            error, output = xconnect.getSmartConnectNextResult(sc)
            sc:rollback()
            isRunning = output and output.isRunning or false
        end
    end
    setErrorStatus(sc, error)

    return error, output and output.smartConnectClientInfo or nil
end

----------------------------------------

local function onboardDevice(sc, device)
    setStatus(('onboarding device %s'):format(tostring(device.bssid)), true)

    sc:writelock()
    local error = xconnect.requestOnboardSmartConnectClient(sc, { bssid = device.bssid })
    if error then
        sc:rollback()
    else
        sc:commit()
        local output
        local isRunning = true
        while not error and isRunning do
            os.execute('sleep 1')
            sc:readlock()
            error, output = xconnect.getOnboardSmartConnectClientStatus(sc)
            sc:rollback()
            isRunning = output and output.isRunning or false
        end
        if not error and (output.status ~= 'Success') then
            error = output.status
        end
    end
    setErrorStatus(sc, error, device)

    return error or nil
end

----------------------------------------

local function isPreauthorizedDevice(deviceId)
    for i = 1, #preauthDevices do
        if preauthDevices[i] == deviceId then
            return true
        end
    end
    return false
end

-----------------------------------------------------
-- Main
-----------------------------------------------------

-- Only one instance of this process can be running,
-- so use a directory lock for mutual exclusion.
lfs.mkdir(LOCK_PATH)
local lock, error = lfs.lock_dir(LOCK_PATH)
if not lock then
    platform.logMessage(platform.LOG_INFO, 'Could not acquire lock: '..error)
    return
end

local sc = sysctx.new()

-- Get a list of preauthorized devices
sc:readlock()
preauthDevices = sc:get_preauthorized_devices()
sc:rollback()

-- If there are no preauthorized devices, then nothing to do
if #preauthDevices == 0 then
    platform.logMessage(platform.LOG_INFO, 'No preauthorized devices found')
    return
end

-- Discover devices
local error, nextDevice = discoverDevices(sc)

-- Onboard discovered devices
while nextDevice do
    local output
    -- If the discovered device is preauthorized, then onboard it
    if (isPreauthorizedDevice(nextDevice.serial)) then
        onboardDevice(sc, nextDevice)
    else
        platform.logMessage(platform.LOG_INFO, ('Device %s is not preauthorized'):format(nextDevice.serial))
    end

    -- Wait 120 seconds for the smartconnect setup process to complete
    local i = 0
    while i <= 24 and sc:getevent('smart_connect::setup_status') ~= 'READY' do
        os.execute('sleep 5')
        i = i + 1
    end

    if i > 24 then
        nextDevice = nil
        setErrorStatus(sc, 'Timed out waiting for smartconnect setup process to complete')
    else
        -- Get the next discovered device
        setStatus('getting next device info', true)
        error, output = xconnect.getSmartConnectNextResult(sc)
        sc:rollback()
        setErrorStatus(sc, error)
        nextDevice = output and output.smartConnectClientInfo or nil
    end
end

-- Set the resulting status
sc:writelock()
if errorOccurred then
    sc:set_onboard_wifi_preauth_status('Error')
else
    sc:set_onboard_wifi_preauth_status('Success')
end
sc:commit()

platform.logMessage(platform.LOG_INFO, 'Done.')

-- Free the directory lock
lock:free()
