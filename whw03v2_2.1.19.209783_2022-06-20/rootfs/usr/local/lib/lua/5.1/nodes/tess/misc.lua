--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

--! @file
--! @brief Miscellaneous facilities for Tesseract

module( ..., package.seeall )

local Misc = {}

--! @fn
--! @brief Copy seleted fields from one table to another.
--! @param what Array of field names
--! @param from Source table
--! @param to Destination Table
--! @param deblank (optional) Don't copy "" string values
--! @return On success, the destination table
--! @except Thrown if any parameter is nil
function Misc.cp_fields( what, from, to, deblank )
   if not what or not from or not to then
      error( ("what(%s), from(%s) or to(%s) are nil"):format(
            tostring(what), tostring( from), tostring(to)), 2 )
   end
   local value
   for _,item in ipairs( what ) do
      value = from[item]
      if not deblank or ( not ( type(value) == 'string' and value == '' )) then
         to[item] = value
      end
   end
   return to
end

function Misc.count_table_keys( t )
   local count = 0
   for _,_ in pairs( t ) do
      count = count + 1
   end
   return count
end

function Misc.table_sum( t )
   local sum = 0.0
   for _,val in ipairs( t ) do
      sum = sum + val
   end
   return sum
end

Misc.DIRS = {}
Misc.DIRS.TESS_BASE = "/tmp/tesseract"
Misc.DIRS.TESS_BAL_RECENTLY_BALANCED_NODES =
   Misc.DIRS.TESS_BASE.."/recently_balanced_nodes"

return Misc
