--- The devinfo module.This module gives access to data in /tmp/msg/DEVINFO directory.
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local utilM             = require ( "nodes.topology.util" )
local lfsM              = require ( "lfs" )
local DIR_NAME          = "DEVINFO"
local DIR_ABSOLUTE_PATH = utilM.join_path( utilM.MSG_DIR, DIR_NAME )

local M = {}

--- Get master devinfo uuid.
-- @return Return the master's uuid string, else nil.
function M.get_master_uuid()
    local devinfo_absolute_path = utilM.join_path( DIR_ABSOLUTE_PATH, "master" )
    
    if utilM.is_file( devinfo_absolute_path ) then
        devinfo_data_table = utilM.load( devinfo_absolute_path )
        return devinfo_data_table.uuid
    end 
end

--- Get devinfo by uuid.
-- @param uuid The uuid of device.
-- @return Return the devinfo data table.
function M.get_devinfo_by_uuid( uuid )
    -- Check if master uuid
    if M.get_master_uuid() == uuid then
        uuid = "master"
    end
    
    local devinfo_data_table    = {}
    local devinfo_absolute_path = utilM.join_path( DIR_ABSOLUTE_PATH, uuid )
    
    -- If devinfo file exist, load the data into a table.
    if utilM.is_file( devinfo_absolute_path ) then
        devinfo_data_table = utilM.load( devinfo_absolute_path ) 
    end
    
    return devinfo_data_table
end

--- Get a list of devinfo uuid.
-- @return Return devinfo uuid list table.
function M.get_devinfo_uuid_list()
    local requested_uuid_list = {}
    
    local master_uuid = M.get_master_uuid()
    
    -- Check the devinfo directory and add all devinfo file names to table.
    if utilM.is_dir( DIR_ABSOLUTE_PATH ) then
        for device in lfsM.dir( DIR_ABSOLUTE_PATH ) do
            if device ~= '.' and device ~= '..' and device ~= nil then
                if device == master_uuid then device = master_uuid end
                table.insert( requested_uuid_list, device )
            end
        end
    end
    
    return requested_uuid_list
end

--- Get a list of devinfo files.
-- @return Return devinfo uuid list table.
function M.get_devinfo_file_list()
    local requested_uuid_list = {}
        
    -- Check the devinfo directory and add all devinfo file names to table.
    if utilM.is_dir( DIR_ABSOLUTE_PATH ) then
        for device in lfsM.dir( DIR_ABSOLUTE_PATH ) do
            if device ~= '.' and device ~= '..' and device ~= nil then
                table.insert( requested_uuid_list, device )
            end
        end
    end
    
    return requested_uuid_list
end

--- Get the devinfo by mac
-- @param mac The mac associated with the device.
-- @return the devinfo
function M.get_devinfo_by_mac( mac )
    local devinfo_data_table    = {}
    
    -- Check iterate through all devinfo files and check which one contains the mac.
    if utilM.is_dir( DIR_ABSOLUTE_PATH ) then
        for device in lfsM.dir( DIR_ABSOLUTE_PATH ) do
            if device ~= '.' and device ~= '..' and device ~= nil then
                local devinfo_absolute_path = utilM.join_path( DIR_ABSOLUTE_PATH, device )
                devinfo_data_table = utilM.load( devinfo_absolute_path )
                local mac_2G_bssid = devinfo_data_table.data.userAp2G_bssid
                local mac_5GL_bssid = devinfo_data_table.data.userAp5GL_bssid
                local mac_5GH_bssid = devinfo_data_table.data.userAp5GH_bssid
                if string.upper( tostring(mac_2G_bssid) ) == string.upper( tostring(mac) ) or string.upper( tostring(mac_5GL_bssid) ) == string.upper( tostring(mac) ) or string.upper( tostring(mac_5GH_bssid) ) == string.upper( tostring(mac) ) then
                    return devinfo_data_table
                end    
            end
        end
    end
    return {}
end

--- Get the intf name by mac
-- @param mac The mac associated with the device intf.
-- @return the intf name
function M.get_intf_name_by_mac( mac )    
    -- Check iterate through all devinfo files and check which one contains the mac.
    if utilM.is_dir( DIR_ABSOLUTE_PATH ) then
        for device in lfsM.dir( DIR_ABSOLUTE_PATH ) do
            if device ~= '.' and device ~= '..' and device ~= nil then
                local devinfo_absolute_path = utilM.join_path( DIR_ABSOLUTE_PATH, device )
                local devinfo_data_table = utilM.load( devinfo_absolute_path )
                local mac_2G_bssid = devinfo_data_table.data.userAp2G_bssid
                local mac_5GL_bssid = devinfo_data_table.data.userAp5GL_bssid
                local mac_5GH_bssid = devinfo_data_table.data.userAp5GH_bssid
                
                if string.upper( tostring(mac_2G_bssid) ) == string.upper( tostring(mac) ) then
                    return {intf_name = "ath0"}
                elseif string.upper( tostring(mac_5GL_bssid) ) == string.upper( tostring(mac) ) then
                    return {intf_name = "ath1"}
                elseif string.upper( tostring(mac_5GH_bssid) ) == string.upper( tostring(mac) ) then
                    return {intf_name = "ath10"}
                end
                
            end
        end
    end
    return {}
end

return M


