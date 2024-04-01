#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="bt_auto_onboard"
NAMESPACE=$SERVICE_NAME
service_start ()
{
	wait_till_end_state ${SERVICE_NAME}
	sysevent set ${SERVICE_NAME}-status started
	ulog ${SERVICE_NAME} status "now started"
}
service_stop ()
{
   wait_till_end_state ${SERVICE_NAME}
	check_err $? "Couldnt handle stop"
	sysevent set ${SERVICE_NAME}-status stopped
	ulog ${SERVICE_NAME} status "now stopped"
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
	bt_auto_onboard::start)
		PROC_PID_LINE="`ps -w | grep "bt_auto_onboard_start" | grep -v grep`"
		PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
		if [ -z "$PROC_PID" ]; then
			/etc/init.d/bt_auto_onboard_start.sh &
			echo "bt_auto_onboard started"
		else
			echo "bt_auto_onboard is already running"
		fi
		;;
	*)
		echo "error : $1 unknown" > /dev/console 
		echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		exit 3
		;;
esac
