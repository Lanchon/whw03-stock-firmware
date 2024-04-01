#!/bin/sh
source /etc/init.d/service_wifi/wifi_sta_utils.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
SERVICE_NAME="wifi_sta_setup"
WIFI_DEBUG_SETTING=`syscfg_get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
HOSTNAME=`hostname`
BRIDGE_NAME=`syscfg_get lan_ifname`
BRIDGE_MODE=`syscfg_get bridge_mode`
SSID=`syscfg_get wifi_bridge::ssid`
RADIO=`syscfg_get wifi_bridge::radio`
CHANNEL=`syscfg_get wifi_sta_channel`
SECURITY=`syscfg get wifi_bridge::security_mode`
PASSPHRASE=`syscfg get wifi_bridge::passphrase`
if [ "2.4GHz" = "$RADIO" ]; then
	OPMODE="11NGHT40PLUS"
	PHY_IF_MAC=`syscfg_get wl0_mac_addr | tr -d :`
	STA_MAC=`syscfg_get wl0_sta_mac_addr | tr -d :`
	PHY_IF="wifi0"
	STA_IF="ath4"
	USER_IF="ath0"
elif [ "5GHz" = "$RADIO" ]; then
	OPMODE="11ACVHT80"
	PHY_IF_MAC=`syscfg_get wl1_mac_addr | tr -d :`
	STA_MAC=`syscfg_get wl1_sta_mac_addr | tr -d :`
	PHY_IF="wifi1"
	STA_IF="ath5"
	USER_IF="ath1"
else
	echo "wifi_sta_setup: incorrect radio specified"
fi
WPA_SUPPLICANT_CONF="/tmp/wpa_supplicant_$STA_IF.conf"
syscfg_set wifi_sta_phy_if $PHY_IF
syscfg_set wifi_sta_vir_if $STA_IF
syscfg_commit
wifi_sta_prepare()
{
	ifconfig $USER_IF down
	wlanconfig $USER_IF destroy
	echo "$SERVICE_NAME, creating STA vap $STA_IF"
	wlanconfig $STA_IF create wlandev $PHY_IF wlanmode sta nosbeacon
	iwpriv $STA_IF mode $OPMODE
	iwconfig $STA_IF essid "$SSID" mode managed
	if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
		iwpriv $STA_IF wds 1
		iwpriv $STA_IF vlan_tag 1
	else
		iwpriv $STA_IF wds 0
		iwpriv $STA_IF extap 1
	fi
	iwpriv $STA_IF vhtsubfee 1
	iwpriv $STA_IF implicitbf 1
	if [ "2.4GHz" = "$RADIO" ]; then
		qca_24_amsdu_performance_fix $STA_IF
	fi
	if [ "5GHz" = "$RADIO" ]; then
		iwpriv $STA_IF vhtmubfee 1
	fi
	brctl addif br0 $STA_IF
}
wifi_sta_connect()
{
	ifconfig $PHY_IF up
	sleep 1
	echo "$SERVICE_NAME, bring up STA vap $STA_IF"
	ifconfig $STA_IF up
	sleep 1
	if [ "wpa-personal" = "$SECURITY" ] || [ "wpa2-personal" = "$SECURITY" ]; then
		generate_wpa_supplicant "$STA_IF" "$SSID" "$SECURITY" "$PASSPHRASE" "" > $WPA_SUPPLICANT_CONF
		wpa_supplicant -B -c $WPA_SUPPLICANT_CONF -i $STA_IF -b br0
	fi
}
wifi_sta_post_connect()
{
	COUNTER=0
	LINK_STATUS=0
	while [ $COUNTER -lt 30 ] && [ "0" = $LINK_STATUS ]
	do
		sleep 10
		if [ "Not-Associated" != "`iwconfig $STA_IF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`" ]; then
			LINK_STATUS=1
			sysevent set wifi_sta_up 1
			echo "${SERVICE_NAME}, post_connect(), $STA_IF connected to $SSID successfully"
                        sysevent set backhaul_ifname_list $STA_IF
			return 0
		fi
		COUNTER=`expr $COUNTER + 1`
		echo "${SERVICE_NAME}, attempting to connect $STA_IF to $SSID"
	done
	sysevent set wifi_sta_up 0
	echo "${SERVICE_NAME}, post_connect(), $STA_IF unable to connect to $SSID"
	return 1
}
if [ "1" = "$BRIDGE_MODE" ] || [ "2" = "$BRIDGE_MODE" ]; then
	WIFI_STA_ENABLED=`syscfg_get wifi_bridge::mode`
	if [ "1" = "$WIFI_STA_ENABLED" ]; then
		STA_UP=`sysevent get wifi_sta_up`
		if [ "1" != "$STA_UP" ]; then
			wifi_sta_prepare
			wifi_sta_connect
			wifi_sta_post_connect
		fi
	fi
fi
exit
