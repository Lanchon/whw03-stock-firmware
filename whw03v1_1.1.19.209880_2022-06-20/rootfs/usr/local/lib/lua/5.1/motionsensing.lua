--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2021/06/02 14:07:08 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/motionsensing.lua#17 $
--

-- motionsensing.lua - library to retrieve motion sensing state.

local util = require('util')
local hdk = require('libhdklua')
local lfs = require('lfs')
local devicelist = require('devicelist')

local _M = {} -- create the module

_M.unittest = {} -- unit test override data store

_M.CONFIG_FILE_PATH = '/tmp/sounder.conf'
_M.PERSISTENT_BOT_FILE_PATH = '/var/config/motion/persistent_bot_list'
_M.SCANNED_BOT_FILE_PATH = '/tmp/scanned_bot_list'
_M.MSG_MOTION_DIR = '/MOTION'
_M.STATUS_SUPPORTED_PATH = 'status.supported'
_M.BOT_CHANGE_TIMEOUT = 10

local BOT_SCAN_BATCH_SIZE = 10      -- devices
local BOT_SCAN_TIME_PER_BATCH = 130 -- seconds

--
-- Get whether motion sensing is enabled.
--
-- input = CONTEXT
--
-- output = BOOL, STRING
--
function _M.getMotionSensingSettings(sc)
    sc:readlock()

    return {
        isMotionSensingEnabled = sc:get_motionsensing_enabled(),
        configurationFile = util.readFile(_M.CONFIG_FILE_PATH)
    }
end

--
-- Set whether parental control is enabled.
--
-- input = CONTEXT, BOOLEAN
--
function _M.setMotionSensingSettings(sc, isEnabled)
    sc:writelock()
    sc:set_motionsensing_enabled(isEnabled)
end

--
-- Get motion sensing capable slaves.
--
-- input = CONTEXT
--
-- output = BOOL, STRING
--
function _M.getMotionSensingCapableSlaves(sc, version)
    sc:readlock()

    local slaves = {}
    -- If we're a master, then collect the slaves, otherwise return an empty array.
    if sc:getnumber('smart_mode::mode') == 2 then
        local subscriberFilePrefix = sc:get_subscriber_file_prefix()
        local motionDirectory = subscriberFilePrefix.._M.MSG_MOTION_DIR

        if lfs.attributes(motionDirectory, 'mode')  == 'directory' then
            for uuid in lfs.dir(motionDirectory) do
                local statusFilePath = table.concat(
                    {
                        motionDirectory,
                        uuid,
                        _M.STATUS_SUPPORTED_PATH
                    }, '/')
                if lfs.attributes(statusFilePath, 'mode')  == 'file' and pcall(hdk.uuid, uuid) then
                    if version == 1 then
                        table.insert(slaves, hdk.uuid(uuid))
                    else
                        local fh = io.open(statusFilePath, 'r')
                        if fh then
                            table.insert(slaves, {
                                deviceID = hdk.uuid(uuid),
                                supportedPhase = tonumber(fh:read('*a'))
                            })
                            fh:close()
                        end
                    end
                end
            end
        end

    end

    local output
    if (version == 1) then
        table.sort(slaves, function(uuid1, uuid2)
            return tostring(uuid1) < tostring(uuid2)
        end)
        output = {
            deviceIDs = slaves
        }
    else
        table.sort(slaves, function(node1, node2)
            return tostring(node1.deviceID) < tostring(node2.deviceID)
        end)
        output = {
            motionCapableSlaves = slaves
        }
    end

    return output
end

-- Create a table where the entries are of the form: lookup[macAddress] = macAddress
local function makeBotLookup()
   local lookup = {}
    -- Get the MAC addresses of active bot devices
    if util.isPathAFile(_M.PERSISTENT_BOT_FILE_PATH) then
        for mac in io.lines(_M.PERSISTENT_BOT_FILE_PATH) do
           lookup[mac:upper()] = mac
        end
    end
    return lookup
end

