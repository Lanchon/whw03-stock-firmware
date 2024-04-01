--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2020/05/13 16:11:22 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/lualib/database.lua#3 $
--

-- database.lua - wrapper library to access node.db sqlite3 database through lsqlite3 binding module.

local sqlite3 = require('lsqlite3')
local platform = require('platform')
local lfs = require('lfs')

local _M = {} -- create the module

-- Check if input pin is existed in server.sql(MASTER) or not.
-- Output = true or false
function _M.isPinExistInMaster(pin)
    local smc_db_path = "/tmp/var/config/smartconnect/server.sql"
    local db = sqlite3.open(smc_db_path)

    if db == nil then
        return false
    end

    local sql = "SELECT * FROM devices WHERE pin='"..pin.."'"

    for row in db:nrows(sql) do
        if pin == row.pin then
            db:close()
            return true
        end
    end

    db:close()
    return false
end

-- Check if user AP wifi credential are existed in client.sql or not.
-- Output = true or false
function _M.isUserWifiExistInSlave()
    local smc_db_path = "/tmp/var/config/smartconnect/client.sql"
    local db = sqlite3.open(smc_db_path)

    if db == nil then
        return false
    end

    local sql = "SELECT * FROM wifi_list"

    for row in db:nrows(sql) do
        if row.ssid then
            db:close()
            return true
        end
    end

    db:close()
    return false
end

--
-- Open a Node Database
--
-- input = none
--
-- output = db : If the call succeeds , nil : If the call fails.
--
function _M.openNodeDB()
    -- Check if /var/config/node directory is existed, if not exists, create a directory.
    local node_path = "/tmp/var/config/node"
    local node_db_path = "/tmp/var/config/node/node.db"

    local cd = lfs.currentdir()
    local success = lfs.chdir(node_path)

    -- If node_path is not existed, success is false
    if not success then
        success = lfs.mkdir(node_path)
    end

    lfs.chdir(cd)

    if not success then
        return nil
    end

    return sqlite3.open(node_db_path)
end

function _M.isHealthCheckManager()
    local db = _M.openNodeDB()
    if db == nil then
        return false
    end

    local count = 0
    local cnt = 0
    local res = {}
    local sql = "SELECT count(*) FROM sqlite_master WHERE type='table' and name='HealthCheckManager'"

    for row in db:nrows(sql) do
        if row then
            res = row
            break
        end
    end

    db:close()

    for k, v in pairs(res) do
        count = count + 1
        if k == 'count(*)' then
            cnt = v
        end
    end

    if count == 0 or cnt == 0 then
        return false
    end

    if cnt == 1 then
        return true
    end
end

function _M.isSpeedTest()
    local db = _M.openNodeDB()
    if db == nil then
        return false
    end

    local count = 0
    local cnt = 0
    local res = {}
    local sql = "SELECT count(*) FROM sqlite_master WHERE type='table' and name='SpeedTest'"

    for row in db:nrows(sql) do
        if row then
            res = row
            break
        end
    end

    db:close()

    for k, v in pairs(res) do
        count = count + 1
        if k == 'count(*)' then
            cnt = v
        end
    end

    if count == 0 or cnt == 0 then
        return false
    end

    if cnt == 1 then
        return true
    end
end

function _M.getHealthCheckTimeStamp(resultID)
    local db = _M.openNodeDB()
    if db == nil then
        return 'ErrorOpenDB'
    end

    local timestamp
    local sql = "SELECT timestamp FROM HealthCheckManager WHERE resultID ='"..resultID.."'"

    for row in db:nrows(sql) do
        if row then
            timestamp = row.timestamp
            break
        end
    end

    db:close()
    return timestamp
end

function _M.getSpeedTest(resultID)
    local db = _M.openNodeDB()
    if db == nil then
        return 'ErrorOpenDB'
    end

    local speedTest = {}
    local sql = "SELECT * FROM SpeedTest WHERE resultID ='"..resultID.."'"

    for row in db:nrows(sql) do
        if row then
            speedTest = {
                resultID = tonumber(row.resultID) or 0,
                exitCode = row.exitCode or 'Unavailable',
                serverID = row.serverID,
                latency = tonumber(row.latency) or 0,
                uploadBandwidth = tonumber(row.uploadBandwidth) or 0,
                downloadBandwidth = tonumber(row.downloadBandwidth) or 0
            }
            break
        end
    end

    db:close()
    return speedTest
end

function _M.getSpeedTestResultIDs()
    local db = _M.openNodeDB()
    if db == nil then
        return 'ErrorOpenDB'
    end

    local resultIDs = {}
    local sql = "SELECT resultID from SpeedTest"

    for row in db:nrows(sql) do
        if row then
            table.insert(resultIDs, row.resultID)
        end
    end

    db:close()
    return resultIDs
