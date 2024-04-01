--
-- 2021 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2021/07/28 15:55:00 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/networksecurity.lua#6 $
--

-- networksecurity.lua - library to configure network security feature.

local lfs = require('lfs')
local util = require('util')
local hdk = require('libhdklua')
local platform = require('platform')
local parentalcontrol = require('parentalcontrol')
local json = require('libhdkjsonlua')

local _M = {} -- create the module
_M.CMD_UPLOAD_THREAT_LOGS = 'shield_upload_threat_logs'

_M.unittest = {}

--
-- Modified networksecurity.hsl struct to fits the proposed schema
-- (Added blockedPageRedirectURL and configurationFormatVersion)
--
-- struct ConfigurationSettings
--
--     InternetBlockScheduleExceptions internetBlockScheduleExceptions
--
--     NetworkSecurityProfiles profiles
--
--     [optional] string blockedPageRedirectURL
--
--     [optional] string configurationFormatVersion
--
-- struct ExportedConfig
--
--     ConfigurationSettings engineConfigs
--
-- Generated via hdkdyn.py --struct=ExportedConfig networksecurity.hsl
--
-- TODO: See if we can retrieve the schema from libjnap_networksecurity.so
--
_M.EXPORTEDCONFIG_SCHEMA = hdk.schema('eJzVmV1v2jAYhf+Lr9EYA9qNO9p1ElLXodJ2F1UvXOcleCR2ZDujqOp/X1KoxgRd7eq4KXcoUfSc44/3i3s2ETPKORtc37MxN6TcSCV0xwYfW+wko7x6wAb37IznZAsuiA3YzLli0G5nUs3t0n4QOm//UrxoK3ILbeaWRGmkW7ZZ6/Gz6ouTu0IbR8mxVlOZloY7qRV7aLGLZVG/nzhTClc9iKiBVCoVrRRYD3YHyJbKkaleH2VazOsFT8qMTu4EFfVCvLWawuipzOitsbe1eUrGPKVzSqQh4S7PT/8VIVVaffBjvSyD6/VPnrGbqNrE5sH8pk3O3RUZu3VKQ/R9Qh6gVGlDTydnqJLHk/R9eDxMEkPWem1mVEHDLNOLQEFdoKA007c8G6+O9jZ796a12FAtnyRs7yBSX0K/paBJQUJOpRj7X8EDoIi/+7MB3nj43CpdqltdVnKSHYt0+M71fYZuohVGFtvZq44LUck5F/+5Wb4hCaloZ057H9JKk/2cSUdHGRfzU2mdxzUD849Wye6YO0q1WY6++lz1L0ANZ6s3k/Wb84DN2bxPL0TIDjJExrj9nR5QoK0ofOlTNiGpuW6C6kqyDWAXlKhGwG5Wmia4UyMboFruSuPJ7UN7AP+IDAUv6nzgC0aWXFWa3ECOlE/Q3RHGkFVWWBUDRWPKGKgkcB0D1faaQgYt4FWVTAdZyow2d2hMRurkNaXMjg4dOV+KpxI56IinEjldiKcSWa/GU4lM9fFUIvNzPJXIZG6fcqTXSPAFYcg4jRTWRUbFGD1dFxkQvXs6KNW7p4NS/Xs6KDakp8P69e/poFzvng57kv17ui4yWYf0dFBwSE/XRSZ+TE/XhTb0jht3IXPazgFxwaQSXyyyXgjyiwQH+MVWHgF+keAAv9iCJsAvEhzgF/mXQZBfJDjAL7KnD/KLBPv77SHr4BC/UHCA373oOnt70XX2kCE4nkpk4IynEhnu4qnci4lnfy8mnn1oWwQcjfSR7QtS2EFTtQgU7J+rDpqqRaBgf7+HTdUiUHCAX2wECPCLBAf4xQaWAL9IcIBf5DgmyC8SHOC3qVkPFPy835uKosq8flqnrZuHP5o/whE=')

_M.PREDEFINED_FILTERS_DB = '/etc/NetworkSecurity_Predefined_Filters.json'
_M.SUPPORTED_CATEGORIES_DB = '/etc/NetworkSecurity_Supported_Categories.txt'

_M.DAYS_OF_WEEK = {'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'}

