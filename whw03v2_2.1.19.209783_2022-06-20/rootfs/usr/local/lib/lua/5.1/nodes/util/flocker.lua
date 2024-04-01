--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

--- @file
--- @brief Flocker - File lock operations

module( ..., package.seeall )

local lfs = require'lfs'
local Klass = require 'nodes.util.klass'
local nutil = require 'nodes.util'

local debout  = nutil.debout
local verbout = nutil.verbout
local errout  = nutil.errout

--- @class
--- @brief Flocker class encapsulates the path to the lock file and
--- modes used to opening and locking it.
Flocker = Klass {
   lock_mode = "w",
   -- "a+" seems the best balance between non-destructive and create
   -- if not present
   lock_file_mode = "a+",
}

--- @constructor
--- Flocker#new Construct a Flocker object.  Requires a lock file name.
--- @param opts a table containing constructor parameter.  Forms basis
--- of eventual Flocker object.  { lock_file } must be path to lock
--- file.
function Flocker:new( o )
   if o == nil or o.lock_file == nil then
      error( "Flocker:new( nil ) - need lock file name", 2 )
   end
   setmetatable( o, self )
   local err
   o.lock_file_handle, err = io.open( o.lock_file, o.lock_file_mode )
   if not o.lock_file_handle then
      error( ("Couldn't open lock file '%s' (mode: %s): %s"):format(
            tostring( o.lock_file ),
            tostring( o.lock_mode ),
            tostring( o.lock_file_mode )), 2)
   end
   return o
end

--- @brief Close lock file
function Flocker:close()
   if self.lock_file_handle then
      self.lock_file_handle:close()
   end
end

--- @Attempt to lock file.
--- @return On success, true.  On fail, nil and a message giving
--- reason why lock didn't take.
function Flocker:lock()
   local locked, msg = lfs.lock( self.lock_file_handle, self.lock_mode )
   debout( "locked: %s, msg: %s", tostring(locked), tostring(msg) )
   return locked, msg
end

--- @brief Lock with timeout
--- Waits timeout seconds.
--- @return on success, returns true, nil, # of seconds waited.  On
--- fail returns false, reason for fail and # of seconds waited.
function Flocker:wait_for_lock( timeout )
   timeout = timeout or math.huge
   local locked, msg = false, ""
   local time_waited = 0
   while (not locked) and (time_waited < timeout) do
      locked, msg = self:lock()
      if not locked then
         debout( "Waiting (%s)", tostring(msg))
         os.execute 'sleep 1'
         time_waited = time_waited + 1
      end
   end
   return locked, msg, time_waited
end

--- @brief Unlock locked file
function Flocker:unlock()
   return lfs.unlock( self.lock_file_handle )
end

return Flocker
