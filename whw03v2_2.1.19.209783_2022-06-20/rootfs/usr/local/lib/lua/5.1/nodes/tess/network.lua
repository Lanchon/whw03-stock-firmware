--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--
--! @file
--! @brief Network class for tesseract subsystem

module( ..., package.seeall )

local Klass = require 'nodes.util.klass'     --!< @private
local DEV   = require "nodes.tess.device"
local NODE  = require "nodes.tess.node"
local INTF  = require "nodes.tess.interface"
local LINK  = require "nodes.tess.link"
local EP    = require "nodes.tess.endpoint"
local Mac   = require('nodes.util.mac').Mac
local nutil = require 'nodes.util'
local Misc  = require 'nodes.tess.misc'      --!< @private
local NETOPS = require 'nodes.tess.net-ops'

local count_table_keys = Misc.count_table_keys
local json_file_to_table = nutil.json_file_to_table
local errout = nutil.errout
local debout = nutil.debout
local join_dirs = nutil.join_dirs

--! @class Network
--! Class representing a state in time of a Network.
local Network = Klass{
   score = NETOPS.score,
   __eq = NETOPS.eq,
   __tostring = function( n )
      return ("[nodes:%d,links:%d,clients:%d]"):format(
         count_table_keys( n.nodes ), #n.links, #n.clients )
   end
}

--! @fn Network##new(o)
--! @memberof Network
--! Network constructor
function Network:new()
   local o = {
      clients = {},
      links   = {},
      nodes   = {},
   }
   return setmetatable( o, self )
end

-- Directories within BASE_MSG_DIR:
Network.WLAN_DIR = "WLAN"
Network.BACKHAUL_DIR = "BH"

-- Other entities in the msg directory
Network.NEIGHBORS   = "neighbors"
Network.STATUS      = "status"
Network.STATUS_UP   = "connected"
Network.STATUS_DOWN = "disconnected"

function Network:add_client( client )
   if not client then error( "Nil client", 2 ) end
   --debout( "Add client '%s' to network", client.uuid )
   if not self.clients then error( "Missing clients list", 2 ) end
   table.insert( self.clients, client )
end

function Network:find_link( link_of_interest )
   local index = nil
   for i,candidate_link in ipairs( self.links ) do
      if candidate_link == link_of_interest then
         index = i
         break
      end
   end
   return index
end

function Network:add_node( node )
   if not node then error( "nil node", 2 ) end
   if not node.uuid then error( "Node with missing UUID" ) end
   self.nodes[node.uuid] = node
   return node
end

function Network:num_nodes()
   return count_table_keys( self.nodes )
end

function Network:add_link( link )
   -- Weave references to the respective Nodes
   function weave_ep( endpoint )
      if endpoint and endpoint.interface then
         --[[
         debout( "Weaving endpoint '%s':'%s'",
                 tostring(endpoint.device),
                 tostring( endpoint.interface.mac))
         --]]
         local node = self:find_node_by_mac( endpoint.interface )
         if node then
            node:add_link( link )
         else
            debout( "Node not found for endpoint '%s'", endpoint.interface )
         end
      end
   end
   if self:find_link( link ) then
      link = LINK.merge( self:remove_link( link ), link )
   end
   table.insert( self.links, link )
   --weave_ep( link.from )
   -- weave_ep( link.to )
end

function Network:remove_link( link )
   if link then
      local index = self:find_link( link )
      if index then
         table.remove( self.links, index )
      end
      function unweave( what )
         if link[what] and link[what].device then
            local node = self:find_node_by{ uuid = link[what].device }
            if node then node:remove_link( link ) end
         end
      end
      -- then remove from any to/from devices
      unweave( "from" )
      unweave( "to" )
   end
   return link
end

--! @fn Round number.
--! Rounds the given number.  If p provided, rounds to p fractional
--! digits.  Otherwise rounds to 3.
--! Examples:
--! * round( 888.88888 ): 888.889
--! * round( 888.88888, 0 ): 889
--! @param x Value to found
--! @param p Precision
--! @return x rounded to p fractional digits of precision
local function round(x,p)
   fmt = "%."..tostring( p or 3 ).."f"
   return tonumber( fmt:format( x ))
end


function Network:make_connections( backhauls )
   local BH_FIELDS_OF_INTEREST = {
      "ap_bssid", "channel", "intf",
      "ip",       "mac",     "noise",
      "phyRate",  "rssi",    "sta_bssid",
      "type",      "userAp2G_bssid",
   }
   for _,bh in ipairs( backhauls ) do
      local link
      if bh.data.type == INTF.TYPE.WIRELESS then
         local parent_mac = bh.data.ap_bssid
         local parent_node = self:find_node_by_mac( parent_mac )
         local parent_intf = parent_node:find_intf_by_mac( parent_mac )
         parent_intf.bssid = parent_mac
         parent_intf.rssi = bh.data.rssi
         parent_intf.channel = bh.data.channel
         parent_intf.band = bh.data.intf
         local to_ep = EP:new{ device = parent_node, interface = parent_intf }

         local child_mac = bh.data.sta_bssid
         local child_node = self:find_node_by_mac( child_mac )
         if child_node then
            local child_intf = child_node:find_intf_by_mac( child_mac )
            if not child_intf then
               child_intf = INTF:new{ mac = child_mac, name = bh.data.intf, type = bh.data.type }
               --child_intf._origin = "Network:make_connections#159"
               child_node:add_interface( child_intf )
            end
            child_intf.bssid = child_mac
            child_intf.rssi = bh.data.rssi
            child_intf.channel = bh.data.channel
            child_intf.name = bh.data.intf
            local from_ep = EP:new{ device = child_node, interface = child_intf }

            -- Determine state based on client data.  Backhaul data can
            -- be stale if the client disconnected recently.
            debout( "Looking for client w/mac '%s' in node %s", tostring(child_mac), tostring( parent_node ))
            local client = parent_node:find_client_by_mac( child_mac )
            debout( "client: %s", tostring( client ))
            local client_state = false
            if client then
               client_state = client.status == Network.STATUS_UP
               debout( "Client found; setting state to %s", tostring(client_state ))
            else
               client_state = bh.data.state == "up"
               debout( "No client found; setting state to %s", tostring(client_state ))
            end

            -- Determine if link should be up.  Since other links
            -- coming up can indicate that this one is down, we need
            -- to consider them too.
            local best_status = self:find_best_subdev_status( child_intf.mac )

            link = LINK:new{ from = from_ep,
                             to = to_ep,
                             type = bh.data.type,
                             active = best_status,
                             _origin = "Network:make_connections#200" }

            Misc.cp_fields( BH_FIELDS_OF_INTEREST, bh.data, link, true )
            link._client = client
            debout( "Resulting link: %s", tostring( link ))
            child_node:add_link( link )
            debout( "Added link %s to node %s", tostring(link), child_node.uuid )
            debout( "child_node link count now %d", #child_node.links )
         end
      elseif bh.data.type == INTF.TYPE.WIRED then
         -- It is a problem determining the parent (topologically
         -- speaking) of a wired Node.
         local master = self:get_master()
         local parent_mac = master.base_mac
         local parent_node = master
         local parent_intf = parent_node:find_intf_by_mac( parent_mac )
         local to_ep = EP:new{ device = parent_node, interface = parent_intf }

         local child_mac = bh.data.mac
         local child_node = self:find_node_by{ uuid = bh.uuid }
         if child_node then
            local child_intf = child_node:find_intf_by_mac( child_mac )
            if not child_intf then
               child_intf = INTF:new{ mac = child_mac, name = bh.data.intf, type = bh.data.type }
               --child_intf._origin = "Network:make_connections#184"
               child_node:add_interface( child_intf )
            end
            local ep = EP:new{ device = child_node, interface = child_intf }
            link = LINK:new{ from = ep,
                             to   = to_ep,
                             type = bh.data.type,
                             active = bh.data.state == "up",
                             _origin = "Network:make_connections#223" }
            Misc.cp_fields( BH_FIELDS_OF_INTEREST, bh.data, link, true )
            --link._origin = "Network:make_connections#134"
            child_node:add_link( link )
         end
      else
         errout( "Unknown link type '%s'", bh.data.type )
         break
      end
      if link then
         if bh.performance and bh.performance.data then
            link.speed = round( bh.performance.data.rate )
         end
         debout( "Adding link (%s <-> %s, active: %s) to net",
                 tostring( link.from and link.from.interface or "?" ),
                 tostring( link.to and link.to.interface or "?" ),
                 tostring( link.active ))
         self:add_link( link )
      end
   end
end


function Network:report_statistics()
   errout( "Network Statistics:" )
   errout(   "\t%d nodes",   self:num_nodes())
   errout(   "\t%d Links",   #self.links )
   errout(   "\t%d Clients", #self.clients )

   errout( "\tNode data:" )
   for uuid,node in pairs( self.nodes ) do
      errout( "\t  %s has %d links", tostring( node ), #node.links )
   end
end


local function correct_neighbor_data( neighbor )
   for _,item in ipairs( neighbor.data.neighbor ) do
      local rssi = item.rssi
      if type( rssi ) ~= 'number' then rssi = tonumber( rssi ) end
      if rssi > 0 then
         rssi = -rssi
      end
      item.rssi = rssi

      if type( item.channel ) ~= 'number' then
         item.channel = tonumber( item.channel )
      end
   end
   return neighbor
end

-- This is neighbor data from Nodes
local function load_neighbor_data()
   local NB_DIR = join_dirs( DEV.DEFAULT_BASE_MSG_DIR, Network.WLAN_DIR )
   local nb_list = {}
   for entry in nutil.dirs_in( NB_DIR ) do
      if entry ~= 'master' then
         local fname = join_dirs( NB_DIR, entry, Network.NEIGHBORS )
         local json,err = json_file_to_table( fname )
         if json then
            correct_neighbor_data( json )
            nb_list[entry] = json
         else
            debout( "Error loading JSON from '%s': %s", fname, tostring( err ))
         end
      end
   end
   return nb_list
end

--! @brief Helper function that picks the later of 2 objects.
--! latest_of compares the timestamp (TS field) of 2
--! objects.  The timestamp must be in ISO 8601 Combo format, which is
--! the standard format for Olympus Messaging JSON data.
--! @param a A table with a TS field
--! @param b A table with a TS field
--! @return a whichever of a or b that has the later timestamp.
--! @throw error if a or b are nil or are missing a TS field
local function latest_of( a, b )
   if not a or not b then error( "Missing parameter", 2 ) end
   if a.TS == nil or b.TS == nil then error( "Missing TS from 1 or more parameters", 2 ) end
   local TS_a, TS_b = nutil.utc_datetime_to_ostime( a.TS ), nutil.utc_datetime_to_ostime( b.TS )
   local result = nil

   -- difftime( a, b ) returns a - b
   if os.difftime( TS_a, TS_b ) >= 0 then
      result = a
   else
      result = b
   end

   return result
end

function Network.load_client_neighbor_data()
   local NB_DIR = join_dirs( DEV.DEFAULT_BASE_MSG_DIR, Network.WLAN_DIR )
   local nb_list = {}
   for node_name in nutil.dirs_in( NB_DIR ) do
      local node_dir = join_dirs( NB_DIR, node_name )
      for client_mac in nutil.dirs_in( node_dir ) do
         local nb_path = join_dirs( node_dir, client_mac, Network.NEIGHBORS )
         local nb_data = json_file_to_table( nb_path )
         if nb_data then
            -- If a survey is already present, check the timestamps
            -- and use the latest one
            if nb_list[client_mac] then
               nb_list[client_mac] = latest_of( nb_list[client_mac], nb_data )
            else
               nb_list[client_mac] = nb_data
            end
         end
      end
   end
   return nb_list
end


function Network:find_matching_link( example )
   local found_link = nil
   for _, maybe in ipairs( self.links ) do
      if maybe == example then
         found_link = maybe
         break
      end
   end
   return found_link
end

local function find_links_by_node( net, what, node )
   if type(node) == 'table' and node.uuid then node = node.uuid end
   local links = {}
   for _,link in ipairs( net.links ) do
      if link[what] and link[what].node == node.uuid then
         table.insert( links, link )
      end
   end
   return links
end

--! @fn Network::get_links_from_node(node)
--! Find links "from" the specified Node
--! @param node a Node object or uuid
--! @return an array of Link objects
function Network:get_links_from_node( node )
   return find_links_by_node( self, "from", node )
end

--! @fn Network::get_links_to_node(node)
--! Find links "to" the specified Node
--! @param node a Node object or uuid
--! @return an array of Link objects
function Network:get_links_to_node( node )
   return find_links_by_node( self, "to", node )
end

function Network:connect_clients( clients )
   --self.clients = clients
end

-- This processes Node neighbor data (as opposed to client neighbor data)
function Network:connect_node_neighbors( neighbors )
   self.neighbors = neighbors -- Temporary
   for uuid, nb_list in pairs( neighbors ) do
      local from_node = self:find_node_by{ uuid = uuid }
      if from_node then
         for _, nb in ipairs( nb_list.data.neighbor ) do
            if nb.bssid then
               local to_node = self:find_node_by_mac( nb.bssid )
               if to_node then
                  local to_intf = to_node:find_intf_by_mac( nb.bssid )
                  local from_ep = EP:new{ device = from_node }
                  local to_ep   = EP:new{ device = to_node, interface = to_intf }
                  local link = LINK:new{
                     active  = false,
                     from    = from_ep,
                     to      = to_ep,
                     type    = INTF.TYPE.WIRELESS,
                     rssi    = nb.rssi,
                     channel = nb.channel,
                     ssid    = nb.ssid,
                     _origin = "Network:connect_node_neighbors#357"
                  }

                  -- Is such a link already present?  Since this is
                  -- only a candidate link we don't want to override a
                  -- possibly active link.
                  -- So if there is no matching link we add this link.

                  -- If there is a matching link that is not active,
                  -- we remove that link and then add this one

                  -- If there is a matching link and it is active then
                  -- we do nothing
                  local present_link = self:find_matching_link( link )
                  if present_link == nil then
                     self:add_link( link )
                  elseif present_link.active == false then
                     self:remove_link( present_link )
                     self:add_link( link )
                  end
                  -- from_node:add_link( link )
                  -- to_node:add_link( link )
               else
                  debout( "No Node has neighbor observed mac '"..tostring(nb.bssid).."'", 2 )
               end
            else
               debout( "No Node found for neighbor list UUID '%s'", uuid )
            end
         end
      end
   end
end


function Network:load_wlan_interfaces()
   local NB_DIR = join_dirs( DEV.DEFAULT_BASE_MSG_DIR, Network.WLAN_DIR )
   local WLAN_INTF_NAME = { "guestAp2G_bssid", "guestAp5G_bssid",
                            "userAp2G_bssid",  "userAp5GH_bssid",
                            "userAp5GL_bssid" }

   for node_dir in nutil.dirs_in( NB_DIR ) do
      local fname = join_dirs( NB_DIR, node_dir, Network.STATUS )
      local json,err = json_file_to_table( fname )
      if json then
         local node = self:find_node_by{ uuid = json.uuid }
         if node then
            for _, intf_name in ipairs( WLAN_INTF_NAME ) do
               -- Get any channel info as well
               local candidate_mac = json.data[intf_name]
               local chan = json.data[(candidate_mac:gsub( 'bssid', 'channel' ))]
               if chan == '' then chan = nil end
               if candidate_mac and candidate_mac ~= "" then
                  local intf = node:find_intf_by_mac( candidate_mac )
                  if intf then
                     intf.mac = intf.mac or candidate_mac
                     intf.name = intf.name or intf_name
                     intf.channel = intf.channel or chan
                  else
                     node:add_interface( INTF:new{ mac = candidate_mac, name = intf_name,
                                                   channel = chan, type = INTF.TYPE.WIRELESS })
                  end
               end
            end
         else
            errout( "Error finding Node matching UUID '%s'", json.uuid )
         end
      else
         debout( "Error loading JSON from '%s': %s", fname, tostring( err ))
      end
   end
end

--! @fn Network##find_bh_for_uuid
--! Find the backhaul object for the Node with the specified UUID
--! @param uuid
--! @return a table holding the JSON data for this Node's backhaul or nil
function Network:find_bh_for_uuid( uuid )
   if not uuid then
      error( "Missing argument (uuid)", 2 )
   end
   -- Find entry for this UUID
   local bh_entry
   if uuid then
      for _,bh in ipairs( self.backhauls ) do
         if type( bh.uuid ) == 'string' and bh.uuid:lower() == uuid:lower() then
            bh_entry = bh
            break
         end
      end
   end
   return bh_entry
end

--! @fn Network##snapshot
--! @static
--! Create a snapshot of the current state of the network.
--! @return a Network object
function Network.snapshot()
   local net = Network:new()
   net.nodes = NODE.load_all( opts )
   net:load_wlan_interfaces()
   net.backhauls = net:load_bh_connections()
   net:make_connections( net.backhauls )
   net:connect_node_neighbors( load_neighbor_data())
   net:connect_clients( net:load_subdevices() )
   if opts and opts.debug then
      net:report_statistics()
   end
   net:get_node_tree()
   return net
end


--! @fn Network##find_node_by
--! @param srch A table of attributes to match
--! @return The first match or nil
function Network:find_node_by(srch)
   local node = nil
   if srch then
      for id,candidate in pairs( self.nodes ) do
         node = candidate
         for k,v in pairs( srch ) do
            if candidate[k] ~= srch[k] then
               node = nil
               break
            end
         end
         if node then break end
      end
   end
   return node
end


--! @fn Network##find_node_by_mac
--! Find a Node with an interface using the supplied mac
--! @param mac The mac to look for
--! @return The first match or nil
function Network:find_node_by_mac( mac )
   if not mac then error( "Missing argument", 2 ) end
   local found_node = nil
   for id,candidate in pairs( self.nodes ) do
      if candidate:has_mac( mac ) then
         found_node = candidate
         break
      end
   end
   return found_node
end


function Network:find_client_by_mac( mac )
   local result = nil
   if not mac then error( "Missing argument", 2 ) end
   for _, client in ipairs( self.clients ) do
      if client:has_mac( mac ) then
         result = client
         break
      end
   end
   return result
end

--! Generate JSON representation of this Network object.
--! @return a String containing JSON
function Network:to_json()
   local JSON = require 'libhdkjsonlua'
   return JSON.stringify( self )
end

--! @fn Network##get_master
--! Return the Master Node for this network.
--! @return A Node object or nil.
function Network:get_master()
   if not self then error( "Self is nil" ) end
   return self.nodes.master
end

local function load_backhaul_data()
   local BH_DIR = join_dirs( DEV.DEFAULT_BASE_MSG_DIR, Network.BACKHAUL_DIR )
   local bh_list = {}
   for entry in nutil.dirs_in( BH_DIR ) do
      local fname = join_dirs( BH_DIR, entry, Network.STATUS )
      local json,err = json_file_to_table( fname )
      if json then
         table.insert( bh_list, json )
         -- See if there is a performance file & load it too if found
         local fname = BH_DIR.."/"..entry.."/status.performance"
         local performance,err = json_file_to_table( fname )
         if performance then
            -- Clean up the values a bit.  The JSON importer seems to
            -- leave some extraneous trailing digits in floating point
            -- values
            for _,k in ipairs{ 'jitter', 'rate', 'delay', } do
               performance.data[k] = round( performance.data[k] )
            end

            json.performance = performance
         end
      else
         debout( "Couldn't load JSON from '%s': %s", fname, tostring( err ))
      end
   end
   return bh_list
end

function Network:harvest_bh_intfs( bh )
   if bh and bh.data then
      if bh.data.type == "WIRELESS" then
         local uuid = bh.uuid
         local mac = bh.data.sta_bssid
         local node = self:find_node_by{ uuid = uuid }
         local chan = bh.data.channel
         if node then
            local intf = node:find_intf_by_mac( mac )
            if not intf then
               intf = INTF:new{ mac = mac, type = bh.data.type, channel = chan, type = bh.data.type }
               intf._origin = "Network:harvest_bh_intfs#570"
               table.insert( node.interfaces, intf )
            end
         else
            errout( "Node '%s' not found", uuid )
         end
      end
   end
end

function Network:load_bh_connections()
   local backhauls = load_backhaul_data()
   for _, bh in ipairs( backhauls ) do
      self:harvest_bh_intfs( bh )
   end
   if opts and opts.debug then
      self.backhauls = backhauls
   end
   return backhauls
end

--! @fn Network##get_backhaul(uuid)
--! @memberof Network
--! Look up backhaul information for specified UUID.
--! @param uuid String containing a UUID (case doesn't matter)
--! @return The data portion of a backhaul status message, or nil if not found
function Network:get_backhaul( uuid )
   local bh = nil
   if type( uuid ) ~= 'string' then
      error( "Invalid UUID: '"..tostring(uuid).."'("..type(uuid)..")" )
   end
   uuid = uuid:lower()
   for i,candidate in ipairs( self.backhauls ) do
      if candidate.uuid:lower() == uuid then
         bh = candidate.data
         break
      end
   end
   return bh
end

function Network:load_subdevices()
   local WLAN_DIR = join_dirs( DEV.DEFAULT_BASE_MSG_DIR, Network.WLAN_DIR )
   local subdevs = {}
   local client_count = 0
   local SUBDEV_FIELDS_OF_INTEREST = {
      "ap_bssid",  "btm_cap", "band",  "guest",   "interface",
      "mcs",       "phyrate", "rssi",  "rrm_cap", "sta_bssid",
      "status",
   }

   for node_entry in nutil.dirs_in( WLAN_DIR ) do
      --debout( "load_subdevices checking '%s'", node_entry )
      for subdev_entry in nutil.dirs_in( join_dirs( WLAN_DIR, node_entry )) do
         local fname = join_dirs( WLAN_DIR, node_entry, subdev_entry, Network.STATUS )
         local json,err = json_file_to_table( fname )
         if json then
            -- Is this client a Node?
            local child_mac = json.data.sta_bssid
            local node = self:find_node_by_mac( child_mac )
            local client
            if node then
                repeat
                   if child_mac then
                      if json.data then
                         --debout( "Looking for Node with MAC '%s'", json.data.sta_bssid )
                         if self:find_node_by_mac( child_mac ) then
                            -- Found matching Node; don't process this as a client
                            --debout( "Rejecting Node from client list" )
                            break
                         end
                      end
                      client = self:find_client_by_mac( child_mac )
                      if client == nil then
                         client = DEV:new{
                            uuid      = "client"..tostring(client_count),
                            mode      = "client"
                         }
                         client:add_interface( INTF:new{ mac = child_mac, type = INTF.TYPE.WIRELESS })
                         self:add_client( client ) -- Temporary!
                         client_count = client_count + 1
                      else
                         debout( "Re-using existing client" )
                      end
                   end
                   if client then
                      node:add_client( client )
                      Misc.cp_fields( SUBDEV_FIELDS_OF_INTEREST, json.data, client )
                      local link = LINK:new{ from = EP:new{ device = client },
                                             to   = EP:new{ device = node.uuid, ap_bssid = client.ap_bssid },
                                             type = INTF.TYPE.WIRELESS,
                                             active = client.status ~= Network.STATUS_DOWN,
                                             _origin = "Network:load_subdevices#586" }
                      debout( "client.status: '%s'", client.status )
                      self:add_link( link )
                      client:add_link( link )
                   end
                until true
            else
               if tostring(json.data.status) == Network.STATUS_UP then
                  debout "Creating non-Node client device"
                  client = DEV:new{
                     uuid      = "client"..tostring(client_count),
                     mode      = "client",
                     ap_bssid  = json.data.ap_bssid
                  }
                  Misc.cp_fields( SUBDEV_FIELDS_OF_INTEREST, json.data, client )
                  self:add_client( client )
                  client:add_interface( INTF:new{ mac = json.data.sta_bssid,
                                                  type = INTF.TYPE.WIRELESS })
               else
                  debout( "Skipping offline client '%s'", json.data.sta_bssid )
               end
            end
         else
            debout( "Error loading JSON from '%s': %s", fname, tostring( err ))
         end
      end
   end

   return subdevs
end

--! @brief Find most up-to-date WLAN link status.
--! Problem: Sub-device status files aren't removed when clients
--! establish new, different links.  Because of this just looking at
--! the data.status (connected/disconnected) field is not adequate to
--! tell if a link is really up.  Solution: Scan though sub-device
--! status files for matching MACs, checking their modification times.
--! The latest of these files determines the overall "up/down" state.
--! @param mac The mac to look for.  Can be either a Lua string or a
--! Mac object.
--! @return true/false indicating the device link is up or down.
function Network:find_best_subdev_status( mac )
   if mac == nil then error( "Missing or nil mac", 2 ) end
   if mac == "" then error( "EMpty mac", 2 ) end
   -- Make sure MAC uses '-' seperators
   if type(mac) == 'string' then mac = Mac:new(mac) end
   mac.SEP = '-'
   mac = tostring( mac )
   local dir = join_dirs( DEV.DEFAULT_BASE_MSG_DIR, Network.WLAN_DIR )
   local latest_path = nil
   local latest_mtime = 0
   -- debout( "looking for mac: '%s'", mac )
   for client_dir in nutil.dirs_in( dir ) do
      -- debout( "client_dir: '%s'", client_dir )
      local node_path = join_dirs( dir, client_dir )
      for d in nutil.dirs_in( node_path ) do
         if d == mac then
            local stat_path = join_dirs( node_path, d, "status" )
            local fstat,err = lfs.attributes( stat_path )
            if fstat then
               local mtime = fstat.modification
               -- debout( "Found one: mtime is %d, status is '%s'",
               --         mtime,
               --         tostring( json_file_to_table(stat_path).data.status ))
               if mtime > latest_mtime then
                  -- debout( "Candidate path: '%s'", stat_path )
                  latest_path = stat_path
                  latest_mtime = mtime
               end
            end
         end
      end
   end
   local status = false
   if latest_path then
      local subdev_data = json_file_to_table( latest_path )
      if subdev_data then
         -- debout( "Connection status from subdev file: %s", tostring(subdev_data.data.status ))
         status = subdev_data.data.status == Network.STATUS_UP
      else
         debout( "No subdev data found" )
      end
   else
      debout( ">>> Note: no latest_path determined for mac '%s'", mac )
   end
   return status
end

-- Validate survey and ensure there is at least one result
local function usable_survey( survey )
   return survey and
      survey.data and
      survey.data.survey_results and
      type(survey.data.survey_results) == 'table' and
      #survey.data.survey_results > 0
end

function Network:get_client_steering_data()
   local WLAN_DIR = join_dirs( DEV.DEFAULT_BASE_MSG_DIR, Network.WLAN_DIR )
   local result = {}
   local clients = {}

   for node_entry in nutil.dirs_in( WLAN_DIR ) do
      --debout( "load_subdevices checking '%s'", node_entry )
      for subdev_entry in nutil.dirs_in( join_dirs( WLAN_DIR, node_entry )) do
         local fname = join_dirs( WLAN_DIR, node_entry, subdev_entry, Network.STATUS )
         local json,err = json_file_to_table( fname )
         if json and json.data and json.data.status == Network.STATUS_UP then
            -- Only non-Node devices are of interest
            local child_mac = json.data.sta_bssid
            -- debout( "child_mac: '%s'",child_mac)
            if self:find_node_by_mac( child_mac ) == nil then
               local client = json.data
               -- Try to load survey data
               local survey_fname = join_dirs( WLAN_DIR, node_entry, subdev_entry, Network.NEIGHBORS )
               local survey_json,err = json_file_to_table( survey_fname )
               if usable_survey(survey_json) then
                  client.survey = survey_json.data.survey_results
                  client.TS = survey_json.TS
                  if clients[child_mac] then
                     clients[child_mac] = latest_of( clients[child_mac], client )
                  else
                     clients[child_mac] = client
                  end
               end
            else
               debout( "Ignoring Node '%s'", child_mac )
            end
         end
      end
   end

   return clients
end

function Network:get_node_tree()
   local tree = self:get_master()
   if tree then
      for i,link in ipairs( self.links ) do
         if link.active then
            local parent_node, child_node = link:get_node_endpoints( self )
            if child_node and parent_node then
               parent_node:adopt( child_node )
            end
         end
      end
   end
   return tree
end

return Network
