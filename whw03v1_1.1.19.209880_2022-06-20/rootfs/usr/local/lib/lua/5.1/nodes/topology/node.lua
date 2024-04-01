--- The node class ( TODO: need to create methods to access all different data so we don't have to access directly.. ).
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local classM    = require ( "nodes.topology.class" )

local Node      = {}
local Node_mt   = classM( Node )

--- Create new node object.
-- @param new_object The object to copy.
-- @return Return the newly created object.
function Node:new( new_object )
    local new_object   = new_object         or {}
    new_object.devinfo = new_object.devinfo or {}
    new_object.bh      = new_object.bh      or { status = {}, parent_ip = "", performance = {} }
    new_object.wlan    = new_object.wlan    or { status = {}, clients = {}, neighbors = {} }
    new_object.eth     = new_object.eth     or { clients = {} }
    return setmetatable( new_object, Node_mt )
end

--- Set devinfo.
-- @param devinfo The devinfo to set.
-- @return Return the devinfo table set.
function Node:set_devinfo( devinfo )
    self.devinfo = devinfo
    return self.devinfo
end

--- Set bh.
-- @param bh The bh data table to set.
-- @return Return the bh data table set.
function Node:set_bh( bh )
    self.bh = bh
    return self.bh
end

--- Set bh status.
-- @param status The bh status to set.
-- @return Return the bh status table set.
function Node:set_bh_status( status )
    self.bh.status = status
    return self.bh.status
end

--- Set bh parent ip.
-- @param parent_ip The bh parent ip to set.
-- @return Return the bh parent ip set.
function Node:set_bh_parent_ip( parent_ip )
    self.bh.parent_ip = parent_ip
    return self.bh.parent_ip
end

--- Set bh performance.
-- @param performance The bh performance data table to set.
-- @return Return the bh performance data table set.
function Node:set_bh_performance( performance )
    self.bh.performance = performance
    return self.bh.performance
end

--- Set the wlan.
-- @param wlan The wlan data table to set.
-- @return Return the wlan data table set.
function Node:set_wlan( wlan )
    self.wlan = wlan
    return self.wlan
end

--- Set the wlan status.
-- @param status The wlan status data table to set.
-- @return Return the wlan status data table set.
function Node:set_wlan_status( status )
    self.wlan.status = status
    return self.wlan.status
end

--- Set the wlan neighbors.
-- @param neighbors The wlan neighbors data table to set.
-- @return Return the wlan neighbors data table set.
function Node:set_wlan_neighbors( neighbors )
    self.wlan.neighbors = neighbors
    return self.wlan.neighbors
end

--- Set the wlan clients.
-- @param clients The wlan clients data table to set.
-- @return Return the wlan clients data table set.
function Node:set_wlan_clients( clients )
    self.wlan.clients = clients
    return self.wlan.clients
end

--- Set the eth.
-- @param eth The eth data table to set.
-- @return Return the eth data table set.
function Node:set_eth( eth )
    self.eth = eth
    return self.eth
end

--- Set the eth clients.
-- @param clients The eth clients data table to set.
-- @return Return the eth clients data table set.
function Node:set_eth_clients( clients )
    self.eth.clients = clients
    return self.eth.clients
end

--- Get the devinfo.
-- @return Return devinfo data table.
function Node:get_devinfo()
    return self.devinfo
end

--- Get the bh.
-- @return Return the bh data table.
function Node:get_bh()
    return self.bh
end

--- Get the bh status.
-- @return Return the bh status data table.
function Node:get_bh_status()
    return self.bh.status
end

--- Get the bh parent ip.
-- @return Return the bh parent ip.
function Node:get_bh_parent_ip()
    return self.bh.parent_ip
end

--- Get the bh performance.
-- @return Return the bh performance data table.
function Node:get_bh_performance()
    return self.bh.performance
end

--- Get the wlan.
-- @return Return the wlan data table.
function Node:get_wlan()
    return self.wlan
end

--- Get the wlan status.
-- @return Return the wlan status data table.
function Node:get_wlan_status()
    return self.wlan.status
end

--- Get the wlan neighbors.
-- @return Return the wlan neighbors data table.
function Node:get_wlan_neighbors()
    return self.wlan.neighbors
end

--- Get the wlan clients.
-- @return Return the wlan clients data table.
function Node:get_wlan_clients()
    return self.wlan.clients
end

--- Get the eth.
-- @return Return the eth data table.
function Node:get_eth()
    return self.eth
end

--- Get the eth clients.
-- @return Return the eth clients data table.
function Node:get_eth_clients()
    return self.eth.clients
end

--- Get the mac list.
-- @return Return the nodes mac list. The strings are uppercased.
function Node:get_mac_list()
    local extra_macs_upper = {}
    local devinfo          = self:get_devinfo()
    
    if devinfo then
        if next( self.devinfo.data.extra_macs ) ~= nil then
            for _,v_mac in ipairs( self.devinfo.data.extra_macs ) do
                table.insert( extra_macs_upper, string.upper(tostring(v_mac)) )
            end
        end
    end
    
    return extra_macs_upper
end

--- Determine if mac address exist.
-- @param mac_address The mac address to check.
-- @return Return true if mac address exist, otherwise false.
function Node:has_mac_address( mac_address )
    local mac_address = string.upper( tostring(mac_address) )
    local mac_list    = self:get_mac_list()
    
    for _,v_mac_address in ipairs( mac_list ) do
        if v_mac_address == mac_address then
            return true
        end
    end
    
    return false
end

--- Get uuid ( this is devinfo file uuid ).
-- @return Return uuid string on success, otherwise nil. Strings are uppercased.
function Node:get_uuid()
    local uuid = nil
    
    if next( self.devinfo ) ~= nil then
        uuid = string.upper( tostring(self.devinfo.uuid) )
    end
    
    return uuid
end

--- Get ap bssid.
-- @return Return ap bssid string on success, otherwise nil. Strings are uppercased.
function Node:get_ap_bssid()
    local ap_bssid = nil
    
    if next( self.bh.status ) ~= nil then
        ap_bssid = string.upper( tostring(self.bh.status.data.ap_bssid) )
    end
    
    return ap_bssid
end

return Node


