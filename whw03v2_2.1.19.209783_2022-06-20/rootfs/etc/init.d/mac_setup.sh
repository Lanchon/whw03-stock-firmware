#!/bin/sh
source /etc/init.d/syscfg_api.sh
SERVICE_NAME="mac_setup"
WIFI_DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
ETH0_MAC="$1"
echo "setting up MAC addresses for all interface based on $ETH0_MAC"
display_usage()
{
	echo "Please check switch mac address" > /dev/console
	exit
}
processing() 
{
	LAN_MAC=$ETH0_MAC
	WAN_MAC=$ETH0_MAC
	W24G_MAC=`apply_mac_inc -m "$WAN_MAC" -i 1`
	W5G_MAC=`apply_mac_inc -m "$WAN_MAC" -i 2`
	W5G_2_MAC=`apply_mac_inc -m "$WAN_MAC" -i 3`
	GUEST_MAC=`apply_mac_inc -m "$WAN_MAC" -i 4`
	GUEST_MAC=`apply_mac_adbit -m "$GUEST_MAC"`
	GUEST_MAC_5G=`apply_mac_inc -m "$WAN_MAC" -i 5`
	GUEST_MAC_5G=`apply_mac_adbit -m "$GUEST_MAC_5G"`
	TC_MAC=`apply_mac_inc -m "$WAN_MAC" -i 6`
	TC_MAC=`apply_mac_adbit -m "$TC_MAC"`
	BT_MAC=$ETH0_MAC
	LAN_MAC=`echo $LAN_MAC | tr '[a-z]' '[A-Z]'`
	WAN_MAC=`echo $WAN_MAC | tr '[a-z]' '[A-Z]'`
	W24G_MAC=`echo $W24G_MAC | tr '[a-z]' '[A-Z]'`
	W5G_MAC=`echo $W5G_MAC | tr '[a-z]' '[A-Z]'`
	W5G_2_MAC=`echo $W5G_2_MAC | tr '[a-z]' '[A-Z]'`
	GUEST_MAC=`echo $GUEST_MAC | tr '[a-z]' '[A-Z]'`
	GUEST_MAC_5G=`echo $GUEST_MAC_5G | tr '[a-z]' '[A-Z]'`
	TC_MAC=`echo $TC_MAC | tr '[a-z]' '[A-Z]'`
	BT_MAC=`echo $BT_MAC | tr '[a-z]' '[A-Z]'`
	syscfg_set lan_mac_addr $LAN_MAC
	syscfg_set wan_mac_addr $WAN_MAC
	syscfg_set wl0_mac_addr $W24G_MAC
	syscfg_set wl1_mac_addr $W5G_MAC
	syscfg_set wl2_mac_addr $W5G_2_MAC
	syscfg_set wl0.1_mac_addr $GUEST_MAC
	syscfg_set wl1.1_mac_addr $GUEST_MAC_5G
	syscfg_set wl0.2_mac_addr $TC_MAC
	syscfg_set bt_mac_addr $BT_MAC
	return 0
}
default_wifi_network() {
	DEFAULT_SSID=`syscfg get device::default_ssid | sed 's/[ ]//g' | sed 's/-/_/g'`
	DEFAULT_PASSPHRASE=`syscfg get device::default_passphrase`
	syscfg_set device::default_ssid "$DEFAULT_SSID"
	syscfg_set wl2_ssid "${DEFAULT_SSID}"
	syscfg_set wl2_passphrase "$DEFAULT_PASSPHRASE"
}
if [ -z "$ETH0_MAC" ]; then
	display_usage
else
    processing
	VALIDATED=`syscfg get wl_params_validated`
	if [ "true" != "$VALIDATED" ]; then
		default_wifi_network
		syscfg_set wl_params_validated true
	fi
    syscfg_commit
fi
exit 0
