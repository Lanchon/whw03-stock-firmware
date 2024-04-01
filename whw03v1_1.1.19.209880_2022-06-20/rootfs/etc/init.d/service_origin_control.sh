#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="origin_control"
SOUNDER_CONF="/tmp/sounder.conf"
SMART_MODE="`syscfg get smart_mode::mode`"
service_start ()
{
	wait_till_end_state ${SERVICE_NAME}
    if [ -f "$SOUNDER_CONF" ]; then
        topology_gen $SOUNDER_CONF
        check_err $? "Can't generate location_topology"
    fi
    LOG_FILE=`syscfg get origin_control_show_debug`
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" -o -c "$LOG_FILE" ]; then
        $SERVICE_NAME >$LOG_FILE 2>&1 &
    else
        $SERVICE_NAME >/dev/null 2>&1 &
    fi
    check_err $? "Couldnt handle start"
    sysevent set ${SERVICE_NAME}-status started
    ulog ${SERVICE_NAME} status "now started"
    cp /etc/origin/gai.conf /tmp/
    sed -i 's%#precedence ::ffff:0:0/96  100%precedence ::ffff:0:0/96  100%g' /tmp/gai.conf
}
service_stop ()
{
    wait_till_end_state ${SERVICE_NAME}
    STATUS=`sysevent get ${SERVICE_NAME}-status`
    if [ "$STATUS" = "started" ]
    then
        killall $SERVICE_NAME
	    check_err $? "Couldnt handle stop"
        sysevent set ${SERVICE_NAME}-status stopped
	    ulog ${SERVICE_NAME} status "now stopped"
        if [ -f /tmp/gai.conf ]; then
            sed -i 's%precedence ::ffff:0:0/96  100%#precedence ::ffff:0:0/96  100%g' /tmp/gai.conf
        fi
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
    origin-status)
        if [ "$SMART_MODE" == "2" ] ; then
            if [ "$2" = "started" ]
            then
                service_stop
                service_start
            elif [ "$2" = "stopped" ]
            then
                service_stop
            fi
        fi
        ;;
    devicedb-backup)
        sleep 1
        kill -USR1 $(pidof $SERVICE_NAME)
        ;;
    *)
		echo "error : $1 unknown" > /dev/console
		echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		exit 3
		;;
esac
