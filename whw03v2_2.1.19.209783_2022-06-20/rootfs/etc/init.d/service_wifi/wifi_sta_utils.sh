source /etc/init.d/service_wifi/wifi_utils.sh
VENDOR_2G_DEFINED_PHY_IFNAME=wdev0
VENDOR_5G_DEFINED_PHY_IFNAME=wdev1
SCRIPT_NAME="wifi_sta_utils"
WIFI_DEBUG_SETTING=`syscfg get ${SCRIPT_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
radio_to_mrvl_physical_ifname()
{
	RADIO=$1
	IFNAME=""
	INDEX=""
	case "`echo $RADIO | tr [:upper:] [:lower:]`" in
		"2.4ghz")
		INDEX=0
		;;
		"5ghz")
		INDEX=1
		;;
	esac
	
	IFNAME=`syscfg get wl"$INDEX"_physical_ifname`
	echo "$IFNAME"
}
radio_to_mrvl_wl_index()
{
	RADIO=$1
	INDEX=""
	IF=`radio_to_mrvl_physical_ifname $RADIO`
	INDEX=`echo $IF | cut -c 5`
	echo $INDEX
}
get_site_survey()
{
	RADIO=$1
	IF=""
	case "`echo "$RADIO" | tr [:upper:] [:lower:]`" in
		"2.4ghz")
		IF=wdev0
		STA_MODE=7
		;;
		"5ghz")
		IF=wdev1
		STA_MODE=8
		;;
		*)
		echo "site survey error: invalid radio"
	esac
	STA_IF="$IF"sta0
	ifconfig "$STA_IF" up
	iwpriv "$STA_IF" stamode "$STA_MODE"
	sleep 1
	iwconfig "$STA_IF" commit
	iwpriv "$STA_IF" stascan 1
	sleep 5
	iwpriv "$STA_IF" getstascan
}
is_sta_connected()
{
	STA_IF=$1 #wdev0sta0 or wdev1sta0
	iwpriv $STA_IF getlinkstatus | awk -F':' '{print $2}'
}
get_stamode_from_interface()
{
	IFNAME=$1
	STAMODE=6
	case "`echo $IFNAME | cut -c 5`" in
		"0")
		STAMODE=7
		;;
		"1")
		STAMODE=8
		;;
	esac
	echo $STAMODE
}
prepare_sta_phy_if()
{
	IF=$1
	CHANNEL=`syscfg get wifi_sta_channel`
	ifconfig $IF up
	iwpriv "$IF" autochannel 1
	if [ -n "$CHANNEL" ]; then
		iwpriv "$IF" autochannel 1
		iwconfig "$IF" channel "$CHANNEL"
	else
		iwpriv "$IF" autochannel 1
	fi
	iwpriv "$IF" wmm 1
	iwpriv "$IF" htbw 0
	sleep 1
	iwconfig $IF commit
}
akm_type_detect()
{
	PHY_INTERFACE=$1
	INTERFACE="$1"sta0
	SSID=$2
	AP_SCAN_FILE=/tmp/ap_scan.txt
	AP_SCAN_ALL_FILE=/tmp/ap_scan_all.txt
	AP_CHANNEL_FILE=/tmp/ap_channel.txt
	SECURITY=""
	ENCRYPTION=""
	RETURN=""
	STAMODE=`get_stamode_from_interface $PHY_INTERFACE`
	IS_UP=""
	IS_UP=`ifconfig $PHY_INTERFACE | grep UP`
	if [ ! -n "$IS_UP" ]; then
		prepare_sta_phy_if $PHY_INTERFACE
	fi
	iwpriv $INTERFACE stamode $STAMODE
	iwpriv $INTERFACE macclone 1
	sleep 1
	iwconfig $INTERFACE commit 
	sleep 1
	ifconfig $INTERFACE up 
	iwpriv $INTERFACE stascan 1
	sleep 10
	iwpriv $INTERFACE getstascan > "$AP_SCAN_ALL_FILE"
	cat $AP_SCAN_ALL_FILE | grep $SSID" " > "$AP_SCAN_FILE"
	FILESIZE=`stat -c %s "$AP_SCAN_FILE"`
	if [ $FILESIZE -eq 0 ]; then
		echo "failed"
		return
	fi
	SECURITY=`cat $AP_SCAN_FILE | awk -F" " '{print $7}'`
	CHANNEL=`cat $AP_SCAN_FILE | awk -F" " '{print $4}'`
	echo $CHANNEL > "$AP_CHANNEL_FILE"
	if [ "$SECURITY" != "None" ]; then
		ENCRYPTION=`cat $AP_SCAN_FILE | awk -F " " '{print $8}'`
	fi
	case "$SECURITY" in
		"None")
		RETURN="open"
		;;
		"WPA")
		RETURN="wpa-personal"
		;;
		"WPA2")
		RETURN="wpa2-personal"
		;;
		"WPA-WPA2")
		RETURN="wpa-mixed"
		;;
		*)
		RETURN="open"
		;;
	esac
	echo "$RETURN"
}
wifi_sta_set_security()
{
	IF=$1
	SECURITY=$2
	PASSPHRASE="$3"
	case "$SECURITY" in
		"wpa-personal")
			iwpriv $IF wpawpa2mode 1
			iwpriv $IF ciphersuite "wpa tkip"
			iwpriv $IF passphrase "wpa $PASSPHRASE"
			;;
		"wpa2-personal")
			iwpriv $IF wpawpa2mode 2
			iwpriv $IF ciphersuite "wpa2 aes-ccmp"
			iwpriv $IF passphrase "wpa2 $PASSPHRASE"
			;;
		"wpa-mixed")
			iwpriv $IF wpawpa2mode 2
			iwpriv $IF ciphersuite "wpa2 aes-ccmp"
			iwpriv $IF passphrase "wpa2 $PASSPHRASE"
			;;
		*)
			iwpriv $IF wpawpa2mode 0
			;;
	esac
}
qca_24_amsdu_performance_fix()
{
	VIR_IF="$1"
	wifitool $VIR_IF beeliner_fw_test 85 1
	wifitool $VIR_IF beeliner_fw_test 86 66
	wifitool $VIR_IF beeliner_fw_test 87 70
}
generate_wpa_supplicant()
{
	STA_IF=$1
	SSID=$2
	SECURITY=$3
	PASSPHRASE=$4
	DESIRED_MAC=$5
	if [ "" != "$DESIRED_MAC" ]; then
		bssid="bssid=$DESIRED_MAC"
	else
		bssid=""
	fi
	if [ "64" != "${#PASSPHRASE}" ]; then
		PASSPHRASE=\"$PASSPHRASE\"
	fi
	if [ "wpa-personal" = "$SECURITY" ]; then
		cat <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant_$STA_IF
ap_scan=2
network={
	ssid="$SSID"
	$bssid
	proto=WPA
	key_mgmt=WPA-PSK
	pairwise=TKIP
	psk=$PASSPHRASE
}
EOF
	elif [ "none" = "$SECURITY" ] || [ "disabled" = "$SECURITY" ];then
		cat <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant_$STA_IF
network={
	scan_ssid=1
	ssid="$SSID"
	$bssid
	proto=RSN
	key_mgmt=NONE
}
EOF
	else
		cat <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant_$STA_IF
network={
	scan_ssid=1
	ssid="$SSID"
	$bssid
	proto=RSN
	key_mgmt=WPA-PSK
	pairwise=CCMP TKIP
	psk=$PASSPHRASE
}
EOF
	fi
}
generate_wpa_supplicant_scan_freq()
{
	STA_IF=$1
	SSID=$2
	SECURITY=$3
	PASSPHRASE=$4
	DESIRED_MAC=$5
	FREQ_LIST=$6
	if [ "" != "$DESIRED_MAC" ]; then
		bssid="bssid=$DESIRED_MAC"
	else
		bssid=""
	fi
	if [ "64" != "${#PASSPHRASE}" ]; then
		PASSPHRASE=\"$PASSPHRASE\"
	fi
	if [ "wpa-personal" = "$SECURITY" ]; then
		cat <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant_$STA_IF
ap_scan=2
network={
	ssid="$SSID"
	$bssid
	proto=WPA
	key_mgmt=WPA-PSK
	pairwise=TKIP
	psk=$PASSPHRASE
	scan_freq=$FREQ_LIST
}
EOF
	elif [ "none" = "$SECURITY" ] || [ "disabled" = "$SECURITY" ];then
		cat <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant_$STA_IF
network={
	scan_ssid=1
	ssid="$SSID"
	$bssid
	proto=RSN
	key_mgmt=NONE
	scan_freq=$FREQ_LIST
}
EOF
	else
		cat <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant_$STA_IF
network={
	scan_ssid=1
	ssid="$SSID"
	$bssid
	proto=RSN
	key_mgmt=WPA-PSK
	pairwise=CCMP TKIP
	psk=$PASSPHRASE
	scan_freq=$FREQ_LIST
}
EOF
	fi
}
AP_interface_down()
{
	hostapd_cli -i ath0 -p /var/run/hostapd disable
	hostapd_cli -i ath5 -p /var/run/hostapd disable
	hostapd_cli -i ath1 -p /var/run/hostapd disable
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ]; then
		hostapd_cli -i ath10 -p /var/run/hostapd disable
	fi
}
AP_interface_up()
{
	C_IF="`sysevent get backhaul::intf`"
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ]; then
		if [ "ath9" = "$C_IF" ];then
			hostapd_cli -i ath10 -p /var/run/hostapd enable
		else 
			hostapd_cli -i ath1 -p /var/run/hostapd enable
		fi
	else
		hostapd_cli -i ath1 -p /var/run/hostapd enable
	fi
	hostapd_cli -i ath0 -p /var/run/hostapd enable
	hostapd_cli -i ath5 -p /var/run/hostapd enable
}
wait_channel_refreshing()
{
	local INTF="$1"
	local WAIT_CNT_MAX="$2"
	local SCANNING=`iwpriv $INTF get_acs_state | awk '{print $2}' | sed 's/.\+://'`
	local WAIT_CNT=0
	if [ -z "$WAIT_CNT_MAX" ]; then
		WAIT_CNT_MAX=20
	fi
	while [ "$SCANNING" = "1" -a "$WAIT_CNT" -lt "$WAIT_CNT_MAX" ]
	do	
		sleep 1
		WAIT_CNT=`expr $WAIT_CNT + 1`
		SCANNING=`iwpriv $INTF get_acs_state | awk '{print $2}' | sed 's/.\+://'`
	done
}
Refresh_channel()
{
	for INT in ath0 ath2 ath4 ath5 ;
	do
			sysevent set ${INT}_refresh-status up
			IF_STATE=`ifconfig $INT | grep UP | awk '{print $1}'`
			if [ "$IF_STATE" = "UP" ]; then
				hostapd_cli -i $INT -p /var/run/hostapd disable
				sysevent set ${INT}_refresh-status down
			fi
	done
	iwconfig ath0 freq 0
	for INT in ath0 ath2 ath4 ath5 ;
	do
			if [ "`sysevent get ${INT}_refresh-status`" = "down" ]; then
				hostapd_cli -i $INT -p /var/run/hostapd enable
			fi
	done
	wait_channel_refreshing "ath0"
	sysevent set wifi_channel_refreshed
}
bh_repeater_refresh_and_wait()
{
	local STA_INTF="$1"
	local CNT=0
	local WAIT_CNT_MAX=10
	local REGION="`syscfg get device::cert_region`"
	local AP_INTF
	local STATUS
	local DFS
	local AP_CHAN
	local STA_CHAN
	if [ -z "$STA_INTF" ]; then
		return 1
	fi
	if [ "1" = "`syscfg get wifi::multiregion_support`" -a "1" = "`syscfg get wifi::multiregion_enable`" -a "1" = "`get_multiregion_region_validation`" ] ; then
	    REGION=`syscfg get wifi::multiregion_region`
	else
	    REGION=`syscfg get device::cert_region`
	fi
	if [ "EU" != "$REGION" -a "ME" != "$REGION" -a "JP" != "$REGION" ] ; then
		DFS="`syscfg get wl1_dfs_enabled`"
	else 
		DFS="1"
	fi
	if [ "`cat /etc/product`" != "nodes" -a "`cat /etc/product`" != "rogue" -a "`cat /etc/product`" != "lion" ]; then
		if [ "$STA_INTF" = "ath9" ]; then
			AP_INTF=ath1
		elif [ "$STA_INTF" = "ath8" ]; then
			AP_INTF=ath0
			return 0
		else
			return 1
		fi
		if [ "$DFS" = "1" ]; then
			WAIT_CNT_MAX=60
		fi
		STA_CHAN="`iwlist $STA_INTF channel | grep "Current" | awk '{print $(NF)}' | sed 's/)//'`"
		AP_CHAN="`iwlist $AP_INTF channel | grep "Current" | awk '{print $(NF)}' | sed 's/)//'`"
		if [ "$STA_CHAN" != "$AP_CHAN" ]; then
			hostapd_cli -i $AP_INTF -p /var/run/hostapd disable
			iwconfig $AP_INTF freq 0
			hostapd_cli -i $AP_INTF -p /var/run/hostapd enable
			wait_channel_refreshing $AP_INTF
			while [ "$CNT" -lt "$WAIT_CNT_MAX" ]
			do
				STATUS="`iwconfig $AP_INTF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
				if [ ! -z "$STATUS" -a "Not-Associated" != "$STATUS" ]; then
					break
				fi
				CNT=`expr $CNT + 1`
				sleep 1
			done
		fi
	fi
	return 0
}
