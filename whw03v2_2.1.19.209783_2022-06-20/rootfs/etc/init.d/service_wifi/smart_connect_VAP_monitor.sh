#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/service_wifi/wifi_utils.sh
SERVICE_NAME="wifi_smart_connect_client"
WIFI_DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
check_ap_abnormal_try_recover(){
	if [ "`sysevent get wifi-status`" != "started" ]; then
		return
	fi
	local INTF="$1"
	local CHAN=$(get_interface_channel $INTF)
	local CHAN_CHK=36
	if [ "$INTF" = "ath10" ]; then
		CHAN_CHK=149	
	fi
	if [ $CHAN -eq $CHAN_CHK ]; then
		local GETMODE=`iwpriv $INTF get_mode | awk -F':' '{print $2}'`
		local OPMODE=`iwconfig $INTF | sed -n '1p' | awk {'print $3'}`
		local RATE=`iwconfig $INTF | sed -n '3p' | awk {'print $2'} | awk -F':' {'print $2'}`
		if [ "$GETMODE" = "11ACVHT80" -a "$OPMODE" = "802.11a" -a "$RATE" = "54" ]; then
			echo "!!! FATAL ERROR: Seems AP interface $INTF is abnormal, try to recover !!!(`date`)" > /dev/console
			hostapd_cli -i $INTF -p /var/run/hostapd disable
			sleep 2
			hostapd_cli -i $INTF -p /var/run/hostapd enable
		else
			:
		fi
	fi
}
if [ "`sysevent get wifi-status`" != "started" ]; then
	exit
fi
if [ "0" = "`syscfg get smart_mode::mode`" ] && [ "`syscfg get xconnect::vap_enabled`" = "1" ] ; then
	if [ "`sysevent get smart_connect::setup_status`" = "READY" ] || [ "`sysevent get smart_connect::setup_status`" = "" ];then
		UNCONFIG_PHY_IF=ath4
		STATUS="`iwconfig $UNCONFIG_PHY_IF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
		if [ "Not-Associated" = "$STATUS" ] ; then
			echo "${SERVICE_NAME}, !!! Unconfig VAP $UNCONFIG_PHY_IF Not-Associated, try to bring it up(`date`)" > /dev/console
			hostapd_cli -i $UNCONFIG_PHY_IF -p /var/run/hostapd disable
			sleep 1
			hostapd_cli -i $UNCONFIG_PHY_IF -p /var/run/hostapd enable
		fi
	fi
fi
if [ "`sysevent get smart_connect::master_search_client_status`" = "RUNNING" ] && [ "2" = "`syscfg get smart_mode::mode`" ] ;then
	exit
fi
if [ "`sysevent get smart_connect::connect_client_status`" = "RUNNING" ] && [ "2" = "`syscfg get smart_mode::mode`" ] ;then
	exit
fi
if [ "DONE" != "`sysevent get smart_connect::setup_status`" ] && [ "READY" != "`sysevent get smart_connect::setup_status`" ] && [ "2" != "`syscfg get smart_mode::mode`" ] ; then
	exit
fi
if [ "up" != "`sysevent get backhaul::status`" ] && [ "1" = "`syscfg get smart_mode::mode`" ]; then
	exit
fi
if [ "`sysevent get wifi_renew_clients-status`" = "starting" ]; then
	exit
fi
sysevent set wifi_renew_VAP-status starting
for WL_SYSCFG in $SYSCFG_INDEX_LIST; do
	PHY_IF=`syscfg get ${WL_SYSCFG}_physical_ifname`
	STATUS="`iwconfig $PHY_IF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
	if [ "`sysevent get ${WL_SYSCFG}_status`" = "up" ] && [ "Not-Associated" = "$STATUS" ] && [ "$(sysevent get blocking::${PHY_IF})" = "" ]; then
		echo "${SERVICE_NAME}, !!!!!! Not-Associated happens on $PHY_IF, try to bring it back(`date`)" > /dev/console
		hostapd_cli -i $PHY_IF -p /var/run/hostapd disable
		sleep 1
		hostapd_cli -i $PHY_IF -p /var/run/hostapd enable
	fi
	if [ "1" = "`syscfg get guest_enabled`" ] && [ "1" = "`syscfg get ${WL_SYSCFG}_guest_enabled`" ] ; then
		if [ "${WL_SYSCFG}" = "wl1" ] && [ "`sysevent get backhaul::intf`" = "ath9" ] ; then
			continue
		fi
		if [ "${WL_SYSCFG}" = "wl2" ] && [ "`sysevent get backhaul::intf`" = "ath11" ] ; then
			continue
		fi
		GUEST_VAP=`syscfg get ${WL_SYSCFG}_guest_vap`
		STATUS="`iwconfig $GUEST_VAP | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
		if [ "`sysevent get ${WL_SYSCFG}_guest_status`" = "up" ] && [ "Not-Associated" = "$STATUS" ] ; then
			echo "${SERVICE_NAME}, !!!!!! Not-Associated happens on $GUEST_VAP, try to bring it back(`date`)" > /dev/console
			hostapd_cli -i $GUEST_VAP -p /var/run/hostapd disable
			sleep 1
			hostapd_cli -i $GUEST_VAP -p /var/run/hostapd enable
		fi
	fi
done
if [ "1" = "`syscfg get smart_mode::mode`" ] || [ "2" = "`syscfg get smart_mode::mode`" ] ; then
	CONFIGURED_VAP=`syscfg get smart_connect::wl0_configured_vap`
	STATUS="`iwconfig $CONFIGURED_VAP | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
	if [ "`sysevent get wl0_configured_status`" = "up" ] && [ "Not-Associated" = "$STATUS" ] ; then
		echo "${SERVICE_NAME}, !!!!!! Not-Associated happens on $CONFIGURED_VAP, try to bring it back(`date`)" > /dev/console
		hostapd_cli -i $CONFIGURED_VAP -p /var/run/hostapd disable
		sleep 1
		hostapd_cli -i $CONFIGURED_VAP -p /var/run/hostapd enable
	fi
	SETUP_VAP=`syscfg get smart_connect::wl0_setup_vap`
	STATUS="`iwconfig $SETUP_VAP | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
	if [ "`sysevent get wl0_setup_status`" = "up" ] && [ "Not-Associated" = "$STATUS" ] ; then
		echo "${SERVICE_NAME}, !!!!!! Not-Associated happens on $SETUP_VAP, try to bring it back(`date`)" > /dev/console
		hostapd_cli -i $SETUP_VAP -p /var/run/hostapd disable
		sleep 1
		hostapd_cli -i $SETUP_VAP -p /var/run/hostapd enable
	fi
fi
if [ "`cat /etc/product`" = "nodes-jr" ]; then
	check_ap_abnormal_try_recover ath1
elif [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ]; then
	check_ap_abnormal_try_recover ath1
	check_ap_abnormal_try_recover ath10
fi
sysevent set wifi_renew_VAP-status started
