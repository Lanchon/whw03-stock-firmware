--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

--! @file
--! @brief Link class for tesseract subsystem

module( ..., package.seeall )

--! @cond
local Klass = require 'nodes.util.klass'     --!< @private
local INTF  = require "nodes.tess.interface"
local EP    = require "nodes.tess.endpoint"
local NU    = require 'nodes.util'
local debout = NU.debout
local errout = NU.errout
--! @endcond

--! @class Link
--! Class representing a link between 2 Interfaces.
--! Wireless devices will have 2 endpoints.  Wired devices only 1.
local Link = Klass{
   ERROR = {
      MISSING_OR_NIL_ARGUMENT = "Link: Missing or nil argument",
      MISSING_TO_ENDPOINT     = "Link: Constructor missing 'to' endpoint",
      MISSING_FROM_ENDPOINT   = "Link: Constructor missing 'from' endpoint",
      WRONG_NUM_ENDPOINTS     = "Link: Wrong # of endpoints (must be >= 1)",
      BAD_INTF_TYPE           = "Link: Bad interface type",
   },
   UNSET = "<unset>",
   __eq = function( a, b )
      return a and b and
         a.from == b.from and
         a.to   == b.to   and
         a.type == b.type
   end,
}

--! @fn Link::__tostring
--! @brief tostring operator
--! @return A string representation of the operator suitable for human viewing.
function Link.__tostring( e )
   local from = e.from or Link.UNSET
   local to = e.to or Link.UNSET
   return ("[from='%s',to='%s (%s)']"):format(
      tostring( from ),
      tostring( to ),
      e.active and "up" or "down" )
end

function Link.fail(msg)
   error( msg, 3 )
end

--! @fn Link::merge
--! @brief Merge 2 links creating a new one.  Values in l1 will
--! override those in l2 if present.
--! @param l1 First link to merge
--! @param l2 Second link to merge
--! @param A new link.
function Link.merge( l1, l2 )
   local from_ep = EP:new{
      device    = l1.from.device    or l2.from.device,
      interface = l1.from.interface or l2.from.interface
   }
   local to_ep = EP:new{
      device    = l1.to.device    or l2.to.device,
      interface = l1.to.interface or l2.to.interface
   }
   local body = {
      from   = from_ep,
      to     = to_ep
   }
   -- For debug only
   body._origin = "Link:merge"
   for k,v in pairs( l1 ) do
      body[k] = body[k] or v
   end
   for k,v in pairs( l2 ) do
      body[k] = body[k] or v
   end
   return Link:new( body )
end

--! @fn Link::new
--! @brief Link constructor.
--! One of "from" or "to" are required.
--! @param o.from Optional "from" Endpoint object
--! @param o.to Optional "to" Endpoint
function Link:new(o)
   local ERR = Link.ERROR
   local fail = Link.fail
   if not o
      or not o.type
      or o.active == nil then fail( ERR.MISSING_OR_NIL_ARGUMENT ) end
   if not o.from                  then fail( ERR.MISSING_FROM_ENDPOINT ) end
   if not o.to and o.type ~= INTF.TYPE.WIRED then
      fail( ERR.MISSING_TO_ENDPOINT )
   end
   if not INTF.TYPE_NAMES[o.type] then fail( ERR.BAD_INTF_TYPE ) end
   return setmetatable( o, self )
end


function Link:get_node_endpoints( net )
   local ep1, ep2 = nil, nil
   local master = net:get_master()
   if self.from and self.to and self.from.device and self.to.device then
      local child_node = net.nodes[self.from.device]
      if child_node then
         local parent_node
         if self.to.device == master.uuid then
            parent_node = master
         else
            parent_node = net.nodes[self.to.device]
         end
         if parent_node then
            ep1, ep2 = parent_node, child_node
         end
      end
   end
   return ep1, ep2
end



return Link
