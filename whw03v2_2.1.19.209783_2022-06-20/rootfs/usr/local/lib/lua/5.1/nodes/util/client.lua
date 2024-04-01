--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

--! @file
--! @brief nodes utility module

module( ..., package.seeall )

local lfs      = require'lfs'
local nutil    = require 'nodes.util'
local ddb      = require('libdevdblua').db()
local ddb_util = require'nodes.util.devdb'
local Mac      = require('nodes.util.mac').Mac

local trim_trailing_slashes = nutil.trim_trailing_slashes
local join_dirs = nutil.join_dirs
local utc_datetime_to_ostime = nutil.utc_datetime_to_ostime

local function run(cmd)
   return nutil.chomp( io.popen(cmd):read("*a"))
end

BASE = run( 'syscfg get subscriber::file_prefix' )
WLAN_BASE = join_dirs( BASE, "WLAN")
DEVINFO_BASE = join_dirs( BASE, "DEVINFO")

local function is_dir( path )
   return lfs.attributes( path, 'mode' ) == 'directory'
end

local function is_node( dev )
   local result = false
   if type(dev) == 'table' and dev.deviceId then
      local inf = ddb:getInfrastructure( dev.deviceId )
      if inf and inf.infrastructure then
         result = tonumber(inf.infrastructure) == 1
      end
   end
   return result
end

local function not_node( dev )
   return not is_node( dev )
end

local function gather_wlan_connections( sc )
   local connections = {}

   if is_dir( WLAN_BASE ) then -- <-- Thanks Henry Sia!
      for node_name in lfs.dir( WLAN_BASE ) do
         if node_name ~= '.' and node_name ~= '..' then
            local node_dir = join_dirs( WLAN_BASE, node_name )
            -- As per request from Henry Sia, adjust node name for Master to be UUID
            if node_name == 'master' then node_name = nutil.get_our_uuid( sc ) end
            if is_dir( node_dir ) then
               for client_mac in lfs.dir( node_dir ) do
                  if client_mac ~= '.' and client_mac ~= '..' and Mac.valid( client_mac ) then
                     local client_mac_path = join_dirs( node_dir, client_mac )
                     local client_mac = (client_mac:gsub( '-', ':' ))
                     if is_dir( client_mac_path ) then
                        local status_path = join_dirs( client_mac_path, 'status' )
                        local raw_connection = nutil.json_file_to_table( status_path )
                        if raw_connection and raw_connection.data.status == 'connected' then
                           ddb:readLock()
                           local dev = ddb:getDeviceByMac( client_mac )
                           ddb:readUnlock()
                           if dev ~= nil and not_node( dev ) then  -- Thanks Henry!
                              raw_connection.data.uuid = dev.deviceId
                              raw_connection.data.timestamp = raw_connection.TS
                              connections[node_name] = connections[node_name] or {}
                              connections[node_name][client_mac] = raw_connection.data
                           end
                        end
                     end
                  end
               end
            end
         end
      end
   end
   return connections
end

function cull_duplicates( connections )
   local macs = {}
   for node_name, node in pairs( connections ) do
      for mac, connection in pairs( node ) do
         if macs[mac] then
            -- Dupe found.  Determine which is fresher.
            local old = macs[mac].connection
            local old_node_name = macs[mac].node_name
            local time1 = utc_datetime_to_ostime( old.timestamp )
            local time2 = utc_datetime_to_ostime( connection.timestamp )
            -- bigger means later
            if time1 > time2 then
               -- First connection is newer; keep it
               connections[node_name][mac] = nil
            else
               -- Second connection is newer; use it & purge first one
               connections[old_node_name][mac] = nil
               macs[mac] = { connection = connection, node_name = node_name }
            end
         else
            macs[mac] = { connection = connection, node_name = node_name }
         end
      end
   end
   -- Cull any now-empty node entries
   for node_name, node in pairs( connections ) do
      -- Is it empty?
      if next( node ) == nil and #node == 0 then
         -- Yes; remove
         connections[node_name] = nil
      end
   end
   return connections
end

--! @brief Gather list of connect client (non-Node) devices.
--! @return an array of objects, each defining a client device in
--! terms of uuid, rssi, etc.
function get_wlan_client_list( sc )
   return cull_duplicates( gather_wlan_connections( sc ) )
end
