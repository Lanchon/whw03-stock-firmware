--
-- Copyright (c) 2016, Belkin Inc. All rights reserved.
--

module(...,package.seeall)

local cli = require "cliargs"

InfraArgs = {}

function InfraArgs:new(o)
   o = o or {}
   setmetatable(o,self)
   self.__index = self
   o.cli = cli
   return o
end

Entity = {}

function Entity:new(s,v)
   o = {}
   setmetatable(o,self)
   self.__index = self
   if s then
      if v then
         o:set( s..Entity.SEP..tostring(v))
      else
         o:set( s )
      end
   end
   return o
end

function Entity:set( s )
   self.raw_entity = s
end

function Entity:__tostring( e )
   return self.raw_entity
end

function Entity:to_json( e )
   if self.ary then
      return tostring( self )
   else
      local name, value = self:to_pair()
      if value == nil or value == '' or value == '""' then
         return string.format( '"%s": ""', name )
      else
         return string.format( '"%s": %s', name, value )
      end
   end
end

function Entity:to_pair()
   local name, value = string.match( self.raw_entity, "([%a%d%p]-)%s*"..Entity.SEP.."%s*(.*)" )
   if self.quoted and value ~= nil then
       value = '"'..value..'"'
   end
   return name,value
end

function Entity:with_quotes()
   self.quoted = true
   return self
end

function Entity:for_array()
   self.ary = true
   return self
end


InfraArgs.Entity = Entity

-- Parse command line options.
-- Returns a table or attribute/value pairs embodying the options
function InfraArgs:parse()
   local raw_entities = {}
   local DEFAULT_SEP = ":"
   Entity.SEP = DEFAULT_SEP
   function add( entity )
      raw_entities[#raw_entities+1] = entity
   end
   function add_raw( option, raw_entity )
      add( Entity:new(raw_entity))
   end
   function add_string( option, raw_entity )
      add( Entity:new(raw_entity):with_quotes() )
   end
   function add_array_item( option, raw_entity )
      add( Entity:new(raw_entity):for_array())
   end
   function set_sep( option, raw_sep )
      Entity.SEP = raw_sep
   end

   -- Set up command line options
   cli:set_name( string.match( arg[0], ".*/(.*)" ) )
   cli:option( "-a,--array-item=ITEM","Set item for use in array",      nil, add_array_item )
   cli:option( "-r,--raw=ENTITY",     "Set entity unquoted (name:val)", nil, add_raw    )
   cli:option( "-s,--set=ENTITY",     "Set entity quoted (name:val)",   nil, add_string )
   cli:option( "-S,--sep=SEP",        "Set seperator character",        DEFAULT_SEP, set_sep )
   cli:option( "-i,--indent=INDENT",  "Amount to indent entities",      indent_default  )
   cli:flag(   "-d,--debug",          "Show debugging output",          debug_default   )
   cli:flag(   "-h,--help",           "This help"                                       )

   local args, err = cli:parse()

   if not args and err then
      print( err )
      os.exit(1)
   else
      local opts = {
         debug = not not args.debug,
         verbose = not not args.verbose,
         indent  = tonumber( args.indent ),
         type = args.type,
         uuid = args.uuid and '"'..args.uuid..'"' or nil,
         raw_entities = raw_entities,
         sep = args.sep,
         args = args -- For custom handling
      }
      -- If debug is set, dump out the options now
      if opts.debug then
         print( cli.name .. " options:" )
         for k,v in pairs( opts ) do
            print( string.format( "%12s: (%s)", k, tostring( v )))
         end
      end
      return opts
   end
end


return InfraArgs
