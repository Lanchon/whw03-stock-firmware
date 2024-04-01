
--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2020/10/29 22:44:11 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/healthcheck.lua#3 $
--

-- healthcheck.lua - library to access the healthcheck settings.

local platform = require('platform')
local database = require('database')
local hdk = require('libhdklua')

local _M = {}   --create the module

_M.SPEED_TEST                   = 'SpeedTest'
_M.CHANNEL_ANALYZER             = 'ChannelAnalyzer'
_M.DEVICE_SCANNER               = 'DeviceScanner'

_M.SUPPORTED_HEALTHCHECK_MODULES = { _M.SPEED_TEST }

_M.HEALTHCHECK_RESULT_ID        = 'healthcheck::resultID'

local function killSpeedTest(sc)
    local speedtest_running = sc:get_healthcheck_speedtest_is_running()
    if speedtest_running then
        local f = assert(io.popen('ps | grep ookla | grep -v grep', 'r'))
        for line in f:lines() do
            local PID = line:match('(%d+)')
            if PID then
                sc:set_healthcheck_speedtest_is_running(false)
                os.execute('kill -9 '..PID)
            end
        end
        f:close()
    end
end

function _M.seed_10us()
    local socket = require('socket')
    return (socket.gettime() - os.time()) * 100000
end

function _M.getResultID()
    -- os.clock() doesn't work in Node platform and some linux distros version.(Ubuntu 12.04) (It returns 0)
    -- os.clock() uses clock() from time.h which returns used processor time, not time since Lua started.
    -- math.randomseed(os.time() - os.clock() * 1000)
    math.randomseed(os.time() - _M.seed_10us())
    return math.random(10000, 99999)
end

function _M.isSupportedHealthCheckModule(module)
    for _, v in pairs(_M.SUPPORTED_HEALTHCHECK_MODULES) do
        if v == module then
            return true
        end
    end
    return false
end

function _M.getSupportedHealthCheckModules()
    return {
        supportedHealthCheckModules = _M.SUPPORTED_HEALTHCHECK_MODULES;
    }
end

function _M.runHealthCheckModule(sc, input)
    sc:writelock()

    local run_module = input.runHealthCheckModule;
    local result_id = _M.getResultID()
    local speedtest = sc:get_healthcheck_speedtest_status()

    if run_module ~= nil then
        if _M.isSupportedHealthCheckModule(run_module) then
            if run_module == _M.SPEED_TEST and (speedtest == '' or speedtest == 'done' or speedtest == 'license_error' or speedtest == 'execution_error' ) then
                database.saveHealthCheck(result_id)
                database.saveSpeedTest(result_id)
                sc:run_healthcheck_modules(run_module)
                sc:set_healthcheck_result_id(result_id)
            else
                return 'ErrorHealthCheckAlreadyRunning', nil
            end
        else
            return 'ErrorUnsupportedHealthCheckModule', nil
        end
    else
        -- All supported healthcheck modules are running sequentially.
        for _, module in pairs(_M.SUPPORTED_HEALTHCHECK_MODULES) do
            if module == _M.SPEED_TEST and (speedtest == '' or speedtest == 'done' or speedtest == 'license_error' or speedtest == 'execution_error' ) then
                database.saveHealthCheck(result_id)
                database.saveSpeedTest(result_id)
                sc:run_healthcheck_modules(module)
                sc:set_healthcheck_result_id(result_id)
            else
                return 'ErrorHealthCheckAlreadyRunning', nil
            end
        end
    end

    return nil, {
        resultID = result_id
    }
end

function _M.getCurrentModuleStatus(sc, module, status)
    sc:readlock()

    local moduleStatus = {}

    if module == _M.SPEED_TEST then
        moduleStatus = {
            healthCheckModuleCurrentlyRunning = module,
            speedTestResult = {
                resultID = sc:get_healthcheck_result_id(),
                exitCode = status,
                serverID = sc:get_healthcheck_speedtest_serverid(),
                latency = sc:get_healthcheck_speedtest_latency(),
                uploadBandwidth = sc:get_healthcheck_speedtest_upload_bandwidth(),
                downloadBandwidth = sc:get_healthcheck_speedtest_download_bandwidth()
            }
        }
        if status ~= 'Unavailable' then
            sc:setevent(_M.HEALTHCHECK_RESULT_ID) -- unset the sysevent
        end
    elseif module == _M.CHANNEL_ANALYZER then
    elseif module == _M.DEVICE_SCANNER then
    end

    return moduleStatus
