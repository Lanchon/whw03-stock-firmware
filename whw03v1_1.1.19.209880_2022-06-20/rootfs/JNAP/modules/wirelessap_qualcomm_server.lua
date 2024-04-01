--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hesia $
-- $DateTime: 2019/10/09 16:05:17 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/wirelessap_qualcomm/wirelessap_qualcomm_server.lua#2 $
--

local wirelessap = require('wirelessap')

local function GetAdvancedRadioSettings(ctx)
    local sc = ctx:sysctx()
    sc:readlock()
    local supportedRadios = wirelessap.getSupportedRadios(sc)
    local radios = {}
    for radioID, radio in pairs(supportedRadios) do
        local radioOutput = {
            radioID = radioID,
            isTxBFEnabled = sc:get_wifi_qca_txbf_enabled(radio.apName),
            isMUMIMOEnabled= sc:get_wifi_qca_mumimo_enabled(radio.apName)
        }
        table.insert(radios, radioOutput)
    end
    return 'OK', {
        qualcommAdvancedRadioSettings = radios
    }
end

local function SetAdvancedRadioSettings(ctx, input)
    local sc = ctx:sysctx()
    sc:writelock()
    for i, newSettings in ipairs(input.qualcommAdvancedRadioSettings) do
        local profile = wirelessap.getSupportedRadios(sc)[newSettings.radioID]
        if not profile then
            return 'ErrorUnknownRadio'
        end
        sc:set_wifi_qca_txbf_enabled(profile.apName, newSettings.isTxBFEnabled)
        sc:set_wifi_qca_mumimo_enabled(profile.apName, newSettings.isMUMIMOEnabled)
    end
    return 'OK'
end

return require('libhdklua').loadmodule('jnap_wirelessap_qualcomm'), {
    ['http://linksys.com/jnap/wirelessap/qualcomm/GetAdvancedRadioSettings'] = GetAdvancedRadioSettings,
    ['http://linksys.com/jnap/wirelessap/qualcomm/SetAdvancedRadioSettings'] = SetAdvancedRadioSettings
}
