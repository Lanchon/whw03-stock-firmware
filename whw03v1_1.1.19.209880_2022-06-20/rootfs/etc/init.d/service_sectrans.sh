#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="sectrans"
BIN_SERVICE_NAME="sectrans_server"
SECTRANS_LOGIN_DEFAULT="sectrans"
SECTRANS_PORT_DEFAULT=13100
_start_sectrans_server ()
{
    echo "${SERVICE_NAME} _start_sectrans_server"
}
_stop_sectrans_server ()
{
    STATUS="$(ps | grep ${BIN_SERVICE_NAME} | grep -v grep | grep -v service_${SERVICE_NAME})"
    if [ -n "${STATUS}" ] ; then
        killall ${BIN_SERVICE_NAME}
    fi
    sleep 3
    PID="$(ps | grep -v service_${SERVICE_NAME} | grep -v grep | grep ${BIN_SERVICE_NAME} | grep -o '^[ ]*[0-9]*')"
    if [ ! -z "$PID" ] ; then
        kill -9 ${PID}
    fi
}
_init ()
{
    if [ "`syscfg get sectrans::login`" == "" ]; then
        syscfg set sectrans::login "$SECTRANS_LOGIN_DEFAULT"
    fi
    if [ "`syscfg get sectrans::port`" == "" ]; then
        syscfg set sectrans::port $SECTRANS_PORT_DEFAULT
    fi
}
_start ()
{
    wait_till_end_state ${SERVICE_NAME}
    if [ "`syscfg get smart_mode::mode`" = "2" ] ; then
        echo "sectrans, we're master node"
        LOGIN_STR=`syscfg get sectrans::login`
        SECRET_STR=`syscfg get smart_connect::configured_vap_passphrase`
        STATUS="$(ps | grep ${BIN_SERVICE_NAME} | grep -v grep | grep -v service_${SERVICE_NAME})"
        if [ -z "$STATUS" ] ; then
            ${BIN_SERVICE_NAME} -s$SECRET_STR -l$LOGIN_STR -d
        else
            echo "${SERVICE_NAME} is running"
        fi
    else
        echo "sectrans, we're slave node"
    fi
    sysevent set ${SERVICE_NAME}-status started
    ulog ${SERVICE_NAME} status "now started"
}
_stop ()
{
    wait_till_end_state ${SERVICE_NAME}
    STATUS=`sysevent get ${SERVICE_NAME}-status`
    if [ "$STATUS" = "started" ]
    then
        _stop_sectrans_server
        check_err $? "Couldnt handle stop"
        sysevent set ${SERVICE_NAME}-status stopped
        ulog ${SERVICE_NAME} status "now stopped"
    fi
}
_init
case "$1" in
    ${SERVICE_NAME}-start)
        _start
        ;;
    ${SERVICE_NAME}-stop)
        _stop
        ;;
    ${SERVICE_NAME}-restart)
        _stop
        _start
        ;;
    lan-started)
        _stop
        _start
        ;;
    *)
        echo "error : $1 unknown" > /dev/console
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
        exit 3
        ;;
esac