end

function _M.getHealthCheckStatus(sc)
    sc:readlock()

    local status
    local current_run_module

    local resultID = sc:get_healthcheck_result_id()

    if resultID == nil or resultID == 0 then
        return {}
    end

    local speedtest = sc:get_healthcheck_speedtest_status()
    if speedtest and speedtest ~= '' then
        current_run_module = _M.SUPPORTED_HEALTHCHECK_MODULES[1]
        if speedtest == 'done' then
            status = 'Success'
        elseif speedtest == 'license_error' then
            status = 'SpeedTestLicenseError'
        elseif speedtest == 'execution_error' then
            status = 'SpeedTestExecutionError'
        elseif speedtest == 'db_error' then
            status = 'DBError'
        else
            status = 'Unavailable'
        end
    end

    return _M.getCurrentModuleStatus(sc, current_run_module, status)
end

--
-- transfer timestamp with string format to datetime type.
-- the string format of input should be "year-month-day hh:mm:ss
--
local function datetimeFromTimeStamp(timestamp)
    local year, month, day, hour, minute, second
    if timestamp then
         year, month, day, hour, minute, second = timestamp:match('^(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
    end
    local currtime = os.date('!*t')

    if year == nil or month == nil or day == nil or hour == nil or minute== nil or second == nil then
        return hdk.datetime(('%04d-%02d-%02dT%02d:%02d:%02dZ'):format(tonumber(currtime.year), tonumber(currtime.month), tonumber(currtime.day), tonumber(currtime.hour), tonumber(currtime.min), tonumber(currtime.sec)))
    else
        -- year = tonumber(month) > currtime.month and (currtime.year - 1) or currtime.year
        return hdk.datetime(('%04d-%02d-%02dT%02d:%02d:%02dZ'):format(tonumber(year), tonumber(month), tonumber(day), tonumber(hour), tonumber(minute), tonumber(second)))
    end
end


function _M.getHealthCheckResults(input)
    local healthCheckResults = {}
    local resultIDs = {}

    if database.isHealthCheckManager() and database.isSpeedTest() then
        if input.healthCheckModule == nil or input.healthCheckModule == _M.SPEED_TEST then
            if input.resultIDs ~= nil then
                resultIDs = input.resultIDs
            else
                if input.lastNumberOfResults then
                    resultIDs = database.getSpeedTestLastNumberOfResultIDs(input.lastNumberOfResults)
                else
                    resultIDs = database.getSpeedTestResultIDs()
                end
            end
            for _, resultID in pairs(resultIDs) do
                local speedTestResult = database.getSpeedTest(resultID)
                local timestamp = database.getHealthCheckTimeStamp(resultID)

                if next(speedTestResult) ~= nil then
                    table.insert(healthCheckResults, {
                        resultID = tonumber(resultID) or 0,
                        timestamp = datetimeFromTimeStamp(timestamp),
                        healthCheckModulesRequested = {_M.SPEED_TEST},
                        speedTestResult = input.includeModuleResults == true and speedTestResult or nil
                    })
                end
            end
        else
            return 'ErrorUnsupportedHealthCheckModule', nil
        end
    end

    return nil, {
        healthCheckResults = healthCheckResults
    }
end

-- Stop the running SpeedTest or other helathcheck modules
function _M.stopHealthCheckModules(sc)
    sc:writelock()

    -- kill the speedtest process if it is running.
    killSpeedTest(sc)
    sc:stop_healthcheck_modules()
end

-- Clear healthcheck databse
function _M.clearHealthCheckHistory()
    database.clearHealthCheckHistory()
end

return _M   -- return the module.
