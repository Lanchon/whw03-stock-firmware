--
-- 2021 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

-- iptv.lua - library to configure LAN Voice and Video Prioritization (IPTV) settings.

local util = require('util')
local router = require('router')
local hdk = require('libhdklua')

local _M = {} -- create the module


function _M.getIPTVSettings(sc)
    sc:readlock()

    return {
        isEnabled = sc:get_iptv_enabled()
    }
end

function _M.setIPTVSettings(sc, input)
    sc:writelock()

    if util.isNodeUtilModuleAvailable() and not require('nodes_util').isNodeAMaster(sc) then
        return 'ErrorDeviceNotInMasterMode'
    end
    sc:set_iptv_enabled(input.isEnabled)
    if input.isEnabled then
        -- If the LAN IP address is currently set to the default subnet (192.168.1.x/24)
        -- then change it to 192.168.10.1
        local lanIPAddress = sc:get_lan_ipaddress()
        local networkPrefixLength = util.subnetMaskToNetworkPrefixLength(hdk.ipaddress(sc:get_lan_subnet_mask()))
        if (networkPrefixLength == 24) and (lanIPAddress:match('^%d+.%d+.%d+') == router.DEFAULT_LAN_IPADDRESS:match('^%d+.%d+.%d+')) then
            sc:set_lan_ipaddress('192.168.10.1')
        end
    end
end


return _M -- return the module
