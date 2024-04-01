--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--
--! @file
--! @brief Endpoint class for tesseract subsystem

module( ..., package.seeall )


--! @cond
local Klass = require 'nodes.util.klass'     --!< @private
local nutil = require 'nodes.util'           --!< @private
local INTF  = require 'nodes.tess.interface' --!< @private
local DEV   = require 'nodes.tess.device' --!< @private
local errout = nutil.errout
local debout = nutil.debout
--! @endcond


--! @class Endpoint
--! Network endpoint class.  This represents one end of a Link.
Endpoint = Klass{
   --! @class Endpoint.ERROR
   --! Error (exception) messages for Endpoint.
   --! Note: By exposing our exception strings here, we can write unit
   --! tests that use them.  See unit-tests/endpoint_spec.lua
   ERROR = {
      MISSING_OR_NIL_ARGUMENT = "Endpoint: Missing or nil argument",
      BAD_ARGUMENT_TYPE       = "Endpoint: Bad argument type",
      WRONG_ARGUMENT_COUNT    = "Endpoint: Wrong argument count",
      BAD_NODE_MODE           = "Endpoint: Bad Node mode",
   },
   UNSET = "<unset>",
   DEFAULT_BASE_MSG_DIR = "/tmp/msg",
   __eq = function( a, b )
      return a and b and
         ( a.interface == nil or
           b.interface == nil or
           a.interface == b.interface ) and
         a.device == b.device
   end,
   __tostring = function( e )
      local dev = e.device or Endpoint.UNSET
      local int = e.interface or Endpoint.UNSET
      local ap_bssid = e.ap_bssid or Endpoint.UNSET
      return ("[device='%s',interface='%s',ap_bssid='%s']"):format( dev, int, ap_bssid )
   end
}

--! @fn Endpoint##new(o)
--! @memberof Endpoint
--! Endpoint constructor
function Endpoint:new(o)
   if not o or not o.device then
      error( self.ERROR.MISSING_OR_NIL_ARGUMENT, 2 )
   end
   -- If device is a table, assume it is a Device object and extract
   -- its' UUID
   if type( o.device ) == 'table' then
      if not o.device.uuid then error( "Invalid device object", 2 ) end
      o.device = o.device.uuid
   end
   -- If interface is a table, assume it is an Interface object and
   -- extract its' mac
   if type( o.interface ) == 'table' then
      if not o.interface.mac then error( "Invalid interface object", 2 ) end
      o.interface = o.interface.mac
   end
   return setmetatable( o, self )
end


return Endpoint