--
-- Serialize Configuration Settings struct to JSON string
--
-- input = {
--     internetBlockScheduleExceptions = {
--         ignoreScheduleAndBlockMACAddresses = ARRAY_OF(MACADDRESS),
--         ignoreScheduleAndAllowMACAddresses = ARRAY_OF(MACADDRESS)
--     },
--     rules = {
--         globalProfile = OPTIONAL({
--             description = STRING,
--             macAddresses = OPTIONAL(ARRAY_OF(MACADDRESS)),
--             internetBlockSchedule = OPTIONAL({
--                 sunday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 monday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 tuesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 wednesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 thursday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 friday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 saturday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }))
--             },
--             urlWhiteBlackList = {
--                 blackList = ARRAY_OF(STRING),
--                 whiteList = ARRAY_OF(STRING)
--             },
--             urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
--         }),
--         deviceSpecificProfiles = ARRAY_OF({
--             description = STRING,
--             macAddresses = ARRAY_OF(MACADDRESS),
--             internetBlockSchedule = {
--                 sunday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 monday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 tuesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 wednesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 thursday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 friday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 saturday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 })
--             },
--             urlWhiteBlackList = {
--                 blackList = ARRAY_OF(STRING),
--                 whiteList = ARRAY_OF(STRING)
--             },
--             urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
--         })
--     }
--
-- output = STRING
--
function _M.serializeConfigurationSettings(sc, configurationSettings)
    sc:readlock()
    -- add versioning and redirect url
    configurationSettings.configurationFormatVersion = sc:get_shield_configversion()
    configurationSettings.blockedPageRedirectURL = sc:get_shield_redirecturl()

    return _M.EXPORTEDCONFIG_SCHEMA:serialize_json({ engineConfigs = configurationSettings }, true --[[do not create new lines]])
end

--
-- Deserialize Configuration Settings struct from JSON string
--
-- input = STRING
--
-- output = {
--     internetBlockScheduleExceptions = {
--         ignoreScheduleAndBlockMACAddresses = ARRAY_OF(MACADDRESS),
--         ignoreScheduleAndAllowMACAddresses = ARRAY_OF(MACADDRESS)
--     },
--     profiles = {
--         globalProfile = OPTIONAL({
--             description = STRING,
--             macAddresses = OPTIONAL(ARRAY_OF(MACADDRESS)),
--             internetBlockSchedule = OPTIONAL({
--                 sunday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 monday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 tuesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 wednesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 thursday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 friday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 saturday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 })
--             }),
--             urlWhiteBlackList = {
--                 blackList = ARRAY_OF(STRING),
--                 whiteList = ARRAY_OF(STRING)
--             },
--             urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
--         }),
--         deviceSpecificProfiles = ({
--             description = STRING,
--             macAddresses = ARRAY_OF(MACADDRESS),
--             internetBlockSchedule = {
--                 sunday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 monday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 tuesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 wednesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 thursday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 friday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 saturday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 })
--             },
--             urlWhiteBlackList = {
--                 blackList = ARRAY_OF(STRING),
--                 whiteList = ARRAY_OF(STRING)
--             },
--             urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
--         })
--     }
--
local function deserializeConfigurationSettings(string)
    local configData = _M.EXPORTEDCONFIG_SCHEMA:deserialize_json(string)
    return {
        internetBlockScheduleExceptions = configData.engineConfigs.internetBlockScheduleExceptions,
        profiles = configData.engineConfigs.profiles
    }
end

local function removeWildcardURLs(urls)
    local retVal = {}
    for _, url in ipairs(urls) do
        if string.sub(url, 1, 1) ~= '*' then
            table.insert(retVal, url)
        end
    end
    return retVal
end

--
-- Helper function to check whether a given URL length is longer than allowed.
-- If the passed URL begins with *., we'll allow an additional of 2 characters.
-- Returns true if URL is within the allowed length.
--
local function isLengthOfURLValid(url, maxLength)
    if string.sub(url, 1, 2) == '*.' then
        maxLength = maxLength + 2
    end
    if #url > maxLength then
        return false
    end
    return true
end

