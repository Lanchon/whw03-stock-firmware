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

-- Backhaul importer action
-- Currently just grabs any MAC addresses & sets 1 long reserves.
-- This has the effect of merging any temporary devices that had been
-- created for those interfaces into the permanent device entry for
-- that Slave Node.
function bh( json )
   debout "Importing Backhaul data"
   if json and json.data then
      local uuid = json.uuid
      debout( "UUID: '%s'", tostring( uuid ))
      if uuid then
         if ddb:writeLock() then
            local ok, status = pcall( function()
                  if json.data.mac ~= nil and json.data.mac ~= '' then
                     ddb:setMacReserve( uuid, json.data.mac, 1 )
                  end
                  if json.data.sta_bssid ~= nil and json.data.sta_bssid ~= '' then
                     ddb:setMacReserve( uuid, json.data.sta_bssid, 1 )
                  end
            end)
            if ok then
               ddb:writeUnlockCommit()
               verbout( "Successfully added BH data to device '%s'", uuid )
            else
               ddb:writeUnlockRollback()
               errout( "Got error '%s'", status )
               error( status, 2 )
            end
         else
            error "Couldn't acquire DeviceDB write-lock"
         end
      else
         error( ("Backhaul data missing UUID: '%s'"):format( tostring( json )))
      end
   else
      error( ("Unrecocgnized JSON data: '%s'"):format( tostring( json )))
   end
end

return bh
