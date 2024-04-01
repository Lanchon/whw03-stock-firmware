--- The bh module. This module gives access to data in /tmp/msg/BH directory.
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local utilM             = require ( "nodes.topology.util" )
local lfsM              = require ( "lfs" )
local FILE_NAME_STATUS  = "status"
local FILE_NAME_PIP     = "status.parent_ip"
local FILE_NAME_PERF    = "status.performance"
local DIR_NAME          = "BH"
local DIR_ABSOLUTE_PATH = utilM.join_path( utilM.MSG_DIR, DIR_NAME )

local M = {}

--- Get bh status by uuid.
-- @param uuid The uuid of device.
-- @return Return bh status data table.
function M.get_bh_status_by_uuid( uuid )
    local bh_status_data_table     = {}
    local bh_status_absolute_path  = utilM.join_path( DIR_ABSOLUTE_PATH, uuid, FILE_NAME_STATUS )
    
    -- If backhaul file exist, load the data into a table.
    if utilM.is_file( bh_status_absolute_path ) then
        bh_status_data_table = utilM.load( bh_status_absolute_path ) 
    end
    
    return bh_status_data_table
end

--- Get parent ip by uuid.
-- @return Return parent ip string on success, otherwise nil.
function M.get_bh_parent_ip_by_uuid( uuid )
    local requested_parent_ip        = nil
    local parent_ip_absolute_path    = utilM.join_path( DIR_ABSOLUTE_PATH, uuid, FILE_NAME_PIP )
    
    -- If parent ip file exist, load the data into a table.
    if utilM.is_file( parent_ip_absolute_path ) then
        requested_parent_ip = utilM.read( parent_ip_absolute_path ) 
    end
    
   return requested_parent_ip
end

--- Get performance by uuid.
-- @return Return performance data table on success, otherwise nil.
function M.get_bh_performance_by_uuid( uuid )
    local requested_bh_performance  = nil
    local performance_absolute_path = utilM.join_path( DIR_ABSOLUTE_PATH, uuid, FILE_NAME_PERF )
    
    -- If backhaul performance file exist, load data into a table.
    if utilM.is_file( performance_absolute_path ) then
        requested_bh_performance = utilM.load( performance_absolute_path ) 
    end
    
   return requested_bh_performance
end

return M


