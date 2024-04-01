--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

JSON = require 'libhdkjsonlua'
nutil    = require 'nodes.util'

module(...,package.seeall)

local Klass = require 'nodes.util.klass'
local nutil = require 'nodes.util'

local debout  = nutil.debout
local verbout = nutil.verbout
local errout  = nutil.errout

local PATH_SPLIT_PAT = "(.*)/(.*)"
Atomizer = Klass{}

function Atomizer.dirname( path )
   local dir
   -- If there are no "/" characters then assume the directory is "."
   if path:find( "/" ) == nil then
      dir = "."
   else
      dir = path:gsub( PATH_SPLIT_PAT, "%1")
   end
   return dir
end

function Atomizer.basename( path )
   local name
   -- If there are no "/" characters then assume the path is a filename
   if path:find( "/" ) == nil then
      name = path
   else
      name = path:gsub( PATH_SPLIT_PAT, "%2")
   end
   return name
end


function Atomizer:new( path )
   o = { staging_dir = self.dirname( path ), fname = self.basename( path )}
   return setmetatable( o, self )
end

function Atomizer:read()
   -- If file doesn't exist, create & lock it.
   local ok = false
   local path = nutil.join_dirs( self.staging_dir, self.fname )
   local fhandle, err = io.open( path, "r" )
   if fhandle then
      self.fhandle = fhandle
      return fhandle:read( "*all" )
   end
   error( err )
end

function Atomizer.mktempfile( dir, name )
   -- Attempt to create temporary file
   local cmdh = io.popen( ("mktemp -p %s %sXXXXXX"):format( dir, name ))
   local tmpfilename = cmdh:read()
   cmdh:close()
   if tmpfilename == nil or tmpfilename == "" then
      error( "Could not create temp file '"..tostring(name).."'", 2 )
   end
   return tmpfilename
end

function Atomizer:write_via_tmp_file( payload )
   local tmpfilepath = self.mktempfile( self.staging_dir, self.fname )
   if tmpfilepath then
      local tmpfh, err = io.open( tmpfilepath, "w+" )
      if tmpfh then
         tmpfh:write( payload )
         tmpfh:close()
         debout( "payload '%s' written to '%s'", payload, tmpfilepath )
         local to_path = nutil.join_dirs( self.staging_dir, self.fname )
         local ok, err = os.rename( tmpfilepath, to_path )
         if not ok then
            error( ("Failed to rename '%s' --> '%s': %s"):format(
                  tostring( tmpfilepath ), tostring( to_path ), err ))
         end
      else
         error( "Could not open '"..tostring( tmpfilename ).."'" )
      end
   else
      error( ("mktempfile( '%s', '%s' ) returned nil"):format(
            tostring( self.staging_dir ) , tostring( self.fname )))
   end
end

return Atomizer