--
-- Start the process of scanning for bot capable device on the network.
--
-- input = CONTEXT
--
-- output = NIL_OR_ONE_OF(
--     'ErrorBotScanningInProcess',
--     'ErrorNoDevicesOnline'
-- )
--
function _M.startBotScanning(sc)
    sc:writelock()
    local status = sc:get_motionsensing_bot_scanning_status()
    if (status == 'Running') or (status == 'Starting') then
        return 'ErrorBotScanningInProcess'
    end

    local scanMacs = {}
    local res, devlist = devicelist.getDevices(sc, {}, 2)
    if res ~= 'OK' then
        return res
    end
    local botLookup = makeBotLookup()
    for _, dev in pairs(devlist.devices) do
        if not dev.nodeType then
            for _, conn in pairs(dev.connections) do
                for _, int in pairs(dev.knownInterfaces) do
                    local intMacStr = tostring(int.macAddress)
                    if tostring(conn.macAddress) == intMacStr and not botLookup[intMacStr:upper()] then
                        if int.interfaceType == 'Wireless' then
                            table.insert(scanMacs, intMacStr)
                        elseif int.interfaceType == 'Unknown' then
                            -- The connection interface type is unknown, so search the Nodes
                            -- wireless connections for the interface MAC address
                            local nnc = require('nodes_networkconnections')
                            local connInfo = nnc.getNodesNetworkConnections(sc, nil, { int.macAddress })
                            for _, node in pairs(connInfo.nodeWirelessConnections) do
                                if #node.connections > 0 then
                                    table.insert(scanMacs, intMacStr)
                                    break
                                end
                            end
                        end
                        break -- We found the interface for this connection, so break
                    end
                end
            end
        end
    end
    if #scanMacs == 0 then
        return 'ErrorNoDevicesOnline'
    end

    sc:start_motionsensing_bot_scanning(table.concat(scanMacs, ','))
end

