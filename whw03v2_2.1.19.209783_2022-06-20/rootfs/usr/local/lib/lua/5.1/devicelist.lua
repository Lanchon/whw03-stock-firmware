--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: bechang $
-- $DateTime: 2021/06/23 10:52:03 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/devicelist_devicedb.lua#9 $
--

local devicedb = require('libdevdblua')
local hdk = require('libhdklua')
local platform = require('platform')

local _M = {} -- create the module

---------------------------------------------------------------------------------
-- Constants.
---------------------------------------------------------------------------------

local MAX_PROPERTIES = 16
local MAX_PROPERTY_NAME_LENGTH = 31
local MAX_PROPERTY_VALUE_LENGTH = 255

---------------------------------------------------------------------------------
-- Utility functions.
---------------------------------------------------------------------------------

-- Create a table of where the entries are of the form: tostring(uuid) = uuid.
local function makeDeviceLookup(deviceIDs)
    local lookup = nil
    if deviceIDs then
        lookup = {}
        for i, deviceID in ipairs(deviceIDs) do
            lookup[tostring(deviceID):upper()] = deviceID
        end
    end
    return lookup
end

-- Create a list of device IDs from a device list
local function deviceListToDeviceIDs(devices)
    local deviceIDs = {}
    if devices then
        for i = 1, #devices do
            deviceIDs[i] = hdk.uuid(devices[i].deviceId)
        end
    end
    return deviceIDs
end

local function isValidPropertyName(name)
    return #name <= MAX_PROPERTY_NAME_LENGTH and string.find(name, '^[A-Za-z][A-Za-z0-9%-_:]*$') ~= nil
end

local function isValidPropertyValue(value)
    return #value <= MAX_PROPERTY_VALUE_LENGTH
end

local function parseInterfaceType(interfaceType)
    if interfaceType then
        if interfaceType == 'wired' then
            return 'Wired'
        elseif interfaceType == 'wireless' then
            return 'Wireless'
        end
    end

    return 'Unknown'
end

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

-- Convert DevDB property to JNAP property
local function toOutputProperties(properties)
    local outputProperties = {}
    if properties then
        for name, value in pairs(properties) do
            table.insert(outputProperties, { name = name, value = value })
        end
    end
    return outputProperties
end

local function toOutputInterface(interfaces, apiVersion)
    local outputInterfaces = {}
    local outputConnections = {}

    if interfaces then
        for _, iface in ipairs(interfaces) do
            -- populate the knownInterfaces / knownMACAddresses table
            local ifaceMacAddr = string.gsub(iface.macAddr, '-', ':')
            if apiVersion == 1 then
                table.insert(outputInterfaces, hdk.macaddress(ifaceMacAddr))
            else
                local interface = {
                    macAddress = hdk.macaddress(ifaceMacAddr),
                    interfaceType = parseInterfaceType(iface.interfaceType)
                }
                -- Populate wifi band
                if interface.interfaceType == 'Wireless' and iface.wifiBand then
                    if iface.wifiBand == '2.4G' then
                        interface.band = '2.4GHz'
                    elseif iface.wifiBand == '5G' then
                        interface.band = '5GHz'
                    end
                end
                table.insert(outputInterfaces, interface)
            end

            -- populate the connections table
            if iface.connectionOnline and tonumber(iface.connectionOnline) == 1 and iface.ipaddr then
                local connection = {}
                for i, ipAddr in ipairs(iface.ipaddr) do
                    connection.macAddress = hdk.macaddress(ifaceMacAddr)
                    if ipAddr.type == 'ipv4' then
                        connection.ipAddress = hdk.ipaddress(ipAddr.ip)
                    end
                    if ipAddr.type == 'ipv6' then
                        connection.ipv6Address = hdk.ipv6address(ipAddr.ip)
                    end
                    if apiVersion == 2 and iface.parentDeviceId and #iface.parentDeviceId > 0 then
                        connection.parentDeviceID = hdk.uuid(iface.parentDeviceId)
                    end
                end
                -- if it's online check to see if it's on the guest network
                if apiVersion == 2 and iface.guestNet and iface.guestNet == '1' then
                    connection.isGuest = true
                end
                table.insert(outputConnections, connection)
            end
        end
    end
    return outputInterfaces, outputConnections
end

