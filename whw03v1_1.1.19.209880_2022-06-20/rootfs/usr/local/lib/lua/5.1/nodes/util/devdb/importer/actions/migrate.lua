--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

module( ..., package.seeall )

local nutil = require 'nodes.util'
local ddb = require('libdevdblua').db()
local ddb_util = require'nodes.util.devdb'

local errout = nutil.errout
local debout = nutil.debout
local verbout = nutil.verbout

local function set_mac( ddb, uuid, mac )
   local ok, status = pcall( ddb.setInterface, ddb, { macAddr = mac }, uuid )
   if ok then
      debout( "MAC %s added to %s", mac, uuid )
   else
      ddb:writeUnlockRollback()
      error( status )
   end
end


-- TopoDB migrate operation
-- Get or create device for UUID
-- Set interface for each MAC in knownMACAddresses
-- Copy in properties userDeviceName & userDeviceLocation
-- Exit w/happy status
function migrate( json )
   local uuid = json.deviceID:upper()
   local ok, dev = true, nil
   local conf, conf_hi = 4096, 100000
   local host = ddb_import.gather_host_info()
   local props_to_copy = {
      userDeviceName     = "userDeviceName",
      userDeviceType     = "userDeviceType",
      userDeviceLocation = "userDeviceLocation",
   }
   local dev_fields_to_copy = {
    -- DDB Name                TopoDB path
    -- ---------         -----------------------
      deviceType      = "model.deviceType",
      hostName        = "hostName",
      operatingSystem = "unit.operatingSystem",
   }
   -- Helper to extract a value from a JSON sub-expression
   function from_json( s )
      local ok, result = pcall( loadstring( "local json=...; return json." .. s ), json )
      if not ok then
         debout( "Couldn't extract '%s' from json (%s)", tostring( s ), result )
         result = nil
      end
      return result
   end

   debout( "json.isAuthority: %s", tostring( json.isAuthority ))
   if ddb:readLock() then
      dev = ddb:getDevice( uuid )
      ddb:readUnlock()
   else
      error "Unable to read-lock DeviceDB"
   end
   if dev == nil then
      if ddb:writeLock() then
         debout( "Creating new device entry to %s", uuid )
         local ok, status = pcall( ddb.setDevice, ddb, { deviceId = uuid }, 4096 )
         if ok then
            ddb:writeUnlockCommit()
            debout( "Created device '%s'", uuid )
         else
            ddb:writeUnlockRollback()
            error( status )
         end
      else
         error "Unable to write-lock DeviceDB"
      end
   end

   -- At this point the DDB device entry should exist
   if ddb:writeLock() then
      -- Infrastructure (NOde) specific migration
      if ddb_util.topodb_json_is_node( json ) then
         debout( "Setting deviceType to Infrastructure" )
         local infra_mode = json.isAuthority and "master" or "slave"
         ddb:setInfrastructure( uuid, 1, infra_mode )
      end

      debout( "There are %d known MAC address(es)", #json.knownMACAddresses )
      if json.knownMACAddresses and #json.knownMACAddresses > 0 then
         for _,mac in ipairs( json.knownMACAddresses ) do
            verbout( "Adding MAC address '%s' to '%s'", mac, uuid )
            set_mac( ddb, uuid, mac )
         end
         debout( "All MAC addressess successfully added" )
      else
         -- This entry has no MAC addresses.  For Master Nodes, this
         -- is a pathological case the can occasionally happen in
         -- TopoDB.  In the case that "we" are the Master and this
         -- UUID matches our own, we can use the current device MAC
         -- instead.
         if host.mode == ACTIONS.MASTER and host.uuid == uuid then
            verbout "Master MAC missing from TopoDB; using system MAC address"
            set_mac( ddb, uuid, host.mac )
         end
      end

      if json.properties then
         debout( "There are %d properties", #json.properties)
         for _,pair in ipairs( json.properties ) do
            debout( "Evaluating property '%s'='%s'", pair.name, pair.value )
            if props_to_copy[pair.name] then
               ddb:addProperty( uuid, pair.name, pair.value, conf )
               debout( "Added %s", pair.name )
            else
               debout( "Skipped %s", pair.name )
            end
         end
      else
         verbout "There are no properties to migrate"
      end

      local dev_needs_save = false
      -- ddbname is the column name in DeviceDB device table.  jexp is
      -- the sub-expression in the TopoiDB JSON holding the value
      for ddbname, jexp in pairs( dev_fields_to_copy ) do
         local value = from_json( jexp )
         if value then
            local confidence = tonumber( from_json( jexp.."_conf" )) or 32
            debout( "Expression '%s' yields value:'%s' (confidence %d)",
                    jexp, value, confidence )
            local dev = { deviceId = uuid }
            dev[ddbname] = value
            ok, status = pcall( ddb.setDevice, ddb, dev, confidence )
            if not ok then
               errout( "Error setting field '%s'='%s': %s",
                       ddbname, value, status )
            end
         end
      end

      ddb:writeUnlockCommit()
   else
      error "Unable to write-lock DeviceDB"
   end
end

return migrate
