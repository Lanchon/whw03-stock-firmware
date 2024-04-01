#!/usr/bin/lua

--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hesia $
-- $DateTime: 2019/10/09 16:05:17 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/devidentd/support/service_devidentd/deviceprune_devicedb.lua#2 $
--

-- deviceprune_devicedb.lua - a tool to prune devices that have been offline for a while.

local devicedb = require('libdevdblua')
local hdk = require('libhdklua')

local function isDeviceOnline(interfaces)
    if interfaces then
        for _, iface in ipairs(interfaces) do
            if iface.connectionOnline and tonumber(iface.connectionOnline) == 1 then
                return true
            end
        end
    end
    return false
end

local function isDeviceAnInfrastructure(device)
    -- device.infrastructure.infrastructureType is either 'master' or 'slave'
    if device.infrastructure and device.infrastructure.infrastructureType then
        return true
    end
    return false
end

local function isGuestDevice(device)
    -- check if device is detected on the guest network
    if device.detectedOnNetwork and device.detectedOnNetwork == 'guest' then
        return true
    end
    -- DeviceDB v1 schema doesn't have detectedOnNetwork property, so we iterate through
    -- all interfaces and see if all of them are on the guest network
    local count = 0
    if device.interface then
        for _, iface in ipairs(device.interface) do
            if iface.guestNet and tonumber(iface.guestNet) == 1 then
                count = count + 1
            end
        end
    end
    return count == #device.interface
end

local utc = os.date('!*t')
local year = utc.year
local month = utc.month - 2
if month < 1 then
    year = year - 1
    month = month + 12
end
local pruneMain = hdk.datetime(string.format('%d-%02d-01T00:00:00Z', year, month))

local currentEpochTime = hdk.datetime(os.date('%Y-%m-%dT00:00:00Z'))
local cutoffInSecGuest = (24 * 60 * 60) -- 24 hours
local pruneGuest = currentEpochTime - cutoffInSecGuest

local ddb = devicedb.db()
if ddb:writeLock() then
    local devices = ddb:getChangedDevices(0)
    for _, device in ipairs(devices) do
        if not device.isAuthority and
                not isDeviceAnInfrastructure(device) and
                not isDeviceOnline(device.interface) and
                device.lastSeenOnline then
            if isGuestDevice(device) then
                if tonumber(device.lastSeenOnline) <= pruneGuest then
                    ddb:deleteDevice(device.deviceId)
                end
            else
                if tonumber(device.lastSeenOnline) <= pruneMain then
                    ddb:deleteDevice(device.deviceId)
                end
            end
        end
    end
    ddb:writeUnlockCommit()
end
