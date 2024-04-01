--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--
--! @file
--! @brief A simple class for Lua OOP

--! @cond
--! @private
local setmetatable = setmetatable
--! @endcond

module( ... )

--! @fn Klass##Klass
--! Simple "class" for Lua.  Handles simple inheritance.
--! @param parent (optional) Parent class for this new class
--! @param Class parameters; this table forms the initial contents of
--! the Class
--! "parent" parameter is optional.  If only 1 parameter is provided
--! it is treated as params.
function Klass( parent, params )
   if not params then parent, params = nil, parent end

   if parent then
      local newf = parent._default_new and parent._default_new or parent.new
      newClass = newf( parent, params or {} )
   else
      newClass = params or {}
   end
   newClass.__index = newClass

   function newClass:new( o )
      o = o or {}
      return setmetatable( o, self )
   end

   return newClass
end

return Klass