local function toOutputDevice(sc, d, apiVersion)
    local model = {
        deviceType = d.deviceType or '',
        manufacturer = d.manufacturer, -- may be nil
        modelNumber = d.modelNumber, -- may be nil
        hardwareVersion = d.hardwareVersion, -- may be nil
        description = d.description -- may be nil
    }
    local unit = {
        serialNumber = d.serialNumber, -- may be nil
        firmwareVersion = d.firmwareVersion, -- may be nil
        firmwareDate = tonumber(d.firmwareDate), -- may be nil
        operatingSystem = d.operatingSystem -- may be nil
    }
    local outputDevice = {
        deviceID = hdk.uuid(d.deviceId),
        lastChangeRevision = tonumber(d.lastChangedRevision) or 0,
        model = model,
        unit = unit,
        friendlyName = d.friendlyName or d.hostName, -- may be nil (fallback to host name if friendly name is not set)
        isAuthority = tonumber(d.isAuthority) == 1 and true or false,
        properties = d.property and toOutputProperties(d.property) or {},
        maxAllowedProperties = MAX_PROPERTIES
    }

    if apiVersion == 1 then
        outputDevice.knownMACAddresses, outputDevice.connections = toOutputInterface(d.interface, apiVersion)
    else -- if apiVersion == 2
        outputDevice.knownInterfaces, outputDevice.connections = toOutputInterface(d.interface, apiVersion)
        if d.infrastructure and d.infrastructure.infrastructure then
            if d.infrastructure.infrastructureType == 'master' then
                outputDevice.nodeType = 'Master'
            elseif d.infrastructure.infrastructureType == 'slave' then
                outputDevice.nodeType = 'Slave'
            end
            outputDevice.isHomeKitSupported = outputDevice.nodeType and sc:get_homekit_supported(d.deviceId)
        end
    end
    return outputDevice
end

---------------------------------------------------------------------------------
-- Inner functions implementing the service's business logic.
---------------------------------------------------------------------------------

local function innerGetDevices(sc, ddb, input, apiVersion)
    local includeDeviceWithID = makeDeviceLookup(input.deviceIDs)
    local devices, revision, deleted
    local output = { devices = {} }
    local result = 'OK'

    -- Use pcall to catch errors from DeviceDB
    local success, errMsg = pcall(function() devices, revision, deleted = ddb:getChangedDevices(input.sinceRevision or 0) end)
    if success then
        output.revision = revision
        for _, device in ipairs(devices) do
            if includeDeviceWithID == nil or includeDeviceWithID[tostring(device.deviceId)] then
                -- filter out offline guest devices
                if not (device.detectedOnNetwork and device.detectedOnNetwork == 'guest' and not isDeviceOnline(device.interface)) then
                    table.insert(output.devices, toOutputDevice(sc, device, apiVersion))
                end
            end
        end

        if input.sinceRevision then
            output.deletedDeviceIDs = {}
            local deletedDevicesByID = deviceListToDeviceIDs(deleted)
            deletedDevicesByID = makeDeviceLookup(deletedDevicesByID)
            for deletedIDString, deletedID in pairs(deletedDevicesByID) do
                if includeDeviceWithID == nil or includeDeviceWithID[tostring(deletedIDString)] then
                    table.insert(output.deletedDeviceIDs, deletedID)
                end
            end
        end
    else
        platform.logMessage(platform.LOG_ERROR, 'ERROR: '..tostring(errMsg))
        result, output = 'ErrorDeviceDBFailure', { ErrorInfo = errMsg }
    end
    pcall(ddb.readUnlock, ddb)

    return result, output
end