--
-- Convert SecurityRule array to ParentalControlRule array
--
-- input = ARRAY_OF({
--     description = STRING,
--     macAddresses = ARRAY_OF(MACADDRESS),
--     internetBlockSchedule = {
--         sunday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         monday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         tuesday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         wednesday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         thursday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         friday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         saturday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         })
--     },
--     urlWhiteBlackList = {
--         blackList = ARRAY_OF(STRING),
--         whiteList = ARRAY_OF(STRING)
--     },
--     urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
--
-- output = BOOLEAN, ARRAY_OF({
--     isEnabled = BOOLEAN,
--     description = STRING,
--     macAddresses = ARRAY_OF(MACADDRESS),
--     wanSchedule = {
--         sunday = STRING,
--         monday = STRING,
--         tuesday = STRING,
--         wednesday = STRING,
--         thursday = STRING,
--         friday = STRING,
--         saturday = STRING
--     },
--     blockedURLs = ARRAY_OF(STRING)
-- })
--
local function convertToLegacyParentalControl(sc, deviceSpecificProfiles)
    local maxRuleBlockedURLLength = parentalcontrol.getMaxParentalControlRuleBlockedURLLength(sc)
    local legacyRules = {}
    for i, deviceSpecificProfile in ipairs(deviceSpecificProfiles) do
        local wanSchedule = {}
        if not deviceSpecificProfile.internetBlockSchedule then
            return 'ErrorMissingInternetBlockSchedule'
        end
        for j, day in ipairs(_M.DAYS_OF_WEEK) do
            local result, schedule = util.convertTimePeriodArrayToBinarySchedule(deviceSpecificProfile.internetBlockSchedule[day])
            if result then
                wanSchedule[day] = schedule
            else
                return 'ErrorInvalidWANSchedule'
            end
        end

        if not deviceSpecificProfile.macAddresses or #deviceSpecificProfile.macAddresses == 0 then
            return 'ErrorMissingMACAddress'
        end

        for k, blockedURL in ipairs(deviceSpecificProfile.urlWhiteBlackList.blackList) do
            if not isLengthOfURLValid(blockedURL, maxRuleBlockedURLLength) then
                return 'ErrorBlockedURLTooLong'
            end
        end

        table.insert(legacyRules, {
            isEnabled = true,
            description = deviceSpecificProfile.description,
            macAddresses = deviceSpecificProfile.macAddresses,
            wanSchedule = wanSchedule,
            blockedURLs = removeWildcardURLs(deviceSpecificProfile.urlWhiteBlackList.blackList)
        })
    end
    return nil, legacyRules
end

--
-- Get the maximum total of allowed URLs.
--
-- input = CONTEXT
--
-- output = NUMBER
--
function _M.getMaxTotalAllowedURLs(sc)
    sc:readlock()
    return sc:get_shield_maxtotalallowedurls()
end

--
-- Get the maximum  length of allowed URL.
--
-- input = CONTEXT
--
-- output = NUMBER
--
function _M.getMaxAllowedURLLength(sc)
    sc:readlock()
    return sc:get_shield_maxallowedurllength()
end

--
-- Get the configuration settings file path.
--
-- input = CONTEXT
--
-- output = STRING
--
function _M.getConfigurationSettingsPath(sc)
    sc:readlock()
    return sc:get_shield_configpath()
end

--
-- Get the temporary configuration settings file path.
--
-- input = CONTEXT
--
-- output = STRING
--
function _M.getTemporaryConfigurationSettingsPath(sc)
    sc:readlock()
    return sc:get_shield_tempconfigpath()
end

--
-- Get the list of supported categories
--
-- input = CONTEXT
--
-- output = ARRAY_OF({
--     categoyID = NUMBNER,
--     presetName = STRING
-- })
--
function _M.getSupportedCategories()
    if lfs.attributes(_M.SUPPORTED_CATEGORIES_DB, 'mode') ~= 'file' then
        return nil
    end

    local supportedCategories = {}
    for line in io.lines(_M.SUPPORTED_CATEGORIES_DB) do
        line = line:gsub('\r','') -- trim carriage return code
        values = util.splitOnDelimiter(line, ',')
        local supportedCategory = {
            categoryID = tonumber(values[1]),
            presetName = values[2]
        }
        table.insert(supportedCategories, supportedCategory)
    end

    return supportedCategories
end

