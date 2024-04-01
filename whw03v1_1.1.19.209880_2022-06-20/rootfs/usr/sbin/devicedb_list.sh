#!/usr/bin/lua
--  -*- lua -*-
--  ---------------------------------------------------------------------------
--  Prints out basic database device data.
--  ---------------------------------------------------------------------------

db = require('libdevdblua').db()

DEVDB_CLIENT = "/usr/sbin/devicedb_client"
-- DEVDB_CLIENT = "./client"

-- line format
--          No   UUID UP   ROLE VER     
DEVLINE  = "%3s) %36s %-4s %-7s %-12s"  
--                   TYPE REMOTE MAC 
INTFLINE = "         %-8s %-6s %17s"

-- ---------------------------------------------------------------------------
-- Debug print table
-- ---------------------------------------------------------------------------
function debug_print_table(tab)
    local k,v
    for k,v in pairs(tab) do print(k,v) end
end

-- ---------------------------------------------------------------------------
-- Prints device data summary
-- INPUT
--     dev - the device data
-- ---------------------------------------------------------------------------
function print_device_summary(idx, dev)
    -- check if this device is online
    local intf
    local online = "Down"
    for _,intf in pairs(dev.interface) do
        if intf.connectionOnline == "1" then
            online = "Up"
        end
    end

    -- get device data
    local role = dev.infrastructure and dev.infrastructure.infrastructureType or "client"
    local ver = dev.firmwareVersion or ""

    -- display first line
    print(DEVLINE:format(idx, dev.deviceId, online, role, ver))

    -- Read MAC and IP

    for _,intf in pairs(dev.interface) do
        local intfType = intf.interfaceType or "arp"
        local remote
        if intf.remote == "1" then
            remote = "remote"
        else
            remote = "local"
        end

        local ip
        local ipstr
        if intf.ipaddr ~= nil then
            ipstr = ""
            for _,ip in pairs(intf.ipaddr) do
                if ipstr == "" then
                    ipstr = ip.ip
                else
                    ipstr = ipstr .. "/" .. ip.ip
                end
            end
        else
            ipstr = ""
        end

        print(INTFLINE:format(intfType, remote, intf.macAddr) .. " " .. ipstr)
    end
end

-- ---------------------------------------------------------------------------
-- Read the devlist, prints out the list, and return the device IDs
-- ---------------------------------------------------------------------------
function print_device_list()
    local devlist

    -- Read list 
    if db:readLock() then
        devlist = db:getAllDevices()
        db:readUnlock()
    else
        print("ERROR: cannot acquire read lock.")
        return nil
    end

    -- Print and build return array ID list
    local idlist = {}
    local i = 1
    local dev

    for _,dev in pairs(devlist) do
        idlist[i] = dev.deviceId;
        print_device_summary(i, dev)
        i = i + 1
    end

    return idlist
end

-- ---------------------------------------------------------------------------
-- START
-- ---------------------------------------------------------------------------

-- Get list
local list = print_device_list()

if list == nil then
    print("No devices found")
    return 0
end

-- Get user input
io.write("Enter Device No (0 to exit): ")
local readline = io.read()
io.write("\n")

if readline == "0" then
    print("Exiting...")
    return 0
end

local devno = tonumber(readline)

if devno == nil then
    print("Error: please enter a number between 1 and " .. #list .. ".")
    return 1
end

if devno < 1 or devno > #list then
    print("Error: please enter a number between 1 and " .. #list .. ".")
    return 1
end

-- Print device (shell)

local devid = list[devno]
local handle = io.popen(DEVDB_CLIENT .. " -c getDeviceById " .. devid)
local result = handle:read("*a")
handle:close()

print(result)