local function innerSetDeviceProperties(sc, ddb, input)
    local device = ddb:getDevice(tostring(input.deviceID):upper())
    if not device then
        ddb:writeUnlockRollback()
        return 'ErrorUnknownDevice'
    else
        -- Convert the existing property array into a dictionary.
        local dict, removed = {}, {}
        if device.property then
            for name, value in pairs(device.property) do
                dict[name] = value
            end
        end

        -- Remove properties from the dictionary.
        if input.propertiesToRemove then
            for i, name in ipairs(input.propertiesToRemove) do
                if not isValidPropertyName(name) then
                    ddb:writeUnlockRollback()
                    return 'ErrorInvalidPropertyName'
                end
                dict[name] = nil
                removed[name] = true
            end
        end

        -- Add/modify properties to/in the dictionary.
        if input.propertiesToModify then
            for i, prop in ipairs(input.propertiesToModify) do
                if not isValidPropertyName(prop.name) then
                    ddb:writeUnlockRollback()
                    return 'ErrorInvalidPropertyName'
                end
                if not isValidPropertyValue(prop.value) then
                    ddb:writeUnlockRollback()
                    return 'ErrorPropertyValueTooLong'
                end
                dict[prop.name] = prop.value
                removed[prop.name] = nil
            end
        end

        -- Convert the dictionary back to array form.
        device.properties = {}
        for name, value in pairs(dict) do
            table.insert(device.properties, { name = name, value = value })
        end

        -- Check if there are too many properties.
        if device.properties and #device.properties > MAX_PROPERTIES then
            ddb:writeUnlockRollback()
            return 'ErrorTooManyProperties'
        end

        -- Add 'no value' entries to the array for all the
        -- properties we want to delete; setDevice interprets
        -- these entries as requests to remove the properties.
        for name, wasRemoved in pairs(removed) do
            table.insert(device.properties, { name = name })
        end
    end

    -- Iterate through the properties. If it has a value, then we need to add it
    -- to the DevDB property. If value is nil, we need to remove the property
    for i, prop in ipairs(device.properties) do
        if prop.value then
            ddb:addProperty(tostring(input.deviceID):upper(), prop.name, prop.value)
        else
            ddb:delProperty(tostring(input.deviceID):upper(), prop.name)
        end
    end

    ddb:writeUnlockCommit()
    -- Need to force a backup here.
    sc:setevent('devicedb-backup')
    return 'OK'
end

local function innerDeleteDevice(sc, ddb, deviceID)
    local deviceIdStr = tostring(deviceID):upper()
    local device = ddb:getDevice(deviceIdStr)
    if not device then
        ddb:writeUnlockRollback()
        return 'ErrorUnknownDevice'
    elseif device.isAuthority or isDeviceOnline(device.interface) then
        ddb:writeUnlockRollback()
        return 'ErrorCannotDeleteDevice'
    else
        ddb:deleteDevice(deviceIdStr) --@ TODO: handle return value from deleteDevice()
        ddb:writeUnlockCommit()
        -- Need to force a backup here.
        sc:setevent('devicedb-backup')
        sc:set_homekit_supported(deviceIdStr, nil)
    end
    return 'OK'
end

local function innerClearDeviceList(sc, ddb, saveProps, apiVersion)
    local result, output = 'OK', {}
    -- TODO: saveProps isn't currently being used. It's coming later.
    local success, errMsg = pcall(function()
        local devices = ddb:getAllDevices()
        for _, device in ipairs(devices) do
            if not device.infrastructure then
                ddb:deleteDevice(device.deviceId)
            end
        end
        ddb:writeUnlockCommit()
    end)

    if success then
        sc:reboot() -- graceful reboot will backup the DB, hence no need to set devicedb-backup sysevent
    else -- Failure occurred in Device DB
        pcall(ddb.writeUnlockRollback, ddb)
        if apiVersion == 2  then
            result, output = 'ErrorDeviceDBFailure', { ErrorInfo = errMsg }
        end
    end

    return result, (apiVersion == 2) and output or nil
end

---------------------------------------------------------------------------------
-- Outer functions that lock the DB before calling the inner functions.
---------------------------------------------------------------------------------

function _M.getDevices(sc, input, apiVersion)
    sc:readlock()
    local ddb = devicedb.db()
    if not ddb:readLock() then
        return 'Error'
    end
    return innerGetDevices(sc, ddb, input, apiVersion)
end

function _M.setDeviceProperties(sc, input)
    sc:writelock()
    local ddb = devicedb.db()
    if not ddb:writeLock() then
        return 'Error'
    end
    return innerSetDeviceProperties(sc, ddb, input)
end

function _M.deleteDevice(sc, deviceID)
    sc:writelock()
    local ddb = devicedb.db()
    if not ddb:writeLock() then
        return 'Error'
    end
    return innerDeleteDevice(sc, ddb, deviceID)
end

function _M.clearDeviceList(sc, saveProps, apiVersion)
    sc:writelock()
    local ddb = devicedb.db()
    if not ddb:writeLock() then
        return 'Error'
    end
    return innerClearDeviceList(sc, ddb, saveProps, apiVersion)
end

return _M -- return the module
