--
-- 2018 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2020/11/30 12:29:30 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/networksecurity/networksecurity_server.lua#3 $
--

local parentalcontrol = require('parentalcontrol')
local networksecurity = require('networksecurity')

local function GetNetworkSecuritySettings(ctx)
    local sc = ctx:sysctx()

    return 'OK', {
        isNetworkSecurityEnabled = parentalcontrol.getIsEnabled(sc),
        engineConfigs = networksecurity.getConfigurationSettings(sc),
        supportedCategories = networksecurity.getSupportedCategories(),
        predefinedFilters = networksecurity.getPredefinedFilters(),
        maxRuleDescriptionLength = parentalcontrol.getMaxParentalControlRuleDescriptionLength(sc),
        maxRuleMACAddresses = parentalcontrol.getMaxParentalControlRuleMACAddresses(sc),
        maxRuleBlockedURLLength = parentalcontrol.getMaxParentalControlRuleBlockedURLLength(sc),
        maxRuleBlockedURLs = parentalcontrol.getMaxParentalControlRuleBlockedURLs(sc),
        maxRuleAllowedURLLength = networksecurity.getMaxAllowedURLLength(sc),
        maxTotalAllowedURLs = networksecurity.getMaxTotalAllowedURLs(sc),
        maxRules = parentalcontrol.getMaxParentalControlRules(sc)
    }
end

local function GetNetworkSecuritySettings2(ctx)
    local sc = ctx:sysctx()

    return 'OK', {
        isParentalControlEnabled = parentalcontrol.getIsEnabled(sc),
        isThreatDetectionEnabled = networksecurity.getIsThreatDetectionEnabled(sc),
        isMaliciousWebsiteDetectionEnabled = networksecurity.getIsMaliciousWebsiteDetectionEnabled(sc),
        engineConfigs = networksecurity.getConfigurationSettings(sc),
        supportedCategories = networksecurity.getSupportedCategories(),
        predefinedFilters = networksecurity.getPredefinedFilters(),
        maxRuleDescriptionLength = parentalcontrol.getMaxParentalControlRuleDescriptionLength(sc),
        maxRuleMACAddresses = parentalcontrol.getMaxParentalControlRuleMACAddresses(sc),
        maxRuleBlockedURLLength = parentalcontrol.getMaxParentalControlRuleBlockedURLLength(sc),
        maxRuleBlockedURLs = parentalcontrol.getMaxParentalControlRuleBlockedURLs(sc),
        maxRuleAllowedURLLength = networksecurity.getMaxAllowedURLLength(sc),
        maxTotalAllowedURLs = networksecurity.getMaxTotalAllowedURLs(sc),
        maxRules = parentalcontrol.getMaxParentalControlRules(sc)
    }
end

local function SetNetworkSecuritySettings(ctx, input)
    local sc = ctx:sysctx()

    local error =
        networksecurity.setLicenseID(sc, input.licenseID) or -- licenseID has to be set before isNetworkSecurityEnabled
        parentalcontrol.setIsEnabled(sc, input.isNetworkSecurityEnabled) or
        networksecurity.setConfigurationSettings(sc, input.engineConfigs)
    return error or 'OK'
end

local function SetNetworkSecuritySettings2(ctx, input)
    local sc = ctx:sysctx()

    local error =
        networksecurity.setLicenseID(sc, input.licenseID) or -- licenseID has to be set before isParentalControlEnabled
        parentalcontrol.setIsEnabled(sc, input.isParentalControlEnabled) or
        networksecurity.setIsThreatDetectionEnabled(sc, input.isThreatDetectionEnabled) or
        networksecurity.setIsMaliciousWebsiteDetectionEnabled(sc, input.isMaliciousWebsiteDetectionEnabled) or
        networksecurity.setConfigurationSettings(sc, input.engineConfigs)
    return error or 'OK'
end

local function GetSubscriptionStatus(ctx)
    local sc = ctx:sysctx()

    return 'OK', {
        licenseID = networksecurity.getLicenseID(sc),
        subscriptionStatus = networksecurity.getSubscriptionStatus(sc)
    }
end

local function GetThreatSignatureStatus(ctx)
    local sc = ctx:sysctx()

    return 'OK', networksecurity.getThreatSignatureStatus(sc)
end

local function GetBackupConfigurationInfo(ctx)
    local sc = ctx:sysctx()

    local error, configInfo = networksecurity.getBackupConfigurationInfo(sc)
    return error or 'OK', nil == error and {
        isBackupAvailable = configInfo.isBackupAvailable,
        configVersion = configInfo.configVersion
    } or nil
end

local function RestoreConfiguration(ctx, input)
    local sc = ctx:sysctx()

    local error, configInfo = networksecurity.getBackupConfigurationInfo(sc)
    if not error then
        if not configInfo.isBackupAvailable then
            return 'ErrorConfigurationNotFound'
        elseif not require('jnap').isServiceSupported(ctx, '/jnap/networksecurity/ConfigVersion'..configInfo.configVersion) then
            return 'ErrorUnsupportedVersion'
        else
            error = networksecurity.restoreConfiguration(sc, input.licenseID, configInfo.configId)
        end
    end
    return error or 'OK'
end

local function SyncLogFiles(ctx, input)
    local sc = ctx:sysctx()

    local error = networksecurity.syncLogFiles(sc)

    return error or 'OK'
end

return require('libhdklua').loadmodule('jnap_networksecurity'), {
    ['http://linksys.com/jnap/networksecurity/GetSubscriptionStatus'] = GetSubscriptionStatus,
    ['http://linksys.com/jnap/networksecurity/GetThreatSignatureStatus'] = GetThreatSignatureStatus,
    ['http://linksys.com/jnap/networksecurity/SetNetworkSecuritySettings'] = SetNetworkSecuritySettings,
    ['http://linksys.com/jnap/networksecurity/SetNetworkSecuritySettings2'] = SetNetworkSecuritySettings2,
    ['http://linksys.com/jnap/networksecurity/GetNetworkSecuritySettings'] = GetNetworkSecuritySettings,
    ['http://linksys.com/jnap/networksecurity/GetNetworkSecuritySettings2'] = GetNetworkSecuritySettings2,
    ['http://linksys.com/jnap/networksecurity/GetBackupConfigurationInfo'] = GetBackupConfigurationInfo,
    ['http://linksys.com/jnap/networksecurity/RestoreConfiguration'] = RestoreConfiguration,
    ['http://linksys.com/jnap/networksecurity/SyncLogFiles'] = SyncLogFiles
}
