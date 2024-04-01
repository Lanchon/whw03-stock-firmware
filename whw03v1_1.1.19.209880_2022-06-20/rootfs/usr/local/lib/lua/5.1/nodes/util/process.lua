--
-- Copyright (c) 2019, Belkin Inc. All rights reserved.
--

--! @file
--! @brief Process control module

module( ..., package.seeall )

--! @brief Return process ID of current process
--! Probably only works on Linux
--! @return This process ID as a number
function mypid()
   return tonumber( io.open("/proc/self/stat"):read("*l"):match("%d+"))
end

--! @brief Pause execution of current process for specified time (in seconds)
--! @param time Sleep time in seconds
function sleep( time )
   if time then
      os.execute( "sleep "..tostring(time))
   else
      error( "Missing time", 2 )
   end
end

--! @brief Schedule termination of this process
--! @param time Delay in seconds before this process is killed
function killme( time )
   local FMT = "sleep %d && kill %d 2>/dev/null&"
   if time then
      os.execute( FMT:format( time, mypid() ))
   else
      error( "Missing time", 2 )
   end
end
