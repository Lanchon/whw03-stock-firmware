--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

-- smartconnect_client.lua - library to configure Linksys non-Node SmartConnect devices.

local _M = {}   --create the module

local platform = require('platform')
local device = require('device')

function _M.getClientDeviceInfo(sc)
    sc:readlock()

    sc:set_smartconnect_presetup(true)
    return {
        serialNumber = device.getSerialNumber(sc),
        description = device.getModelDescription(sc),
        model = device.getModelNumber(sc),
        vendor = device.getManufacturer(sc)
    }
end

function _M.startSmartConnectClient(sc, settings)
    sc:writelock()

    if not sc:start_smartconnect_client(settings.serverSSID, settings.setupPIN) then
        return 'ErrorStartClientFailed'
    end
end

function _M.detach(sc)
    sc:writelock()

    sc:set_smartconnect_presetup(false)
end


return _M   -- return the module.
