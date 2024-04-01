#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_wifi/wifi_physical.sh
source /etc/init.d/service_wifi/wifi_sta_utils.sh
source /etc/init.d/syscfg_api.sh
DEBUG_SETTING=`syscfg_get wifi_bridge_api_debug`
DEBUG() 
{
    [ "$DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
COMMAND=$1
print_help()
{
	echo "Usage: wifi_bridge_api.sh is_connected"
	echo "       			get_conn_ssid"
	echo "       			get_conn_bssid"
	echo "       			get_conn_radio"
	echo "       			get_conn_network_mode"
	echo "       			get_conn_channel_width"
	echo "       			get_conn_channel"
	echo "       			get_conn_signal_strength"
	echo "       			get_wireless_networks <2.4GHz|5GHz>"
	echo "       			check_connection <ssid> <security> <radio> <passphrase>"
	exit
}
is_sta_connected()
{
	STA_VIR_IF=`syscfg_get wifi_sta_vir_if`
	if [ -z "$STA_VIR_IF" ]; then
		echo "error: no STA interface specified"
		exit
	fi
	if [ "Not-Associated" = "`iwconfig $STA_VIR_IF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`" ]; then
		echo "no"
	else
		echo "yes"
	fi
}
get_ssid()
{
	syscfg_get wifi_bridge::ssid
}
get_bssid()
{
	echo "xx:xx:xx:xx:xx:xx"
}
get_radio()
{
	syscfg_get wifi_bridge::radio
}
get_network_mode()
{
	STA_VIR_IF="`syscfg_get wifi_sta_vir_if`"
	MODE="`iwpriv $STA_VIR_IF get_mode | cut -d ':' -f 2 | tr -d '[[:space:]]'`"
	case "$MODE" in
		"11B")
			echo "11b"
			;;
		"11G")
			if [ "1" = "`iwpriv $STA_VIR_IF get_pureg | cut -d ':' -f 2 | tr -d '[[:space:]]'`" ]; then
				echo "11g"
			else
				echo "11b 11g"
			fi
			;;
		"11NGHT20"|"11NGHT40PLUS"|"11NGHT40MINUS"|"11NGHT40")
			if [ "1" = "`iwpriv $STA_VIR_IF get_puren | cut -d ':' -f 2 | tr -d '[[:space:]]'`" ]; then
				echo "11n"
			else
				echo "11b 11g 11n"
			fi
			;;
		"11A")
			echo "11a"
			;;
		"11NAHT20"|"11NAHT40PLUS"|"11NAHT40MINUS")
			if [ "1" = "`iwpriv $STA_VIR_IF get_puren | cut -d ':' -f 2 | tr -d '[[:space:]]'`" ]; then
				echo "11n"
			else
				echo "11a 11n"
			fi
			;;
		"11ACVHT20"|"11ACVHT40PLUS"|"11ACVHT40MINUS"|"11ACVHT80")
			if [ "1" = "`iwpriv $STA_VIR_IF get_pure11ac | cut -d ':' -f 2 | tr -d '[[:space:]]'`" ]; then
				echo "11ac"
			else
				echo "11a 11n 11ac"
			fi
			;;
		"AUTO")
			echo "mixed"
			;;
		*)
			echo "mixed"
	esac
}
get_channel_width()
{
	STA_VIR_IF=`syscfg_get wifi_sta_vir_if`
	HTBW=`iwpriv $STA_VIR_IF get_chwidth | awk -F':' '{print $2}'`
	case "`echo $HTBW`" in
		"0")
		echo "auto"
		;;
		"2")
		echo "standard"
		;;
		"3")
		echo "wide"
		;;
		*)
		echo "error: unknown channel width"
	esac
	
}
get_channel()
{
	STA_VIR_IF=`syscfg_get wifi_sta_vir_if`
	iwlist $STA_VIR_IF channel | grep "(Channel" | awk '{print $NF}' | cut -c -2
}
get_connection_signal_strength()
{
	STA_VIR_IF=`syscfg_get wifi_sta_vir_if`
	if [ -z "$STA_VIR_IF" ]; then
		echo "error: no STA interface specified"
		exit
	fi
	SSID=`syscfg_get wifi_bridge::ssid | cut -c -11`
	wlanconfig $STA_VIR_IF list ap | grep $SSID | awk {'print $5'} | cut -d':' -f1
}
get_site_survey()
{
	RADIO=$1
	IF=""
	WLINDEX=""
	FILE="/tmp/site_survey"
	case "`echo $RADIO | tr [:upper:] [:lower:]`" in
		"2.4ghz")
		IF_1=ath0
		WLINDEX_1="wl0"
		
		;;
		"5ghz")
		IF_1=ath1
		WLINDEX_1="wl1"
		IF_2=ath10
		WLINDEX_2="wl2"
		;;
		*)
		echo "Usage: wifi_bridge_api.sh get_wireless_networks <2.4GHz|5GHz>"
		exit
	esac
	ifconfig $IF_1 up
	iwlist $IF_1 scan > /tmp/site_survey
	
	if [ $IF_2 != "" ];then
		ifconfig $IF_2 up
		iwlist $IF_2 scan >> /tmp/site_survey
	fi
	if [ "down" = `syscfg_get $WLINDEX_1"_state"` ]; then
		ifconfig $IF_1 down
	fi
	if [ $IF_2 != "" ] && [ "down" = `syscfg_get $WLINDEX_2"_state"` ];then
		ifconfig $IF_2 down
	fi
	ROW_LIST=`sed -n '/Cell [0-9]* - Address:/=' $FILE`
	APNUM=`echo $ROW_LIST | awk '{print NF}'`
	INDEX=1
	while [ ${INDEX} -le ${APNUM} ]
	do
		RESULTFILE="/tmp/bbb"
		if [  ${INDEX} -eq $APNUM ] ; then
			STARTROWNUM=`echo $ROW_LIST | awk '{print $"'$INDEX'" }' `
			sed -n "${STARTROWNUM},$ p" $FILE > ${RESULTFILE}
		else
			STARTROWNUM=`echo $ROW_LIST | awk '{print $"'$INDEX'" }' `
			ENDROWNUM=`expr ${INDEX} + 1`
			ENDROWNUM=`echo $ROW_LIST | awk '{print $"'$ENDROWNUM'" }' `
			ENDROWNUM=`expr ${ENDROWNUM} - 1`
			sed -n "${STARTROWNUM},${ENDROWNUM}p" $FILE > ${RESULTFILE}
		fi
		SSID=` grep 'ESSID:' ${RESULTFILE} | awk -F ':' '{print $2}'`
		SSID=`echo "${SSID%?}" | sed 's/"//' `
		if [ "$SSID" = "" ]; then
			INDEX=`expr $INDEX + 1`
			continue
		fi
		BSSID=` grep ' Address: ' ${RESULTFILE} | awk -F ': ' '{print $2}'`
		if [ "$BSSID" = "" ]; then
			INDEX=`expr $INDEX + 1`
			continue
		fi
	
		RSSI=`grep "Signal level=" ${RESULTFILE} | awk -F '=' '{print $3}' | awk '{print $1}'`
		if [ -n "`grep 'Encryption key:on' ${RESULTFILE}`" ] ; then
			SECURITY=`grep "IE:" ${RESULTFILE} | sed -n 1p | awk -F '/' '{print $2}' | awk '{print $1}' | sed -e s/"WPA"/"wpa-personal"/ -e s/"WPA2"/"wpa2-personal"/ -e s/"WPA-WPA2"/"wpa-mixed"/ `
		elif [ -n "`grep 'Encryption key:off' ${RESULTFILE}`"  ] ; then
			SECURITY="disabled"
		fi
		RADIO="$RADIO"
		echo "$SSID;$BSSID;$RSSI;$SECURITY;$RADIO"
		INDEX=`expr ${INDEX} + 1`
	done	
	
	exit
}
check_sta_connection()
{
	ulog wlan status "${SERVICE_NAME}, check_connection()"
	STA_SSID="$1"
	STA_SECURITY="$2"
	STA_RADIO="$3"	#2.4GHz or 5GHz
	STA_PASSPHRASE="$4"
	killall wpa_supplicant
	echo "${SERVICE_NAME}, check_connection(), this will disrupt the user and guest VAPs on $STA_RADIO"
	if [ "2.4GHz" = "$STA_RADIO" ]; then
		OPMODE="11NGHT40PLUS"
		PHY_IF="wifi0"
		STA_IF="ath4"
		USER_IF="ath0"
		WLINDEX="wl0"
	elif [ "5GHz" = "$STA_RADIO" ]; then
		OPMODE="11ACVHT80"
		PHY_IF="wifi1"
		STA_IF="ath5"
		USER_IF="ath1"
		WLINDEX="wl1"
	fi
	WPA_SUPPLICANT_CONF_TEST="/tmp/wpa_supplicant_${STA_IF}_test_conn.conf"
	sysevent set wifi_bridge_conn_status "connecting"
	wlanconfig $STA_IF create wlandev $PHY_IF wlanmode sta nosbeacon
	iwpriv $STA_IF mode $OPMODE
	iwconfig $STA_IF essid $STA_SSID mode managed
	if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
		iwpriv $STA_IF wds 1
	else
		iwpriv $STA_IF wds 0
		iwpriv $STA_IF extap 1
	fi
	ifconfig $PHY_IF up
	sleep 1
	echo "$SERVICE_NAME, bring up STA vap $STA_IF"
	ifconfig $STA_IF up
	sleep 1
	if [ "wpa-personal" = "$STA_SECURITY" ] || [ "wpa2-personal" = "$STA_SECURITY" ]; then
		generate_wpa_supplicant "$STA_IF" "$STA_SSID" "$STA_SECURITY" "$STA_PASSPHRASE" "" > $WPA_SUPPLICANT_CONF_TEST
		wpa_supplicant -B -c $WPA_SUPPLICANT_CONF_TEST -i $STA_IF -b br0
	fi
	
	COUNTER=0
	LINK_STATUS=0
	while [ $COUNTER -lt 15 ] && [ "0" = $LINK_STATUS ]
	do
		sleep 5
		if [ "Not-Associated" != "`iwconfig $STA_IF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`" ]; then
			LINK_STATUS=1
			echo "${SERVICE_NAME}, check_connection, $STA_IF test connection to $STA_SSID was SUCCESSFUL"
			sysevent set wifi_bridge_conn_status "success"
			restore_wifi_settings $PHY_IF $WLINDEX $STA_RADIO $STA_IF
			return 0
		fi
		COUNTER=`expr $COUNTER + 1`
	done
	echo "${SERVICE_NAME}, check_connection, $STA_IF test connection to $STA_SSID was UNSUCCESSFUL"
	sysevent set wifi_bridge_conn_status "failed"
	restore_wifi_settings $PHY_IF $WLINDEX $STA_RADIO $STA_IF
	return 1
}
restore_wifi_settings()
{
	PHY_IF=$1
	WLINDEX=$2
	RADIO=$3
	STA_IF=$4
	WPA_SUPPLICANT_CONF_TEST="/tmp/wpa_supplicant_${STA_IF}_test_conn.conf"
	echo "${SERVICE_NAME}, restoring user defined settings on $RADIO"
	killall wpa_supplicant
	ifconfig $STA_IF down
	wlanconfig $STA_IF destroy
	rm -f $WPA_SUPPLICANT_CONF_TEST
	sysevent set wifi_sta_up 0
		sysevent set wifi-restart
	return 0
}
case "`echo $COMMAND`" in
	"is_connected")
	is_sta_connected
	;;
	"get_conn_ssid")
	get_ssid
	;;
	"get_conn_bssid")
	get_bssid
	;;
	"get_conn_radio")
	get_radio
	;;
	"get_conn_network_mode")
	get_network_mode
	;;
	"get_conn_channel_width")
	get_channel_width
	;;
	"get_conn_channel")
	get_channel
	;;
	"get_conn_signal_strength")
	get_connection_signal_strength
	;;
	"get_wireless_networks")
	get_site_survey "$2"
	;;
	"check_connection")
	check_sta_connection "$2" "$3" "$4" "$5"
	;;
	*)
	print_help
esac
