--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--
--
--! @file
--! @brief Network optimizer module for tesseract subsystem

module( ..., package.seeall )

--! @cond
local Klass = require 'nodes.util.klass' --!< @private
local nutil = require 'nodes.util'       --!< @private
local Commander = require'nodes.util.commander'
local Node  = require 'nodes.tess.node'  --!< @private
local errout = nutil.errout
local debout = nutil.debout
local Intf = require'nodes.tess.interface'
local Rebalancer = require'nodes.tess.rebalance'
--! @endcond

--! @class Optimizer
--! Networkoptimizer class.
Optimizer = Klass{
   ERROR = {
      MISSING_OR_NIL_ARGUMENT = "Optimizer: Missing or nil argument",
      MISSING_NET_ARG         = "Optimizer: Missing network parameter",
      WRONG_ARGUMENT_COUNT    = "Optimizer: Wrong argument count",
      BAD_NODE_MODE           = "Optimizer: Bad Node mode",
   },
}

--! @fn Optimizer##new(o)
--! @memberof Optimizer
--! Optimizer constructor
function Optimizer:new(net)
   if not net then error( self.ERROR.MISSING_NET_ARG, 2 ) end
   local o = {
      net = net,
      low = math.huge,
      high = -1
   }
   return setmetatable( o, self )
end

-- Make list of Slave Nodes that are directly connected to Master
function Optimizer:gather_subsidiary_nodes()
   if not self then error( "self is NIL", 2 ) end
   local found = {}
   for id, node in pairs( self.net.nodes ) do
      if node.mode == 'slave' then
         local act = node:active_link()
         if act and act.type == 'WIRELESS' then
            local parent = self.net:find_node_by{ uuid = act.to.device }
            if parent and parent:is_master() then
               table.insert( found, node )
            end
         end
      end
   end
   return found
end

function Optimizer:analyze()
   if not self then error( "self is NIL", 2 ) end -- Do not be selfless
   local result = false

   -- Gather list of all subsidiary nodes actively wirelessly connected to Master
   local subs = self:gather_subsidiary_nodes()
   debout( "%d candidate node(s) detected", #subs )

   self.subs_by_intf = {}
   if #subs >= 2 then
      local master = self.net:get_master()
      for k,band_name in pairs( Intf.WIFI_BANDS ) do
         self.subs_by_intf[band_name] = {}
      end
      for _, sub in ipairs( subs ) do
         local act_link = sub:active_link()
         debout( "act_link: %s", tostring( act_link ))
         local master_intf = master:find_intf_by_mac( act_link.to.interface )
         -- If this Slave is using another Slave as its' back-haul,
         -- then master_intf will be nil.
         if master_intf then
            local intf_name = master_intf.band
            if intf_name then
               self.subs_by_intf[intf_name] = self.subs_by_intf[intf_name] or {}
               table.insert( self.subs_by_intf[intf_name], sub )
            else
               io.stderr:write( "NOTE: Master interface has no name.\n" )
            end
         else
            debout( "Master interface not found for '%s'", act_link.to.interface )
         end
      end
      debout "Per-band Counts:"
      for k,v in pairs( self.subs_by_intf ) do
         debout( "  %s: %d", k, #v )
         self.low = math.min( self.low, #v )
         self.high = math.max( self.high, #v )
      end
      self.variance = math.abs( self.high - self.low )
      debout "\nSummary:"
      debout( "  low:      %d\n  high:     %d\n  Variance: %d", self.low, self.high, self.variance )
      if self.variance > 1 then
         debout "Balancing is Recommended."
         result = true
      else
         debout "Network is balanced."
         result = false
      end
   else
      debout( "Nothing to do with only %d Wi-Fi slave-nodes", #subs )
   end

   return result
end

function Optimizer:balance(opts)
   opts = opts or {}
   local updates, result
   function fn(s) s.moved = true end -- Mark moved subs
   if opts.debalance then
      updates, result = Rebalancer.debalance( self.subs_by_intf, fn, opts )
   else
      updates, result = Rebalancer.rebalance( self.subs_by_intf, fn )
   end
   debout "Rebalancer updates list:"
   Rebalancer.show_list( updates )
   return result, updates
end

function Optimizer:act_on( updates )
   function steer_node_cmd( uuid, band, mac )
      return ("pub_bh_config %s %s auto %s"):format( uuid, band, mac )
   end
   -- First, make a list of bands & matching Master MACs
   local band_macs = {}
   local m = self.net:get_master()
   local to_be_updated = {}
   -- Harvest Master band macs
   for band,_ in pairs( updates ) do
      band_macs[band] = m:find_intf_for_band( band ).mac
   end
   -- debout "Bands/macs:"
   -- for k,v in pairs( band_macs ) do
   --    print( k,v )
   -- end
   -- Generate steering command for each moved node
   local steerage = {}
   for band,list in pairs( updates ) do
      for i, node in ipairs( list ) do
         if node.moved then
            table.insert( steerage,
                          Commander.pub_bh_config:new{ uuid = node.uuid,
                                                       band = band,
                                                       mac = band_macs[band]})
            table.insert( to_be_updated, node )
         end
      end
   end
   return steerage, to_be_updated
end

return Optimizer
