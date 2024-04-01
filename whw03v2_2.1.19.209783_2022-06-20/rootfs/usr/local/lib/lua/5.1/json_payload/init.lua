-- Module for generating JSON payloads
--
-- Copyright (c) 2016, Belkin Inc. All rights reserved.
--

module(...,package.seeall)

local Args = require'json_payload.args'

-- Define store class
JSPayload = {}

local default_outer = {
   prefix = "{",
   suffix = "}"
}

function JSPayload:new(outer)
   local o = {
      outer = outer or default_outer,
      entities = {}
   }
   setmetatable(o,self)
   self.__index = self

   function o.entities:add(x)
      self[#self+1] = x
      return self
   end

   self.indent = self.indent or 0
   return o
end

function JSPayload:add_pair( name, value )
   if type( value ) ~= 'string' then
      value = tostring( value )
   end
   self.entities:add( Args.Entity:new( name, value ))
   return self
end

function JSPayload:add( entity )
   self.entities:add( entity )
   return self
end

function JSPayload:add_list( list )
   for _,entity in ipairs( list ) do
      self:add( entity )
   end
   return self
end

function JSPayload:__tostring(e)
   local buffer = {}
   local pad = string.rep( ' ', self.indent )

   for _,entity in ipairs( self.entities ) do
      buffer[#buffer+1] = pad .. entity:to_json()
   end
   return string.format( "%s\n  %s%s\n%s", self.outer.prefix,
                         pad, table.concat( buffer, ",\n  " ), self.outer.suffix )
end


return JSPayload
