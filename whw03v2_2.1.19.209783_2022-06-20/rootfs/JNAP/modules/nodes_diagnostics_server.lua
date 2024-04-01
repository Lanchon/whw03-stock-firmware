--
-- 2018 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--

local function UploadSysinfoData(ctx, input)
    local ndiag = require("nodes_diagnostics")
    local sc = ctx:sysctx()

    local error, output = ndiag.uploadSysinfoData(sc, input)

    return error or 'OK', output
end

local function GetBackhaulInfo(ctx, input)
    local ndiag = require("nodes_diagnostics")
    local sc = ctx:sysctx()
    local error, output = ndiag.getBackhaulDeviceInfo(sc)

    return error or 'OK', output
end

local function GetNodeNeighborInfo(ctx, input)
    local ndiag = require("nodes_diagnostics")
    local sc = ctx:sysctx()
    local error, output = ndiag.getNodeNeighborDevices(sc)

    return error or 'OK', output
end

local function SetWiFiClientSiteSurveyInfo(ctx, input)
    local ndiag = require("nodes_diagnostics")
    local sc = ctx:sysctx()
    local error = ndiag.setWiFiClientSiteSurveyInfo(sc, input)

    return error or 'OK'
end

local function GetSlaveBackhaulStatus(ctx, input)
    local ndiag = require("nodes_diagnostics")
    local sc = ctx:sysctx()

    -- Register the logging callback for this call.
    require('platform').registerLoggingCallback(function(level, message) ctx:serverlog(level, message) end)

    local error, output = ndiag.getSlaveBackhaulStatus(sc, input)

    return error or 'OK', output
end

local function RefreshSlaveBackhaulData(ctx, input)
    local ndiag = require("nodes_diagnostics")
    local sc = ctx:sysctx()

    -- Register the logging callback for this call.
    require('platform').registerLoggingCallback(function(level, message) ctx:serverlog(level, message) end)

    local error = ndiag.refreshSlaveBackhaulData(sc, input)

    return error or 'OK'
end


return require('libhdklua').loadmodule('jnap_nodes_diagnostics'), {
    ['http://linksys.com/jnap/nodes/diagnostics/UploadSysinfoData'] = UploadSysinfoData,
    ['http://linksys.com/jnap/nodes/diagnostics/GetBackhaulInfo'] = GetBackhaulInfo,
    ['http://linksys.com/jnap/nodes/diagnostics/GetNodeNeighborInfo'] = GetNodeNeighborInfo,
    ['http://linksys.com/jnap/nodes/diagnostics/SetWiFiClientSiteSurveyInfo'] = SetWiFiClientSiteSurveyInfo,
    ['http://linksys.com/jnap/nodes/diagnostics/GetSlaveBackhaulStatus'] = GetSlaveBackhaulStatus,
    ['http://linksys.com/jnap/nodes/diagnostics/RefreshSlaveBackhaulData'] = RefreshSlaveBackhaulData
}
