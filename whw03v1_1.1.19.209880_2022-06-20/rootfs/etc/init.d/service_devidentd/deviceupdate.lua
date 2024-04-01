#!/usr/bin/lua

--
-- 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hesia $
-- $DateTime: 2018/09/11 16:24:38 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/devidentd/support/service_devidentd/deviceupdate_devicedb.lua#1 $
--

local hdk = require('libhdklua')
local sysctx = require('libsysctxlua')
local device = require('device')
local platform = require('platform')
local devdb = require('libdevdblua')

local sc = sysctx.new()
local ddb = devdb.db()

-- An implicit read lock is acquired by device calls, which cannot be upgraded. Therefore a write lock must be
-- acquired before any calls to device are made.
sc:readlock()

local lanMACAddress = tostring(platform.getMACAddressFromNetName(sc:get('lan_ifname')))

local function getIPv4Address(sc)
    if sc:getinteger('bridge_mode', 0) > 0 then
        return sc:getevent('ipv4_wan_ipaddr')
    else
        return sc:getevent('lan_ipaddr')
    end
end

local localDev = {
    deviceId = device.getUUID(sc),
    deviceType = 'Infrastructure',
    manufacturer = device.getManufacturer(sc),
    modelNumber = device.getModelNumber(sc),
    hardwareVersion = device.getHardwareRevision(sc),
    description = device.getModelDescription(sc),
    serialNumber = device.getSerialNumber(sc),
    firmwareVersion = device.getFirmwareVersion(sc),
    firmwareDate = device.getFirmwareDate(sc),
    isAuthority = 1,
    friendlyName = device.getHostName(sc)
}

------------------------------------------------------------------------------------------------
-- RAINIER-9267: Check to see if there's any cached custom properties that need to be set
pcall(function(device)
    local PROP_CACHE_FILE = '/tmp/var/config/ipa/props/'..lanMACAddress
    local properties = {}
    for line in io.lines(PROP_CACHE_FILE) do
        local token = line:find('=')
        if token then
            table.insert(properties, { name = line:sub(1, token - 1), value = line:sub(token + 1) })
        end
    end
    if #properties > 0 then
        device.properties = properties
        os.remove(PROP_CACHE_FILE)
    end
end, localDev)
------------------------------------------------------------------------------------------------

ddb:writeLock()
-- Use a very high confidence value
ddb:setDevice(localDev, 1000000)
-- Make sure the OUI are the same, so we know it's not a bogus MAC address.
if lanMACAddress then
    local localInterface = {
        macAddr = lanMACAddress,
        interfaceType = 'wired',
        connectionOnline = 1,
        detectedByDriver = 0
    }
    ddb:setInterface(localInterface, localDev.deviceId)

    local ipAddress = getIPv4Address(sc)
    if ipAddress and ipAddress ~= ''  then
        ddb:addIpAddr(lanMACAddress, ipAddress, 'ipv4')
    end
end

-- Use the serial number as an alias
if localDev.serialNumber ~= nil and #localDev.serialNumber > 0 then
    ddb:addDeviceAlias(localDev.deviceId, localDev.serialNumber)
end

-- Commit
ddb:writeUnlockCommit()
