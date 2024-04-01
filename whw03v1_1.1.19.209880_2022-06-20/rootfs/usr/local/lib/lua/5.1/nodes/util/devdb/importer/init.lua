--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

module( ..., package.seeall )

local nutil   = require'nodes.util'
local errout  = nutil.errout
local debout  = nutil.debout
local verbout = nutil.verbout

--! @brief Gether selected pieces of info from the host.
--! This currently includes smart-mode, uuid & mac
--! @return A table containing host information
function gather_host_info()
   local togather = {
      mac  = "device::mac_addr",
      mode = "smart_mode::mode",
      uuid = "device::uuid",
   }
   local info = {}
   local sc = require('libsysctxlua').new()
   sc:readlock() -- No return status to check
   for k,v in pairs( togather ) do
      info[k] = sc:get( v ):upper()
   end
   sc:rollback()
   -- Uncomment for more diagnostic poo regarding localling harvested
   -- host data
   -- if opts.verbose then
   --    verbout "Gathered host data:"
   --    for k,v in pairs( info ) do
   --       verbout( "info.%s = '%s'", k, v )
   --    end
   -- end
   return info
end


--! @brief Establish existense of device for MAC with ID.
--! There are 3 cases this handles.  If the device exists with the
--! specified ID, we are done.  If an existing device with a different
--! ID is associated with the specified MAC exists, the device is
--! renamed.  If no device at all is associated with the MAC, then a
--! new device is created with the specified name and is associated
--! with the MAC.
--! If the device cannot be created an error is generated.
--! @param mac MAC address to look up device by
--! @param desired id
--! @return Nothing
--! @exception Throws descriptive error on fail
function establish_named_device( mac, uuid )
   verbout( ("establish_named_device( '%s'(%s), '%s'(%s) )"):format(
         tostring( mac ),  type( mac ),
         tostring( uuid ), type( uuid )
   ))

   ddb:readLock()
   -- Current version of getDevice never throws an error
   local dev = ddb:getDevice( uuid )
   ddb:readUnlock()

   if dev == nil then
      debout( "Existing device for id '%s' not found; attempting update", uuid )
      ddb:writeLock()
      local ok, status = pcall( ddb.changeDeviceId, ddb, mac, uuid )
      if not ok then
         -- The device doesn't exist in any form so now we will
         -- attempt to create it ourselves
         debout( "No device to reassign; creating new device entry for %s", uuid )
         ok, status = pcall( function()
               -- Note: these DeviceDB functions only return true or throw errors
               return ddb:setDevice( { deviceId = uuid }, 4096 ) and
                      ddb:setInterface( { macAddr = mac }, uuid )
         end)
      end

      if ok then
         ddb:writeUnlockCommit()
         debout( "Established device '%s' with MAC '%s'", uuid, mac )
      else
         ddb:writeUnlockRollback()
         io.stderr:write(
            ("Problem updating DeviceDB; ok: %s, status: %s\n"):format(
               tostring( ok ),
               tostring( status )))
         error( status )
      end

      -- Now try again; it should be there
      ddb:readLock()
      dev = ddb:getDevice( uuid )
      ddb:readUnlock()
      if not dev then
         error( ("Device not found at id '%s' after DB writes"):format( uuid ))
      end
   else
      debout( "Found existing device for id '%s', MAC '%s'", uuid, mac )
   end
   return true
end
