--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

--! @file Network object comparison & scoring operations
module( ..., package.seeall )

--! @brief Provide equality and score features for Network class.
--! This is broken out into a seperate module for easier multi-party
--! development.

-- Import & cache references to some functions from misc
local MISC  = require "nodes.tess.misc"
local count_table_keys = MISC.count_table_keys
local table_sum = MISC.table_sum

-- The module object
NetOps = {}

-- Experimental scoring function.  It is probably inadequate but
-- provides enough functionality to allow unit tests to succeed.
-- This module gets loaded by and incorporated into Network.

-- @fn score
-- @brief Generate a numeric score for the current network.  Better
-- connectivity translates to a higher score.  This is used to compare
-- the desirability of different topologies.
--! @return a number
function NetOps:score()
   local score = 0.0
   local values = {}
   local INTF  = require "nodes.tess.interface"
   for _,link in ipairs( self.links ) do
      if link.active then
         if link.type == INTF.TYPE.WIRELESS
            and link.rssi ~= nil then
               table.insert( values, math.abs( link.rssi ))
         end
      end
   end
   -- Now take average of calculated link scores
   score = table_sum( values ) / #values
   return score
end

--! @fn
--! @brief This becomes the equality operator for Networks.  It is
--! used to evaluate topological similarity, as opposed to performance
--! or desirability.  An example use is to see if a current topology
--! matches a proposed one.
--! Note that this will normally be used via the quality ("==")
--! operator rather than called explicitly.  For example, if one has
--! two network objects "proposed" and "current", simply do this:
--!     if propsed == current then ...
--! Also see unit-tests/network-comp-ops_spec.lua.
--! @param a The first network to compare
--! @param the second network to compare
--! @return Boolean equality
function NetOps.eq( a, b )
   return a and b and
      count_table_keys( a.nodes ) == count_table_keys( b.nodes )
end

return NetOps
