--
-- 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

-- nodes_firmwareupdate.lua - library to configure firmware update state for Nodes platform.

local platform = require('platform')

local _M = {} -- create the module

_M.FWUP_STATUS_DIR = '/tmp/msg/FWUPD'
_M.FWUP_STATUS_PATH = _M.FWUP_STATUS_DIR..'/%s/status'
_M.STATUS_PARSE_CMD = 'jsonparse -f %s %s'

local function getFWStatusValue(deviceId, name)
    local cmd = string.format(_M.STATUS_PARSE_CMD, _M.FWUP_STATUS_PATH:format(deviceId), name)
    local file = io.popen(cmd)
    if file then
        local value = file:read()
        file:close()
        return value
    end
end

--
-- Get information about the currently available firmware update, if any.
--
-- input = CONTEXT
--
-- output = OPTIONAL({
--     firmwareVersion = STRING,
--     firmwareDate = NUMBER,
--     description = STRING
-- })
--
function _M.getAvailableUpdate(deviceId)
    local fwversion = getFWStatusValue(deviceId, 'data.fwup_newfirmware_version')
    local fwdate = tonumber(getFWStatusValue(deviceId, 'data.fwup_newfirmware_date'))
    if fwversion and #fwversion > 0 and fwdate and fwdate ~= 0 then
        local fwupdate = {
            firmwareVersion = fwversion,
            firmwareDate = fwdate,
            description = getFWStatusValue(deviceId, 'data.fwup_newfirmware_details')
        }
        return fwupdate
    end
end

--
-- Get the status of the pending firmware update operation.
--
-- input = CONTEXT
--
-- output = OPTIONAL({
--     operation = STRING,
--     progressPercent = NUMBER
-- })
--
function _M.getPendingOperationStatus(deviceId)
    local progress = getFWStatusValue(deviceId, 'data.progress')
    if progress then
        local state, pct = progress:match('(%d+),(%d+)')
        state = tonumber(state)
        if state and pct then
            local op
            if state == 1 then
                op = 'Checking'
            elseif state == 3 then
                op = 'Downloading'
            elseif state == 4 then
                op = 'Installing'
            elseif state == 5 then
                op = 'Rebooting'
            end
            if op then
                return {
                    operation = op,
                    progressPercent = tonumber(pct)
                }
            end
        end
    end
end

--
-- Get the last firmware update operation failure.
--
-- input = CONTEXT
--
-- output = OPTIONAL(STRING)
--
function _M.getLastOperationFailure(deviceId)
    local details = getFWStatusValue(deviceId, 'data.fwup_newfirmware_status_details')
    if details and details:find('ERROR') then
        if details:find('server') then
            return 'CheckFailed'
        elseif details:find('Downloading') then
            return 'DownloadFailed'
        else
            return 'InstallFailed'
        end
    end
end


--
-- Get the firmware update status for all nodes on the network.
--
-- input = CONTEXT
--
-- output = ARRAY_OF({
--      lastSuccessfulCheckTime = NUMBER,
--      deviceUUID = UUID,
--      firmwareUpdate = OPTIONAL({
--          firmwareVersion = STRING,
--          firmwareDate = DATE,
--          description = STRING
--      })
--      pendingOperation = OPTIONAL({
--          operation = STRING,
--          progressPercent = INT
--      })
--      lastOperationFailure = OPTIONAL(STRING)
--  })
--
function _M.getFirmwareUpdateStatus(sc)
    local util = require('util')
    local hdk = require('libhdklua')
    local firmwareupdate = require('firmwareupdate')
    local fwupStatus = {}

    sc:readlock()

    -- Get the status information for this (master) node
    local deviceId = sc:get_device_uuid()
    local status = {
        deviceUUID = hdk.uuid(deviceId),
        lastSuccessfulCheckTime = firmwareupdate.getLastSuccessfulCheckTime(sc),
        availableUpdate = firmwareupdate.getAvailableUpdate(sc),
        pendingOperation = firmwareupdate.getPendingOperationStatus(sc),
        lastOperationFailure = firmwareupdate.getLastOperationFailure(sc)
    }
    fwupStatus[1] = status

    -- Get the status information for connected secondary nodes
    local deviceIds = util.getSubdirectorySet(_M.FWUP_STATUS_DIR)
    if deviceIds then
        deviceIds = util.setToArray(deviceIds)
        for i = 1, #deviceIds do
            deviceId = deviceIds[i]
            status = {
                deviceUUID = hdk.uuid(deviceId),
                lastSuccessfulCheckTime = tonumber(getFWStatusValue(deviceId, 'data.fwup_lastsuccess_checktime')) or 0,
                availableUpdate = _M.getAvailableUpdate(deviceId),
                pendingOperation =  _M.getPendingOperationStatus(deviceId),
                lastOperationFailure = _M.getLastOperationFailure(deviceId)
            }
            fwupStatus[i+1] = status
        end
    end

    return { firmwareUpdateStatus = fwupStatus }
end

return _M -- return the module
