#!/bin/sh
source /etc/init.d/syscfg_api.sh
show_settings()
{
	VIR_IFNAME=$1
	
	if [ "${VIR_IFNAME}" = "ath0" ]; then
		SSID=`syscfg_get wl0_ssid`
	elif [ "${VIR_IFNAME}" = "ath2" ]; then
		SSID=`syscfg_get guest_ssid`
	elif [ "${VIR_IFNAME}" = "ath1" ]; then
		SSID=`syscfg_get wl1_ssid`
	elif [ "${VIR_IFNAME}" = "ath10" ]; then
		SSID=`syscfg_get wl2_ssid`
	fi
	
	echo "------------- ${VIR_IFNAME} Settings -------------"
	echo "Interface name: $VIR_IFNAME"
	echo "SSID: $SSID"
	echo "Mac address: `iwconfig ${VIR_IFNAME} | grep Access | awk {'print $6'}`"
	echo "`iwconfig ${VIR_IFNAME} | grep Freq | awk {'print $2 $3'}`" #Channel Frequency
	echo "Banwidth (0=HT 20HMz,1=40HMz,2=80HMz,3=80_80/160MHz): `iwpriv ${VIR_IFNAME} get_chwidth`"
	echo "Network Mode: `iwpriv ${VIR_IFNAME} get_mode`"
	echo "Guard Interval (0=auto,1=Short,2=Long): Current `iwpriv ${VIR_IFNAME} get_shortgi`"
	echo "Current connected client(s): `wlanconfig ${VIR_IFNAME} list sta`"
	echo "WMM mode (0=AC_BE, 1=AC_BK, 2=AC_VI, 3=AC_VO): `iwpriv ${VIR_IFNAME} get_wmm`"
	echo "SSID broacast (0=show and respond to probe requests, 1=hide and do not respond to probe requests) `iwpriv ${VIR_IFNAME} get_hide_ssid`"
	echo "Beacon interval (20-1000: interval in time units 1=1.024ms): `iwpriv ${VIR_IFNAME} get_bintval`"
	echo "Power save DTIM (1-255): `iwpriv ${VIR_IFNAME} get_dtim_period`"
	echo "11g protection (0=protection off, 1=protection auto): `iwpriv ${VIR_IFNAME} get_protmode`"
	echo "WDS mode (0=disable, 1=enable ): `iwpriv ${VIR_IFNAME} get_wds`"
	echo "HT20/40 Coex: `iwpriv ${VIR_IFNAME} g_disablecoext`"
	echo "HT40 intolerance: `iwpriv ${VIR_IFNAME} get_ht40intol`"
}
echo "========================== Wi-Fi General Information =========================="
PHYSICAL_IF_LIST=`syscfg_get lan_wl_physical_ifnames`
if [ "`syscfg_get wl0_state`" = "up" ]; then
	USER24_ENABLED=1
else
	USER24_ENABLED=0
fi
if [ "`syscfg_get wl1_state`" = "up" ]; then
	USER5_ENABLED=1
else
	USER5_ENABLED=0
fi
if [ "`syscfg_get wl2_state`" = "up" ]; then
	USER5_2nd_ENABLED=1
else
	USER5_2nd_ENABLED=0
fi
GUEST_ENABLED=`syscfg_get guest_enabled`
GUEST24_ENABLED=`syscfg_get wl0_guest_enabled`
GUEST5_ENABLED=`syscfg_get wl1_guest_enabled`
TC_ENABLED=`syscfg_get tc_vap_enabled`
WIFI_SCHEDULER_ENABLED=`syscfg_get wifi_scheduler::enabled`
echo "Country code                  : `iwpriv wifi0 getCountryID`"
echo "Device Serial Number          : `syscfg_get device::serial_number`"
echo "Primary 2.4GHz enabled        : $USER24_ENABLED"
echo "Primary 5GHz enabled          : $USER5_ENABLED"
echo "Second 5GHz enabled          : $USER5_2nd_ENABLED"
echo "Guest Master Switch enabled   : $GUEST_ENABLED"
echo "Guest 2.4GHz enabled          : $GUEST24_ENABLED"
echo "Guest 5GHz enabled            : $GUEST5_ENABLED"
echo "SimpleTap enabled             : $TC_ENABLED"
echo "Wi-Fi scheduler enabled       : $WIFI_SCHEDULER_ENABLED"
echo ""
echo "----- MAC address (from ifconfig) -----"
LAN_IF=`syscfg_get lan_ethernet_physical_ifnames`
WAN_IF=`syscfg_get wan_physical_ifname`
echo "LAN Mac Address			: `ifconfig ${LAN_IF} | grep HWaddr | awk '{print $5}'`"
echo "WAN Mac Address			: `ifconfig ${WAN_IF} | grep HWaddr | awk '{print $5}'`"
for PHY_IF in $PHYSICAL_IF_LIST; do
	WL_SYSCFG=`syscfg_get ${PHY_IF}_syscfg_index`
	USER_IF=`syscfg_get ${WL_SYSCFG}_user_vap`
	if [ "${WL_SYSCFG}" = "wl0" ]; then
		RADIO_NAME="2.4GHz"
	elif [ "${WL_SYSCFG}" = "wl2" ]; then
		RADIO_NAME="5GHz(2nd)"
	else
		RADIO_NAME="5GHz"
	fi
	
	echo "Primary Mac Address $RADIO_NAME	: `ifconfig ${USER_IF} | grep HWaddr | awk '{print $5}'`"
	if [ "$GUEST_ENABLED" = "1" ]; then
		if [ "`syscfg_get "${WL_SYSCFG}"_guest_enabled`" = "1" ]; then
			GUEST_IF=`syscfg_get ${WL_SYSCFG}_guest_vap`
			echo "Guest Mac Address $RADIO_NAME	: `ifconfig ${GUEST_IF}| grep HWaddr | awk '{print $5}'`"
		fi
	fi
	if [ "${WL_SYSCFG}" = "wl0" ] && [ "$TC_ENABLED" = "1" ]; then
		TC_IF=`syscfg_get tc_vap_user_vap`
		echo "SimpleTap Mac Address (2.4G)  : `ifconfig ${TC_IF}   | grep HWaddr | awk '{print $5}'`"
	fi
