#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="thrulay"
NAMESPACE=$SERVICE_NAME
dfc_enabled="1"
dfc_port="5003"
dfc_serverip="192.168.1.1"
dfc_test_duration="3"
dfc_low_drops="2"
dfc_location="${dfc_serverip}:${dfc_port}"
dfc_min_bad_seq_len="3"
dfc_log="/tmp/.thrulay.log"
dfc_host_list="/tmp/.thrulay.hosts"
TMP_BUF="/tmp/.thrulay.buf.$RANDOM"
export TZ=`sysevent get TZ`
service_init ()
{
	[ "$(syscfg get "${NAMESPACE}::debug")" == "1" ] && DEBUG=1
	if [ ! "`sysevent get thrulay:inited`" ] ; then
		if [ "`syscfg get ${NAMESPACE}::enabled`" == "" ] ; then
			syscfg set ${NAMESPACE}::enabled $dfc_enabled
		fi
		if [ "`syscfg get ${NAMESPACE}::port`" == "" ] ; then
			syscfg set ${NAMESPACE}::port $dfc_port
		fi
		if [ "`syscfg get ${NAMESPACE}::serverip`" == "" ] ; then
			syscfg set ${NAMESPACE}::serverip $dfc_serverip
		fi
		if [ "`syscfg get ${NAMESPACE}::test_duration`" == "" ] ; then
			syscfg set ${NAMESPACE}::test_duration $dfc_test_duration
		fi
		if [ "`syscfg get ${NAMESPACE}::low_drops`" == "" ] ; then
			syscfg set ${NAMESPACE}::low_drops $dfc_low_drops
		fi
		if [ "`syscfg get ${NAMESPACE}::min_bad_seq_len`" == "" ] ; then
			syscfg set ${NAMESPACE}::min_bad_seq_len $dfc_min_bad_seq_len
		fi
		if [ "`syscfg get ${NAMESPACE}::log`" == "" ] ; then
			syscfg set ${NAMESPACE}::log $dfc_log
		fi
		if [ "`syscfg get ${NAMESPACE}::host_list`" == "" ] ; then
			syscfg set ${NAMESPACE}::host_list $dfc_host_list
		fi
		sysevent set thrulay::inited 1
	fi
	
	if [ "`syscfg get ${NAMESPACE}::enabled`" != "1" ] ; then
		echo "${NAMESPACE} disabled in syscfg"
		exit 0
	fi
}
service_start ()
{
	wait_till_end_state ${SERVICE_NAME}
	
	PORTNO="`syscfg get ${SERVICE_NAME}::port`"
	TEST_TIME="`syscfg get ${SERVICE_NAME}::test_duration`"
	LOG_FILE="`syscfg get ${SERVICE_NAME}::log`"
	
	touch "`syscfg get ${NAMESPACE}::host_list`"
	
	SMART_MODE="`syscfg get smart_mode::mode`"
	if [ "$SMART_MODE" == "0" ] ; then
		exit 0
	elif [ "$SMART_MODE" == "1" ] || [ "$SMART_MODE" == "2" ] ; then
		/sbin/thrulayd -p $PORTNO &
	else
		echo "thrulay service unknown smart mode setting ( $SMART_MODE )"
	fi
	check_err $? "Couldnt handle start"
	sysevent set ${SERVICE_NAME}-status started
	ulog ${SERVICE_NAME} status "now started"
}
service_stop ()
{
  wait_till_end_state ${SERVICE_NAME}
  SMART_MODE="`syscfg get smart_mode::mode`"
  if [ "$SMART_MODE" != "0" ] ; then
		killall -9 thrulayd 2>&1
		killall -9 thrulay 2>&1
  fi
	check_err $? "Couldnt handle stop"
	sysevent set ${SERVICE_NAME}-status stopped
	ulog ${SERVICE_NAME} status "now stopped"
}
service_init 
case "$1" in
	${SERVICE_NAME}-start)
		if [ "`sysevent get lan-status`" == "started" ] ; then
			service_start
		fi
		;;
	${SERVICE_NAME}-stop)
		if [ "`sysevent get lan-status`" == "started" ] ; then
			service_stop
		fi
		;;
	${SERVICE_NAME}-restart)
		if [ "`sysevent get lan-status`" == "started" ] ; then
			service_stop
			service_start
		fi
		;;
	lan-started)
		if [ "`sysevent get lan-status`" == "started" ] ; then
				service_stop
				service_start
		fi
		;;
	thrulay::location)
			S_IP="${2%:*}"
			S_PORT="${2#*:}"
			TEST_TIME="`syscfg get ${NAMESPACE}::test_duration`"
			LOWS_TO_DROP="$(syscfg get ${SERVICE_NAME}::low_drops)"
			PORTNO="`syscfg get ${SERVICE_NAME}::port`"
			LOG_FILE="`syscfg get ${SERVICE_NAME}::log`"
			SMART_MODE="`syscfg get smart_mode::mode`"
			
			if [ "$S_IP" ] && [ "$S_PORT" ] ; then
				ulog ${SERVICE_NAME} status "thrulay::location change ${S_IP}:${S_PORT}"
				HOST_LIST="`syscfg get thrulay::host_list`"
				DEV_EXISTS="`cat $HOST_LIST | grep ${S_IP}:${S_PORT}`"
				if [ ! "$DEV_EXISTS" ] ; then
					echo "${S_IP}:${S_PORT}" >> $HOST_LIST
				fi
				if [ "$SMART_MODE" == "2" ] || [ "$SMART_MODE" == "1" ]  ; then
					if [ "$S_IP" ] && [ "$S_PORT" ] ; then
						/usr/bin/logger "running thrulay test to $S_IP"
						if [ "$DEBUG" = '1' ]; then
							DEB_OPT="--debug "
						fi
						retry_cnt=0
						while [ "$retry_cnt" -lt "10" ] ; do
							eval $(thrulayer $DEB_OPT --shell --tests=${TEST_TIME} --low-drops=${LOWS_TO_DROP} \
								--port=${S_PORT} ${S_IP} 2> /dev/console)
							[ -n "$AVG_MBPS" ] && break
							sleep 15
							retry_cnt=`expr $retry_cnt + 1`
						done
						DATE="`date`"
						if [ "$S_IP" ] && [ "$RTT" ] && [ "$AVG_MBPS" ] ; then
							sysevent set thrulay::last_thrulay "$MBPS/$JITTER/$RTT/$S_IP/$DATE"
							echo "${DATE}, ip:${S_IP}, mbps:${MBPS}, rtt:${RTT}, jitter:${JITTER}, min:${MIN_MBPS}, avg:${AVG_MBPS}, max:${MAX_MBPS}, duration:${TEST_TIME}" >> $LOG_FILE
							/usr/bin/logger "thrulay to $S_IP, MBPS:${MBPS}, RTT:${RTT}"
							LOG_LINE_COUNT=`cat $LOG_FILE | wc -l`
							if [ $LOG_LINE_COUNT -gt 200 ] ; then
								echo "rotate thrulay log" >> /dev/console
								tail -n 200 $LOG_FILE > ${LOG_FILE}.0
								echo "" > $LOG_FILE
							fi
						fi
						rm -rf $TMP_BUF
					fi
				fi
			fi
		;;
	*)
		echo "error : $1 unknown" > /dev/console 
		echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		exit 3
		;;
esac
