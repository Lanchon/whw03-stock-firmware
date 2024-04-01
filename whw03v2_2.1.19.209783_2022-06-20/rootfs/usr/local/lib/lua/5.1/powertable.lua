--
-- 2018 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: jianxiao $
-- $DateTime: 2018/05/28 00:12:59 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/powertable.lua#1 $
--

-- powertable.lua - library to configure powertable.

local _M = {} -- create the module

--
-- Get the power table country.
--
-- input = CONTEXT
--
-- output = BOOLEAN
--
function _M.getPowerTableSettings(sc)
    sc:readlock()
    isPowerTableSelectable = sc:get_powertable_is_supported() and sc:get_powertable_is_enabled()
    country = sc:get_powertable_country()
    return {
        isPowerTableSelectable = isPowerTableSelectable,
        country = country ~= '' and country or nil,
        supportedCountries = sc:get_powertable_supportedcountries()
    }
end

--
-- Check whether selected country is supported
--
-- input = STRING, ARRAY_OF(STRING)
--
-- output = BOOLEAN
--
local function isCountrySupported(selectedCountry, supportedCountries)
    for _, value in ipairs(supportedCountries) do
        if selectedCountry == value then
            return true
        end
    end
    return false
end

--
-- Set the power table country.
--
-- input = CONTEXT, STRING
--
function _M.setPowerTableSettings(sc, country)
    sc:writelock()

    if not sc:get_powertable_is_supported() or not sc:get_powertable_is_enabled() then
        return 'ErrorPowerTableLocked'
    end

    if not isCountrySupported(country, sc:get_powertable_supportedcountries()) then
        return 'ErrorInvalidPowerTableCountry'
    end

    sc:set_powertable_country(country)
end

return _M -- return the module
