--- The publisher module. This module is for executing publish commands.
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local jsonM        = require ( "libhdkjsonlua" )
local lfsM         = require ( "lfs" )
local utilM        = require ( "nodes.topology.util" )

local M = {}

--- Publish topic with payload.
-- @param raw The string in json format. Requires the keys "topic" and "payload".
-- @return Returns published output or error information.
function M.publish( raw )
    -- Generate publish command.
    local function publish_cmd( topic, payload )
        return ("omsg-publish \"%s\" -m \"%s\""):format( topic, payload )
    end
    
    -- Parse the required data for publish command.
    local json_data_table,error_code = jsonM.parse( raw )
    if json_data_table then
        local topic, payload = nil, nil
        
        if json_data_table.topic     then topic    = json_data_table.topic     end
        if json_data_table.payload   then payload  = json_data_table.payload   end
        
        -- Issue publish command.
        if topic and payload then
            local command_call = publish_cmd( topic, payload )
            utilM.debug_print( "command_call: "..command_call )
            return utilM.execute( command_call )
        else
            error( "Missing parameters! Please include topic and payload." )
        end
    else
        error( error_code )
    end
end

return M