--
-- Get the list of pre-defined filters
--
-- input = CONTEXT
--
-- output = ARRAY_OF({
--     filterName = STRING,
--     urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
-- })
--
function _M.getPredefinedFilters()
    local fh = io.open(_M.PREDEFINED_FILTERS_DB, 'r')
    if not fh then
        return nil, 'Failed to open pre-defined filter database file "'.._M.PREDEFINED_FILTERS_DB..'"'
    end

    local str = fh:read('*a')
    if not str then
        return nil, 'Failed to read pre-defined filter database file.'
    end

    local predefinedFilters = json.parse(str)
    if not predefinedFilters then
        return nil, 'Failed to parse pre-defined filter database file.'
    end

    return predefinedFilters
end

--
-- Set license ID.
--
-- input = CONTEXT, STRING
--
function _M.setLicenseID(sc, licenseID)
    if licenseID and #licenseID == 0 then
        return 'ErrorInvalidLicenseID'
    end

    sc:writelock()
    if not platform.isReady(sc) then
        return '_ErrorNotReady'
    end

    sc:set_shield_licenseid(licenseID)
end

--
-- Get license ID.
--
-- input = CONTEXT
--
-- output = NIL_OR(STRING)
--
function _M.getLicenseID(sc)
    sc:readlock()
    return sc:get_shield_licenseid()
end

--
-- Convert ParentalControlRule array to NetworkSecurityRule array
--
-- input = ARRAY_OF({
--     isEnabled = BOOLEAN,
--     description = STRING,
--     macAddresses = ARRAY_OF(MACADDRESS),
--     wanSchedule = {
--         sunday = STRING,
--         monday = STRING,
--         tuesday = STRING,
--         wednesday = STRING,
--         thursday = STRING,
--         friday = STRING,
--         saturday = STRING
--     },
--     blockedURLs = ARRAY_OF(STRING)
-- })
--
-- output = ARRAY_OF({
--     description = STRING,
--     macAddresses = ARRAY_OF(MACADDRESS),
--     internetBlockSchedule = {
--         sunday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         monday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         tuesday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         wednesday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         thursday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         friday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         saturday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         })
--     },
--     urlWhiteBlackList = {
--         blackList = ARRAY_OF(STRING),
--         whiteList = ARRAY_OF(STRING)
--     },
--     urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
--
function _M.convertToNetworkSecurityRules(legacyRules)
    local securityRules = {}
    for i, legacyRule in ipairs(legacyRules) do
        local internetBlockSchedule = {}
        for j, day in ipairs(_M.DAYS_OF_WEEK) do
            local result, schedule = util.convertBinaryScheduleToTimePeriodArray(legacyRule.wanSchedule[day])
            if result then
                internetBlockSchedule[day] = schedule
            else
                internetBlockSchedule[day] = {}
            end
        end

        table.insert(securityRules, {
            description = legacyRule.description,
            macAddresses = legacyRule.macAddresses,
            internetBlockSchedule = internetBlockSchedule,
            urlWhiteBlackList = {
                whiteList = {},
                blackList = legacyRule.blockedURLs
            },
            urlBlockedCategoryIDs = {}
        })
    end
    return securityRules
end

--
-- Get the configuration settings. It will read from the config file, if it exists.
-- Otherwise, it'll read from the syscfg.
--
-- input = CONTEXT
--
-- output = {
--     internetBlockScheduleExceptions = {
--         ignoreScheduleAndBlockMACAddresses = ARRAY_OF(MACADDRESS),
--         ignoreScheduleAndAllowMACAddresses = ARRAY_OF(MACADDRESS)
--     },
--     profiles = {
--         globalProfile = OPTIONAL({
--             description = STRING,
--             macAddresses = OPTIONAL(ARRAY_OF(MACADDRESS)),
--             internetBlockSchedule = OPTIONAL({
--                 sunday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 monday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 tuesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 wednesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 thursday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 friday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 saturday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 })
--             }),
--             urlWhiteBlackList = {
--                 blackList = ARRAY_OF(STRING),
--                 whiteList = ARRAY_OF(STRING)
--             },
--             urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
--         }),
--         deviceSpecificProfiles = ARRAY_OF({
--             description = STRING,
--             macAddresses = ARRAY_OF(MACADDRESS),
--             internetBlockSchedule = {
--                 sunday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 monday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 tuesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 wednesday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 thursday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 friday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 }),
--                 saturday = ARRAY_OF({
--                     startTime = STRING,
--                     endTime = STRING
--                 })
--             },
--             urlWhiteBlackList = {
--                 blackList = ARRAY_OF(STRING),
--                 whiteList = ARRAY_OF(STRING)
--             },
--             urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
--         })
--     }
--
function _M.getConfigurationSettings(sc)
    sc:readlock()

    -- If a config file exists, we read from it. Otherwise, read from syscfg
    local configPath = _M.getConfigurationSettingsPath(sc)
    if lfs.attributes(configPath, 'mode') == 'file' then
        local fh = io.open(configPath, 'r')
        if fh then
            local str = fh:read('*a')
            return deserializeConfigurationSettings(str)
        end
    end

    return {
        profiles = {
            deviceSpecificProfiles = _M.convertToNetworkSecurityRules(parentalcontrol.getRules(sc))
        },
        internetBlockScheduleExceptions = {
            ignoreScheduleAndBlockMACAddresses = {},
            ignoreScheduleAndAllowMACAddresses = {}
        }
    }
