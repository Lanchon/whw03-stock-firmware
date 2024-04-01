--
-- Copyright (c) 2018, Belkin Inc. All rights reserved.
--

module( ..., package.seeall )

local nutil    = require 'nodes.util'
local json     = require 'libhdkjsonlua'

debout = nutil.debout

local MSG_DIR="/tmp/msg"
local BH_DIR=MSG_DIR.."/BH"

ERROR = {
   MISSING_OMSG_CACHE_DATA = "Missing omsg cache data",
   COULDNT_ACQUIRE_DEVICEDB_LOCK = "Couldn't acquire DeviceDB lock",
   BAD_ARGUMENT = "bad argument"
}

STATE = {
   UNKNOWN      = "unknown",
   CONNECTED    = "connected",
   DISCONNECTED = "disconnected",
   NOT_SLAVE    = "not_slave"
}

function node_is_master( uuid )
   local ddb = require('libdevdblua').db()
   local result = false
   if type(uuid) == 'string' then
      if ddb:readLock() then
         local ok, infra = pcall( ddb.getInfrastructure, ddb, uuid )
         ddb:readUnlock()
         if not ok then error( dev ) end
         result = infra and infra.infrastructureType == 'master'
      else
         error( STATE.COULDNT_ACQUIRE_DEVICEDB_LOCK)
      end
      nutil.debout( ("Device '%s' %s master"):format(
            uuid,
            ( result and "is" or "isn't" )
      ))
      return result, infra
   else
      error( STATE.BAD_ARGUMENT )
   end
end

function node_is_known( uuid )
   local ddb = require('libdevdblua').db()
   local result = false
   if type(uuid) == 'string' then
      if ddb:readLock() then
         local ok, dev = pcall( ddb.getDevice, ddb, uuid )
         ddb:readUnlock()
         if not ok then error( dev ) end
         result = dev ~= nil
      else
         error "Couldn't acquire DeviceDB lock"
      end
      return result
   else
      error( "Bad uuid argument ("..tostring(uuid)")" )
   end
end

function get_bh_report()
   local fh = io.popen( "bh_report -j", "r" )
   if fh then
      local raw = fh:read "*all"
      report = json.parse( raw )
      fh:close()
      return report.bh_report,raw
   else
      error "Couldn't run bh_report"
   end
end

function get_bh_report_dev( uuid )
   local result = nil
   if type( uuid ) == 'string' then
      uuid = string.upper( uuid )
      for _, item in ipairs( get_bh_report()) do
         if string.upper( item.uuid ) == uuid then
            result = item
            break
         end
      end
   end
   return result
end

local function _backhaul_status( uuid )
   if type( uuid ) ~= 'string' or uuid == "" then
      error "Bad or missing UUID argument"
   end
   local result = { uuid = uuid }
   if node_is_known( uuid ) then
      if node_is_master( uuid ) then
         result.state = STATE.NOT_SLAVE
      else
         local bh_item = get_bh_report_dev( uuid )
         if bh_item and bh_item.state == "up" then
            result.state = STATE.CONNECTED
            local bh_dev_dir = nutil.join_dirs( BH_DIR, uuid )
            local stat_file_path = nutil.join_dirs( bh_dev_dir, "status" )
            local stat_timestamp = lfs.attributes( stat_file_path, "modification" )
            local perf_file_path = stat_file_path..".performance"
            local perf_timestamp = lfs.attributes( perf_file_path, "modification" )

            -- If performance data is present and newer than status then
            -- load it and include speed
            -- debout( "stat_timestamp(%s): %d, perf_timestamp(%s): %d",
            --         tostring( stat_file_path ), tonumber( stat_timestamp ),
            --         tostring( perf_file_path ), tonumber( perf_timestamp ) )
            if stat_timestamp and perf_timestamp and stat_timestamp <= perf_timestamp then
               debout "Fresh performance data detected"
               local json,err = nutil.json_file_to_table( perf_file_path )
               if json and json.data.rate then
                  result.speed = json.data.rate
               end
            end
         else
            result.state = STATE.DISCONNECTED
         end
      end
   else
      result.state = STATE.UNKNOWN
   end
   return result
end

function backhaul_status( uuid )
   return pcall( _backhaul_status, uuid )
end
