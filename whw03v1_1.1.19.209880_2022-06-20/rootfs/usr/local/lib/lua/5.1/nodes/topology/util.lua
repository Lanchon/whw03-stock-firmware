--- Utility for topology management.
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local lfsM       = require ( "lfs" )
local jsonM      = require ( "libhdkjsonlua" )
local MSG_DIR    = "/tmp/msg"
local TM_DIR     = "/tmp/topology_management"

local M = {
    MSG_DIR = MSG_DIR,
    TM_DIR  = TM_DIR
}

--- Dump table contents. This is for debugging.
-- @param table The target table.
-- @param msg The message to print ( usually the values ).
-- @param level The level depth of recursion.
function M.dumpTable( table, msg, level )
    local function indent()
        io.write( string.rep("-", level) )
    end
    
    if level == nil then level = 0 end
    
    if msg then
        indent()
        print( msg )
    end
    
    for k,v in pairs( table ) do
        if type( v ) == "table" then
            M.dumpTable( v, k, level + 4 )
        else
            indent()
            print( k, v )
        end
    end
end

--- Read file to string.
-- @param absolute_path The absolute file path.
-- @return Return file data as string on success, otherwise nil and error_code.
function M.read( absolute_path )
    local raw_data      = nil
    local error_code    = nil
    local iostream      = nil
    iostream,error_code = io.open( absolute_path, "r" )
    
    if iostream then
        raw_data = iostream:read( "*all" )
        iostream:close()
    end
    
    raw_data,error_code = M.chomp( raw_data )
    
    return raw_data, error_code
end

--- Write string to file.
-- @param absolute_path The absolute file path.
-- @param str The string written to file.
-- @return Returns nil on success, otherwise error_code,
function M.write( absolute_path, str )
    local error_code    = nil
    local iostream      = nil
    iostream,error_code = io.open( absolute_path, "w+" )
    
    if iostream then
        _,error_code = iostream:write( str )
        iostream:close( file )
    else
        error_code = "Unable to open filename: " .. tostring( absolute_path )
    end
    
    return error_code
end

--- Load JSON data from file to table. The data must be in JSON format.
-- @param absolute_path The absolute path to file.
-- @return Return data as table on success otherwise nil and error.
function M.load( absolute_path )
    local json_data_table = nil
    local error_code      = nil
    local iostream        = nil
    iostream,error_code   = io.open( absolute_path, "r" )
    
    if iostream then
        local raw_data,error_code = iostream:read( "*all" )
        iostream:close()
        
        if raw_data then
            json_data_table,error_code = jsonM.parse( raw_data )
        end
    else
        error_code = "Unable to open filename: " .. tostring( absolute_path )
    end

    return json_data_table,error_code
end

--- Save JSON data table to file. The data will be saved as JSON format.
-- @param absolute_path The absolute path of file.
-- @param json_data_table The json data table.
-- @return Returns the JSON data string saved to file on success, otherwise nil and error.
function M.save( absolute_path, json_data_table )
    local raw_data       = nil
    local error_code     = nil
    raw_data,error_code = jsonM.stringify( json_data_table )
    
    if raw_data then
        local iostream,error_code = io.open( absolute_path, "w+" )
        
        if iostream then
            _,error_code = iostream:write( raw_data )
            iostream:close()
        else
            error_code = "Unable to open filename: " .. tostring( absolute_path )
        end
    end
    
    return raw_data,error_code
end

--- Check if a path refers to a directory.
-- @param path The absolute path to check.
-- @return Returns true if a directory, false otherwise. Error code is also returned, if any.
function M.is_dir( path )
    local attr       = nil
    local error_code = nil
    attr,error_code  = lfsM.attributes( path )
    
    return type( attr ) == "table" and attr.mode == "directory",error_code
end

--- Check if a path refers to a file.
-- @param path The absolute path to check.
-- @return Return true if a file, false otherwise. Error code is also returned if any.
function M.is_file( path )
    local attr       = nil
    local error_code = nil
    attr,error_code  = lfsM.attributes( path )
    
    return type( attr ) == "table" and attr.mode == "file",error_code
end

--- Remove any trailing slashes from a path.
-- @param path The file system path.
-- @return The pruned path.
function M.trim_trailing_slashes( path )
    local pruned_path = path
    
    while #pruned_path > 1 and pruned_path:sub( -1 ) == '/' do
        pruned_path = pruned_path:sub( 1, -2 )
    end
    
    return pruned_path
end

--- Joins strings together with '/' between them.
-- @param ... The file system path components.
-- @return Return the combined path.
function M.join_path( ... )
    local path = nil
    local PATH_SEP = "/"
    for _,component in ipairs{ ... } do
        if path then
            path = path..PATH_SEP..M.trim_trailing_slashes( component )
        else
            path = M.trim_trailing_slashes( component )
        end
    end
    
    return path or ""
end

--- Lua version of Perl chomp function.
-- @param string The string to Chomp.
-- @return Return the copy of same string with any trailing newline removed on success, otherwise nil and error code.
function M.chomp( string )
    local chomped_string = nil
    local error_code     = nil
    
    chomped_string, error_code = string:gsub( "\n$", "" )
    
    return chomped_string,error_code
end

--- Execute command.
-- @param cmd The command to execute.
-- @return Returns data on success, otherwise nil and error_code.
function M.execute( cmd )
    local data            = nil
    local data_chomped    = nil
    local error_code      = nil
    local pipe            = nil
    
    pipe,error_code = io.popen( cmd )
    
    if pipe then
        data,error_code = pipe:read( "*a" )
        pipe:close()
    else
        error_code = "Unable to popen command: " .. tostring( cmd )
    end
    
    data_chomped,error_code = M.chomp( data )
    
    return data_chomped,error_code
end

--- Tokenize string by space.
-- @param string The string to tokenize.
-- @return Return a table of strings.
function M.tokenize_by_space( string )
    local tokens = {}
    
    if string then
        for token in string:gmatch("%S+") do
            table.insert( tokens, token );
        end
    end
    
    return tokens;
end

--- Remove newlines in string.
-- @param string The string to remove newlines from.
-- @return Return the modified string.
function M.remove_newlines( string )
    return string.gsub( string, "\n", "" )
end

--- If Global DEBUG var is true, print string.
-- @param string The string to print.
function M.debug_print( string )
    if DEBUG then print( "topology_management: ", string ) end
end

return M
