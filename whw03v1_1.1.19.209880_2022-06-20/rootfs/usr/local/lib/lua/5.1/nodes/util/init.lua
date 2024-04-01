--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

--! @file
--! @brief nodes utility module

module( ..., package.seeall )

local lfs      = require 'lfs'
local json     = require 'libhdkjsonlua'
local sysctx   = require('libsysctxlua')

local DEFAULT_MSG_TREE = "/tmp/msg"
local CONFIG_ME_SUBDIR = "CONFIG-ME"

local SC = nil
local function getSC()
   SC = SC or sysctx.new()
   return SC
end

--! @brief Check if a path refers to a directory.
--! @param path Path to check
--! @return true if a directory, false if not
function is_dir( path )
   local attr = lfs.attributes( path )
   return type( attr ) == "table" and attr.mode == "directory"
end


--! @brief printf-like function for reporting errors.
--! @param fmt Printf-style format string
--! Writes formatted results to stderr with an appended newline
function errout( fmt, ... )
   if fmt == nil then error( "Bad format: type '"..type(fmt).."'",2) end
   local ok, s = pcall( string.format, fmt .. "\n", ... )
   if not ok then error( s, 2 ) end
   io.stderr:write( s )
end

--! @brief printf-like function debugging output.
--! Looks for a global "opts" table containing a debug flag.  If set,
--! it outpus the message to stderr.  If not it doesn't.
--! @param fmt Printf-style format string
--! Writes formatted results to stderr with an appended newline
function debout( fmt, ... )
   if opts and opts.debug then
      local ok, result = pcall( errout, fmt, ... )
      if not ok then error( result, 2 ) end
   end
end

--! @brief printf-like function verbose output.
--! Looks for a global "opts" table containing a verbose flag.  If set,
--! it outpus the message to stderr.  If not it doesn't.
--! @param fmt Printf-style format string
--! Writes formatted results to stderr with an appended newline
function verbout( fmt, ... )
   if opts and opts.verbose then
      local ok, result = pcall( errout, fmt, ... )
      if not ok then error( result, 2 ) end
   end
end


--! @brief printf-like function that writes to system console.
--! Writes formatted results to console with an appended newline
--! @param fmt Printf-style format string
function consout( fmt, ... )
   local ok, s = pcall( string.format, fmt .. "\n", ... )
   if not ok then error( s, 2 ) end

   local f=io.open("/dev/console","w")
   if f then
      f:write( s )
      f:flush()
      f:close()
   end
end

