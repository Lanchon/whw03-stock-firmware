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
DEBUG() 
{
	[ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
COMMAND=$2
COMMAND="`echo $COMMAND | tr '[:upper:]' '[:lower:]'`"
conn_check()
{
	DESIRE_MAC="$1"
	if [ "Not-Associated" != "`iwconfig $STA_IF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`" ]; then
		CONNECTED_MAC="`iwconfig $STA_IF|grep "Access Point"|awk '{print $6}' | tr [:upper:] [:lower:]`"
		IP_ADDR="`/sbin/ifconfig $STA_IF | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}'`"
		echo "${SERVICE_NAME}, $STA_IF associated to $CONNECTED_MAC" > /dev/console 
		if [ "$CONNECTED_MAC" = "$DESIRE_MAC" -a ! -z "$IP_ADDR" ]; then
			return 1
		fi
	fi
	
	return 0
}
start_smartconnect()
{
	GATEWAY_IP="`sysevent get master_search_gateway`"
	if [ ! -z "$IP_ADDR" -a ! -z "$GATEWAY_IP" ]; then
		echo "${SERVICE_NAME}, success connect to the client AP(`date`)" > /dev/console
		echo "${SERVICE_NAME}, Request StartSmartConnectCilent to the client that smartconnect ready client" > /dev/console
		PIN="`/bin/echo "$DESIRE_MAC" | md5sum | cut -c 1-12`"
		SETUPSSID="`syscfg get smart_connect::setup_vap_ssid`"
		OUTPUT="`porter -C -i $GATEWAY_IP -b $STA_IF -P $PIN -S $SETUPSSID -t $JNAP_SERVER_PORT`"
		RESULT="`echo "$OUTPUT" | cut -f 1 -d ',' | grep "OK"`"
		if [ ! -z "$RESULT" ]; then
			echo "${SERVICE_NAME}, Start SmartConnectServer with PIN: $PIN(`date`)" > /dev/console
			sleep 1
			SETUPSTATUS="`sysevent get smart_connect::setup_status`"
			if [ "READY" != "$SETUPSTATUS" -a ! -z "$SETUPSTATUS" ]; then
				STATUS="ErrorFailedStartSmartConnectServer"
			else
				syscfg set smart_connect::client_pin "$PIN"
				sysevent set wifi_smart_connect_setup-run
				sysevent set smart_connect::wifi_setupap_ready
				STATUS="OK"
				return 0
			fi
		else
			echo "${SERVICE_NAME}, Failed to request the StartSmartConnectClient JNAP(`date`)" > /dev/console
			STATUS="ErrorFailedRequest"
		fi
	else
		echo "${SERVICE_NAME}, Failed to getting ip address from the client AP(`date`)" > /dev/console
		STATUS="ErrorFailedGetIP"
	fi
	return 1
}
if [ "2" != "`syscfg get smart_mode::mode`" ] ;then
	exit 1
fi
SETUPSTATUS="`sysevent get smart_connect::setup_status`"
if [ "READY" != "$SETUPSTATUS" -a ! -z "$SETUPSTATUS" ]; then
	sysevent set smart_connect::connect_client_status "ErrorSetupAlreadyInProgress"
	exit 1
fi
kill -9 $(ps -w | grep 'smart_connect_connect_client.sh' | grep -v "$$" | awk '{print $1}') > /dev/null 2>&1
WIFI_INFO_FILE="${RESULT_DIR}/${COMMAND}.wifi"
STATUS="ErrorNotExistBSSID"
if [ -e $WIFI_INFO_FILE ]; then
	conn_check "$COMMAND"
	RET=$?
	if [ "$RET" = "1" ]; then
		C_CNT=0
		while [ "$C_CNT" -lt 3 ];
		do
			C_CNT=`expr $C_CNT + 1`
			start_smartconnect
			RET=$?
			if [ "$RET" = "0" ]; then
				break
			fi
			/etc/init.d/service_smartconnect/ms_dhcp_link.sh ms_dhcp_client-release
			sleep 2
			/etc/init.d/service_smartconnect/ms_dhcp_link.sh ms_dhcp_client-renew
		done
	else
		echo "${SERVICE_NAME}, unexpectly lose connection, try to reconnect(`date`)" > /dev/console
		while read line
		do
			STA_SSID="`echo $line | awk '{print $NF}'`"
			DESIRE_MAC="`echo $line | awk '{print $1}'`"
			DESIRE_CHAN="`echo $line | awk '{print $2}'`"
			C_CNT=0
			FIX_CHAN_MODE=1
			while [ "$C_CNT" -lt 3 ];
			do
				C_CNT=`expr $C_CNT + 1`
				xc_client_connect "$FIX_CHAN_MODE"
				CLIENT_CONNECT_RET=$?
				if [ "0" = "$CLIENT_CONNECT_RET" ];then
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
					start_smartconnect
					RET=$?
					if [ "$RET" = "0" ]; then
						break
					fi
					/etc/init.d/service_smartconnect/ms_dhcp_link.sh ms_dhcp_client-release
				else
					echo "${SERVICE_NAME}, Failed to connect the client AP(`date`)" > /dev/console
					FIX_CHAN_MODE=0
					STATUS="ErrorConnectBSSID"
				fi
			done
		done < $WIFI_INFO_FILE
	fi
fi
/etc/init.d/service_smartconnect/ms_dhcp_link.sh ms_dhcp_client-release
xc_sta_cleanup
if [ "$STATUS" = "OK" ]; then
	sysevent set smart_connect::connect_client_status "ONBOARDING"
	sleep 1
	/etc/init.d/service_wifi/smart_connect_VAP_monitor.sh&
	EXPIRE_TIME=0
	while [ "$EXPIRE_TIME" -le "12" ] ; do
		PIN_STATUS="`sysevent get smart_connect::pin_${PIN}`"
		if [ "$PIN_STATUS" = "config_done" -o "$PIN_STATUS" = "setup_done" -o "$PIN_STATUS" = "preauth_done" ]; then
			break;
		fi
		EXPIRE_TIME=`expr $EXPIRE_TIME + 1`
		sleep 10
	done
	if [ "$PIN_STATUS" = "setup_done" ]; then
		EXPIRE_TIME=0
		while [ "$EXPIRE_TIME" -le "12" ] ; do
			PIN_STATUS="`sysevent get smart_connect::pin_${PIN}`"
			if [ "$PIN_STATUS" = "config_done" -o "$PIN_STATUS" = "preauth_done" ]; then
				break;
			fi
			EXPIRE_TIME=`expr $EXPIRE_TIME + 1`
			sleep 10
		done
	fi
	if [ "$EXPIRE_TIME" -gt "12" ] ; then
		PIN_STATUS="`sysevent get smart_connect::pin_${PIN}`"
		if [ "$PIN_STATUS" != "config_done" -a "$PIN_STATUS" != "preauth_done" ]; then
			echo "${SERVICE_NAME}, SmartConnectP2 setup did not complete in 2 minutes" > /dev/console
			STATUS="SmartConnectSetupTimeout"
		fi
	fi
	sysevent set smart_connect::connect_client_status "$STATUS"
else
	sysevent set smart_connect::connect_client_status "$STATUS"
	sleep 1
	/etc/init.d/service_wifi/smart_connect_VAP_monitor.sh&
fi
