#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME=ddd_ethernet_agent
BIN_NAME=$SERVICE_NAME
APP_NAME=/usr/sbin/$BIN_NAME
PID_FILE=/var/run/$BIN_NAME.pid
PMON=/etc/init.d/pmon.sh
PMON_RESTART_CMD="/etc/init.d/service_$SERVICE_NAME.sh $SERVICE_NAME-restart"
DEFAULT_UDSPATH=/tmp/ddd/uds_s
service_start ()
{
    wait_till_end_state ${SERVICE_NAME}
    local STATUS=`sysevent get ${SERVICE_NAME}-status`
    if [ "$STATUS" != "started" ]; then
        sysevent set ${SERVICE_NAME}-errinfo 
        sysevent set ${SERVICE_NAME}-status starting
        echo "Starting ${SERVICE_NAME} ... "
        $APP_NAME -d
        check_err_exit "$?" "Unable to start"
        sysevent set ${SERVICE_NAME}-status started
        local pid=`pgrep $BIN_NAME`
        echo $pid > $PID_FILE
        $PMON setproc $SERVICE_NAME $BIN_NAME $PID_FILE "$PMON_RESTART_CMD"
    fi
}
service_stop ()
{
  wait_till_end_state ${SERVICE_NAME}
  local STATUS=`sysevent get ${SERVICE_NAME}-status`
  if [ "$STATUS" != "stopped" ] ; then
    sysevent set ${SERVICE_NAME}-errinfo 
    sysevent set ${SERVICE_NAME}-status stopping
    echo "Stopping ${SERVICE_NAME} ... "
    rm -rf $PID_FILE
    $PMON unsetproc $SERVICE_NAME
    killall $BIN_NAME
    sysevent set ${SERVICE_NAME}-status stopped
  fi
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
    devicedb-ready)
        STATUS=`sysevent get ${SERVICE_NAME}-status`
        if [ ! -z "$STATUS" ] ; then
            service_stop
        fi
        service_start
        ;;
    *)
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart | devicedb-ready]" > /dev/console
        exit 3
        ;;
esac