done
if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "wraith" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
		echo "Smart Connect SetupVAP  : `ifconfig ath4   | grep HWaddr | awk '{print $5}'`"
		echo "Smart Connect ConfigVAP  : `ifconfig ath5   | grep HWaddr | awk '{print $5}'`"
fi
echo ""
for PHY_IF in $PHYSICAL_IF_LIST; do
	WL_SYSCFG=`syscfg_get ${PHY_IF}_syscfg_index`
	USER_IF=`syscfg_get ${WL_SYSCFG}_user_vap`
	
	if [ "`syscfg_get ${WL_SYSCFG}_state`" = "up" ]; then
		show_settings ${USER_IF}
		if [ "$GUEST_ENABLED" = "1" ] && [ "`syscfg_get "${WL_SYSCFG}"_guest_enabled`" = "1" ]; then
			GUEST_IF=`syscfg_get ${WL_SYSCFG}_guest_vap`
			show_settings ${GUEST_IF}
		fi
	fi
done
echo "------------- Wi-Fi syscfg section -------------"
echo "`syscfg show | grep wl0_ | grep -v passphrase | grep -v password | sort`"
echo ""
echo "`syscfg show | grep wl1_ | grep -v passphrase | grep -v password | sort`"
echo ""
echo "`syscfg show | grep wl2_ | grep -v passphrase | grep -v password | sort`"
echo ""
echo "`syscfg show | grep guest_ | grep -v passphrase | grep -v password | sort`"
echo ""
echo "`syscfg show | grep wl_access_restriction`"
echo "`syscfg show | grep wl_mac_filter`"
if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "wraith" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
		echo "------------- Smart Connect section -------------"
		if [ "`syscfg get smart_mode::mode`" = "2" ] ; then
			echo "Smart Connect SetupVAP  : `iwconfig ath4`"
			echo "Smart Connect ConfigVAP  : `iwconfig ath5`"
		elif [ "`syscfg get smart_mode::mode`" = "1" ]; then
			echo "Smart Connect SetupVAP  : `iwconfig ath4`"
			echo "Smart Connect ConfigVAP  : `iwconfig ath5`"
			if [ "`sysevent get backhaul::intf`" = "ath9" ] ; then
				echo "5G Low backhaul  : `iwconfig ath9`"
				echo "5G High AP  : `iwconfig ath10`"
			elif [ "`sysevent get backhaul::intf`" = "ath11" ]; then
				echo "5G High backhaul  : `iwconfig ath11`"
				echo "5G Low AP  : `iwconfig ath1`"
			fi
		fi
		if [ "`syscfg get smart_mode::mode`" = "2" ] || [ "`syscfg get smart_mode::mode`" = "1" ]; then
			echo "------------- Smart Connect syscfg section -------------"
			echo "`syscfg show | grep smart_connect | grep "client_pin" -v | grep "passphrase" -v | sort`"
			echo "`syscfg show | grep smart_mode | sort`"
		fi
		if [ "`syscfg get smart_mode::mode`" = "2" ] || [ "`syscfg get smart_mode::mode`" = "1" ]; then
			echo "------------- wifi apstats section -------------"
			echo "radio level information of 2.4G:"
			apstats -r -i wifi0
			echo "radio level information of 5G low:"
			apstats -r -i wifi1
			echo "radio level information of 5G high:"
			apstats -r -i wifi2
		fi
		if [ "`syscfg get smart_mode::mode`" = "2" ] || [ "`syscfg get smart_mode::mode`" = "1" ]; then
			echo "------------- wlan_report section -------------"
			wlan_report 2>/dev/null
		fi
		echo "------------- dfs radar detect section -------------"
		echo "Radar: detect on 2.4G:"
		radartool -i wifi0 numdetects
		radartool -i wifi0 shownol
		echo "Radar: detect on 5G:"
		radartool -i wifi1 numdetects
		radartool -i wifi1 shownol
		if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
			echo "Radar: detect on 5GH:"
			radartool -i wifi2 numdetects
			radartool -i wifi2 shownol
		fi
fi
echo "========================== End Of Wi-Fi General Information =========================="
echo ""
echo ""
echo ""
echo ""
