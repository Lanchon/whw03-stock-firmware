--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--
--! @file
--! @brief DeviceDB importer modes

module( ..., package.seeall )

Action_names = {
   bh           = "bh",
   devinfo      = "devinfo",
   migrate      = "migrate",
   offline      = "offline",
   wlan_subdev  = "wlan_subdev",
}

function opt_list()
   local opts = {}
   for k,v in pairs( Action_names ) do
      table.insert( opts, v )
   end
   return table.concat( opts, ", " )
end
