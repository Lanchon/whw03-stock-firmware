--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function RequestSmartConnectSurvey(ctx)
    local xconn = require('xconnect')
    local sc = ctx:sysctx()

    local error = xconn.requestSmartConnectSurvey(sc)

    return error or 'OK'
end

local function GetSmartConnectSurveyResult(ctx)
    local xconn = require('xconnect')
    local sc = ctx:sysctx()

    local error, output = xconn.getSmartConnectSurveyResult(sc)

    return error or 'OK', output
end

local function GetSmartConnectNextResult(ctx)
    local xconn = require('xconnect')
    local sc = ctx:sysctx()

    local error, output = xconn.getSmartConnectNextResult(sc)

    return error or 'OK', output
end

local function RequestOnboardSmartConnectClient(ctx, input)
    local xconn = require('xconnect')
    local sc = ctx:sysctx()

    local error = xconn.requestOnboardSmartConnectClient(sc, input)

    return error or 'OK'
end

local function GetOnboardSmartConnectClientStatus(ctx)
    local xconn = require('xconnect')
    local sc = ctx:sysctx()

    local error, output = xconn.getOnboardSmartConnectClientStatus(sc)

    return error or 'OK', output
end


return require('libhdklua').loadmodule('jnap_xconnect'), {
    ['http://linksys.com/jnap/xconnect/RequestSmartConnectSurvey'] = RequestSmartConnectSurvey,
    ['http://linksys.com/jnap/xconnect/GetSmartConnectSurveyResult'] = GetSmartConnectSurveyResult,
    ['http://linksys.com/jnap/xconnect/GetSmartConnectNextResult'] = GetSmartConnectNextResult,
    ['http://linksys.com/jnap/xconnect/RequestOnboardSmartConnectClient'] = RequestOnboardSmartConnectClient,
    ['http://linksys.com/jnap/xconnect/GetOnboardSmartConnectClientStatus'] = GetOnboardSmartConnectClientStatus
}
