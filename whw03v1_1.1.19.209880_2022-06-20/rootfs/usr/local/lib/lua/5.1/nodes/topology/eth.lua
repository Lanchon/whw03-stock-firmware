--- The eth module.This module gives access to data in /tmp/msg/ETH directory.
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local utilM             = require ( "nodes.topology.util" )
local lfsM              = require ( "lfs" )
local FILE_NAME_STATUS  = "status"
local DIR_NAME          = "ETH"
local DIR_ABSOLUTE_PATH = utilM.join_path( utilM.MSG_DIR, DIR_NAME )

local M = {}

--- Get eth clients by uuid.
-- @param The uuid of device.
-- @return Return eth clients data table belonging to device. 
function M.get_eth_clients_by_uuid( uuid )
    local eth_clients_table    = {}
    local eth_device_dir_absolute_path = utilM.join_path( DIR_ABSOLUTE_PATH, uuid )
    
    -- Check for all ETH client devices and add data to table.
    if utilM.is_dir( eth_device_dir_absolute_path ) then
        for client in lfsM.dir( eth_device_dir_absolute_path ) do
            if client ~= '.' and client ~= '..' and client ~= nil then
                local client_status_absolute_path = utilM.join_path( eth_device_dir_absolute_path, client, FILE_NAME_STATUS )
                
                if utilM.is_file( client_status_absolute_path ) then
                    local client_data_table = utilM.load( client_status_absolute_path )
                    table.insert( eth_clients_table, client_data_table )
                end
            end
        end
    end
    
    return eth_clients_table
end

return M