--! @brief Make a list of unconfigured Nodes.
--! This is done by iterating over directories in the network
--! "configure me" directory.  For each unconfigured wired Node, there
--! should be a directory whose name is that Nodes' UUID.  Within
--! there is a status file containing the PIN & other goodies.
--! This code tries to be resilient of errors (e.g. directories that
--! aren't UUID dirs, malformed or unopenable status files).
--! @param opts Table containing command line options (e.g. degub,
--! verbose, base_dir).
--! @return Data is returned as an array of tables, each table
--! containing at least the pin and uuid.  If no items are found an
--! emtpy table is returned.
function get_unconfigured_wired_nodes( opts )
   opts = opts or {}
   local base_dir = opts.base_dir or DEFAULT_MSG_TREE
   local conf_me_dir = base_dir.."/"..CONFIG_ME_SUBDIR
   local list = {}
   for dir in lfs.dir( conf_me_dir ) do
      if dir ~= "." and dir ~= ".." then
         -- This should be the parent directory containing the status file
         local full_dir = conf_me_dir.."/"..dir
         if is_dir( full_dir ) then
            local status_file = full_dir.."/".."status"
            local file,err = io.open( status_file, "r" )
            if file then
               local raw_data = file:read("*all")
               local cooked_data, err = json.parse( raw_data )
               if cooked_data then
                  local status = cooked_data.data.status
                  if status == "unconfigured" then
                     list[#list+1] = {
                        uuid = cooked_data.uuid,
                        pin =  cooked_data.data.pin
                     }
                  end
               else
                  errout( "Error parsing JSON: %s", tostring( err ) )
               end
               file:close()
            else
               errout( "Error opening file: %s", err )
            end
         end
      end
   end
   return list
end


--! @brief Simple test function for get_unconfigured_wired_nodes().
--! Run this to report all known unconfigured wired Nodes to stdout.
--! An easy way to run this on a Nodes console is with this command
--!
--!       lua -e "require('nodes.util').test_get_unconfigured_wired_nodes()"
function test_get_unconfigured_wired_nodes()
   local list = get_unconfigured_wired_nodes()

   print( string.format( "Found %d unconfigured wired Nodes", #list ))
   for i,n in ipairs( list ) do
      print( string.format( "%d: uuid: %s, pin: %s", i, n.uuid, n.pin ))
   end
end


function get_device_by_mac( desired_mac )
   local result, err = nil, "Device not found " .. tostring( desired_mac )
   if desired_mac then
      desired_mac = string.upper( tostring( desired_mac ))
      local sc  = getSC()
      local tdb = require('libtopodblua').db(sc)
      if tdb:readLock() then
         local devs = tdb:getAllDevices()
         sc:rollback()
         if devs then
            for _,dev in ipairs( devs.devices ) do
               for _,mac in ipairs( dev.knownMACAddresses ) do
                  if string.upper(tostring(mac)) == desired_mac then
                     result,err = dev,nil
                     break
                  end
               end
            end
         else
            err = "No devices at all"
         end
      else
         err = "Error acquiring topodb read lock"
      end
   else
      result, err = nil, "get_device_by_mac: Missing mac parameter"
   end
   return result, err
end


function get_device_by_hostname( hostname )
   local dev, err = nil, nil
   if hostname then
      local sc  = getSC()
      local tdb = require('libtopodblua').db(sc)
      if tdb:readLock() then
         dev = tdb:getDeviceByAlias( hostname )
         sc:rollback()
         if dev == nil then
            err = "Device not found " .. tostring(hostname)
         end
      end
   else
      dev, err = nil, "get_device_by_hostname: Missing hostname parameter"
   end
   return dev, err
end


--! @brief Get the friendly from a device object.
--! @param hostname A Node hostname (e.g. alias)
--! @return On success, a string.  On fail a nil & error message
function get_friendly_name( hostname )
   local name, err
   if hostname then
      name = hostname

      local dev,err = get_device_by_hostname( hostname )
      if dev then
         -- Use friendlyname if present
         name = dev.friendlyName or name
         -- Now look for a user-provided name that overrides the default
         -- friendly name
         if dev.properties then
            for _,prop in ipairs( dev.properties ) do
               if prop.name == "userDeviceName" and prop.value ~= nil then
                  name = prop.value
                  break
               end
            end
         end
      else
         name = nil
      end
   end
   return name, err
end


--! @brief Load JSON data from file.
--! @param filename File name of payload file
--! @return On success: payload data as a table & nil
--!         On error:   nil, error message string
function json_file_to_table( filename )
   local jdata = nil
   local err   = nil
   local storage,err = io.open( filename, "r" )

   if storage then
      local raw_data = storage:read("*all")
      storage:close()
      jdata,err = json.parse( raw_data )
   else
      err = "Unable to open filename: " .. tostring( filename )
   end
   return jdata, err
end


--! @brief Remove any trailing slashes from a path.
--! For example, "/foo/bar/baz/" becomes "/foo/bar/baz"
--! @param path Filesystem path
--! @return Pruned path
function trim_trailing_slashes(path)
   while #path > 1 and path:sub(-1) == '/' do
      path = path:sub( 1, -2 )
   end
   return path
end


--! @brief Joins strings together with '/" between them.
--! Trailing /'s are removed from components and final path.
--! Examples:
--!  * join_dirs( 'a' )  ==> a
--!  * join_dirs( 'a', 'b' )  ==> 'a/b'
--!  * join_dirs( 'a/', 'b/c/d//' )  ==> 'a/b/c/d'
--! @param ... 1 or more filesystem path components
--! @return A single combined path
function join_dirs(...)
   local path = nil
   local PATH_SEP = "/"
   for _,component in ipairs{ ... } do
      if path then
         path = path..PATH_SEP..trim_trailing_slashes( component )
      else
         path = trim_trailing_slashes( component )
      end
   end
   return path or ""
end


--! @brief Lua version of Perl chomp function.
--! Removes trailing newline.  Inspired by Perl chomp.
--! @param s String to Chomp
--! @return Copy of same string with any trailing newline removed.
function chomp( s )
   return s:gsub( "\n$", "" )
end

--! @brief Convert ISO 8601 Combo format date/time string to seconds since epoch.
--! @param date_time Date & time in format like "2017-03-31T14:17:27Z"
--! @return Seconds since unix epoch
function utc_datetime_to_ostime( date_time )
   local FMT = '(%d+)-(%d+)-(%d+)T(%d%d):(%d%d):(%d%d)Z'
   local t = {}
   t.year, t.month, t.day, t.hour, t.min, t.sec = date_time:match( FMT )
   return os.time( t )
end


--! @brief Get this hosts' UUID.
--! @param sc Optional system context.  If provided, the UUID variable
--! is read via this context w/o locking. Otherwise a system context
--! is created and locked before access (and unlocked after).
--! @return Upper-case UUID as string
function get_our_uuid( sc )
   local uuid = nil
   function getuuid() return sc:get( 'device::uuid' ):upper() end
   if sc ~= nil then
      uuid = getuuid()
   else
      sc = getSC()
      sc:readlock()
      uuid = getuuid()
      sc:rollback()
   end
   return uuid
end

--! @brief Fetch syscfg value with optional locking
--! This function only locks system context if an optional flag is
--! provided.  It is thus safe to call within a locked context.
--! Note: this function uses its' own system context.
--! @param name Name (key) of syscfg variable to read
--! @param Optional lock flag.  If it evaluates to true then the
--! system context is locked before the variable is accessed and
--! unlocked after.
--! @return The value as a string
function syscfg_get( name, lockit )
   local SC = getSC()
   if not SC then error "Could not acquire system context" end
   local value = nil
   if lockit then
      SC:readlock()
      value = SC:get( name )
      SC:rollback()
   else
      value = SC:get( name )
   end
   return value
end


-- For debug mode.  Just dump out the data we harvested above
function diagnostic_dump( sys, names )
   local FMT = "%20s:  '%s'"
   for _,name in ipairs( names ) do
      print( FMT:format( name, tostring( sys[name] )))
   end
end

-- Helper function that confirms that the specified table has all the
-- specified fields.  Throws error is any are missing.
local function validate_fields( t, fields )
   for _,field in ipairs( fields) do
      if t[field] == nil then
         error( "Required parameter '"..field.." missing" )
      end
   end
end

--! @brief Ask a Slave Node to reconnect its' backhaul to a specific Node
--! @param uuid Node to effect
--! @param band Band to use.  Usually "5GH" or "5GL".
--! @param channel Which WI-Fi channel.  (Use `iwlist ath0 freq` to list them)
--! @param bssid The Node Wi-Fi MAC to the Slave should connect to
--! @return true if no error encountered sending message.
function steer_node_to_parent(opts)
   local fields = { "uuid", "band", "channel", "bssid" }
   validate_fields( opts, fields )
   -- for _,field in ipairs( fields ) do
   --    print( field, opts[field], type( opts[field] ))
   -- end
   local cmd = "pub_bh_config %s %s %s %s > /dev/null"
   return os.execute( cmd:format(
                         opts.uuid,
                         opts.band,
                         opts.channel,
                         opts.bssid ))
end

--! @brief Iterate over non "." nor ".." directories.
--! The following example will output only the names of directories in
--! /tmp and not files:
--!    for dir in dir_in( "/tmp" ) do print(dir) end
--! dir_in does this by wrapping lfs.dir and filtering out files and
--! directories named "." or ".."
--! @param path String containing path to examine
--! @return An iterator
function dirs_in(path)
   local lfs = require 'lfs'
   local state
   local function iter( state )
      local entry
      repeat
         entry = state.iter( state.invariant )
      until entry == nil or
            ( is_dir( path.."/"..entry ) and
            ( entry ~= "." and entry ~= ".." ))
      return entry
   end
   local it,y = lfs.dir( path )
   state = { iter=it, invariant=y }
   return iter, state
end


--! @brief Node model prefixes
NODE_MODELS = {
   "A0",         --!< Apple-branded Velop SR (A03)
   "Nodes",      --!< Early, pre-production Velops.
   "WHW",        --!< Original Velop (WHW03) and JR (WHW01).
   "VLP",        --!< Walmart specials (VLP01, VLP01B, etc)
}

--! @brief see if 1st string starts with 2nd
--! @param s1 String to look within
--! @param s2 string to look for
--! @return True if 1st string starts with 2nd (e.g. "ABCDE" starts
--! with "ABC").  False otherwise or if arguments are wrong type or
--! nil
function string_starts_with( s1, s2 )
   return s1 and type( s1 ) == 'string' and
          s2 and type( s2 ) == 'string' and
          s1:sub( 1, #s2 ) == s2
end


--! @brief Determine if string is a Nodes model
--! @param maybe A string that might be a Nodes model
--! @return True if it starts witha well-known Nodes model prefix,
--! false if not (or it is nil)
function is_node_model( maybe_node )
   local result = false
   if type( maybe_node ) == 'string' then
      for _, a_node_model in ipairs( NODE_MODELS ) do
         result = string_starts_with( maybe_node, a_node_model )
         if result then break end
      end
   end
   return result
end

--! Convert an RCPI value to RSSI.
--! RCPI is "Received Channel Power Indicator"
--! See specification 802.11k, section 15.4.8.5 for details
--! @param rcpi A floating point number
--! @return A float RSSI
function rcpi_to_rssi( rcpi )
   local result = 0.0

   rcpi = tonumber( rcpi )
   if type( rcpi ) ~= 'nil' then
      if rcpi <= 0.0 then
         result = -110.0
      elseif rcpi >= 220.0 then
         result = 0.0
      else
         result = rcpi / 2.0 - 110.0
      end
   end

   return result
end
