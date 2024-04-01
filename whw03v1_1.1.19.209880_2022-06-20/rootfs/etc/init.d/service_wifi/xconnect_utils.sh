#!/bin/sh
AP_LIST='/tmp/ap_list'
AP_LIST_SORT_TMP='/tmp/sc_data/.discovered_aps'
AP_LIST_SORT='/tmp/sc_data/discovered_aps'
HOSTAP_IE_FILE="/tmp/hostapd_IE_payload"
RESULT_DIR="/tmp/sc_data"
JNAP_SERVER_PORT="8080"
STA_IF="ath8"
xc_sta_cleanup()
{
	PROC_PID_LINE="`ps -w | grep "wpa_supplicant" | grep -v grep`"
	if [ ! -z "$PROC_PID_LINE" ]; then
		killall -9 wpa_supplicant
		sleep 2
	fi
	ifconfig $STA_IF down
}
wifi_sta_prepare()
{
	STA_RADIO="2.4GHz"
	STA_BRIDGE="br0"
	return 0
}
wifi_sta_init()
{
	OPMODE="11NGHT40"
	PHY_IF="wifi0"
	USER_IF="ath0"
	echo "${SERVICE_NAME}, smart connect connect to SSID - $STA_SSID, MAC - $DESIRE_MAC, CHANNEL - $DESIRE_CHAN(`date`)" > /dev/console 
	PROC_PID_LINE="`ps -w | grep "wpa_supplicant" | grep -v grep`"
	if [ ! -z "$PROC_PID_LINE" ]; then
			killall -9 wpa_supplicant
			sleep 2
	fi
	
	CONF_FILE=/tmp/var/run/wpa_supplicant_"$STA_IF"/"$STA_IF"
	if [ -e $CONF_FILE ]; then
		rm -f $CONF_FILE
	fi
	WPA_SUPPLICANT_CONF="/tmp/wpa_supplicant_$STA_IF.conf"
	
	echo "${SERVICE_NAME}, init()" > /dev/console 
	echo "${SERVICE_NAME}, creating STA vap $STA_IF" > /dev/console 
	ifconfig $STA_IF down
	if [ ! -e /sys/class/net/$STA_IF ]; then
		wlanconfig $STA_IF create wlandev $PHY_IF wlanmode sta nosbeacon
	fi
	
	iwpriv $STA_IF mode $OPMODE
	iwconfig $STA_IF essid "$STA_SSID" mode managed ap "$DESIRE_MAC"
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		iwpriv $STA_IF wds 1
	fi
	iwpriv $STA_IF vhtsubfee 1
	iwpriv $STA_IF implicitbf 1
	iwpriv $STA_IF shortgi 1
	if [ "2.4GHz" = "$STA_RADIO" ]; then
		qca_24_amsdu_performance_fix $STA_IF
	fi
	if [ "$STA_IF" = "ath8" ] && [ "`cat /etc/product`" = "wraith" ] ; then
		echo "@@@@@ for wraith please do not add ath8 to br0" > /dev/console
	fi
}
wifi_sta_connect()
{
	local FIX_CHAN_SCAN="$1"
	STA_CHAN=$(get_interface_channel $STA_IF)
	if [ "$STA_CHAN" != "$DESIRE_CHAN" ];then
		echo "${SERVICE_NAME}, switch channel" > /dev/console 
		iwconfig $USER_IF channel $DESIRE_CHAN
		iwconfig $STA_IF channel $DESIRE_CHAN
	fi
	
	echo "${SERVICE_NAME}, connect()" > /dev/console 
	echo "${SERVICE_NAME}, bring up STA vap $STA_IF (`date`)" > /dev/console 
	sleep 1
	
	if [ "$FIX_CHAN_SCAN" = "1" ]; then
		STA_FREQ=$(chan_to_freq $DESIRE_CHAN)
		generate_wpa_supplicant_scan_freq "$STA_IF" "$STA_SSID" "none" "" "$DESIRE_MAC" "$STA_FREQ" > $WPA_SUPPLICANT_CONF
	else
		generate_wpa_supplicant "$STA_IF" "$STA_SSID" "none" "" "$DESIRE_MAC" > $WPA_SUPPLICANT_CONF
	fi
	
	wpa_supplicant -B -c $WPA_SUPPLICANT_CONF -i $STA_IF -b $STA_BRIDGE
}
wifi_sta_verify_connection()
{
	local COUNTER=0
	LINK_STATUS=0
	
	while [ "0" = $LINK_STATUS ] && [ "$COUNTER" -lt 25 ];
	do
		sleep 1
		COUNTER=`expr $COUNTER + 1`
		if [ "Not-Associated" != "`iwconfig $STA_IF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`" ]; then
			if [ "" != "$DESIRE_MAC" ];then
				CONNECTED_MAC="`iwconfig $STA_IF|grep "Access Point"|awk '{print $6}' | tr [:upper:] [:lower:]`"
				if [ "$CONNECTED_MAC" != "$DESIRE_MAC" ];then
					iwconfig $STA_IF
					echo "${SERVICE_NAME}, associated to wrong BSSID($CONNECTED_MAC), desired($DESIRE_MAC)...(`date`)" > /dev/console 
					continue
				fi
			fi	
			LINK_STATUS=1
			echo "${SERVICE_NAME}, verify_connection(), $STA_IF associated to $STA_SSID  $DESIRE_MAC successfully(`date`)" > /dev/console 
			return 0
		fi
	done
	echo "${SERVICE_NAME}, verify_connection(), $STA_IF unable to connect to $STA_SSID(`date`)" > /dev/console 
	ifconfig $STA_IF down
	return 1
}
xc_client_connect()
{
	local SCAN_MODE="$1"
	wifi_sta_prepare
	wifi_sta_init
	wifi_sta_connect "$SCAN_MODE"
	wifi_sta_verify_connection
	return $?
}
