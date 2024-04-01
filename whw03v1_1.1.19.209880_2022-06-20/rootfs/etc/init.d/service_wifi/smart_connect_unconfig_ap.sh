#!/bin/sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_sta_utils.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_user.sh
wifi_unconfig_ap_start()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	SMART_MODE=`syscfg get smart_mode::mode`
	if [ $SMART_MODE != "0" ] ; then
		echo "${SERVICE_NAME}, smart::mode is not in unconfigured, do not start unconfig ap" > /dev/console
		return 1
	fi
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ERROR: invalid interface name, ignore the request"
		return 1
	fi
	
	UNCONFIG_VAP="ath4"
	UNCONFIG_BRIDGE="`syscfg_get lan_ifname`"
	UN_INTF=`get_phy_interface_name_from_vap "$PHY_IF"`
	search_master_ap
	MASTER_CHAN=$?
	if [ "$MASTER_CHAN" = "0" ]; then
		MASTER_CHAN="6"
	fi
	wlanconfig $UNCONFIG_VAP create wlandev $UN_INTF wlanmode ap
	/sbin/ifconfig $UNCONFIG_VAP txqueuelen 1000
	UNCONFIG_SSID="`syscfg_get wl0_ssid`-SCP2"
	iwconfig $UNCONFIG_VAP essid $UNCONFIG_SSID
	iwconfig $UNCONFIG_VAP freq $MASTER_CHAN
	iwconfig ath0 freq $MASTER_CHAN
	HOSTAPD_CONF="/tmp/hostapd-$UNCONFIG_VAP.conf"
	generate_hostapd_config $UNCONFIG_VAP "$UNCONFIG_SSID" "" "0" "" "" "" ""> $HOSTAPD_CONF
	if [ "2" = "`syscfg get smart_mode::ML`" ] ; then
		generate_hostapd_IE_section $WIFI_IE_XCS_MASTER_ONLY >> $HOSTAPD_CONF
	elif [ "1" = "`syscfg get smart_mode::ML`" ] ; then
		generate_hostapd_IE_section $WIFI_IE_XCS_SLAVE_ONLY >> $HOSTAPD_CONF
	else
		generate_hostapd_IE_section $WIFI_IE_XCS_NO_LIMIT >> $HOSTAPD_CONF
	fi
	iwpriv $UNCONFIG_VAP wds 1
	iwpriv $UNCONFIG_VAP shortgi 1
}
wifi_unconfig_ap_stop() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME},ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ERROR: invalid interface name, ignore the request"
		return 1
	fi
	STATUS=`sysevent get "$WIFI_SMART_CONFIGURED"_"$PHY_IF"-status`
	if [ "stopped" = "$STATUS" ] || [ "stopping" = "$STATUS" ] ; then
		echo "${SERVICE_NAME}, "$WIFI_SMART_CONFIGURED"_"$PHY_IF" is already stopping/stopped, ignore this request"
		ulog wlan status "${SERVICE_NAME}, "$WIFI_SMART_CONFIGURED"_"$PHY_IF" is already stopping/stopped, ignore this request"
		return 1
	fi
	sysevent set "$WIFI_SMART_CONFIGURED"_"$PHY_IF"-status stopping
	UNCONFIG_VAP="ath4"
	UNCONFIG_BRIDGE="`syscfg_get lan_ifname`"
	UN_INTF=`get_phy_interface_name_from_vap "$PHY_IF"`
	
	ip -4 addr flush dev $UNCONFIG_VAP
	ifconfig $UNCONFIG_VAP down
	sysevent set ${SYSCFG_INDEX}_configured_status "down"
	sysevent set "$WIFI_SMART_CONFIGURED"_"$PHY_IF"-status stopped
	return 0
} 
wifi_unconfig_ap_configure_ip()
{
	UNCONFIG_VAP="ath4"
	UNCONFIG_VAP_IPADDR="172.31.255.1"
	ifconfig $UNCONFIG_VAP $UNCONFIG_VAP_IPADDR netmask 255.255.255.0
}
search_master_ap()
{
	echo "Searching master AP for fix channel..." > /dev/console
	AP_LIST='/tmp/ap_list'
	AP_LIST_SORT='/tmp/ap_list_sort'
	HOSTAP_IE_FILE="/tmp/hostapd_IE_payload"
	HOSTAPD_IE_MASTER="dd0808863b00${WIFI_IE_SC_MASTER}"
	IF="ath8"
	PHY_IF="wifi0"
	USER_IF="ath0"
	if [ ! -e /sys/class/net/$IF ]; then
		wlanconfig $IF create wlandev $PHY_IF wlanmode sta nosbeacon
	fi
	  
	SCAN_CNT=0
	
	if [ -e $AP_LIST ]; then
		rm $AP_LIST
	fi
	rm -rf $AP_LIST_SORT
	WPA_PID_LINE="`ps -w|grep "wpa_supplicant_$IF.conf"|grep -v "grep"`"
	if [ "" = "$WPA_PID_LINE" ];then
		PROC_PID_LINE="`ps -w | grep "wpa_supplicant" | grep -v grep`"
		if [ ! -z "$PROC_PID_LINE" ]; then
			killall -9 wpa_supplicant
		fi
		CONF_FILE=/tmp/var/run/wpa_supplicant_$IF/$IF
		if [ -e $CONF_FILE ]; then
			rm -f $CONF_FILE
		fi
		generate_wpa_supplicant "$IF" "none" "none" "" "" > "/tmp/wpa_supplicant_$IF.conf"
		wpa_supplicant -B -c "/tmp/wpa_supplicant_$IF.conf" -i $IF -b br0
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
	rm -rf $HOSTAP_IE_FILE
	echo "$HOSTAPD_IE_MASTER" > $HOSTAP_IE_FILE
	wpa_cli -p /var/run/wpa_supplicant_$IF -i $IF scan_results_belkin > "/tmp/scan_result"
		
	MYNUM="`wc -l /tmp/scan_result | awk '{print $1}'`"
	INDEX=2
	while [ $INDEX -le $MYNUM ];do
		LINE="` sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null`"
		tmp="`sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null |awk '{print $1"\t"$2"\t"$3"\t"$4"\t"}'|sed 's/\[/\\\[/g'|sed 's/\]/\\\]/g'`"
		SSID="`sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null |sed 's/'"$tmp"'//g'`"
		FREQUENCY="`sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null | awk '{print $2}'`"
		let "INDEX=INDEX+1"
		
		if [ -z "$SSID" ] || [ -z "$LINE" ] || [ -z "$FREQUENCY" ] ;then
			continue
		fi
		echo $LINE | awk '{print $1" "$2" "$3" '"$SSID"'"}' >> $AP_LIST
		let "SCAN_CNT+=1"
	done
	rm -rf "/tmp/scan_result"
	killall -9 wpa_supplicant
	sleep 2
	ifconfig $IF down
	if [ "0" != "$SCAN_CNT" ];then 
		echo "search_master_ap scan results: $SCAN_CNT AP(s)" > /dev/console 
		sort -n -r -k 3 $AP_LIST > $AP_LIST_SORT
		echo "  Scan results:" > /dev/console 
		cat $AP_LIST_SORT | sed -n '1p'
	else
		echo "search_master_ap: no desired master AP found...(`date`)" > /dev/console 
		return 0
	fi
	if [ -e $AP_LIST_SORT ]; then
		while read line
		do
			tmp="`echo "$line"|awk '{print $1" "$2" "$3" "}'`"
			STA_SSID="`echo "$line"|sed 's/'"$tmp"'//g'`"
			DESIRE_MAC="`echo $line | awk '{print $1}'`"
			DESIRE_MAC="`echo $DESIRE_MAC | tr '[:upper:]' '[:lower:]'`"
			SETUP_FREQ="`echo $line | awk '{print $2}'`"
			change_freq_to_chan $SETUP_FREQ
			DESIRE_CHAN=$?
			echo "${SERVICE_NAME} successfully find 1 Master $DESIRE_MAC on channel $DESIRE_CHAN, stop scanning" > /dev/console
			break
		done < $AP_LIST_SORT
	fi
	return $DESIRE_CHAN
}
