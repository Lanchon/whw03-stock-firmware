--- The wlan module. This module gives access to data in /tmp/msg/WLAN directory.
-- @copyright Copyright (c) 2020, Belkin Inc. All rights reserved.

local jsonM         = require ( "libhdkjsonlua" )
local ddb           = require('libdevdblua').db()

local M = {}

--- Get all devices in db.
-- @return Return lua table of all devices in db.
function M.get_all_devices()
    if ddb:readLock() then
       local devs = ddb:getAllDevices()
       ddb:readUnlock()
       if devs then
           return devs
       else
          error( "No devices at all" )
       end
    else
       error( "Error acquiring read lock" )
    end
end

--- Get device interface.
-- @param The device table.
-- @return Return the device interface table.
function M.get_device_interface_table( device )
    if device.interface and #device.interface > 0 then
        return device.interface
    else
        error( "No interface data avaialble" )
    end
end

--- Get device interface table by mac.
-- @param The device mac.
-- @return Return the device interface table.
function M.get_device_interface_table_by_mac( mac )
    local devs_table,error_code = M.get_all_devices()
    if devs_table then
        for _,dev in ipairs( devs_table ) do
            local dev_intf,error_code = M.get_device_interface_table( dev )
            if dev_intf then
                local intf = dev_intf[1]
                local mac_addr = intf.macAddr
                if string.upper( tostring(mac_addr) ) == string.upper( tostring(mac) ) then
                    return intf
                end
            else
                error( error_code )
            end
        end
    else
        error( error_code )
    end
    error( "No devices matched with mac address" )
end

--- Get client ip address.
-- @param The mac address of device.
-- @return Return client ip address.
function M.get_client_ip_address_by_mac( mac )
    local devs_table,error_code = M.get_all_devices()
    if devs_table then
        for _,dev in ipairs( devs_table ) do
            local dev_intf,error_code = M.get_device_interface_table( dev )
            if dev_intf then
                local intf = dev_intf[1]
                local mac_addr = intf.macAddr
                if string.upper( tostring(mac_addr) ) == string.upper( tostring(mac) ) then
                    if intf.ipaddr and #intf.ipaddr > 0 then
                        local ipaddr = intf.ipaddr[1]
                        return ipaddr.ip
                    else
                        error( "No ip address data avaialble" )
                    end
                end
            else
                error( error_code )
            end
        end
    else
        error( error_code )
    end
    error( "No devices matched with mac address" )
end

--- Get device by mac.
-- @param The mac address of device.
-- @return Return the device table.
function M.get_device_by_mac( mac )
    local devs_table,error_code = M.get_all_devices()
    if devs_table then
        for _,dev in ipairs( devs_table ) do
            local dev_intf,error_code = M.get_device_interface_table( dev )
            if dev_intf then
                local intf = dev_intf[1]
                local mac_addr = intf.macAddr
                if string.upper( tostring(mac_addr) ) == string.upper( tostring(mac) ) then
                    return dev
                end
            else
                error( error_code )
            end
        end
    else
        error( error_code )
    end
    error( "No devices matched with mac address" )
end

return M