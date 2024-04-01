--- The steerer module. This module is for executing steering commands.
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local jsonM        = require( "libhdkjsonlua" )
local lfsM         = require( "lfs" )
local utilM        = require( "nodes.topology.util" )
local wlanM        = require( "nodes.topology.wlan" )
local devinfoM     = require( "nodes.topology.devinfo" )

local M = {}

--- Change the nodes parent ( the backhaul ).
-- @param raw The string in json format. Requires the keys "uuid", "band", "channel", and "bssid" ( band is optional ).
-- @return Returns published output or error information.
function M.change_node_parent( raw )
    -- Generate the node steer commmand.
    local function steer_node_cmd( uuid, band, channel, bssid )
        if not channel then channel = "auto" end
        return ("pub_bh_config %s %s %s %s"):format( uuid, band, channel, bssid )
    end
    
    -- Parse the required data for node steering.
    local json_data_table,error_code = jsonM.parse( raw )
    if json_data_table then
        local uuid, band, channel, bssid = nil, nil, nil, nil
        
        if json_data_table.uuid    then uuid    = json_data_table.uuid    end
        if json_data_table.band    then band    = json_data_table.band    end
        if json_data_table.channel then channel = json_data_table.channel end
        if json_data_table.bssid   then bssid   = json_data_table.bssid   end
        
        -- Issue node steering command.
        if uuid and band and bssid then
            local command_call = steer_node_cmd( uuid, band, channel, bssid )
            utilM.debug_print( "command_call: "..command_call )
            return utilM.execute( command_call )
        else
            error( "Missing parameters! Please include uuid, band, and bssid." )
        end
    else
        error( error_code )
    end
end

--- Change the clients parent ( the client can be a node or any wlan device )
--  @param raw The string in json format. Requires the keys "client" and "uuid".
-- @return Returns published output or error information.
function M.change_client_parent( raw )
    local function get_steer_11v_params( client, uuid, client_current_band )
        local ap_data_table = devinfoM.get_devinfo_by_uuid( uuid )
        local steer_11v_params = {}
        
        -- If client was previously connected to 2.4G band then attempt to connect to 2.4G, if not 5G
        if ap_data_table.data.userAp2G_channel ~= "" and client_current_band ~= "5G" then
            steer_11v_params["ap_bssid"] = ap_data_table.data.userAp2G_bssid
            steer_11v_params["ap_channel"] = ap_data_table.data.userAp2G_channel
            steer_11v_params["client_bssid"] = client
        elseif ap_data_table.data.userAp5GL_channel ~= "" then
            steer_11v_params["ap_bssid"] = ap_data_table.data.userAp5GL_bssid
            steer_11v_params["ap_channel"] = ap_data_table.data.userAp5GL_channel
            steer_11v_params["client_bssid"] = client
        elseif ap_data_table.data.userAp5GH_channel ~= "" then
            steer_11v_params["ap_bssid"] = ap_data_table.data.userAp5GH_bssid
            steer_11v_params["ap_channel"] = ap_data_table.data.userAp5GH_channel
            steer_11v_params["client_bssid"] = client
        end
        
        return steer_11v_params
    end
    
    local function get_temporary_blacklist_params( client, uuid )
        local temporary_blacklist_params = {}
        
        temporary_blacklist_params["client"]   = client
        temporary_blacklist_params["duration"] = "30"
        temporary_blacklist_params["action"]   = "start"
        temporary_blacklist_params["exclude"]  = uuid
        
        return temporary_blacklist_params
    end
    
    -- Parse the required data for client steer decision.
    local json_data_table,error_code = jsonM.parse( raw )
    if json_data_table then
        local client, uuid = nil, nil
        
        if json_data_table.client then client = json_data_table.client end
        if json_data_table.uuid   then uuid   = json_data_table.uuid   end
        
        if client and uuid then
            local client_data_table = wlanM.get_wlan_client_status_by_mac( client )
            utilM.debug_print(client, uuid)
            -- Is client 11v capable, if so use 11v steer, if not use blacklist.
            if client_data_table.data.btm_cap == "true" then
                -- steer using 11v
                local client_current_band = client_data_table.data.band  or ""-- Try to connect to same band on different parent.
                local steer_11v_params = get_steer_11v_params( client, uuid, client_current_band )
                local raw_data,error_code = jsonM.stringify( steer_11v_params )
                if raw_data then
                    return M.publish_steer_11v( raw_data )
                else
                    error( error_code )
                end
            else
                -- steer using blacklist
                local temporary_blacklist_params = get_temporary_blacklist_params( client, uuid )
                local raw_data,error_code = jsonM.stringify( temporary_blacklist_params )
                if raw_data then
                    return M.publish_temporary_blacklist( raw_data )
                else
                    error( error_code )
                end
            end
        end
    else
        error( error_code )
    end
