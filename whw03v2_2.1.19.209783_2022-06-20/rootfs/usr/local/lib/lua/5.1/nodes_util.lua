--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2020/10/29 22:44:11 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/nodes/nodes_util.lua#3 $
--

-- nodes_util.lua - utility functions related to nodes.

local json = require('libhdkjsonlua')
local lfs = require('lfs')
local util = require('util')

local _M = {}   --create the module

-- Directories
_M.MSG_SMARTCONNECT_DIR = 'SC'
_M.MSG_CONFIGME_DIR = 'CONFIG-ME'
_M.MSG_BACKHAUL_DIR = 'BH'
_M.MSG_WIRELESS_DIR = 'WLAN'
_M.MSG_MESHUSB_DIR = 'MESHUSB'

--
-- Returns the smart mode of the device
-- 0 for unconfigured, 1 for Slave, and 2 for Master.
--
local function getSmartMode(sc)
    return sc:get_smartmode()
end

--
-- Returns true if node is a master
--
function _M.isNodeAMaster(sc)
    sc:readlock()
    if getSmartMode(sc) == 2 then
        return true
    end
    return false
end

--
-- Returns true if node is a slave
--
function _M.isNodeASlave(sc)
    sc:readlock()
    if getSmartMode(sc) == 1 then
        return true
    end
    return false
end

--
-- Returns UUIDs of online slaves.
-- Slaves that are gracefully shutdown won't be returned.
--
function _M.getOnlineSlaveUUIDs(sc)
    sc:readlock()
    local uuids = {}
    local backhaulDirectory = util.concatPaths({
        _M.getSubscriberFilePrefix(sc),
        _M.MSG_BACKHAUL_DIR
    })

    if util.isPathADirectory(backhaulDirectory) then
        -- Iterate through status file under /BH directory
        for uuid in lfs.dir(backhaulDirectory) do
            if uuid ~= '.' and uuid ~= '..' then
                local statusFilePath = util.concatPaths({
                    backhaulDirectory,
                    uuid,
                    'status'
                })
                local statusShutdownFilePath = statusFilePath..'.shutdown'

                local statusTS = lfs.attributes(statusFilePath, 'modification') or 0
                local shutdownTS = lfs.attributes(statusShutdownFilePath, 'modification') or 0

                if util.isPathAFile(statusFilePath) and statusTS > shutdownTS then
                    local statusFile = io.open(statusFilePath)
                    if (statusFile) then
                        local content = statusFile:read('*a')
                        statusFile:close()
                        local parsedContent, err = json.parse(content)
                        if err == nil and parsedContent and parsedContent.type and parsedContent.type == 'status' and
                                parsedContent.data and parsedContent.data.state and parsedContent.data.state == 'up' then
                            table.insert(uuids, uuid)
                        end
                    end
                end
            end
        end
    end

    return uuids
end

function _M.isSlaveOnline(sc, uuid)
    sc:readlock()
    local uuid = uuid:upper()
    for _, v in pairs(_M.getOnlineSlaveUUIDs(sc)) do
        if v == uuid then
            return true
        end
    end
    return false
end

function _M.getSubscriberFilePrefix(sc)
    sc:readlock()
    return sc:get_subscriber_file_prefix()
end

return _M   -- return the module.
