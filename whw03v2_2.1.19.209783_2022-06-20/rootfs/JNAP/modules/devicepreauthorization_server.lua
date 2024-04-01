--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function AddPreauthorizedDevices(ctx, input)
    local preauth = require('devicepreauthorization')
    local sc = ctx:sysctx()

    local error = preauth.addPreauthorizedDevices(sc, input)

    return error or 'OK'
end

local function GetPreauthorizedDevices(ctx)
    local preauth = require('devicepreauthorization')
    local sc = ctx:sysctx()

    local error, output = preauth.getPreauthorizedDevices(sc, input)

    return error or 'OK', output
end

local function OnboardWiFiPreauthorizedDevices(ctx)
    local preauth = require('devicepreauthorization')
    local sc = ctx:sysctx()

    local error = preauth.onboardWiFiPreauthorizedDevices(sc)

    return error or 'OK'
end

local function GetOnboardWiFiPreauthorizedStatus(ctx)
    local preauth = require('devicepreauthorization')
    local sc = ctx:sysctx()

    local error, output = preauth.getOnboardWiFiPreauthorizedStatus(sc)

    return error or 'OK', output
end

return require('libhdklua').loadmodule('jnap_devicepreauthorization'), {
    ['http://linksys.com/jnap/devicepreauthorization/AddPreauthorizedDevices'] = AddPreauthorizedDevices,
    ['http://linksys.com/jnap/devicepreauthorization/GetPreauthorizedDevices'] = GetPreauthorizedDevices,
    ['http://linksys.com/jnap/devicepreauthorization/OnboardWiFiPreauthorizedDevices'] = OnboardWiFiPreauthorizedDevices,
    ['http://linksys.com/jnap/devicepreauthorization/GetOnboardWiFiPreauthorizedStatus'] = GetOnboardWiFiPreauthorizedStatus
}