end

--
-- Write the configuration settings to a specified file
--
-- input = CONTEXT, ARRAY_OF({
--     description = STRING,
--     macAddresses = ARRAY_OF(MACADDRESS),
--     internetBlockSchedule = {
--         sunday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         monday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         tuesday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         wednesday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         thursday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         friday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         saturday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         })
--     },
--     urlWhiteBlackList = {
--         blackList = ARRAY_OF(STRING),
--         whiteList = ARRAY_OF(STRING)
--     },
--     urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
-- })
--
function _M.writeConfigurationSettings(sc, settings)
    local filePath = _M.getTemporaryConfigurationSettingsPath(sc)
    if filePath and #filePath > 0 then
        -- check if parent directory exist, create one if it doesn't.
        local dir = util.getParentDiretory(filePath)
        if dir and lfs.attributes(dir, 'mode') ~= 'directory' then
            if not util.createParentDirectoryHelper(dir) then
                return 'ErrorConfigurationSettingsWriteFailed'
            end
        end
        local fh, err = io.open(filePath, 'w+')
        if fh then
            fh:write(_M.serializeConfigurationSettings(sc, settings))
            fh:close()
        else
            return 'ErrorConfigurationSettingsWriteFailed'
        end
    end
end

--
-- If configuration settings differ, we need to fire shield::config_changed sysevent
-- This will cause the json config file to be copied from temp to permanent location
--
function _M.fireConfigChangedSysevent(sc, newSettings)
    sc:writelock()
    local currentSettings = _M.getConfigurationSettings(sc)
    if not util.isTableEqual(currentSettings, newSettings) then
        sc:set_shield_configchanged()
    end
end

