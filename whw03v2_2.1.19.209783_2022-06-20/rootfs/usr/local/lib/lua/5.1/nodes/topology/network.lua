--- The network class ( Need to create methods for nodes.lua to access data indirectly... currently accessing directly ).
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local classM     = require( "nodes.topology.class" )
local nodeM      = require( "nodes.topology.node" )
local devinfoM   = require( "nodes.topology.devinfo" )
local bhM        = require( "nodes.topology.bh" )
local wlanM      = require( "nodes.topology.wlan" )
local ethM       = require( "nodes.topology.eth" )

local Network    = {}
local Network_mt = classM( Network )

--- Create new network object.
-- @param new_object The object to copy.
-- @return Return the newly created network object.
function Network:new( new_object )
    local new_object = new_object or {}
    
    new_object.nodes   = new_object.nodes   or {}
    new_object.links   = new_object.links   or {}
    new_object.clients = new_object.clients or {}
    
    return setmetatable( new_object, Network_mt )
end

--- Set network nodes.
-- @param nodes The nodes to set.
-- @return Return the nodes set.
function Network:set_nodes( nodes )
    self.nodes = nodes
    return self.nodes
end

--- Set network links.
-- @param links The links to set.
-- @return Return the links set.
function Network:set_links( links )
    self.links = links
    return self.links
end

--- Set network clients.
-- @param clients The clients to set.
-- @return Return the clients set.
function Network:set_clients( clients )
    self.clients = clients
    return self.clients
end

--- Get network nodes.
-- @return Return the network nodes.
function Network:get_nodes()
    return self.nodes
end

--- Get network links.
-- @return Return the network links.
function Network:get_links()
    return self.links
end

--- Get network clients.
-- @return Return network clients.
function Network:get_clients()
    return self.clients
end

--- Get a list of devinfo uuid.
-- @return Return devinfo uuid list table.
function Network:get_node_uuid_list()
    local requested_uuid_list = {}
    local nodes               = self:get_nodes()
    
    for _,v_node in pairs( nodes ) do
        local uuid = v_node.devinfo.uuid
        table.insert( requested_uuid_list, uuid )
    end
    
    return requested_uuid_list
end

--- Get node by mac address.
-- @param mac_address The device mac address.
-- @return Return node on success, otherwise nil.
function Network:get_node_by_mac_address( mac_address )
    local mac_address = string.upper( tostring(mac_address) )
    local nodes       = self:get_nodes()
    
    for i,v_node in ipairs( nodes ) do
        if v_node:has_mac_address( mac_address ) then
            return v_node
        end
    end
    
    return nil
end

--- Get node by uuid ( this is devinfo file uuid ).
-- @param uuid The device uuid.
-- @return Return node on success, otherwise nil.
function Network:get_node_by_uuid( uuid )
    local uuid  = string.upper( tostring(uuid) )
    local nodes = self:get_nodes()
    
    for i,v_node in ipairs( nodes ) do
        if v_node:get_uuid() == uuid then
            return v_node
        end
    end
    
    return nil
end

--- Create network nodes table.
-- @return Return the network created nodes.
function Network:create_nodes()
    local nodes     = {}
    local uuid_list = devinfoM:get_devinfo_uuid_list()

    for _,v_uuid in ipairs( uuid_list ) do
        local new_node          = nodeM:new()
        
        new_node:set_devinfo( devinfoM.get_devinfo_by_uuid(v_uuid) )
        new_node:set_bh_status( bhM.get_bh_status_by_uuid(v_uuid) )
        new_node:set_bh_parent_ip( bhM.get_bh_parent_ip_by_uuid(v_uuid) )
        new_node:set_bh_performance( bhM.get_bh_performance_by_uuid(v_uuid) )
        new_node:set_wlan_status( wlanM.get_wlan_node_status_by_uuid(v_uuid) )
        new_node:set_wlan_clients( wlanM.get_wlan_client_status_by_uuid(v_uuid) )
        new_node:set_wlan_neighbors( wlanM.get_wlan_node_neighbors_by_uuid(v_uuid) )
        new_node:set_eth_clients( ethM.get_eth_clients_by_uuid(v_uuid) )
        table.insert( nodes, new_node )
    end
    
    self.nodes = nodes
    return self.nodes
end

--- Create network node links table.
-- @return Return the network created links.
function Network:create_node_links()
    local links = {}
    local nodes = self:get_nodes()
    
    for _,v_node in ipairs( nodes ) do
        local v_node_ap_bssid = v_node:get_ap_bssid()
        local node_ap         = self:get_node_by_mac_address( v_node_ap_bssid )
        
        if v_node and node_ap then
            local link = {}
            link.from  = v_node
            link.to    = node_ap
            table.insert( links, link )
        end
    end
    
    self.links = links
    return self.links
end

--- Create network snapshot.
-- @return Return the network snapshot.
function Network:create_network_snapshot()
    self:create_nodes()
    self:create_node_links()
    
    local snapshot   = {}
    snapshot.nodes   = self:get_nodes()
    snapshot.links   = self:get_links()
    snapshot.clients = self:get_clients()
    
    return snapshot
end

--- Create netjson network graph table.
-- @return Return the network json network graph data table.
function Network:create_netjson_network_graph()
    local netjson_network_graph = {}
    local netjson_links         = {}
    local netjson_nodes         = {}
    local netjson_parents       = {}
    local netjson_clients       = { wired = {}, wireless = {} }
    local netjson_wlan_clients  = {}
    local netjson_eth_clients   = {}
    local ss                    = self:create_network_snapshot()
    local links                 = ss.links
    local nodes                 = ss.nodes
    
    -- links
    for _,v_link in pairs( links ) do
        local link = {}
        local rssi = v_link.from.bh.status.data.rssi
        local from = v_link.from.bh.status.uuid
        local to   = v_link.to.devinfo.uuid
        
        link.from = from
        link.to   = to
        link.rssi = rssi
        
        table.insert( netjson_links, link )
    end
    
    -- nodes
    for _,v_node in pairs( nodes ) do
        if next( v_node.devinfo ) ~= nil then
            local node       = {}
            local uuid       = v_node.devinfo.uuid
            local label      = v_node.devinfo.data.mode
            local properties = v_node.devinfo.data
            
            node.uuid       = uuid
            node.label      = label
            node.properties = properties
            
            table.insert( netjson_nodes, node )
        end
    end
    
    -- parents
    for _,v_node in pairs( nodes ) do
        if next( v_node.bh.status ) ~= nil then
            local parent     = {}
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
            
            netjson_parents[v_node.bh.status.uuid] = parent 
        end 
    end
    
    -- clients
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
                netjson_wlan_clients[uuid] = clients_no_timestamp
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
                netjson_eth_clients[uuid] = clients_no_timestamp
            end
        end 
    end
    
    -- Set all clients under one table
    netjson_clients.wired         = netjson_eth_clients
    netjson_clients.wireless      = netjson_wlan_clients
    
    netjson_network_graph.nodes   = netjson_nodes
    netjson_network_graph.links   = netjson_links
    netjson_network_graph.parents = netjson_parents
    netjson_network_graph.clients = netjson_clients
    return netjson_network_graph
end

return Network
