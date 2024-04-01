--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--
--! @file
--! @brief Device (host) class for tesseract subsystem

module( ..., package.seeall )


--! @cond
local Klass = require 'nodes.util.klass'     --!< @private
local nutil = require 'nodes.util'           --!< @private
local MAC   = require('nodes.util.mac').Mac  --!< @private
local INTF  = require 'nodes.tess.interface' --!< @private
local errout = nutil.errout
local debout = nutil.debout
--! @endcond


--! @class Device
--! Network device class.  This represents a network host.
--! Each will have at least a UUID.
Device = Klass{
   --! @class Device.ERROR
   --! Error (exception) messages for Device.
   --! Note: By exposing our exception strings here, we can write unit
   --! tests that use them.  See unit-tests/device_spec.lua
   ERROR = {
      MISSING_OR_NIL_ARGUMENT = "Device Missing or nil argument",
      BAD_ARGUMENT_TYPE       = "Device Bad argument type",
      WRONG_ARGUMENT_COUNT    = "Device Wrong argument count",
      BAD_NODE_MODE           = "Device Bad Node mode",
   },
   DEFAULT_BASE_MSG_DIR = "/tmp/msg",
   data = {},
   __eq = function( a, b )
      return a and a.uuid and b and b.uuid and a.uuid == b.uuid
   end,
   __tostring = function( self )
      local FIELDS = { "uuid", "mode", "moved" }
      local result = {}
      for _,f in ipairs( FIELDS ) do
         if self[f] then
            table.insert( result, f..": "..tostring(self[f]))
         end
      end
      return "{ "..table.concat( result, ", " ) .. " }"
   end
}

function Device:_default_new(o)
   o = o or {}
   o.interfaces = o.interfaces or {}
   o.links = o.links or {}
   return setmetatable( o, self )
end


--! @fn Device##new(o)
--! @memberof Device
--! Device constructor
function Device:new(o)
   if not o or not o.uuid then
      error( self.ERROR.MISSING_OR_NIL_ARGUMENT, 2 )
   end
   return self:_default_new(o)
end


function Device:add_link( link )
   if not link then error( "Missing link", 2 ) end
   if not self.links then error "Hey, no links???" end
   debout( "Device:add_link( %s ) --> %s(%s)",
           tostring(link), self.uuid, tostring( self ))
   table.insert( self.links, link )
   debout( "Device:add_link #self.links now %d", #self.links )
end

function Device:remove_link( link )
   if link then
      for i,l in ipairs( self.links ) do
         if l == link then
            table.remove( self.links, i )
            break
         end
      end
   end
end

function Device:active_link()
   local result = nil
   if self.links then
      for _, l in ipairs( self.links ) do
         if l.active then
            result = l
            break
         end
      end
   end
   return result
end

function Device:add_interface( intf )
   if intf then
      table.insert( self.interfaces, intf )
   end
end

function Device:find_intf_by_mac( mac )
   local intf = nil
   if mac then
      if type( mac ) == "string" then mac = MAC:new( mac ) end
      for _, candidate in ipairs( self.interfaces ) do
         if candidate.mac and candidate.mac ~= "" then
            local candidate_mac = MAC:new( candidate.mac )
            if candidate_mac == mac then
               intf = candidate
               break
            end
         end
      end
   end
   return intf
end

function Device:get_apbssid()
   local result = nil
   if self.ap_bssid then
      result = self.ap_bssid
   else
      for _,link in ipairs( self.links ) do
         if link.active and link.to.ap_bssid then
            result = link.to.ap_bssid
            break
         end
      end
   end
   return result
end

--! @fn Device::short_name
--! Returns a short name for this device.
--! @param max Optional: Maximum name to return (truncates to this).
--! @return Short name
function Device:short_name( max )
   max = (max or 5) * -1
   return self.uuid:sub( max )
end

-- Debugging helper
function Device.__diddle_DEFAULT_BASE_MSG_DIR( dir )
   Device.DEFAULT_BASE_MSG_DIR = dir
end


return Device
