--- The viewer module. This module is for viewing the network data in specific formats.
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local jsonM        = require ( "libhdkjsonlua" )
local lfsM         = require ( "lfs" )
local utilM        = require ( "nodes.topology.util" )
local networkM     = require( "nodes.topology.network" )

local M = {}

-- Create a new network object for viewer use.
local network          = networkM:new()
local network_snapshot = network:create_network_snapshot()

--- Generate the network json network graph view.
-- @return Returns netjson network graph view.
function M.generate_netjson_network_graph()
    local network_graph = network:create_netjson_network_graph()
    return network_graph
end

--- Generate the network network view.
-- @return Returns network view.
function M.generate_network()
    local network_graph    = {}
    network_graph.nodes    = M.generate_network_nodes()
    network_graph.clients  = M.generate_network_clients()
    network_graph.links    = M.generate_network_links()
    network_graph.parents  = M.generate_network_parents()
    
    return network_graph
end

--- Generate the network nodes view.
-- @return Returns the network nodes view.
function M.generate_network_nodes()
    local nodes = network_snapshot.nodes
    
    local nodes_no_timestamp = {}
    for _,v_node in pairs( nodes ) do
        if next( v_node.devinfo ) ~= nil then
            local uuid       = v_node.devinfo.uuid
            local data       = v_node.devinfo.data
            
            nodes_no_timestamp[uuid] = data
        end
    end
    
    return nodes_no_timestamp
end

--- Generate the network clients view.
-- @return Returns the network clients view.
function M.generate_network_clients()
    local nodes         = network_snapshot.nodes
    
    local clients       = {}
    local wlan_clients  = {}
    local eth_clients   = {}
    
    for _,v_node in pairs( nodes ) do
        -- wireless
        if next( v_node.wlan.clients ) ~= nil and next( v_node.wlan.status ) ~= nil then
            local clients_no_timestamp = {}
            local clients              = v_node.wlan.clients
            local uuid                 = v_node.wlan.status.uuid
            
            for _,v_client in pairs( clients ) do
                if v_client.data.status == "connected" then
                    table.insert( clients_no_timestamp, v_client.data )
                end
            end
            
            if next( clients_no_timestamp ) ~= nil then
                wlan_clients[uuid] = clients_no_timestamp
            end
        end
        
        -- wired
        if next( v_node.eth.clients ) ~= nil and next( v_node.devinfo ) ~= nil then
            local clients_no_timestamp = {}
            local clients             = v_node.eth.clients
            local uuid                = v_node.devinfo.uuid -- there is no eth status file for infrastructure nodes like wlan, subsitute with devinfo
            
            for _,v_client in pairs( clients ) do
                if v_client.data.status == "connected" then
                    table.insert( clients_no_timestamp, v_client.data )
                end
            end
            
            if next( clients_no_timestamp ) ~= nil then
                eth_clients[uuid] = clients_no_timestamp
            end
        end
        
        -- Set all clients under one table
        clients.wired         = eth_clients
        clients.wireless      = wlan_clients
    end
    
    return clients
end

--- Generate the network parents view.
-- @return Returns the network parents view.
function M.generate_network_parents()
    local nodes = network_snapshot.nodes
    
    local parents = {}
    for _,v_node in pairs( nodes ) do
        if next( v_node.bh.status ) ~= nil then
            local parent      = {}
            parent.intf       = v_node.bh.status.data.intf
            parent.type       = v_node.bh.status.data.type
            parent.channel    = v_node.bh.status.data.channel
            parent.rssi       = v_node.bh.status.data.rssi
            parent.noise      = v_node.bh.status.data.noise
            parent.phyRate    = v_node.bh.status.data.phyRate
            parent.phyRate_2  = v_node.bh.status.data.phyRate_2
            parent.ap_bssid   = v_node.bh.status.data.ap_bssid
            parent.sta_bssid  = v_node.bh.status.data.sta_bssid
            parent.ap_bssid   = v_node.bh.status.data.ap_bssid
            parent.mac        = v_node.bh.status.data.mac
            parent.ip         = v_node.bh.status.data.ip
            parent.state      = v_node.bh.status.data.state
            
            parents[v_node.bh.status.uuid] = parent 
        end 
    end
    
    return parents
end

--- Generate the network links view.
-- @return Returns the network links view.
function M.generate_network_links()
    local links = network_snapshot.links
    
    local links_no_data = {}
    for _,v_link in pairs( links ) do
        local link = {}
        local rssi = v_link.from.bh.status.data.rssi
        local from = v_link.from.bh.status.uuid
        local to   = v_link.to.devinfo.uuid
        
        link.from = from
        link.to   = to
        link.rssi = rssi
        
        table.insert( links_no_data, link )
    end
    
    return links_no_data
end

--- Generate the node view by mac address.
-- @param mac_address The node mac address.
-- @return Return node on success, otherwise nil.
function M.generate_node_by_mac_address( mac_address )
    local nodes = network_snapshot.nodes

    for i,v_node in ipairs( nodes ) do
        if v_node:has_mac_address( mac_address ) then
            return v_node
        end
    end
    
    return nil
end
    
return M
