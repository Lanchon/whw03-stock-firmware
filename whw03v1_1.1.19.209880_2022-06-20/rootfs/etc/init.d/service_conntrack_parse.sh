#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="conntrack_parse"
NAMESPACE=$SERVICE_NAME
dfc_enabled="1"
dfc_db="/tmp/conntrack.db"
dfc_poll_freq="30"
dfc_debug="0"
service_init ()
{
	if [ "`syscfg get ${NAMESPACE}::enabled`" == "" ] ; then
		syscfg set ${NAMESPACE}::enabled $dfc_enabled
	fi
	if [ "`syscfg get ${NAMESPACE}::debug`" == "" ] ; then
		syscfg set ${NAMESPACE}::debug $dfc_debug
	fi
	if [ "`syscfg get ${NAMESPACE}::enabled`" == "1" ] ; then
		echo "$SERVICE_NAME running $1"
				if [ ! -f "/tmp/cron/cron.everyminute/conntrack_collector.sh" ] ; then
				echo "creating conntrack cron job" >> /dev/console
				echo "#!/bin/sh" > /tmp/cron/cron.everyminute/conntrack_collector.sh
				if [ -f "/proc/net/ip_conntrack" ] ; then
					echo "/usr/sbin/conntrack_parse -e /proc/net/ip_conntrack" >> /tmp/cron/cron.everyminute/conntrack_collector.sh
				fi
				if [ -f "/proc/net/nf_conntrack" ] ; then
					echo "/usr/sbin/conntrack_parse -e /proc/net/nf_conntrack" >> /tmp/cron/cron.everyminute/conntrack_collector.sh
				fi
				chmod +x /tmp/cron/cron.everyminute/conntrack_collector.sh
				fi
	else
		rm -rf /tmp/cron/cron.everyminute/conntrack_collector.sh
		exit 1
	fi
}
service_start ()
{
	wait_till_end_state ${SERVICE_NAME}
	$BIN_NAME $CONF_FILE &
	check_err $? "Couldnt handle start"
	sysevent set ${SERVICE_NAME}-status started
	ulog ${SERVICE_NAME} status "now started"
}
service_stop ()
{
   wait_till_end_state ${SERVICE_NAME}
	killall -9 $BIN_NAME
	check_err $? "Couldnt handle stop"
	sysevent set ${SERVICE_NAME}-status stopped
	ulog ${SERVICE_NAME} status "now stopped"
}
service_init 
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
    lan-started)
        if [ "`sysevent get wan-status`" == "started" ] ; then
            service_stop
            service_start
        fi
        ;;
	*)
		echo "error : $1 unknown" > /dev/console 
		echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		exit 3
		;;
esac