end

--- Temporary blacklist a client.
-- @param raw The string in json format. Requires the keys "client", "duration", "action", and "exclude" ( exclude is optional ).
-- @return Returns published output or error information.
function M.publish_temporary_blacklist( raw )
    -- Generate blacklist payload command.
    local function blacklist_payload_cmd( client, duration, action, exclude )
        if not exclude then exclude = "" end
        -- jsongen requires the literal '\"' surrounding the string, it doesn't do it automatically for some reason.
        -- without is [ uuid ], with is [ "uuid" ]
        return ("mk_infra_payload -s \"client:%s\" -s \"duration:%s\" -s \"action:%s\" -r \"exclude:$(jsongen -o a -a \\\"%s\\\")\""):format( client, duration, action, exclude )
    end
    
    -- Generate blacklist command.
    local function blacklist_cmd( topic, payload )
        return ("%s | omsg-publish \"%s\""):format( payload, topic )
    end
    
    -- Parse the required data for blacklist command.
    local json_data_table,error_code = jsonM.parse( raw )
    if json_data_table then
        local client, duration, action, exclude = nil, nil, nil, nil
        
        if json_data_table.client   then client   = json_data_table.client    end
        if json_data_table.duration then duration = json_data_table.duration  end
        if json_data_table.action   then action   = json_data_table.action    end
        if json_data_table.exclude  then exclude  = json_data_table.exclude   end
        
        -- Issue blacklist command.
        if client and duration and action then
            local topic = "topomgmt/cmd/temporary_blacklist"
            local payload_command_call = blacklist_payload_cmd( client, duration, action, exclude )
            utilM.debug_print( "payload_command_call: "..payload_command_call )
            local command_call = blacklist_cmd( topic, payload_command_call )
            utilM.debug_print( "command_call: "..command_call )
            
            if command_call then
                return utilM.execute( command_call )
            end
        else
            error( "Missing parameters! Please include client, duration, and action." )
        end
    else
        error( error_code )
    end
end

--- 11v steer a client.
-- @param raw The string in json format. Requires the keys "client_bssid", "ap_bssid", "ap_channel", and "ap_uuid" ( ap_uuid is optional ).
-- @return Returns published output or error information.
function M.publish_steer_11v( raw )
    -- Generate 11v steer payload command.
    local function steer_11v_payload_cmd( client_bssid, ap_bssid, ap_channel, ap_uuid )
        return ("mk_infra_payload -t cmd -s \"client_bssid:%s\" -s \"ap_bssid:%s\" -s \"ap_channel:%s\" -s \"ap_uuid:%s\""):format( client_bssid, ap_bssid, ap_channel, ap_uuid )
    end
    
    -- Generate 11v steer command.
    local function steer_11v_cmd( topic, payload )
        return ("%s | omsg-publish \"%s\""):format( payload, topic )
    end
    
    -- Parse the required data for 11v steer command.
    local json_data_table,error_code = jsonM.parse( raw )
    if json_data_table then
        local client_bssid, ap_bssid, ap_channel, ap_uuid = nil, nil, nil, nil
        
        if json_data_table.client_bssid then client_bssid = json_data_table.client_bssid end
        if json_data_table.ap_bssid     then ap_bssid     = json_data_table.ap_bssid     end
        if json_data_table.ap_channel   then ap_channel   = json_data_table.ap_channel   end
        if json_data_table.ap_uuid      then ap_uuid      = json_data_table.ap_uuid      end
        
        -- Issue 11v steer command.
        if client_bssid and ap_bssid and ap_channel then
            if not ap_uuid then ap_uuid = utilM.execute( "mac_to_uuid "..ap_bssid ) end
            if not ap_uuid then error( "Unable to obtain ap_bssid using mac_to_uuid" ) end
            
            local topic = "topomgmt/cmd/steer_11v"
            local payload_command_call = steer_11v_payload_cmd( client_bssid, ap_bssid, ap_channel, ap_uuid )
            utilM.debug_print( "payload_command_call: "..payload_command_call )
            local command_call = steer_11v_cmd( topic, payload_command_call )
            utilM.debug_print( "command_call: "..command_call )
            
            if command_call then
                return utilM.execute( command_call )
            end
        else
            error( "Missing parameters! Please include client_bssid, ap_bssid, and ap_channel." )
        end
    else
        error( error_code )
    end
end

return M
