#!/bin/sh
source /etc/init.d/service_wifi/wifi_physical.sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
source /etc/init.d/service_wifi/wifi_sta_utils.sh
source /etc/init.d/syscfg_api.sh
SERVICE_NAME="wifi_repeater"
WIFI_DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
HOSTNAME=`hostname`
BRIDGE_NAME=`syscfg_get lan_ifname`
SSID=`syscfg_get wifi_bridge::ssid`
RADIO=`syscfg_get wifi_bridge::radio`
SECURITY=`syscfg get wifi_bridge::security_mode`
PASSPHRASE=`syscfg get wifi_bridge::passphrase`
wifi_repeater_prepare()
{
	echo "${SERVICE_NAME}, prepare()"
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
		echo "$SERVICE_NAME: invalid radio specified"
	fi
	WPA_SUPPLICANT_CONF="/tmp/wpa_supplicant_$STA_IF.conf"
	syscfg_set wifi_sta_phy_if $PHY_IF
	syscfg_set wifi_sta_vir_if $STA_IF
	syscfg_commit
}
wifi_repeater_init()
{
	echo "${SERVICE_NAME}, init()"
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
	brctl addif $BRIDGE_NAME $STA_IF
}
wifi_repeater_connect()
{
	echo "${SERVICE_NAME}, connect()"
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
wifi_repeater_post_connect()
{
	echo "${SERVICE_NAME}, post_connect()"
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
		echo "${SERVICE_NAME}, verifying $STA_IF connection to $SSID"
	done
	sysevent set wifi_sta_up 0
	echo "${SERVICE_NAME}, post_connect(), $STA_IF unable to verify connection to $SSID"
	return 1
}
BRIDGE_MODE=`syscfg get bridge_mode`
if [ "1" = "$BRIDGE_MODE" ] || [ "2" = "$BRIDGE_MODE" ]; then
	WIFI_REPEATER_MODE=`syscfg get wifi_bridge::mode`
	if [ "1" = "$WIFI_REPEATER_MODE" ] || [ "2" = "$WIFI_REPEATER_MODE" ]; then
		REPEATER_UP=`sysevent get wifi_sta_up`
		if [ "1" != "$REPEATER_UP" ]; then
			wifi_repeater_prepare
			wifi_repeater_init
			wifi_repeater_connect
			wifi_repeater_post_connect
		fi
	fi
fi
exit
