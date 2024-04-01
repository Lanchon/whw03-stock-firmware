--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

module( ..., package.seeall )

--! @cond
local Klass = require 'nodes.util.klass'     --!< @private
local nutil = require 'nodes.util'           --!< @private
local MAC   = require('nodes.util.mac').Mac  --!< @private
local INTF  = require 'nodes.tess.interface' --!< @private
local errout = nutil.errout
local debout = nutil.debout
--! @endcond

Rebalancer = Klass()

-- require'helper'

function Rebalancer.show_list( list )
   for i, sub in pairs( list ) do
      local buff = {}
      for _,item in ipairs( sub ) do
         table.insert( buff, tostring( item ))
      end
      debout( "%3s(%d): %s", i, #sub, table.concat( buff, ", " ))
   end
end


function Rebalancer.analyze( list_of_lists )
   if type(list_of_lists) ~= 'table' then
      error( "analyze called with "..type(list_of_lists), 2 )
   end
   local low, high
   local count, list_count = 0,0
   for k, list in pairs( list_of_lists ) do
      low = low and math.min( low, #list ) or #list
      high = high and math.max( high, #list ) or #list
      count = count + #list
      list_count = list_count + 1
   end
   return low, high, count, list_count
end

function Rebalancer.needs_rebalancing( list_of_lists )
   local result = false
   local low, high, count, list_count = Rebalancer.analyze( list_of_lists )
   debout( "low: %s, high: %s, count: %s, lists: %s",
         tostring( low ), tostring( high ), tostring( count ), tostring( list_count ))
   if low and high then result = high - low >= 2 end
   return result
end

local function first_key( t )
   for k,_ in pairs( t ) do
      return k
   end
end

local function first_val( t )
   for _,v in pairs( t ) do
      return v
   end
end

local function first( t )
   for k,v in pairs( t ) do
      return k,v
   end
end

function Rebalancer.debalance( list_of_lists, fn, opts )
   local modified = true
   opts = opts or {}
   _fn = fn or function(n) end
   fn = function(n) _fn(n) ; return n end
   -- Determin which list to pile the rest on to
   local to, to_key
   if opts.pile_onto then
      to_key = opts.pile_onto
      to = list_of_lists[to_key]
      if to == nil then
         list_of_lists[to_key] = {}
         to = list_of_lists[to_key]
      end
   else
      to_key, to = first( list_of_lists )
   end
   if type( to ) ~= 'table' then
      error( ("Bad 'to' (type: %s) = '%s'"):format( type(to), tostring(to)))
   end
   if to then
      -- Now copy all items from any non "to" list to "to"
      for k, list in pairs( list_of_lists ) do
         if k ~= to_key then
            while #list > 0 do
               table.insert( to, fn( table.remove( list )))
            end
         end
      end
   else
      error( "Couldn't determine item to fill" )
   end
   return list_of_lists, modified
end

function previously_manipulated( uuid )
   local status = false
   local lfs = require 'lfs'
   local misc = require'nodes.tess.misc'

   for fname in lfs.dir( misc.DIRS.TESS_BAL_RECENTLY_BALANCED_NODES  ) do
      if fname ~= '.' and fname ~= '..' then
         debout( "Checking directory entry '%s' against uuid '%s'", fname, uuid )
         if fname == uuid then
            debout( "Match found: '%s' was previously manipulated", uuid )
            status = true
            break
         else
            debout( "prev/manip check: '%s' ~= '%s'", fname, uuid )
         end
      end
   end
   return status
end

-- Remove & return Node from list if it has been neither previously
-- balanced nor steered
-- @param list Array of Nodes
-- @return A Node if there was a candidate or nil
function remove_candidate( list )
   local removed = nil

   for i,node in ipairs(list) do
      debout( "Checking if node '%s' has been previously manipulated:", node.uuid )
      if not previously_manipulated( node.uuid ) then
         debout "   it hasn't been; removing from list"
         removed = table.remove( list, i )
         break
      else
         debout "  ... it has"
      end
   end

   return removed
end

function Rebalancer.rebalance( list_of_lists, fn )
   if list_of_lists == nil then error( "Rebalancer.rebalance: NIL list", 2 ) end
   local temp = {}
   local modified = false
   _fn = fn or function(n) end
   fn = function(n) _fn(n) ; return n end
   -- First pass analyzes the lists
   local low, high, count, list_count = Rebalancer.analyze( list_of_lists )
   local mean = math.ceil( count / list_count )

   -- We should exclude some trivial cases here, including:
   -- - No items
   -- - Little or no differences

   -- Second pass culls excess items any too-full lists
   -- But only if they've never been balanced or steered before
   debout "Initial lists:"
   Rebalancer.show_list( list_of_lists )
   for k, list in pairs( list_of_lists ) do
      for i = mean + 1,#list do
         debout( "Removing an item from %s", k )
         local item = remove_candidate( list )
         if item then
            fn( item )
            table.insert( temp, item )
         else
            debout "No more valid candidates to manipulate"
            break
         end
      end
   end

   if #temp > 0 then
      -- While it shouldn't happen if the earlier trivial rejectors
      -- are working, we might take this opportunity to stop if the
      -- temp list is empty
      -- for _, item in ipairs( temp ) do
      --    if type( item ) == 'table' then item.moved = true end
      -- end
      debout "\nIntermediate lists:"
      Rebalancer.show_list( list_of_lists )
      -- Third pass redistributes culled items to small lists
      for level=low,high do
         debout( "Level: %d", level )
         if #temp == 0 then break end
         for k, list in pairs( list_of_lists ) do
            if #list <= level then
               debout( "Adding item to '%s'", k )
               table.insert( list, table.remove( temp ) )
               modified = true
            end
            if #temp == 0 then break end
         end
      end
      debout "\nFinal lists"
      Rebalancer.show_list( list_of_lists )
   else
      debout( "Done early; no culled items" )
   end
   return list_of_lists, modified
end

return Rebalancer
