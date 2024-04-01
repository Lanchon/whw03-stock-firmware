--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

module( ..., package.seeall )

local nutil        = require 'nodes.util'
local ddb          = require('libdevdblua').db()
local ddb_util     = require'nodes.util.devdb'
local ddb_importer = require'nodes.util.devdb.importer'

local errout = nutil.errout
local debout = nutil.debout
local verbout = nutil.verbout

local establish_named_device = ddb_importer.establish_named_device

-- List of fields to import from JSON data area.  Key is the field
-- name in the JSON, value is the name of the corresponding field in
-- devicedb
local extra_fields = {
   description  = "description",
   fw_ver       = "firmwareVersion",
   manufacturer = "manufacturer",
   serialNumber = "serialNumber",
}

function devinfo( json )
   local flog = require('nodes.util.flogger').flog
   function _log( pri, fmt, ... )
      flog({ tag = 'omsg_import.devinfo', priority = pri, msg = fmt }, ... )
   end
   function log( fmt, ... )    _log( 'daemon.notice', fmt, ... ) end
   function errlog( fmt, ... ) _log( 'daemon.error',  fmt, ... ) end
   local uuid = json.uuid
   log( "Importing DEVINFO MQTT data for Node '%s'", tostring( uuid ))
   local mac = json.data.mac
   local conf = 100000 -- Confidence value
   local err_cnt = 0
   if establish_named_device( mac, uuid ) then
      log "Locking database"
      ddb:writeLock() -- Throws error on fail
      -- Field num_macs has been deprecated & replaced by num_macs2.
      -- Some older firmware versions had wildly incorrect values.  If
      -- num_macs2 is not set, assume a default value of 6 for
      -- num_macs.
      local default_num_macs = 6
      local num_macs = nil
      if json.data.num_macs2 == nil then
         verbout( "Supported field num_macs2 not found, only deprecated num_macs ('%s'); using default value (%d)",
                  tostring( json.data.num_macs ),
                  default_num_macs )
         num_macs = default_num_macs
      else
         num_macs = json.data.num_macs2
         verbout( "Setting mac reserve to %d based on supported num_macs2 field", num_macs )
      end
      log( "Setting num_macs to %d", num_macs )
      ddb:setMacReserve( uuid, json.data.base_mac, num_macs )
      if json.data.extra_macs then
         for _,mac in ipairs( json.data.extra_macs ) do
            verbout( "Setting extra mac %s", mac )
            ddb:setMacReserve( uuid, mac, 1 )
         end
      end
      log( "Setting device '%s' as infrastructure", tostring( uuid ))
      verbout( "Setting device %s infrastructure 1/%s", uuid, json.data.mode )
      ddb:setInfrastructure( uuid, 1, json.data.mode )
      ddb:writeUnlockCommit()
      log( "Device '%s' successfully set as infrastructure & committed", tostring( uuid ))
      debout "MAC reserve updated"

      -- private set_field helper function
      function do_set_field( name, value )
         local ok,err = pcall( set_device_field, uuid, name, value,  conf )
         if not ok then
            err_cnt = err_cnt + 1
            errlog( "Error in set_device_field( '%s', '%s, '%s', %d ): %s",
                    tostring( uuid ), tostring( name ), tostring( value ), conf, err )
         end
      end

      for jname, dbname in pairs( extra_fields ) do
         local jdata = json.data[jname]
         if type(jdata) == 'string' and jdata ~= '' then
            log( "Setting Node '%s' '%s' to '%s'",
                 "..."..uuid:sub(-10), dbname, tostring( jdata ))
            do_set_field( dbname, jdata )
         else
            err_cnt = err_cnt + 1
            errlog( "Error in set_device_field( '%s', '%s, '%s', %d ): %s",
                    tostring( uuid ), tostring( dbname ), tostring( jdata ), conf, err )

            errlog( "Skipping import of missing '%s' to '%s' for Node '%s'",
                    jname, dbname, "..."..uuid:sub(-10))
         end
      end

      -- Special handling for model.  Support app requests model_base
      -- instead of model_number.  If model_base not present, use
      -- model_number anyway.
      do_set_field( "modelNumber", json.data.model_base or json.data.model_number )

      -- Set the device type as Infrastructure
      do_set_field( "deviceType", "Infrastructure" )

      -- Mark as on-line
      if ddb_util.set_node_online( uuid, mac, json.data.ip ) then
         debout( "Device successfully set on-line" )
         log( "Node '%s' imported with %d problems", tostring( uuid ), err_cnt )
      else
         errout( "Error: Failed to set device on-line" )
      end
   else
      error "Could neither find nor create device to update"
   end
end


return devinfo