--
-- Set the configuration settings
--
-- input = CONTEXT, ARRAY_OF({
--     description = STRING,
--     macAddresses = ARRAY_OF(MACADDRESS),
--     internetBlockSchedule = {
--         sunday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         monday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         tuesday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         wednesday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         thursday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         friday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         }),
--         saturday = ARRAY_OF({
--             startTime = STRING,
--             endTime = STRING
--         })
--     },
--     urlWhiteBlackList = {
--         blackList = ARRAY_OF(STRING),
--         whiteList = ARRAY_OF(STRING)
--     },
--     urlBlockedCategoryIDs = ARRAY_OF(NUMBER)
-- })
--
-- output = NIL_OR_ONE_OF(
--     'ErrorDescriptionTooLong',
--     'ErrorInvalidDescription',
--     'ErrorInvalidMACAddress',
--     'ErrorTooManyMACAddresses',
--     'ErrorInvalidWANSchedule',
--     'ErrorBlockedURLTooLong',
--     'ErrorTooManyBlockedURLs',
--     'ErrorRulesOverlap'
--     'ErrorTooManyRules',
--     'ErrorAllowedURLTooLong',
--     'ErrorTooManyAllowedURLs',
--     'ErrorConfigurationSettingsWriteFailed'
-- )
--
function _M.setConfigurationSettings(sc, settings)
    sc:writelock()
    if not platform.isReady(sc) then
        return '_ErrorNotReady'
    end

    local maxAllowedURLLength  = _M.getMaxAllowedURLLength(sc)
    local maxTotalAllowedURLs = _M.getMaxTotalAllowedURLs(sc)
    local counter = 0
    local err = nil
    local legacyParentalControlRules = {}

    -- Validate globalProfile
    if settings.profiles and settings.profiles.globalProfile then
        if settings.profiles.globalProfile.internetBlockSchedule then
            for i, day in ipairs(_M.DAYS_OF_WEEK) do
                if settings.profiles.globalProfile.internetBlockSchedule[day] and #settings.profiles.globalProfile.internetBlockSchedule[day] > 0 then
                    return 'ErrorSuperfluousInternetBlockSchedule'
                end
            end
        end
        if settings.profiles.globalProfile.macAddresses and #settings.profiles.globalProfile.macAddresses > 0 then
            return 'ErrorSuperfluousMACAddress'
        end
    end

    -- Validate whiteList and blackList
    if settings.profiles and settings.profiles.deviceSpecificProfiles then
        for _, profile in ipairs(settings.profiles.deviceSpecificProfiles) do
            if profile.urlWhiteBlackList and profile.urlWhiteBlackList.whiteList then
                for i, allowedURL in ipairs(profile.urlWhiteBlackList.whiteList) do
                    if not isLengthOfURLValid(allowedURL, maxAllowedURLLength) then
                        return 'ErrorAllowedURLTooLong'
                    end
                    counter = counter + 1
                end
                if counter > maxTotalAllowedURLs then
                    return 'ErrorTooManyAllowedURLs'
                end
            end
        end
        err, legacyParentalControlRules = convertToLegacyParentalControl(sc, settings.profiles.deviceSpecificProfiles)
        if err then
            return err
        end
    end

    -- Validate exception lists
    if settings.internetBlockScheduleExceptions and
            settings.internetBlockScheduleExceptions.ignoreScheduleAndBlockMACAddresses and
            settings.internetBlockScheduleExceptions.ignoreScheduleAndAllowMACAddresses then
        for a, j in ipairs(settings.internetBlockScheduleExceptions.ignoreScheduleAndBlockMACAddresses) do
            for b, k in ipairs(settings.internetBlockScheduleExceptions.ignoreScheduleAndAllowMACAddresses) do
                if tostring(j) == tostring(k) then
                    return 'ErrorScheduleExceptionsOverlap'
                end
            end
        end
    end

    _M.fireConfigChangedSysevent(sc, settings)

    return _M.writeConfigurationSettings(sc, settings) or
            parentalcontrol.setRules(sc, legacyParentalControlRules, true)
end

--
-- Get the subscription status
--
-- input = CONTEXT
--
-- output = STRING
--
function _M.getSubscriptionStatus(sc)
    sc:readlock()
    if sc:get_shield_subscriptionstatus() ~= 'active' then
        return 'Inactive'
    else
        return 'Active'
    end
end

--
-- Get information about a backup configuration in the cloud.
--
-- input = CONTEXT
--
-- output = nil, {
--     isBackupAvailable = BOOLEAN,
--     configVersion = OPTIONAL(STRING)
--     configId = OPTIONAL(STRING)
--   }
--   OR_ONE_OF(
--     ErrorNoWANConnection
--     ErrorCloudUnavailable
--   )
--
function _M.getBackupConfigurationInfo(sc)
    local isBackupAvailable = true
    local configId, configVersion
    local device = require('device')
    local cloud = require('cloud')

    -- Ensure no lock is held when making this call as it is blocking
    assert(not sc:isreadlocked() and not sc:iswritelocked(), 'must not hold the sysctx lock when calling getBackupConfigurationInfo')

    local ownedsc = _M.unittest.ctx and _M.unittest.ctx:sysctx() or require('libsysctxlua').new()
    ownedsc:readlock()

    if (ownedsc:get_wan_connection_status() ~= 'started') then
        return 'ErrorNoWANConnection'
    end

    local function getValueForKey(list, key)
        for i = 1, #list do
            if list[i].name == key then
                return list[i].value
            end
        end
    end

    local host = device.getCloudHost(ownedsc)
    local token = device.getLinksysToken(ownedsc)
    local verifyHost = device.getVerifyCloudHost(ownedsc)

    -- Roll back the local ctx before calling the cloud
    ownedsc:rollback()

    local error, configurations = cloud.getConfigurationInfo(host, token, {type = 'NETWORK_SECURITY'}, verifyHost)
    if error then
        if error == 'ErrorConfigurationNotFound' then
            isBackupAvailable = false
        else
            return error
        end
    end
    if isBackupAvailable then
        configVersion = getValueForKey(configurations[1].configKey, 'formatVersion')
    end

    return nil, {
        isBackupAvailable = isBackupAvailable,
        configId = configurations and configurations[1].configurationId,
        configVersion = tonumber(configVersion)
    }
