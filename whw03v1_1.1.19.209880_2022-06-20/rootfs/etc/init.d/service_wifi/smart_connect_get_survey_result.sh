#!/bin/sh
source /etc/init.d/service_wifi/wifi_physical.sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
source /etc/init.d/service_wifi/wifi_sta_utils.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/xconnect_utils.sh
SERVICE_NAME="wifi_xconnect"
WIFI_DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
COMMAND=$1
DEBUG() 
{
	[ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
assoc_check()
{
	if [ "Not-Associated" != "`iwconfig $STA_IF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`" ]; then
		CONNECTED_MAC="`iwconfig $STA_IF|grep "Access Point"|awk '{print $6}' | tr [:upper:] [:lower:]`"
		echo "${SERVICE_NAME}, $STA_IF associated to $CONNECTED_MAC" > /dev/console 
		return 1
	fi
	
	return 0
}
cancel_blinking()
{
    GATEWAY_IP="`sysevent get master_search_gateway`"
    OUTPUT="`porter -X -i $GATEWAY_IP -b $STA_IF -t $JNAP_SERVER_PORT`"
    SUCCESS="`echo "$OUTPUT" | cut -f 1 -d ',' | grep "OK"`"
    if [ ! "$SUCCESS" ]; then
         echo "Failed JNAP Detach request" > /dev/console
    fi
}
start_blinking()
{
:
}
_preinit()
{
	if [ "2" != "`syscfg get smart_mode::mode`" ] ;then
		exit 1
	fi
	sysevent set smart_connect::get_survey_result_status "RUNNING"
}
_fin()
{
	sysevent set smart_connect::get_survey_result_status "IDLE"
	sleep 1
	/etc/init.d/service_wifi/smart_connect_VAP_monitor.sh&
}
xc_get_result_all()
{
	_preinit
	if [ ! -e $AP_LIST_SORT ]; then
		echo "${SERVICE_NAME}: no sorted list, please do scan first!" > /dev/console 
		sysevent set smart_connect::get_survey_result_status "NoSortedList"
		exit 1
	fi
	CURRENT_INDEX=0
	CLIENT_NR="`jsonparse count < $AP_LIST_SORT`"
	SUCCESS_DONE=0
	FIX_CHAN_MODE=1
	while [ "$CURRENT_INDEX" -lt "$CLIENT_NR" ];
	do
		CURRENT_INDEX=`expr $CURRENT_INDEX + 1`
		CUT_CMD_INDEX=`expr $CURRENT_INDEX + 1`
		DESIRE_ENTRY="`jsonparse -i0 APs < $AP_LIST_SORT | cut -f $CUT_CMD_INDEX -d '{' | tr -d '\",[]{}'`"
		DESIRE_MAC="`echo $DESIRE_ENTRY | awk '{print $2}'`"
		DESIRE_CHAN="`echo $DESIRE_ENTRY | awk '{print $4}'`"
		STA_SSID="`echo $DESIRE_ENTRY | awk '{print $NF}'`"
		if [ ! -f ${RESULT_DIR}/${DESIRE_MAC}.wifi ]; then
			echo "${SERVICE_NAME}: no wifi entry $DESIRE_MAC" > /dev/console 
			continue
		fi
		xc_client_connect "$FIX_CHAN_MODE"
		RET_VAL=$?
		if [ "0" = "$RET_VAL" ];then
			/etc/init.d/service_smartconnect/ms_dhcp_link.sh ms_dhcp_client-renew
			EXPIRE_TIME=0
			while [ "$EXPIRE_TIME" -lt "10" ] ; do
				IP_ADDR="`/sbin/ifconfig $STA_IF | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}'`"
				if [ ! -z "$IP_ADDR" ]; then
					break
				fi
				EXPIRE_TIME=`expr $EXPIRE_TIME + 1`
				sleep 1
			done
			GATEWAY_IP="`sysevent get master_search_gateway`"
			if [ ! -z "$IP_ADDR" -a ! -z "$GATEWAY_IP" ]; then
				echo "${SERVICE_NAME} success connect to the client AP(`date`)" > /dev/console
				OUTPUT="`porter -g -i $GATEWAY_IP -b $STA_IF -t $JNAP_SERVER_PORT`"
				RESULT="`echo "$OUTPUT" | cut -f 1 -d ',' | grep "OK"`"
				if [ "$RESULT" ]; then
					echo "Successfully get the GetDeviceInfo JNAP: #$CURRENT_INDEX(`date`)" > /dev/console
					echo $OUTPUT > ${RESULT_DIR}/${DESIRE_MAC}.info
					SUCCESS_DONE=`expr $SUCCESS_DONE + 1`
				else
					echo "Failed to request the GetDeviceInfo JNAP: #$CURRENT_INDEX(`date`)" > /dev/console
				fi
			else
				echo "Failed to getting ip address from the client AP(`date`)" > /dev/console
			fi
			cancel_blinking
			/etc/init.d/service_smartconnect/ms_dhcp_link.sh ms_dhcp_client-release
		else
			xc_sta_cleanup
		fi
	done
	echo "Statistics: $CLIENT_NR APs, `expr $CLIENT_NR - $SUCCESS_DONE` failure!" > /dev/console 
	xc_sta_cleanup
	_fin
}
xc_get_result_next()
{
	_preinit
	assoc_check
	RET=$?
	if [ "$RET" = "1" ]; then
		echo "${SERVICE_NAME}, disconnect from AP $CONNECTED_MAC(`date`)" > /dev/console 
		cancel_blinking
		/etc/init.d/service_smartconnect/ms_dhcp_link.sh ms_dhcp_client-release
		xc_sta_cleanup
	fi
	if [ ! -e $AP_LIST_SORT ]; then
		echo "${SERVICE_NAME}: no sorted list, please do scan first!" > /dev/console 
		sysevent set smart_connect::get_survey_result_status "NoSortedList"
		exit 1
	fi
	CURRENT_INDEX="`sysevent get smart_connect::current_device`"
	CLIENT_NR="`jsonparse count < $AP_LIST_SORT`"
	SUCCESS_DONE=0
	FIX_CHAN_MODE=1
	while [ "$CURRENT_INDEX" -lt "$CLIENT_NR" ];
	do
		CURRENT_INDEX=`expr $CURRENT_INDEX + 1`
		sysevent set smart_connect::current_device $CURRENT_INDEX
		CUT_CMD_INDEX=`expr $CURRENT_INDEX + 1`
		DESIRE_ENTRY="`jsonparse -i0 APs < $AP_LIST_SORT | cut -f $CUT_CMD_INDEX -d '{' | tr -d '\",[]{}'`"
		DESIRE_MAC="`echo $DESIRE_ENTRY | awk '{print $2}'`"
		DESIRE_CHAN="`echo $DESIRE_ENTRY | awk '{print $4}'`"
		STA_SSID="`echo $DESIRE_ENTRY | awk '{print $NF}'`"
		if [ ! -f ${RESULT_DIR}/${DESIRE_MAC}.wifi ]; then
			echo "${SERVICE_NAME}: no wifi entry $DESIRE_MAC" > /dev/console 
			continue
		fi
		xc_client_connect "$FIX_CHAN_MODE"
		RET_VAL=$?
		if [ "0" = "$RET_VAL" ];then
			/etc/init.d/service_smartconnect/ms_dhcp_link.sh ms_dhcp_client-renew
			EXPIRE_TIME=0
			while [ "$EXPIRE_TIME" -lt "10" ] ; do
				IP_ADDR="`/sbin/ifconfig $STA_IF | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}'`"
				if [ ! -z "$IP_ADDR" ]; then
					break
				fi
				EXPIRE_TIME=`expr $EXPIRE_TIME + 1`
				sleep 1
			done
			GATEWAY_IP="`sysevent get master_search_gateway`"
			if [ ! -z "$IP_ADDR" -a ! -z "$GATEWAY_IP" ]; then
				echo "${SERVICE_NAME} success connect to the client AP(`date`)" > /dev/console
				OUTPUT="`porter -g -i $GATEWAY_IP -b $STA_IF -t $JNAP_SERVER_PORT`"
				RESULT="`echo "$OUTPUT" | cut -f 1 -d ',' | grep "OK"`"
				if [ "$RESULT" ]; then
					echo "Successfully get the GetDeviceInfo JNAP: #$CURRENT_INDEX(`date`)" > /dev/console
					echo $OUTPUT > ${RESULT_DIR}/${DESIRE_MAC}.info
					SUCCESS_DONE=1
					break
				else
					echo "Failed to request the GetDeviceInfo JNAP: #$CURRENT_INDEX(`date`)" > /dev/console
				fi
			else
				echo "Failed to getting ip address from the client AP(`date`)" > /dev/console
			fi
		else
			xc_sta_cleanup
		fi
	done
	if [ "$CURRENT_INDEX" -ge "$CLIENT_NR" -a "$SUCCESS_DONE" = "0" ]; then
		echo "${SERVICE_NAME}: Sorted list empty!" > /dev/console 
		sysevent set smart_connect::get_survey_result_status "NoMoreClient"
		exit 1
	fi
	_fin
}
case "$COMMAND" in
	"get_all")
		xc_get_result_all
		;;
	"get_next")
		xc_get_result_next
		;;
	*)
		echo "Invalid command: $COMMAND" > /dev/console 
		exit 1
		;;
esac
