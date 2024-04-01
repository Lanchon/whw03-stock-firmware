-- -*- lua -*-
--
-- Copyright (c) 2016, Belkin Inc. All rights reserved.
--
--! @file
--! @brief DeviceDB utility module

module( ..., package.seeall )

local ddb     = require('libdevdblua').db()
local nutil   = require 'nodes.util'
local errout  = nutil.errout
local debout  = nutil.debout
local verbout = nutil.verbout

--! Get the friendly name for a device
--! @param uuid The ID of the device
--! return a friendly name (if present) or "somewhere"
function get_user_friendly_name( uuid )
   local name = "somewhere"
   if uuid then
      if ddb:readLock() then
         local ok, dev = pcall( ddb.getDevice, ddb, uuid )
         ddb:readUnlock()
         if ok and dev then
            name = dev.friendlyName or dev.hostname or ""
            if dev.property then
               name = dev.property.userDeviceName or
                  dev.property.userDeviceLocation or
                  name
            end
         end
      end
   end
   return name
end

--! @brief Determine if device is a Velop Node
--! Uses manufaturer name & model
--! @param dev Device table from DeviceDB
--! @return true if dev is determined to be a Node, false if not
function is_node( dev )
   return type(dev) == 'table' and
          dev.manufacturer == 'Linksys' and
          nutil.is_node_model( dev.modelNumber )
end

--! @brief Set Node as on-line.
--! @param id UUID of Node
--! @param base_mac Node base MAC as string
--! @param ipaddr IP address as a string
--! @return 1 on success, 0 for error
function set_node_online( id, base_mac, ipaddr )
   local status = 0

   if ddb:writeLock() then
      local ok, status = pcall( function()
            -- Note hard-coded address type (ipv4).  This may need to
            -- change in the future.
            return ddb:setInfraDeviceOnline( id, base_mac, ipaddr, "ipv4" )
      end)
      if ok then
         ddb:writeUnlockCommit()
         debout(("Node '%s' set online; status: %s"):format(
               id, tostring( status )
         ))
      else
         ddb:writeUnlockRollback()
         errout( ("Error setting node '%s' online; status: %s"):format( id, status ))
      end
   else
      error "Unable to write-lock DeviceDB"
   end

   return status
end

--! @brief Set Node as off-line.
--! @param id UUID of Node
--! @return 1 on success, 0 for error
function set_node_offline( id )
   local status = 0

   if ddb:writeLock() then
      local ok, status = pcall( function()
            return ddb:setInfraDeviceOffline( id )
      end)
      if ok then
         ddb:writeUnlockCommit()
         debout(("Node '%s' set offline; status: %s"):format(
               id, tostring( status )
         ))
      else
         ddb:writeUnlockRollback()
         errout( ("Error setting node '%s' offline; status: %s"):format( id, status ))
      end
   else
      error "Unable to write-lock DeviceDB"
   end

   return status
end


--! @brief Determine if device is a Velop Node
--! Uses manufaturer name & model
--! @param json A table converted from TopoDB JSON persistence file
--! @return true if dev is determined to be a Node, false if not
function topodb_json_is_node( json )
   local is_node = false
   if json.model then
      if json.model.manufacturer and json.model.manufacturer == 'Linksys' then
         if json.model.modelNumber then
            local modnum = json.model.modelNumber
            if modnum:sub(1,5) == "WHW03" or modnum == "Nodes" then
               is_node = true
            end
         end
      end
   end
   return is_node
end
