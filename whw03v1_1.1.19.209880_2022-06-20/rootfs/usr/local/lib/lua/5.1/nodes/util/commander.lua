-- -*- lua -*-
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

module( ..., package.seeall )

--! @cond
local NU    = require 'nodes.util'       --!< @private
local Klass = require 'nodes.util.klass' --!< @private
local debout = NU.debout                 --!< @private
local errout = NU.errout                 --!< @private
--! @endcond

local Command = Klass{
   new = function(self,o)
      if o == nil or o.cmd == nil then error( "Missing param", 2 ) end
      return setmetatable( o, self )
   end,
   render_args = function( self )
      return "<abstract render_args>"
      -- error( "render_args: Unimplemented abstract method", 2 )
   end,
   __tostring = function( self )
      return self.cmd.." "..self:render_args()
   end,
   run = function( self )
      return os.execute( self.cmd.." "..self:render_args())
   end,
}

pub_bh_config = Command:new{
   new = function( self, o )
      if o == nil then error( "Missing param", 2 ) end
      o.cmd = o.cmd or "pub_bh_config"
      return setmetatable( o, self )
   end,
   __tostring = Command.__tostring,
   __index = {
      run = Command.run,
      render_args = function(self)
         local PBH_FMT = "%s %s %s %s"
         return PBH_FMT:format( self.uuid,
                                self.band,
                                self.channel or "auto",
                                self.mac )
      end,
   }
}

-- Test command object
echo = Command:new{
   new = function( self, o )
      o.cmd = "echo"
      return setmetatable( o, self )
   end,
   __tostring = Command.__tostring,
   __index = {
      run = Command.run,
      render_args = function(self)
         return self.msg or 'nothing'
      end,
   }
}

local Commander = Klass{
   Command = Command,
   pub_bh_config = pub_bh_config,
   echo = echo
}

return Commander
