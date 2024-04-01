--
-- Copyright (c) 2017, Belkin Inc. All rights reserved.
--

JSON  = require 'libhdkjsonlua'
ATOM  = require 'nodes.util.atomizer'
nutil = require 'nodes.util'
opts = opts

module(...,package.seeall)

debout  = nutil.debout
verbout = nutil.verbout
errout  = nutil.errout

function load_syscfg_list( infile )
   local syscfgs = {}
   for line in infile:lines() do
      table.insert( syscfgs, line )
   end
   return syscfgs
end

function parse_args( prog_name )
   if prog_name == nil then error "Missing prog_name" end
   -- Set up command line options
   cli:set_name( prog_name )
   cli:set_description( 'Add syscfg variable names to backup list' )
   cli:flag(   "-d,--debug",        "Show debugging output", false                     )
   cli:flag(   "-v,--verbose",      "Be verbose",            false                     )
   cli:flag(   "-h,--help",         "This help"                                        )
   cli:flag(   "-t,--test", "Test mode; delay holding lock", false                     )
   cli:option( "-m,--master=FILE",  "Master file"                                      )
   cli:option( "-s,--syscfgs=FILE", "Path to syscfg list"                              )
   cli:argument( 'backup', 'path to backup file' )
   local args, err = cli:parse()

   if not args and err then
      print( err )
      os.exit(1)
   else
      if args.backup == nil then
         errout( "Need backup file\n" )
         cli:print_help()
         os.exit( 1 )
      end
      local opts = {
         backup  = args.backup,
         debug   = not not args.debug,
         master  = args.master,
         syscfgs = args.syscfgs or io.stdin,
         test    = not not args.test,
         verbose = not not args.verbose,
      }
      if opts.syscfgs == nil then
         errout( "Must specify syscfg file" )
         cli:print_help()
         os.exit( 1 )
      elseif type( opts.syscfgs ) == 'string' then
         local storage,err = io.open( opts.syscfgs, "r" )
         if not storage then
            error( "Error opening '"..opts.syscfgs.."':"..err )
         end
         opts.syscfgs = storage
      else
         error( "Invalid syscfg source '"..tostring(opts.syscfgs).."'" )
      end
      -- If debug is set, dump out the options now
      if opts.debug then
         debout( cli.name .. " options:" )
         for k,v in pairs( opts ) do
            debout( string.format( "%12s: (%s)", k, tostring( v )))
         end
      end
      return opts
   end
end

function load_syscfg_map( filename )
   local syscfg_map, err = nil, nil
   if filename then
      syscfg_map, err = nutil.json_file_to_table( filename )
   end
   return syscfg_map
end

function load_backup_file( bfname )
   return nutil.json_file_to_table( bfname ) or {}
end

function find_syscfg( map, new_syscfg )
   local found_section_name
   if map then
      for section_name,section in pairs( map ) do
         if section.syscfg then
            for _,varname in ipairs( section.syscfg ) do
               if varname == new_syscfg then
                  found_section_name = section_name
                  break
               end
            end
         end
      end
   else
      debout( "No map to search" )
   end
   return found_section_name
end

function array_has_item( t, item )
   local result = false
   if t then
      for _,current in ipairs( t ) do
         if current == item then
            result = true
            break
         end
      end
   end
   return result
end

function inject_syscfg( args )
   local map = args.map
   local backup = args.backup or {}
   local new_syscfg = args.syscfg
   local injected = false

   if new_syscfg == nil then
      error( "inject_syscfg called w/nil syscfg name", 2 )
   end
   local section_name = find_syscfg( map, new_syscfg ) or "auto"
   debout( "Using section '%s' name for '%s'", section_name, new_syscfg )
   local events = map and map[section_name] and map[section_name].sysevent
   backup[section_name] = backup[section_name] or {}
   local section = backup[section_name]
   if array_has_item( section.syscfg, new_syscfg ) == false then
      section.syscfg = section.syscfg or {}
      table.insert( section.syscfg, new_syscfg )
      if section.sysevent == nil then
         section.sysevent = events
      end
      if opts and opts.verbose and events then
         local event_names = {}
         for _, event in ipairs( events ) do
            for k,v in pairs( event ) do
               table.insert( event_names, k )
            end
         end
         event_names = table.concat( event_names, ", " )
         verbout( "Injected '%s' (events:%s)", new_syscfg, event_names )
      end
      injected = true
   end
   return injected
end


function inject( args )
   local map = args.map
   local backup = args.backup or {}
   local new_syscfg = args.syscfg
   local injected = false
   local new_syscfg_type = type( new_syscfg )

   if new_syscfg_type == 'nil' then
      error( 'Missing new syscfg', 2 )
   elseif new_syscfg_type == 'string' then
      injected = inject_syscfg( args )
   elseif new_syscfg_type == 'table' then
      for _,syscfg in ipairs( new_syscfg ) do
         debout( "Attempting to inject '%s'", tostring( syscfg ))
         local item_injected = inject_syscfg{ map = map,
                                              backup = backup,
                                              syscfg = syscfg }
         injected = injected or item_injected
      end
   else
      error( "Unsupported type for new syscfg: '"..new_syscfg_type.."'", 2 )
   end
   return injected
end

function write_backup_file( fname, json )
   local json_string = JSON.stringify( json )
   local atomsk = ATOM:new( fname )
   debout( "Want to write '%s' to file '%s'", json_string, fname )
   atomsk:write_via_tmp_file( json_string )
end