end

function _M.getSpeedTestLastNumberOfResultIDs(lastNumberOfResults)
    local db = _M.openNodeDB()
    if db == nil then
        return 'ErrorOpenDB'
    end

    local resultIDs = {}
    local sql = "SELECT * from HealthCheckManager ORDER BY timestamp DESC Limit "..lastNumberOfResults..";"

    for row in db:nrows(sql) do
        if row then
            table.insert(resultIDs, row.resultID)
        end
    end

    db:close()
    return resultIDs
end

function _M.clearHealthCheckHistory()
    local db = _M.openNodeDB()
    if db == nil then
        return 'ErrorOpenDB'
    end

    local sql = "DELETE FROM HealthCheckManager;"
    db:exec(sql)

    sql = "DELETE FROM SpeedTest;"
    db:exec(sql)

    db:close()
end

function _M.saveHealthCheck(resultID)
    local db = _M.openNodeDB()

    if db == nil then
        return 'ErrorOpenDB'
    end

    local sql = "CREATE TABLE IF NOT EXISTS HealthCheckManager (resultID INTEGER PRIMARY KEY NOT NULL, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, healthCheckModules TEXT)"
    db:exec(sql)

    sql = "INSERT INTO HealthCheckManager (resultID, healthCheckModules) VALUES ('"..resultID.."','SpeedTest');"
    local success = db:exec(sql)

    db:close()

    if success ~= sqlite3.OK then
        return 'ErrorSaveDB'
    end
end

function _M.saveSpeedTest(resultID)
    local db = _M.openNodeDB()

    if db == nil then
        return 'ErrorOpenDB'
    end

    local sql = "CREATE TABLE IF NOT EXISTS SpeedTest (resultID INTEGER PRIMARY KEY NOT NULL, exitCode TEXT, serverID TEXT, latency INTEGER, uploadBandwidth INTEGER, downloadBandwidth INTEGER)"
    db:exec(sql)

    sql = "INSERT INTO SpeedTest (resultID, exitCode, serverID, latency, uploadBandwidth, downloadBandwidth) VALUES ('"..resultID.."','Unavailable','0',0,0,0);"
    local success = db:exec(sql)

    db:close()

    if success ~= sqlite3.OK then
        return 'ErrorSaveDB'
    end
end

--
-- Get the RTT value from the rtt client tool and save it to the node.db with timestamp
--
-- input = CONTEXT
--
-- output = STRING
--
-- syscfg get rtt::portno (default port = 13131)
-- syscfg get rtt::serverip (default server ip = 192.168.1.1)

--[[
    == How to start a rtt_client on Master Node ==

    # Case1 : rtt_serevr runs on the Master, rtt_client runs on the Slave
    As of now, rtt_server is running on the Master Node and JNAP which can trigger action to execute rtt_client is called in Master JNAP CGI.
    So, it need to tigger an event to run rtt_client on Slave Node.

    * prerequisite *
    Master node has the ip address of the all slave node.

    ======================================================================================================
    On slave node, we need to register handler to receive the sysevent name for running rtt_client.
    (e.g.)
    sysevent name    : 'rtt_client_run'
    sysevent handler : '/tmp/rtt_client_handler.sh'
    'sysevent async rtt_client_run /tmp/rtt_client_handler.sh'

    << rtt_client_handler.sh $1 : sysevent name("rtt_client_run"), $2 : sysevent value("192.168.1.1:13131") >>
    #!/bin/sh
    if [ "$1" == "rtt_client_run" ] ; then
        SERVER_IP=`echo $2 | awk -F":" '{print $1]'`
        SERVER_PORT=`echo $2 | awk -F":" '{print $2}'`
        rtt_client $SERVER_IP $SERVER_PORT
    fi

    rtt_client output : Round time trip in 469 microseconds
    ======================================================================================================

    ======================================================================================================
    On master node, we need to know the slave node's ip address to run a rtt_client on slave node.
    (e.g.) : Slave node's ip address : 192.168.1.148
             sysevent name : rtt_client_run
             sysevent value : "rtt_server_ip_address:port"
             rtt_server_ip_address : 192.168.1.1
             rtt_server_port : 13131
    'sysevent --ip 192.168.1.148 set rtt_client_run "192.168.1.1:13131"'

    << rtt_server displays the below information. >>
    Peer IP address: 192.168.1.148
    192.168.1.148 (192.168.1.148) -> mac_addr: C0:56:27:16:A8:26
    --tcp_info--
    pmtu: 1500
    rcv_ssthresh: 14480
    rtt: 10000
    rtt_var: 7500
    snd_ssthread: 2147483647
    snd_cwnd: 10
    advmss: 1448
    reordering: 3
    get successful interface: eth1
    interface eth1 is not wireless.
    The json object created (length: 357):

    {
        "rtt_info": {
            "rtt_rtt": 469,
            "timeval": {
                "tv_sec": 1461841725, "tv_usec": 957726
            }
        },
        "client_info": {
            "conn_type": "Wired",
            "mac_addr": "C0:56:27:16:A8:26"
        },
        "tcp_metrics": {
                "tcpi_rtt": 10000,
                "tcpi_advmss": 1448,
                "tcpi_rcv_ssthresh": 14480,
                "tcpi_pmtu": 1500,
                "tcpi_rttvar": 7500,
                "tcpi_snd_cwnd": 10,
                "tcpi_snd_ssthresh": 2147483647,
                "tcpi_reordering": 3
        }
    }

    If RTT server can save the above JSON data, JNAP module can load the JSON data and then use them in the database module.
    ======================================================================================================

    # Case2 : rtt_serevr runs on the Slave, rtt_client runs on the Master
    On the other hand, in case #2, the rtt_server is running on the Slave and rtt_client is running on the Naster.
    In this case, I think trigger event does not need to run rtt_client.

    * prerequisite *
    Master node has the ip address of the all slave node.

    ======================================================================================================
    On master node, we need to know the slave node's ip address to connect rtt_server of slave node.
    Just call "rtt_client rtt_server_ip rtt_server_port" in the below code --> saveRTT(sc).

    The rtt_client uses a result JSON data internally, so if rtt_client can save it to file, JNAP module can load the JSON data and use them in database.
    ======================================================================================================

    ======================================================================================================
    On slave node, just run rtt_server.
    ======================================================================================================

    I think case #2 is a simple way to avoid having to use a trigger event to run rtt_client on slave node.
]]

