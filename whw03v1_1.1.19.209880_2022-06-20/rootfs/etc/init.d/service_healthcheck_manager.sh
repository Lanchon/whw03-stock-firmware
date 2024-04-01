#!/bin/sh
source /etc/init.d/ulog_functions.sh
SERVICE_NAME="healthcheck_manager"
SPEED_TEST="SpeedTest"
CHANNEL_ANALYZER="ChannelAnalyzer"
DEVICE_SCANNER="DeviceScanner"
NODE_DB="/var/config/node/node.db"
service_start ()
{
   wait_till_end_state ${SERVICE_NAME}
   STATUS=`sysevent get ${SERVICE_NAME}-status`
   if [ "started" != "$STATUS" ] ; then
      sysevent set ${SERVICE_NAME}-errinfo
      sysevent set ${SERVICE_NAME}-status started
   fi
}
service_stop ()
{
   wait_till_end_state ${SERVICE_NAME}
   STATUS=`sysevent get ${SERVICE_NAME}-status`
   if [ "stopped" != "$STATUS" ] ; then
      sysevent set ${SERVICE_NAME}-errinfo
      sysevent set ${SERVICE_NAME}-status stopped
   fi
}
run_sql_db()
{
    DB="$1"
    SQL="$2"
    if [ -n "$DB" -a -n "$SQL" ]; then
        if [ ! -f "$DB" ]; then
            mkdir -p `dirname $DB`
            touch $DB
            /bin/sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS SpeedTest (resultID INTEGER PRIMARY KEY NOT NULL, exitCode TEXT, serverID TEXT, latency INTEGER, uploadBandwidth INTEGER, downloadBandwidth INTEGER)"
        fi
        /bin/sqlite3 "$DB" "$SQL"
    else
        (exit 1)
    fi
}
wait_qos_finished()
{
    secs=10
    endTime=$(( $(date +%s) + secs ))
    while [ $(date +%s) -lt $endTime ]; do
        QOS_STATUS=`sysevent get qos-status`
        echo "QOS" $QOS_STATUS > /dev/console
        if [ "$QOS_STATUS" = "started" -o "$QOS_STATUS" = "stopped" ]; then
            echo "Success in wait_qos_finished" > /dev/console
            sleep 1
            return 1
        fi
        sleep 2
    done
    echo "Timeout in wait_qos_finished" > /dev/console
    return 0
}
run_speed_test()
{
    RET=0
    EXITCODE="Unavailable"
    SERVERID=0
    LATENCY=0
    UPLOAD_SPEED=0
    DOWNLOAD_SPEED=0
    wan_interface="`syscfg get wan_physical_ifname`"
    cd /bin/ookla
    sysevent set healthcheck::speedtest start
    sysevent set healthcheck::serverid "$SERVERID"
    sysevent set healthcheck::latency "$LATENCY"
    sysevent set healthcheck::upload_speed "$UPLOAD_SPEED"
    sysevent set healthcheck::download_speed "$DOWNLOAD_SPEED"
    sysevent set speedtest::running 1
    if [ ! -z $wan_interface ] ; then
        ethtool -K $wan_interface gro on
        ethtool -K $wan_interface tso on
    fi
    wait_qos_finished
    ./ookla | while read LOGLINE
    do
        echo "$LOGLINE" > /dev/console
        if echo "$LOGLINE" | grep "NoLicenseKey" -q; then
            sysevent set healthcheck::speedtest license_error
            break
        fi
        if echo "$LOGLINE" | grep "LICENSE_ERROR" -q; then
            sysevent set healthcheck::speedtest license_error
            break
        fi
        if echo "$LOGLINE" | grep "^serverid:" -q; then
            SERVERID=$(echo "$LOGLINE" | awk -F' ' '{print $2}')
            echo "$SERVERID" > /dev/console
            sysevent set healthcheck::serverid "$SERVERID"
        elif echo "$LOGLINE" | grep "^latency:" -q; then
            LATENCY=$(echo "$LOGLINE" | awk -F' ' '{print $2}')
            echo "$LATENCY" > /dev/console
            if [ -n "$(echo $LATENCY | sed -n "/^[0-9]\+$/p")" ]; then
                sysevent set healthcheck::latency "$LATENCY"
            else
                sysevent set healthcheck::latency 0
            fi
            sysevent set healthcheck::speedtest downloading
        elif echo "$LOGLINE" | grep "^download:" -q; then
            DOWNLOAD_SPEED=$(echo "$LOGLINE" | awk -F' ' '{print $2}')
            echo "$DOWNLOAD_SPEED" > /dev/console
            if [ -n "$(echo $DOWNLOAD_SPEED | sed -n "/^[0-9]\+$/p")" ]; then
                sysevent set healthcheck::download_speed "$DOWNLOAD_SPEED"
            else
                sysevent set healthcheck::download_speed 0
            fi
            sysevent set healthcheck::speedtest uploading
        elif echo "$LOGLINE" | grep "^upload:" -q; then
            UPLOAD_SPEED=$(echo "$LOGLINE" | awk -F' ' '{print $2}')
            echo "$UPLOAD_SPEED" > /dev/console
            if [ -n "$(echo $UPLOAD_SPEED | sed -n "/^[0-9]\+$/p")" ]; then
                sysevent set healthcheck::upload_speed "$UPLOAD_SPEED"
            else
                sysevent set healthcheck::upload_speed 0
            fi
            break
        else
            echo "$LOGLINE" > /dev/console
            if echo "$LOGLINE" | grep "connect timeout" -q; then
                sysevent set healthcheck::speedtest connecting
            fi
        fi
    done
    RET=$?
    if [ "$RET" = "0" ]; then
        sysevent set healthcheck::speedtest done
    else
        sysevent set healthcheck::speedtest execution_error
    fi
    echo "Exit parsing loop..." > /dev/console
    SPEED_TEST=`sysevent get healthcheck::speedtest`
    SERVERID=`sysevent get healthcheck::serverid`
    LATENCY=`sysevent get healthcheck::latency`
    DOWNLOAD_SPEED=`sysevent get healthcheck::download_speed`
    UPLOAD_SPEED=`sysevent get healthcheck::upload_speed`
    echo "Speed Test " "$SPEED_TEST" > /dev/console
    speedtest_running=`sysevent get speedtest::running`
    if [ "$speedtest_running" = "0" ]; then
        sysevent set healthcheck::speedtest done
        EXITCODE="AbortedByUser"
    else
        if [ "$SPEED_TEST" = "license_error" ]; then
            EXITCODE="SpeedTestLicenseError"
        elif [ "$SPEED_TEST" = "done" ]; then
            if [ "$DOWNLOAD_SPEED" != "0" ] && [ "$UPLOAD_SPEED" != "0" ]; then
                EXITCODE="Success"
            else
                sysevent set healthcheck::speedtest execution_error
                EXITCODE="SpeedTestExecutionError"
            fi
        else
            sysevent set healthcheck::speedtest execution_error
            EXITCODE="SpeedTestExecutionError"
        fi
    fi
    run_sql_db $NODE_DB "UPDATE SpeedTest SET exitCode='$EXITCODE', serverID='$SERVERID', latency='$LATENCY', uploadBandwidth='$UPLOAD_SPEED', downloadBandwidth='$DOWNLOAD_SPEED' WHERE resultID='$1';"
    RET=$?
    if [ ! -z $wan_interface ] ; then
        ethtool -K $wan_interface gro off
        ethtool -K $wan_interface tso off
    fi
    sysevent set speedtest::running 0
    if [ "$RET" = "1" ]; then
        sysevent set healthcheck::speedtest db_error
        (exit 1)
    fi
}
run_channel_analyzer()
{
    echo "Run channel analyzer"
}
run_device_scanner()
{
    echo "Run device scanner"
}
stop_speed_test()
{
    echo "Stop speed test"
    sysevent set healthcheck::resultID
    sysevent set healthcheck::speedtest done
}
stop_channel_analyzer()
{
    echo "Stop channel analyzer"
}
stop_device_scanner()
{
    echo "Stop device scanner"
}
case "$1" in
    ${SERVICE_NAME}-start)
        service_start
        ;;
    ${SERVICE_NAME}-stop)
        service_stop
        ;;
    ${SERVICE_NAME}-restart)
        service_stop
        service_start
        ;;
    healthcheck::modules_to_run)
        ulog healthcheck manager "HealthCheck service is starting: $1  $2 ..."
        HEALTHCHECK_MODULE=`sysevent get healthcheck::modules_to_run`
        RESULT_ID=`sysevent get healthcheck::resultID`
        ulog healthcheck manager "Run to modules = $HEALTHCHECK_MODULE"
        if [ "$HEALTHCHECK_MODULE" = "$SPEED_TEST" ]; then
            run_speed_test $RESULT_ID
        fi
        if [ "$HEALTHCHECK_MODULE" = "$CHANNEL_ANALYZER" ]; then
            run_channel_analyzer
        fi
        if [ "$HEALTHCHECK_MODULE" = "$DEVICE_SCANNER" ]; then
            run_device_scanner
        fi
        ;;
    healthcheck::modules_to_stop)
        stop_speed_test
        stop_channel_analyzer
        stop_device_scanner
        ;;
    *)
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
        exit 3
        ;;
esac
