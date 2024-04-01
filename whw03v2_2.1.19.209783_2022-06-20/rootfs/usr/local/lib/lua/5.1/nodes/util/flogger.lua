--
-- Copyright (c) 2018, Belkin Inc. All rights reserved.
--

--! @file
--! @brief nodes utility module

module( ..., package.seeall )

--! @brief log message using logger
--! This can be used in several ways:
--! - As a printf-style function: log( "Error code #%d", code )
--! - Using named parameters for more logger control:
--!     flog{ msg = "foo", stderr = true }
--!     Note these can be combined like so:
--!       flog({ stderr = true, msg = "%s is good with %s" }, "sake", "cheese" )
--! - ultra simply as:
--!     flog "some message"
--! @param opts.stderr If present and truthy, message also sent to stderr
--! @param tag Log message tag.  Unspecified, this defaults to current user
--! @param priority A number or facility.level pair
function flog( parms, ... )
   -- Wrap in protected call.  Having a logging function kill the
   -- client due to an internal error just seems so wrong and unfair
   local ok,err = pcall( function( parms, ...)
      if type( parms ) == 'string' then
         local msg = parms:format(...)
         os.execute( 'logger "'..msg..'"' )
      elseif type( parms ) == 'table' then
         if type( parms.msg ) == 'string' then
            local TEMPLT   = 'logger %s %s %s'
            local text     = parms.msg:format(...)
            local priority = parms.priority and '-p "'..parms.priority..'"' or ''
            local stderr   = parms.stderr   and '-s' --[[ No arg --]]       or ''
            local tag      = parms.tag      and '-t "'..parms.tag..'"'      or ''
            local cmd      = TEMPLT:format( stderr, tag, priority )
            --io.stderr:write( "flog executing cmd '"..cmd.."'\n" )
            local fh = io.popen( cmd, "w" )
            if io.type(fh) == 'file' then
               fh:write( text )
               fh:close()
            end
         end
      end
   end, parms, ... )
   if not ok then io.stderr:write( err..'\n' ) end
end
