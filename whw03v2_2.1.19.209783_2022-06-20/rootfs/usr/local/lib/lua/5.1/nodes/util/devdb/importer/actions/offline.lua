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

-- Slave offline importer action
-- Extracts the Node UUID and sets it offline.
function offline( json )
   debout "Importing Offline data"
   if json and json.data then
      local uuid = json.uuid
      debout( "UUID: '%s'", tostring( uuid ))
      if uuid then
         -- Mark as off-line
         if ddb_util.set_node_offline( uuid ) then
            debout( "Device successfully set off-line" )
         else
            errout( "Error: Failed to set device off-line" )
         end
      else
         error( ("Backhaul data missing UUID: '%s'"):format( tostring( json )))
      end
   else
      error( ("Unrecocgnized JSON data: '%s'"):format( tostring( json )))
   end
end

return offline