end

--
-- Restores the configuration settings from from the backup configuration in the cloud.
--
-- input = CONTEXT, STRING, STRING
--
-- output = NIL_OR_ONE_OF(
--     ErrorNoWANConnection,
--     ErrorConfigurationNotFound,
--     ErrorInvalidLicenseID,
--     ErrorUnsupportedVersion,
--     ErrorCloudUnavailable
--   )
--
function _M.restoreConfiguration(sc, licenseId, configId)
    -- Ensure no lock is held when making this call as it is blocking
    assert(not sc:isreadlocked() and not sc:iswritelocked(), 'must not hold the sysctx lock when calling restoreConfiguration()')

    local device = require('device')
    local ownedsc = _M.unittest.ctx and _M.unittest.ctx:sysctx() or require('libsysctxlua').new()

    ownedsc:readlock()

    local host = device.getCloudHost(ownedsc)
    local token = device.getLinksysToken(ownedsc)
    local verifyHost = device.getVerifyCloudHost(ownedsc)

    ownedsc:rollback()

    local error, configuration = require('cloud').getConfiguration(host, token, configId, verifyHost)
    if not error then
        error = _M.setLicenseID(sc, licenseId) or
                _M.setConfigurationSettings(sc, deserializeConfigurationSettings(configuration.configValue))
    end

    return error
end

--
-- Get whether the threat detection feature is enabled.
--
-- input = CONTEXT
--
-- output = BOOLEAN
--
function _M.getIsThreatDetectionEnabled(sc)
    sc:readlock()
    return sc:get_shield_threat_detection_enabled()
end

--
-- Set whether the threat detection feature is enabled.
--
-- input = CONTEXT, BOOLEAN
--
function _M.setIsThreatDetectionEnabled(sc, isEnabled)
    sc:writelock()
    sc:set_shield_threat_detection_enabled(isEnabled)
end

--
-- Get whether the malicious website detection feature is enabled.
--
-- input = CONTEXT
--
-- output = BOOLEAN
--
function _M.getIsMaliciousWebsiteDetectionEnabled(sc)
    sc:readlock()
    return sc:get_shield_malwebsite_detection_enabled()
end

--
-- Set whether the malicious website detection feature is enabled.
--
-- input = CONTEXT, BOOLEAN
--
function _M.setIsMaliciousWebsiteDetectionEnabled(sc, isEnabled)
    sc:writelock()
    sc:set_shield_malwebsite_detection_enabled(isEnabled)
end

--
-- Get status of the the threat signature data in firmware.
--
-- input = CONTEXT
--
-- output = DATETIME
--
function _M.getThreatSignatureStatus(sc)
    sc:readlock()

    return {
        signatureDate = hdk.datetime(tonumber(sc:get_shield_threat_signature_timestamp()))
    }
end

--
-- Send the latest threat log files to the cloud
--
-- input = CONTEXT
--
-- output = STRING_OR_ONE_OF(
--     ErrorNoInternetConnection,
--     ErrorUploadFailed
--   )
--
function _M.syncLogFiles(sc)
    -- Ensure no lock is held when making this call as it is blocking
    assert(not sc:isreadlocked() and not sc:iswritelocked(), 'must not hold the sysctx lock when calling this function')
    local ownedsc = require('libsysctxlua').new()

    ownedsc:readlock()
    local internetState = sc:get_icc_internet_state()
    ownedsc:rollback()

    if (internetState ~= 'up') then
        return 'ErrorNoInternetConnection'
    end
    local rc = os.execute(_M.CMD_UPLOAD_THREAT_LOGS)
    if (rc ~= 0) then
        return 'ErrorLogSyncFailed'
    end
end


return _M -- return the module
