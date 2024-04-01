--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

--! @file
--! @brief nodes cloud utility module

module( ..., package.seeall )

local cloud = require 'cloud'
local nutil = require 'nodes.util'
local syscfg_get = nutil.syscfg_get


-- For Nodes, the network name is the SSID.  Also for Nodes, all
-- non-guest user-facing Wi-Fi radios have the same SSID.  To be
-- portable, we mustn't hard-code the interface names.  So use the
-- first in the list strored in system configuration variable
-- configurable_wl_ifs.
function get_nodes_ssid()
   local raw_wl_if_list = syscfg_get( "configurable_wl_ifs", true )
   if raw_wl_if_list == nil or raw_wl_if_list == "" then
      error "Could not get wireless interface list"
   end
   -- configurable_wl_ifs is a space seperated list of interface
   -- names.  We split them on the spaces and take the first one.  Any
   -- will do really.
   wl_if_list = {}
   for w in raw_wl_if_list:gmatch( '%S+') do
      table.insert( wl_if_list, w )
   end
   local if_name = wl_if_list[1]

   local ssid = syscfg_get( if_name.."_ssid", true )
   if opts and opts.debug then print( "ssid:", ssid ) end
   return ssid
end

EVENT_TYPES = {
   ROUTER_OFFLINE      = "ROUTER_OFFLINE",
   SLAVE_OFFLINE       = "DEVICE_LEFT_NETWORK",
   ROUTER_NOTIFICATION = "ROUTER_NOTIFICATION"
}


function post_node_event( sys, event_type, payload )
   local err, id = true, "Unknown"
   if opts and opts.dry_run then
      print( "Would call cloud.createEvent( ", sys.host, sys.networkID,
             sys.networkPassword, tostring( sys.deviceID ),
             event_type,
             sys.eventTime, sys.verifyHost,
             payload, ")" )
      err, id = false, "dry-run"
   else
      err, id = cloud.createEvent( sys.host, sys.networkID,
                                   sys.networkPassword, tostring( sys.deviceID ),
                                   event_type,
                                   sys.eventTime, sys.verifyHost,
                                   payload )
   end
   return err, id
end


function post_offline_node_event( sys, payload )
   return post_node_event( sys, EVENT_TYPES.SLAVE_OFFLINE, payload )
end
