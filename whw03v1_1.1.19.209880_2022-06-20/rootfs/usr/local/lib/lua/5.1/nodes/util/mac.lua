--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--
--! @file

module(...,package.seeall)

--! @class Mac
--! @brief A class encapsulating a MAC number
--! Can be constructed from a string using ":" or "-" as delimters.

Mac = {}
Mac_mt = {
   __index = Mac,
   __tostring = function(m)
      return table.concat( m.octets, m.SEP )
   end,
   __eq = function( a, b )
      local result = #a.octets == #b.octets
      if result then
         for i,aitem in ipairs( a.octets ) do
            if aitem ~= b.octets[i] then
               result = false
               break
            end
         end
      end
      return result
   end,
   -- "*" overridden to compare oui's
   __mul = function( a, b )
      return a:oui() == b:oui()
   end,
   -- "/" ocerriden to compare nic's
   __div = function( a, b )
      return a:nic() == b:nic()
   end,
}


local function split_octets( s )
   if s == nil then error( "Missing constructor parameter" ) end
   local o = {}
   local SEPS = ":-"  -- MACs can use several separators
   local SEP = nil
   -- The first capture is the whole pattern, the 3rd is the seperator.
   local seps_mpat = "((%x%x)(["..SEPS.."])(%x%x)%3(%x%x)%3(%x%x)%3(%x%x)%3(%x%x))"
   local noseps_mpat = "(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)"
   if s:match(':') or s:match('-') then
      -- Use captures to 1st separator to ensure they are all the same.
      -- Note that using a capture this way perterbs the ordering of
      -- return values from match
      -- Split the lower-case shifted MAC string on either ":" or "-".
      _, o[1], SEP, o[2], o[3], o[4], o[5], o[6] = s:lower():match( seps_mpat )
   else
      o[1], o[2], o[3], o[4], o[5], o[6] = s:lower():match( noseps_mpat )
   end
   return o, SEP
end

function Mac:new(s)
   local o, sep = split_octets( s )
   if #o ~= 6 then error( "Bad MAC format ("..tostring(s)..")", 2 ) end
   sep = sep or ":"
   return setmetatable(  { octets = o, SEP = sep }, Mac_mt )
end

function Mac:oui()
   local m = self.octets
   return table.concat( { m[1], m[2], m[3] }, self.SEP )
end

local function nic_octets( mac )
   local m = mac.octets
   return { m[4], m[5], m[6] }
end

function Mac:nic()
   return table.concat( nic_octets(self), self.SEP )
end

function Mac.valid( pat )
   local valid = false
   if pat then
      valid = pcall( Mac.new, Mac, pat )
   end
   return valid
end

function Mac:tonumber()
   return tonumber( table.concat( self.octets ), 16 )
end

function Mac:nic_tonumber()
   return tonumber( table.concat( nic_octets(self)), 16 )
end
