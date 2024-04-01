--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--
-- "Action" module for ddb_omsg_import

-- ---------------------------------------------------------------------------
-- NOTE !! : This file has been deprecated, the action here is performed by  
--           the DDD agent instead. Also this file contains the old DeviceDB 
--           API and may not work with the current code.
-- ---------------------------------------------------------------------------

module( ..., package.seeall )

local nutil = require 'nodes.util'
local ddb = require('libdevdblua').db()
local ddb_util = require'nodes.util.devdb'

local errout = nutil.errout
local debout = nutil.debout
local verbout = nutil.verbout

--! @brief Interpret guestNet value.
--! The guestNet field in the JSON data can be either a string or a
--! boolean depending on firmware version.
--! @param value wither a string containing "true" or "false" or a
--! boolean
--! @return An integer 1 or 0.
local function interpret_guestnet( value )
   local result = 0
   if type( value ) == 'string' then
      result = value == "true" and 1 or 0
   elseif type( value ) == 'boolean' then
      result = value and 1 or 0
   end
   return result
end

-- WLAN sub-device importer action
-- Currently we set a Wi-Fi device as on/orr-line, store the BSSID's
-- and whether it is connected tot he guest network or not.
function wlan_subdev( json )
   debout "Importing sub-device data"
   if not json or not json.data then
      error( ("Missing or unrecognized JSON data: '%s'"):format( tostring( json )))
   end
   local intf = {
      guestNet       = interpret_guestnet( json.data.guest ),
      ap_bssid       = json.data.ap_bssid,
      connectionType = json.data.mode,
      wifiBand       = json.data.band
   }
   debout( "Setting guestNet to %s(%s)", tostring(intf.guestNet), type( intf.guestNet ))
   if opts.debug then
      local fmt = "   %14s: '%s'"
      debout( fmt:format( "uuid", tostring( json.uuid )))
      debout( fmt:format( "status", tostring( json.data.status )))
      debout( fmt:format( "sta_bssid", tostring( json.data.sta_bssid )))
      debout( "Interface data:" )
      for k,v in pairs( intf ) do
         k,v = tostring(k), tostring(v)
         debout( fmt:format( k, v ))
      end
   end
   local device_mac = json.data.sta_bssid
   if device_mac and device_mac ~= "" then
      if ddb:writeLock() then
         local ok, status = pcall( function()
               local status
               if json.data.status == "connected" then
                  status = ddb:setWifiMacOnline( device_mac, intf, "", json.uuid )
               else
                  status = ddb:setWifiMacOffline( device_mac, intf.ap_bssid )
               end
               return status
         end)
         if ok then
            ddb:writeUnlockCommit()
            debout(("Interface '%s' set to state '%s'; status: %s"):format(
                  device_mac, json.data.status, tostring( status )
            ))
         else
            ddb:writeUnlockRollback()
            errout( ("Error setting interface '%s' to status '%s': %s"):format(
                  device_mac, json.data.status, status
            ))
         end
      else
         error "Unable to write-lock DeviceDB"
      end
   else
      errout "No MAC address in message; no actions possible"
   end
end

return wlan_subdev
