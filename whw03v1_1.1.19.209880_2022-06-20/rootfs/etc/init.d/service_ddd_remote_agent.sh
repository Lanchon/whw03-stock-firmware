#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME=ddd_remote_agent
BIN_NAME=$SERVICE_NAME
APP_NAME=/usr/sbin/$BIN_NAME
WLAN_TOPIC=`omsg-conf -a=event WLAN_subdev`
ETH_TOPIC=`omsg-conf -a=event ETH_subdev`
DEFAULT_UDSPATH=/tmp/ddd/uds_s
wlan_data_handler()
{
    local WLAN_FILE=`sysevent get $WLAN_TOPIC`
    if [ -f "$WLAN_FILE" ]; then
		VERIFY_MASTER=`echo "$WLAN_FILE" | grep "master"`
		if [ -n "$VERIFY_MASTER" ]; then
			echo "Don't need to get wlan data of ${SERVICE_NAME} ... " > /dev/console
			exit 3
		fi
        echo "Starting get wlan data of ${SERVICE_NAME} ... " > /dev/console
        $APP_NAME -w "$WLAN_FILE"
        check_err_exit "$?" "Failed in writing wlan file"
    fi
}
eth_data_handler()
{
    local ETH_FILE=`sysevent get $ETH_TOPIC`
    if [ -f "$ETH_FILE" ]; then
		VERIFY_MASTER=`echo "$ETH_FILE" | grep "master"`
		if [ -n "$VERIFY_MASTER" ]; then
			echo "Don't need to get eth data of ${SERVICE_NAME} ... " > /dev/console
			exit 3
		fi
        echo "Starting to get eth data of ${SERVICE_NAME} ... " > /dev/console
        $APP_NAME -e "$ETH_FILE"
        check_err_exit "$?" "Failed in writing eth file"
    fi
}
service_start ()
{
    local mode=`syscfg get smart_mode::mode`
    if [ "$mode" != "2" ]; then
        echo "servce_$SERVICE_NAME.sh - not in master mode." > /dev/console
        return
    fi
  	wait_till_end_state ${SERVICE_NAME}
	local STATUS=`sysevent get ${SERVICE_NAME}-status`
	if [ "$STATUS" != "started" ] ; then
   		wait_till_end_state ${SERVICE_NAME}
    	sysevent set ${SERVICE_NAME}-errinfo
    	sysevent set ${SERVICE_NAME}-status starting
    	echo "Starting ${SERVICE_NAME} ... "
    	sysevent set ${SERVICE_NAME}-status started
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
    $WLAN_TOPIC)
        service_start
        wlan_data_handler
        service_stop
        ;;
    $ETH_TOPIC)
        service_start
        eth_data_handler
        service_stop
        ;;
    *)
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart | $WLAN_TOPIC]" > /dev/console
        exit 3
        ;;
esac
