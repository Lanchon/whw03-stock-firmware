--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

module( ..., package.seeall )

--! @cond
local Klass     = require 'nodes.util.klass'     --!< @private
local Device    = require 'nodes.tess.device'    --!< @private
local Interface = require 'nodes.tess.interface' --!< @private
local nutil     = require 'nodes.util'           --!< @private
local Misc      = require 'nodes.tess.misc'      --!< @private
local Mac       = require('nodes.util.mac').Mac  --!< @private

local debout = nutil.debout
local errout = nutil.errout
local join_dirs = nutil.join_dirs
--! @endcond

Node = Klass(Device)

Node.MODE_NAME = {
   MASTER       = "master",
   SLAVE        = "slave",
   UNCONFIGURED = "UNCONFIGURED"
}

function Node:new(o)
   if not o or not o.uuid then
      error( self.ERROR.MISSING_OR_NIL_ARGUMENT, 2 )
   end
   o = Device:_default_new( o )
   o.mode = o.mode or "unconfigured"
   o.clients = o.clients or {}
   o.kids = o.kids or {}
   return setmetatable( o, self )
end

function Node:has_client( client )
   local result = false
   for _, candidate in ipairs( self.clients ) do
      if client == candidate then
         result = true
         break
      end
   end
   return result
end

function Node:add_client( client )
   if not self:has_client( client ) then
      table.insert( self.clients, client )
   end
   return self
end

local function cp_named_items_to_array( which, from, to )
   if not which or not from or not to then error( "Missing parameters", 2 ) end
   for _,item in ipairs( which ) do
      table.insert( to, from[item] )
   end
end



local DEVINFO_FIELDS_OF_INTEREST = { "mode", "hw_version", "model_number", "num_macs" }
local DEVINFO_MAC_FIELD_NAMES = { mac = "mac" }
DEVINFO_MAC_FIELD_NAMES[ Interface.WIFI_BANDS.HI  ] = "userAp5GH_bssid"
DEVINFO_MAC_FIELD_NAMES[ Interface.WIFI_BANDS.LOW ] = "userAp5GL_bssid"
DEVINFO_MAC_FIELD_NAMES["2G"] = "userAp2G_bssid"

--! @brief Load device data from DEVINFO file
--! @param filename Path to DEVINFO file to load
--! @return On success, a Node object.  On fail a nil.
function Node.from_devinfo( filename )
   local jdata,err = nutil.json_file_to_table( filename )
   local dev = nil
   if jdata then
      jdata.data.uuid = jdata.uuid
      dev = Node:new{
         uuid = jdata.uuid,
         interfaces = {},
      }
      Misc.cp_fields( DEVINFO_FIELDS_OF_INTEREST, jdata.data, dev )
      dev.base_mac = jdata.data.base_mac
      for band,field_name in pairs( DEVINFO_MAC_FIELD_NAMES ) do
         local mac = jdata.data[field_name]
         if mac and mac ~= "" then
            local chan
            local channel_field_name = (field_name:gsub( 'bssid', 'channel' ))
            if channel_field_name ~= field_name then
               chan = jdata.data[channel_field_name]
            end
            local intf = Interface:new{ name = field_name, mac = mac, band = band, channel = chan,
                                        type = ( mac == 'mac' and Interface.TYPE.WIRED or Interface.TYPE.WIRELESS )}
            intf._origin = "Node.from_devinfo#91(name='"..intf.name..
               ",channel_field_name='"..channel_field_name.."',chan='"..tostring(chan).."')"
            if intf then
               table.insert( dev.interfaces, intf )
            end
         end
      end
      if jdata.data.extra_macs then
         for i, mac in ipairs( jdata.data.extra_macs ) do
            if not dev:has_mac( mac ) then
               table.insert( dev.interfaces, Interface:new{
                                mac = mac,
                                _origin = "Node.from_devinfo#61" })
            end
         end
      end
   else
      errout( "Error opening file '%s': %s", tostring( filename ), err)
   end
   return dev
end

local function is_dir( path )
   return lfs.attributes( path, 'mode' ) == 'directory'
end

function Node:is_master()
   return self.mode == 'master'
end

function Node.load_all(opts)
   local lfs = require 'lfs'
   local opts = opts or {}
   opts.path = opts.path or Device.DEFAULT_BASE_MSG_DIR
   local devinfo_path = join_dirs( opts.path, "DEVINFO" )
   local nodes = {}
   if is_dir( devinfo_path ) then
      for fname in lfs.dir( devinfo_path ) do
         if fname ~= '.' and fname ~= '..' then
            local node_path = join_dirs( devinfo_path, fname )
            local node = Node.from_devinfo( node_path )
            if node then
               if node.mode == 'master' then
                  nodes.master = node
               else
                  nodes[node.uuid] = node
               end
            else
               errout( "Failed to load '"..node_path..'"' )
            end
         end
      end
      return nodes
   else
      error( "Invalid path '"..tostring(devinfo_path).."'", 2 )
   end
end

local function macify( maybe_mac )
   if not maybe_mac then error( "Missing argument", 2 ) end
   if maybe_mac == "" then error( "Blank argument", 2 ) end
   if type( maybe_mac ) == 'string' then
      maybe_mac = Mac:new( maybe_mac )
   end
   return maybe_mac
end

function printf( s, ... )
   io.write( s:format(...))
   return io.write( '\n' )
end

function Node:has_mac( mac )
   if mac == nil then error( "NIL mac", 2 ) end
   local result = false
   if mac then
      mac = macify( mac ) -- Convert to Mac object if needed
      for i,intf in ipairs( self.interfaces ) do
         if macify(intf.mac) == mac then
            result = true
            break
         end
      end
   end
   return result
end

function Node:find_intf_for_band( band )
   local result
   for _, intf in ipairs( self.interfaces ) do
      if intf.band == band then
         result = intf
         break
      end
   end

   return result
end

function Node:find_client_by_mac( mac )
   if mac == nil then error( self.ERROR.MISSING_OR_NIL_ARGUMENT, 2 ) end
   local found = nil
   mac = macify( mac )
   for _,client in ipairs( self.clients ) do
      if client.sta_bssid then
         local client_mac = macify( client.sta_bssid )
         if client_mac == mac then
            found = client
            break
         end
      end
   end
   return found
end

--! @brief Tell if kid is a child of this Node
function Node:has_kid( kid )
   local present = false
   if kid and self.kids then
      for _,k in ipairs( self.kids ) do
         if k == kid then
            present = true
            break
         end
      end
      return present
   end
end

--! @brief Add specified child to list of children if not already present
function Node:adopt( child )
   if child and not self:has_kid( child ) then
      table.insert( self.kids, child )
   end
end

return Node
