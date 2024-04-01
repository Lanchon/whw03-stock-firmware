--- The wlan module. This module gives access to data in /tmp/msg/WLAN directory.
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local utilM             = require ( "nodes.topology.util" )
local lfsM              = require ( "lfs" )
local FILE_NAME_STATUS  = "status"
local FILE_NAME_NEIGH   = "neighbors"
local DIR_NAME          = "WLAN"
local DIR_ABSOLUTE_PATH = utilM.join_path( utilM.MSG_DIR, DIR_NAME )

local M = {}

--- Get wlan status by uuid of node.
-- @param The uuid of device.
-- @return Return wlan status data table.
function M.get_wlan_node_status_by_uuid( uuid )
    local wlan_status_data_table    = {}
    local wlan_status_absolute_path = utilM.join_path( DIR_ABSOLUTE_PATH, uuid, FILE_NAME_STATUS )
    
    -- If node wlan status file exist, load data into table.
    if utilM.is_file( wlan_status_absolute_path ) then
        wlan_status_data_table = utilM.load( wlan_status_absolute_path ) 
    end
    
    return wlan_status_data_table
end

--- Get wlan neighbors by uuid of node.
-- @param The uuid of device.
-- @return Return wlan neighbors data table.
function M.get_wlan_node_neighbors_by_uuid( uuid )
    local wlan_neighbors_data_table    = {}
    local wlan_neighbors_absolute_path = utilM.join_path( DIR_ABSOLUTE_PATH, uuid, FILE_NAME_NEIGH )
    
    -- If node neighbor file exist, load data into table.
    if utilM.is_file( wlan_neighbors_absolute_path ) then
        wlan_neighbors_data_table = utilM.load( wlan_neighbors_absolute_path ) 
    end
    
    return wlan_neighbors_data_table
end

--- Get wlan clients by uuid of node.
-- @param The uuid of device.
-- @return Return wlan clients data table belonging to node. 
function M.get_wlan_client_status_by_uuid( uuid )
    local wlan_clients_table    = {}
    local wlan_device_dir_absolute_path = utilM.join_path( DIR_ABSOLUTE_PATH, uuid )
    
    -- If client status file exists for a certain node, add data into table.
    if utilM.is_dir( wlan_device_dir_absolute_path ) then
        for client in lfsM.dir( wlan_device_dir_absolute_path ) do
            if client ~= '.' and client ~= '..' and client ~= nil and client ~= "status" and client ~= "neighbors" then
                local client_status_absolute_path = utilM.join_path( wlan_device_dir_absolute_path, client, FILE_NAME_STATUS )
                
                if utilM.is_file( client_status_absolute_path ) then
                    local client_data_table = utilM.load( client_status_absolute_path )
                    table.insert( wlan_clients_table, client_data_table )
                end
            end
        end
    end
    
    return wlan_clients_table
end

--- Get wlan clients by MAC.
-- @param The MAC of client.
-- @return Return client data table. 
function M.get_wlan_client_status_by_mac( mac )
    local function convert_mac_to_dash( mac )
        return string.gsub( mac, ":", "-" )
    end
    
    local mac = convert_mac_to_dash( mac )
    utilM.debug_print( mac )
    -- Recurse through WLAN directory to find the device containing the mac address and load data into table.
    if utilM.is_dir( DIR_ABSOLUTE_PATH ) then
        for node in lfsM.dir( DIR_ABSOLUTE_PATH ) do
            if node ~= '.' and node ~= '..' and node ~= nil then
                local node_dir = utilM.join_path( DIR_ABSOLUTE_PATH, node )
                
                if utilM.is_dir( node_dir ) then
                    for client in lfsM.dir( node_dir ) do
                        if client ~= '.' and client ~= '..' and client ~= nil and client ~= "status" and client ~= "neighbors" then
                            -- TODO: make a function to convert mac and uppercase it for better comparison
                            if string.upper( client ) == string.upper( mac ) then
                                local client_status_absolute_path = utilM.join_path( node_dir, client, FILE_NAME_STATUS )
                                
                                if utilM.is_file( client_status_absolute_path ) then
                                    local wlan_client_status_table = utilM.load( client_status_absolute_path )
                                    
                                    local client_status = wlan_client_status_table.data.status
                                    if client_status == "connected" then
                                        return wlan_client_status_table
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return {}
end

return M