_M.RTT_CLIENT_CMD = 'rtt_client server_ip server_port'

function _M.saveRTT(sc)
    sc:writelock()

    os.execute(_M.RTT_CLIENT_CMD)

    -- If RTT clinet can save the result JSON data to the specific directory such as "/tmp/rtt", we can use the json data in the database module.

    -- Check and Load RTT JSON data.
    local conn_type
    local mac_address
    local rtt
    local timestamp

    -- Open the node.db
    local db = _M.openNodeDB()

    if db == nil then
        return 'ErrorOpenDB'
    end

    local sql = "CREATE TABLE IF NOT EXISTS rtt_info (conn_type TEXT, mac_address TEXT, rtt TEXT , sqltime TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL);"
    db:exec(sql)

    -- If sqltime is omitted in INSERT statement, it will add the current timestamp to the table. (2016-04-29 08:55:59)
    sql = "INSERT INTO rtt_info (conn_type, mac_address, rtt) VALUES ('"..conn_type.."','"..mac_address.."','"..rtt.."');"

    -- sql = "INSERT INTO rtt_info (conn_type, mac_address, rtt, sqltime) VALUES ('"..conn_type.."','"..mac_address.."','"..rtt.."','"..timestamp.."');"
    local success = db:exec(sql)

    db:close()

    if success ~= sqlite3.OK then
        return 'ErrorSaveRTT'
    end
end

function _M.getRTT(sc)
    sc:readlock()

    -- Open the node.db
    local db = _M.openNodeDB()

    if db == nil then
        return 'ErrorOpenDB'
    end

    local rtt = nil

    for rtt_val in db:urows('SELECT rtt FROM rtt_info ORDER BY sqltime DESC') do
        rtt = rtt_val
        break
    end

    db:close()
    return rtt
end

function _M.saveRSSI(sc)
    sc:writelock()

    local rssi
    local timestamp

    local db = _M.openNodeDB()

    if db == nil then
        return 'ErrorOpenDB'
    end

    local sql = "CREATE TABLE IF NOT EXISTS rssi_info (rssi, sqltime TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL);"
    db:exec(sql)

    -- If sqltime is omitted in INSERT statement, it will add the current timestamp to the table. (2016-04-29 08:55:59)
    sql = "INSERT INTO rtt_info (conn_type, mac_address, rtt) VALUES ('"..conn_type.."','"..mac_address.."','"..rtt.."');"

    -- sql = "INSERT INTO rssi_info (rssi, sqltime) VALUES ('"..rssi.."','"..timestamp.."');"
    local success = db:exec(sql)

    db:close()

    if success ~= sqlite3.OK then
        return 'ErrorSaveRSSI'
    end
end

return _M -- return the module
