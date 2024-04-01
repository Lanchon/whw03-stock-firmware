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
HOSTAPD_IE_DEFAULT="dd0808863b00${WIFI_IE_XCS_NO_LIMIT}"
HOSTAPD_IE_MASTER_ONLY="dd0808863b00${WIFI_IE_XCS_MASTER_ONLY}"
HOSTAPD_IE_SLAVE_ONLY="dd0808863b00${WIFI_IE_XCS_SLAVE_ONLY}"
DEBUG() 
{
	[ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
scan_ie()
{
	case "$1" in
		"$HOSTAPD_IE_DEFAULT")
			SYMBOL="U"
		;;
		"$HOSTAPD_IE_MASTER_ONLY")
			SYMBOL="M"
		;;
		"$HOSTAPD_IE_SLAVE_ONLY")
			SYMBOL="S"
		;;
		*)
			SYMBOL="U"
		;;
	esac
	rm -rf $HOSTAP_IE_FILE
	echo "$1" > $HOSTAP_IE_FILE
	wpa_cli -p /var/run/wpa_supplicant_$STA_IF -i $STA_IF scan_results_belkin > "/tmp/scan_result"
	MYNUM="`wc -l /tmp/scan_result | awk '{print $1}'`"
	INDEX=2
	while [ $INDEX -le $MYNUM ];do
		LINE="` sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null`"
		tmp="`sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null |awk '{print $1"\t"$2"\t"$3"\t"$4"\t"}'|sed 's/\[/\\\[/g'|sed 's/\]/\\\]/g'`"
		SSID="`sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null |sed 's/'"$tmp"'//g'`"
		FREQUENCY="`sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null | awk '{print $2}'`"
		change_freq_to_chan $FREQUENCY
		CHAN=$?
		let "INDEX=INDEX+1"
		
		if [ -z "$SSID" ] || [ -z "$LINE" ] || [ -z "$FREQUENCY" ] ;then
			continue
		fi
		if [ "$CHAN" = "$MASTER_CHAN" ]; then
			PRIORITY=2
		elif [ "$CHAN" = "6" ]; then
			PRIORITY=1
		else
			PRIORITY=0
		fi
		echo $LINE | awk '{print $1" '"$CHAN"' "$3" '"$PRIORITY"' '"$SYMBOL"' '"$SSID"'"}' >> $AP_LIST
		DESIRE_MAC="`echo $LINE | awk '{print $1}' | tr '[:upper:]' '[:lower:]'`"
		echo $LINE | awk '{print $1" '"$CHAN"' "$3" '"$SSID"'"}' > ${RESULT_DIR}/${DESIRE_MAC}.wifi
		let "SCAN_CNT+=1"
	done
}
search_ap()
{
	PHY_IF="wifi0"
	USER_IF="ath0"
	if [ ! -e /sys/class/net/$STA_IF ]; then
		wlanconfig $STA_IF create wlandev $PHY_IF wlanmode sta nosbeacon
	fi
	  
	MASTER_CHAN=$(get_interface_channel $STA_IF)
	SCAN_CNT=0
	echo "${SERVICE_NAME}: scanning APs...(`date`)" > /dev/console
	
	if [ -e $AP_LIST ]; then
		rm $AP_LIST
	fi
	WPA_PID_LINE="`ps -w|grep "wpa_supplicant_$STA_IF.conf"|grep -v "grep"`"
	if [ "" = "$WPA_PID_LINE" ];then
		PROC_PID_LINE="`ps -w | grep "wpa_supplicant" | grep -v grep`"
		if [ ! -z "$PROC_PID_LINE" ]; then
			killall -9 wpa_supplicant
		fi
		CONF_FILE=/tmp/var/run/wpa_supplicant_$STA_IF/$STA_IF
		if [ -e $CONF_FILE ]; then
			rm -f $CONF_FILE
		fi
		generate_wpa_supplicant "$STA_IF" "none" "none" "" "" > "/tmp/wpa_supplicant_$STA_IF.conf"
		wpa_supplicant -B -c "/tmp/wpa_supplicant_$STA_IF.conf" -i $STA_IF -b br0
	fi
	
	sysevent set smart_connect::scan_done 0
	sleep 1
	WPA_CNT=0
	while [ "1" != "`sysevent get smart_connect::scan_done`" ] && [ "$WPA_CNT" -lt 15 ];
	do 
		WPA_CNT=`expr $WPA_CNT + 1`
		sleep 1
	done
	sysevent set smart_connect::scan_done 0
	scan_ie $HOSTAPD_IE_DEFAULT
	scan_ie $HOSTAPD_IE_SLAVE_ONLY
	rm -rf "/tmp/scan_result"
	echo "${SERVICE_NAME}: scanning done (`date`)" > /dev/console
	killall -9 wpa_supplicant
	sleep 2
	ifconfig $STA_IF down
	if [ "0" != "$SCAN_CNT" ];then 
		echo "${SERVICE_NAME} scan results: $SCAN_CNT AP(s)" > /dev/console 
		sort -n -r -k 4 -k 2 -k 3 $AP_LIST > $AP_LIST_SORT_TMP
		echo "  Scan results:" > /dev/console 
		cat $AP_LIST_SORT_TMP
		AP_LIST_JSON=""
		SCAN_CNT=0
		while read line
		do
			DESIRE_MAC="`echo "$line" | awk '{print $1}'`"
			CHANNEL="`echo "$line" | awk '{print $2}'`"
			SSID="`echo "$line" | awk '{print $NF}'`"
			if [ -n "$DESIRE_MAC" -a -n "$CHANNEL" -a -n "$SSID" ]; then
				ap_json=$(jsongen -s "mac:${DESIRE_MAC}" -s "channel:${CHANNEL}" -s "ssid:${SSID}")
				if [ -z "$AP_LIST_JSON" ]; then
					AP_LIST_JSON="$ap_json"
				else
					AP_LIST_JSON="$AP_LIST_JSON, $ap_json"
				fi
				SCAN_CNT=`expr $SCAN_CNT + 1`
			fi
		done < $AP_LIST_SORT_TMP
		echo "{ \"count\":${SCAN_CNT}, \"APs\": " > $AP_LIST_SORT
		jsongen -o a -a "$AP_LIST_JSON" >> $AP_LIST_SORT
		echo " }" >> $AP_LIST_SORT
	else
		echo "${SERVICE_NAME}: no desired AP found...(`date`)" > /dev/console 
	fi
}
if [ "2" != "`syscfg get smart_mode::mode`" ] ;then
	exit 1
fi
kill -9 $(ps -w | grep 'smart_connect_master_search.sh' | grep -v "$$" | awk '{print $1}') > /dev/null 2>&1
sysevent set smart_connect::current_device "0"
rm -rf "$RESULT_DIR"
mkdir "$RESULT_DIR"
search_ap 
xc_sta_cleanup
sysevent set smart_connect::master_search_client_status "IDLE"
sleep 1
/etc/init.d/service_wifi/smart_connect_VAP_monitor.sh&
