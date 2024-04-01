--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--
--! @file
--! @brief Interface (host) class for tesseract subsystem

module( ..., package.seeall )


--! @cond
local Klass = require 'nodes.util.klass'     --!< @private
local nutil = require 'nodes.util'     --!< @private
local errout = nutil.errout
local debout = nutil.debout
--! @endcond

--! @class Interface
--! Network interface class.  This represents a network interface
--! (e.g. ethernet, Wi-Fi).  Each must have a mac and optionally a
--! type and name
Interface = Klass{
   --! @class Interface.ERROR
   --! Error (exception) messages for Interface.
   --! Note: By exposing our exception strings here, we can write unit
   --! tests that use them.  See unit-tests/interface_spec.lua
   ERROR = {
      MISSING_OR_NIL_ARGUMENT = "Interface: Missing or nil argument",
      BAD_ARGUMENT_TYPE       = "Interface: Bad argument type",
      WRONG_ARGUMENT_COUNT    = "Interface: Wrong argument count",
      BAD_NODE_MODE           = "Interface: Bad Node mode",
   },
   TYPE = {
      WIRELESS = "WIRELESS",
      WIRED    = "WIRED"
   },
   WIFI_BANDS = {
      HI  = "5GH",
      LOW = "5GL"
   },
   __tostring = function( self )
      local FIELDS = { "name", "mac", "channel", "type" }
      local result = {}
      for _,f in ipairs( FIELDS ) do
         if self[f] then
            table.insert( result, f..": "..tostring(self[f]))
         end
      end
      return "{ "..table.concat( result, ", " ) .. " }"
   end

}
Interface.TYPE_NAMES = {}
Interface.TYPE_NAMES[Interface.TYPE.WIRELESS] = Interface.TYPE.WIRELESS
Interface.TYPE_NAMES[Interface.TYPE.WIRED]    = Interface.TYPE.WIRED

--! @fn Interface##new(o)
--! @memberof Interface
--! Interface constructor
function Interface:new(o)
   if not o or not o.mac or o.mac == '' then
      error( self.ERROR.MISSING_OR_NIL_ARGUMENT, 2 )
   end
   return setmetatable( o, self )
end


return Interface