--
-- Get the current status of the bot scanning process.
--
-- input = CONTEXT
--
-- output = {
--      remainingScanTime = INTEGER,
--      status = (OPTIONAL) STRING
--  }
--
function _M.getBotScanningStatus(sc)
    sc:readlock()
    local status = sc:get_motionsensing_bot_scanning_status()
    local timeRemaining = 0
    if status == 'Starting' or status == 'Running' then
        local mscSlaves = _M.getMotionSensingCapableSlaves(sc, 1)
        local batchScanTime = (#mscSlaves.deviceIDs == 0) and BOT_SCAN_TIME_PER_BATCH or (BOT_SCAN_TIME_PER_BATCH + 10)
        local startTime = sc:get_motionsensing_bot_scanning_starttime()
        local macList = sc:get_motionsensing_bot_scanlist()
        local numMacs = #util.splitOnDelimiter(macList, ',')
        local totalTime = math.ceil(numMacs / BOT_SCAN_BATCH_SIZE) * batchScanTime
        local curTime = _M.unittest.ostime or os.time()
        timeRemaining = totalTime - (curTime - startTime)
    end

    return {
        remainingScanTime = (timeRemaining < 0) and 0 or timeRemaining,
        status = status
    }
end

-- Create a table where the entries are of the form: tostring(uuid) = device.
local function makeDeviceLookup(devices)
    local lookup = nil
    if devices then
        lookup = {}
        for _, dev in pairs(devices) do
            local deviceID = tostring(dev.deviceID):upper()
            lookup[deviceID] = dev
        end
    end
    return lookup
end

--
-- Add or remove bot devices
--
-- input = CONTEXT, STRING, ARRAY_OF(UUID)
--
-- output = NIL_OR_ONE_OF(
--     'ErrorUnknownDevice',
--     'ErrorWirelessMACAddressNotFound'
-- ), TABLE
--
local function changeActiveBots(sc, operation, deviceIDs)
    -- Ensure that no lock is held when making this call, as it is blocking
    assert(not sc:isreadlocked() and not sc:iswritelocked(), 'must not hold the sysctx lock when adding/removing bots')

    -- Create a local sysctx, so we can commit the changes before
    -- waiing for the bot update to complete
    local ownedsc = _M.unittest.ctx and _M.unittest.ctx:sysctx() or require('libsysctxlua').new()
    ownedsc:writelock()

    local macList = {}

    -- Get the device info for the input deviceIDs
    local res, devlist = devicelist.getDevices(ownedsc, { deviceIDs = deviceIDs }, 2)
    if res ~= 'OK' then
        return res
    end
    local deviceLookup = makeDeviceLookup(devlist.devices)
    for _, deviceID in pairs(deviceIDs) do
        local found = false
        local device = deviceLookup[tostring(deviceID):upper()]
        if device then
            -- Search for the interface MAC address in the respective bot list
            for _, int in pairs(device.knownInterfaces) do
                local path = (operation == 'add') and _M.SCANNED_BOT_FILE_PATH or _M.PERSISTENT_BOT_FILE_PATH
                local rc = os.execute(('grep -iq %s %s'):format(tostring(int.macAddress), path))
                if (rc == 0) then
                    table.insert(macList, tostring(int.macAddress))
                    found = true
                    break
                end
            end
        else
            ownedsc:rollback()
            return 'ErrorUnknownDevice', { errorDeviceID = deviceID }
        end

        -- Return error if the device MAC address was not found in the respective bot list
        if not found then
            ownedsc:rollback()
            return 'ErrorWirelessMACAddressNotFound', { errorDeviceID = deviceID }
        end
    end
    if (operation == 'add') then
        ownedsc:add_motionsensing_bots(table.concat(macList, ','))
    elseif (operation == 'remove') then
        ownedsc:remove_motionsensing_bots(table.concat(macList, ','))
    end

    -- Commit the sysctx context before waiting for the bot update to complete
    -- unless running a unittest, where we need to preserve the state for
    -- subsequent reads.
    if not _M.unittest.ctx then
        ownedsc:commit()
    end

    -- Now wait for the bot change to complete
    for i = 1, _M.BOT_CHANGE_TIMEOUT do
        -- No lock is necessary because the function only reads sysevents
        if not sc:is_bot_change_pending() then
            break
        end
        os.execute('sleep 1')
    end

    return nil, {}
end

--
-- Add bot devices to the motion sensing network.
--
-- input = CONTEXT, ARRAY_OF(UUID)
--
-- output = NIL_OR_ONE_OF(
--     'ErrorUnknownDevice',
--     'ErrorWirelessMACAddressNotFound'
-- ), TABLE
--
function _M.addMotionSensingBots(sc, deviceIDs)
    return changeActiveBots(sc, 'add', deviceIDs)
end

--
-- Remove bot devices from the motion sensing network.
--
-- input = CONTEXT, ARRAY_OF(UUID)
--
-- output = NIL_OR_ONE_OF(
--     'ErrorUnknownDevice',
--     'ErrorWirelessMACAddressNotFound'
-- ), TABLE
--
function _M.removeMotionSensingBots(sc, deviceIDs)
    return changeActiveBots(sc, 'remove', deviceIDs)
end

--
-- Get available motion sensing bot devices.
--
-- input = CONTEXT
--
-- output = ARRAY_OF(UUID)
--
function _M.getAvailableMotionSensingBots(sc)
    sc:readlock()
    local macList = {}
    local deviceIDs = {}

    -- Get MAC addresses of available bots from the scanned bot file
    if util.isPathAFile(_M.SCANNED_BOT_FILE_PATH) then
        for line in io.lines(_M.SCANNED_BOT_FILE_PATH) do
            local mac, good = line:match('^Device:%s+(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)%s+(Good)')
            if mac and good then
                table.insert(macList, mac)
            end
        end
    end

    -- If available bots were found, then get the device ID's by matching the bot
    -- MAC addresses to their respective interfaces in the device list
    local res, devlist
    if (#macList > 0) then
        res, devlist = devicelist.getDevices(sc, {}, 2)
        if res ~= 'OK' then
            return res
        end
    end
    for _, mac in pairs(macList) do
        for _, dev in pairs(devlist.devices) do
            for _, int in pairs(dev.knownInterfaces) do
                if mac:upper() == tostring(int.macAddress):upper() then
                    table.insert(deviceIDs, dev.deviceID)
                    break
                end
            end
        end
    end

    return nil, { deviceIDs = deviceIDs }
end

--
-- Get active motion sensing bot devices.
--
-- input = CONTEXT
--
-- output = ARRAY_OF(UUID)
--
function _M.getActiveMotionSensingBots(sc)
    sc:readlock()
    local macList = {}
    local deviceIDs = {}

    -- Get the MAC addresses of active bot devices from the config file
    if util.isPathAFile(_M.PERSISTENT_BOT_FILE_PATH) then
        for mac in io.lines(_M.PERSISTENT_BOT_FILE_PATH) do
           table.insert(macList, mac)
        end
    end

    -- If active bots were found, then get the device ID's by matching the bot
    -- MAC addresses to their respective interfaces in the device list
    local res, devlist
    if (#macList > 0) then
        res, devlist = devicelist.getDevices(sc, {}, 2)
        if res ~= 'OK' then
            return res
        end
    end
    for _, mac in pairs(macList) do
        for _, dev in pairs(devlist.devices) do
            if not dev.nodeType then
                for _, int in pairs(dev.knownInterfaces) do
                    if mac:upper() == tostring(int.macAddress):upper() then
                        table.insert(deviceIDs, dev.deviceID)
                        break
                    end
                end
            end
        end
    end

    return nil, { deviceIDs = deviceIDs }
end


return _M -- return the module
