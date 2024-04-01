#!/bin/sh
export TZ=`sysevent get TZ`
source /etc/init.d/syscfg_api.sh
SERVICE_NAME="wifi"
WIFI_PHYSICAL="wifi_physical"
WIFI_VIRTUAL="wifi_virtual"
WIFI_USER="wifi_user"
WIFI_GUEST="wifi_guest"
WIFI_SMART_SETUP="wifi_smart_setup"
WIFI_SMART_CONFIGURED="wifi_smart_configured"
WIFI_SMART_CONNECT="wifi_smart_connect"
WIFI_SIMPLETAP="wifi_simpletap"
SYSCFG_INDEX_LIST=`syscfg_get configurable_wl_ifs`
DEFAULT_PHYSICAL_IF_LIST=`syscfg_get lan_wl_physical_ifnames`
PHYSICAL_IF_LIST=$DEFAULT_PHYSICAL_IF_LIST
STA_PHY_IF=`syscfg_get wifi_sta_phy_if`
STA_VIR_IF=`syscfg_get wifi_sta_vir_if`
WIFI_IE_SC_SETUP="00010001"
WIFI_IE_SC_MASTER="00010003"
WIFI_IE_SC_SLAVE="00010004"
WIFI_IE_XCS_NO_LIMIT="00010002"
WIFI_IE_XCS_SLAVE_ONLY="00010012"
WIFI_IE_XCS_MASTER_ONLY="00010022"
WIFI_PRIV_NAMESPACE="lrhk"
if [ "0" != "`syscfg_get bridge_mode`" ] && [ -f /etc/init.d/service_wifi/wifi_sta_setup.sh ] && [ "1" = "`syscfg_get wifi_bridge::mode`" ] && [ ! -z $STA_VIR_IF ]; then
	if [ "wifi0" = "$STA_PHY_IF" ]; then
		USER_VAP=`syscfg_get wl0_user_vap`
	else
		USER_VAP=`syscfg_get wl1_user_vap`
	fi
	PHYSICAL_IF_LIST=`echo $DEFAULT_PHYSICAL_IF_LIST | sed 's/'"${USER_VAP}"'//g' | sed 's/ //g'`
fi
VIRTUAL_IF_LIST=`syscfg_get lan_wl_virtual_ifnames`
DEVICE_TYPE=`syscfg_get device::deviceType | awk -F":" '{print $4}'`
EXTENDER_RADIO_MODE=`syscfg_get extender_radio_mode`
HOSTNAME=`syscfg_get hostname`
CHANGED_FILE=/tmp/wl_changed_settings.conf
HTBW_AUTO=40
HTBW_20MHZ=20
HTBW_40MHZ=40
HTBW_80MHZ=80
WL0_PHYSICAL="wl0_state wl0_channel wl0_radio_band wl0_sideband wl0_network_mode wl0_security_mode wl0_wmm_ps wl0_stbc emf_wmf wl0_cts_protection_mode wl0_transmission_rate wl0_n_transmission_rate wl0_transmission_power wl0_txpower wl0_grn_field_pre wl0_ht_dup_mcs32 wl0_beacon_interval wl0_dtim_interval wl0_fragmentation_threshold wl0_rts_threshold wl_wmm_support wl_no_acknowledgement wl0_txbf_enabled wl0_dfs_enabled wl0_txbf_3x3_only wifi::wl0_mumimo_enabled"
WL1_PHYSICAL="wl1_state wl1_channel wl1_radio_band wl1_sideband wl1_network_mode wl1_security_mode wl1_wmm_ps wl1_stbc emf_wmf wl1_cts_protection_mode wl1_transmission_rate wl1_n_transmission_rate wl1_transmission_power wl1_txpower wl1_grn_field_pre wl1_ht_dup_mcs32 wl1_beacon_interval wl1_dtim_interval wl1_fragmentation_threshold wl1_rts_threshold wl_wmm_support wl_no_acknowledgement wl1_txbf_enabled wl1_dfs_enabled wl1_txbf_3x3_only wifi::wl1_mumimo_enabled WiFi::5GHz_40MHZ"
WL2_PHYSICAL="wl2_state wl2_channel wl2_radio_band wl2_sideband wl2_network_mode wl2_security_mode wl2_wmm_ps wl2_stbc emf_wmf wl2_cts_protection_mode wl2_transmission_rate wl2_n_transmission_rate wl2_transmission_power wl2_txpower wl2_grn_field_pre wl2_ht_dup_mcs32 wl2_beacon_interval wl2_dtim_interval wl2_fragmentation_threshold wl2_rts_threshold wl_wmm_support wl_no_acknowledgement wl2_txbf_enabled wl2_dfs_enabled wl2_txbf_3x3_only wifi::wl2_mumimo_enabled WiFi::5GHz_40MHZ"
WL0_VIRTUAL="wl0_key_0 wl0_key_1 wl0_key_2 wl0_key_3 wps_user_setting wl_access_restriction wl_mac_filter wl0_ssid wl0_passphrase wl0_radius_port wl0_shared wl0_tx_key wl0_ap_isolation wl0_frame_burst wl0_radius_server wl0_ssid_broadcast wl0_pmf smart_connect::configured_vap_passphrase smart_connect::configured_vap_security_mode smart_connect::configured_vap_ssid smart_connect::setup_vap_ssid device::wps_pin ${WIFI_PRIV_NAMESPACE}::enabled"
WL1_VIRTUAL="wl1_key_0 wl1_key_1 wl1_key_2 wl1_key_3 wps_user_setting wl_access_restriction wl_mac_filter wl1_ssid wl1_passphrase wl1_radius_port wl1_shared wl1_tx_key wl1_ap_isolation wl1_frame_burst wl1_radius_server wl1_ssid_broadcast wl1_pmf device::wps_pin ${WIFI_PRIV_NAMESPACE}::enabled"
WL2_VIRTUAL="wl2_key_0 wl2_key_1 wl2_key_2 wl2_key_3 wps_user_setting wl_access_restriction wl_mac_filter wl2_ssid wl2_passphrase wl2_radius_port wl2_shared wl2_tx_key wl2_ap_isolation wl2_frame_burst wl2_radius_server wl2_ssid_broadcast wl2_pmf device::wps_pin ${WIFI_PRIV_NAMESPACE}::enabled"
WL0_GUEST="guest_lan_ipaddr guest_lan_netmask guest_enabled wl0_guest_enabled guest_ssid guest_ssid_broadcast guest_password"
WL1_GUEST="guest_lan_ipaddr guest_lan_netmask guest_enabled wl1_guest_enabled wl1_guest_ssid wl1_guest_ssid_broadcast wl1_guest_password"
WL2_GUEST="guest_lan_ipaddr guest_lan_netmask guest_enabled wl2_guest_enabled wl2_guest_ssid wl2_guest_ssid_broadcast"
WL0_SIMPLETAP="tc_vap_enabled"
WL1_SIMPLETAP="tc_vap_enabled"
restart_required ()
{
	if [ "`syscfg_get ${SERVICE_NAME}_debug`" = "1" ]; then
		set +x
	fi
	MODE=$1
	SYSCFG_INDEX=$2
	RESTART=0
	PHY_INF=`get_phy_interface_name_from_syscfg $SYSCFG_INDEX`
	if [ "`cat /etc/product`" != "nodes" ] && [ "`cat /etc/product`" != "nodes-jr" ] && [ "`cat /etc/product`" != "rogue" ] && [ "`cat /etc/product`" != "lion" ] ; then
		if [ "physical" = "$MODE" ]; then
			if [ "2" = "`syscfg_get wifi_bridge::mode`" ] && [ "$PHY_INF" = "`syscfg_get wifi_sta_phy_if`" ]; then
				echo "restart_required: $PHY_INF is repeater, do not restart physical interface"
				return 0
			fi
		fi
	fi
	FILENAME=/tmp/"$SYSCFG_INDEX"_"$MODE"_settings.conf
	if [ ! -f $FILENAME ]; then
		create_files
		RESTART=1
	else
		INFO_NEEDED=`get_settings_list $MODE $SYSCFG_INDEX`
		for FIELD in $INFO_NEEDED; do
			INFO=`syscfg_get ${FIELD}`
			FIELD_DATA="$FIELD":" $INFO"
			FROM_FILE=`cat ${FILENAME} | grep "^$FIELD:"`
			if [ "$FROM_FILE" != "$FIELD_DATA" ] ; then
				RESTART=1 #set flag to indicate restart when the remaining settings that have changed
				echo "$FIELD" >> $CHANGED_FILE
			fi
		done
	fi
	if [ "`syscfg_get ${SERVICE_NAME}_debug`" = "1" ]; then
		set -x
	fi
	return $RESTART
}
get_settings_list()
{
	MODE=$1
	SYSCFG_INDEX=$2
	INFO_NEEDED=""
	if [ "wl0" = "$SYSCFG_INDEX" ]; then
		if [ "physical" = "$MODE" ]; then
			INFO_NEEDED=$WL0_PHYSICAL
		elif [ "virtual" = "$MODE" ]; then
			INFO_NEEDED=$WL0_VIRTUAL
		elif [ "guest" = "$MODE" ]; then
			INFO_NEEDED=$WL0_GUEST
		elif [ "simpletap" = "$MODE" ]; then
			INFO_NEEDED=$WL0_SIMPLETAP
		fi
	elif [ "wl1" = "$SYSCFG_INDEX" ]; then
		if [ "physical" = "$MODE" ]; then
			INFO_NEEDED=$WL1_PHYSICAL
		elif [ "virtual" = "$MODE" ]; then
			INFO_NEEDED=$WL1_VIRTUAL
		elif [ "guest" = "$MODE" ]; then
			INFO_NEEDED=$WL1_GUEST
		elif [ "simpletap" = "$MODE" ]; then
			INFO_NEEDED=$WL1_SIMPLETAP
		fi
	elif [ "wl2" = "$SYSCFG_INDEX" ]; then
		if [ "physical" = "$MODE" ]; then
			INFO_NEEDED=$WL2_PHYSICAL
		elif [ "virtual" = "$MODE" ]; then
			INFO_NEEDED=$WL2_VIRTUAL
		elif [ "guest" = "$MODE" ]; then
			INFO_NEEDED=$WL2_GUEST
		fi
	fi
	echo "$INFO_NEEDED"
}
create_files ()
{
	for MODE in physical virtual guest simpletap
	do
		SYSCFG_INDEX_LIST=`syscfg_get configurable_wl_ifs`
		for SYSCFG_INDEX in $SYSCFG_INDEX_LIST; do
			FILENAME=/tmp/"$SYSCFG_INDEX"_"$MODE"_settings.conf
			ulog wlan status "${SERVICE_NAME}, cache: saving $SYSCFG_INDEX $MODE settings"
			INFO_NEEDED=`get_settings_list $MODE $SYSCFG_INDEX`
			for FIELD in $INFO_NEEDED; do
				INFO=`syscfg_get ${FIELD}`
				FIELD_DATA="$FIELD":" $INFO"
				echo "$FIELD_DATA" >> $FILENAME
			done
		done
	done
}
update_wifi_cache ()
{
	if [ "`syscfg_get ${SERVICE_NAME}_debug`" = "1" ]; then
		set +x
	fi
	MODE=$1
	SYSCFG_INDEX=$2
	if [ "physical" != "$MODE" ] && [ "virtual" != "$MODE" ] && [ "guest" != "$MODE" ] ; then
		echo "Fatal error, the settings will not be saved" > /dev/console
		if [ "`syscfg_get ${SERVICE_NAME}_debug`" = "1" ]; then
			set -x
		fi
		return 1
	fi
	FILENAME=/tmp/"$SYSCFG_INDEX"_"$MODE"_settings.conf
	ulog wlan status "${SERVICE_NAME}, cache: updating $SYSCFG_INDEX $MODE settings"
	INFO_NEEDED=`get_settings_list $MODE $SYSCFG_INDEX`
	for FIELD in $INFO_NEEDED; do
		INFO=`syscfg_get ${FIELD} | sed 's/\&/\\\&/g'`
		FIELD_DATA="$FIELD":" $INFO"
		sed -i 's/'"$FIELD"':.*/'"$FIELD_DATA"'/g' $FILENAME
		if [ $? -ne 0 ] ; then
			FIELD_DATA="$FIELD":" "
			sed -i 's/'"$FIELD"':.*/'"$FIELD_DATA"'/g' $FILENAME
		fi
	done
	if [ "`syscfg_get ${SERVICE_NAME}_debug`" = "1" ]; then
		set -x
	fi
	return 0
}
wifi_refresh_interfaces()
{
	WL0STATE=`syscfg_get wl0_state`
	WL1STATE=`syscfg_get wl1_state`
	WL2STATE=`syscfg_get wl2_state`
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`sysevent get backhaul::intf`" = "ath9" ] ; then
		WL1STATE="down"
	fi
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`sysevent get backhaul::intf`" = "ath11" ] ; then
		WL2STATE="down"
	fi
	if [ "up" = "$WL0STATE" ]; then
		IF=`syscfg get wl0_physical_ifname`
		hostapd_cli -i $IF -p /var/run/hostapd disable
		if [ "1" = "`syscfg_get wl0_guest_enabled`" ] && [ "1" = "`syscfg_get guest_enabled`" ]; then
			GA_IF=`syscfg get wl0_guest_vap`
			hostapd_cli -i $GA_IF -p /var/run/hostapd disable
		fi
		sleep 1
		if [ "1" = "`syscfg_get wl0_guest_enabled`" ] && [ "1" = "`syscfg_get guest_enabled`" ]; then
			hostapd_cli -i $GA_IF -p /var/run/hostapd enable
		fi
		hostapd_cli -i $IF -p /var/run/hostapd enable
	fi
	if [ "up" = "$WL1STATE" ]; then
		IF=`syscfg get wl1_physical_ifname`
		hostapd_cli -i $IF -p /var/run/hostapd disable
		if [ "1" = "`syscfg_get wl1_guest_enabled`" ] && [ "1" = "`syscfg_get guest_enabled`" ]; then
			GA_IF=`syscfg get wl1_guest_vap`
			hostapd_cli -i $GA_IF -p /var/run/hostapd disable
		fi
		sleep 1
		if [ "1" = "`syscfg_get wl1_guest_enabled`" ] && [ "1" = "`syscfg_get guest_enabled`" ]; then
			hostapd_cli -i $GA_IF -p /var/run/hostapd enable
		fi
		hostapd_cli -i $IF -p /var/run/hostapd enable
	fi
	if [ "up" = "$WL2STATE" ]; then
		IF=`syscfg get wl2_physical_ifname`
		hostapd_cli -i $IF -p /var/run/hostapd disable
		sleep 1
		hostapd_cli -i $IF -p /var/run/hostapd enable
	fi
	return
}
get_interface_channel()
{
	INT=$1
	CHANNEL="`iwlist $INT channel | grep "Current" | awk '{print $(NF)}' | sed 's/)//'`"
	echo "$CHANNEL"
}
get_phy_interface_name_from_syscfg()
{
	SYSCFG=$1
	INF=""
	if [ "$SYSCFG" = "`syscfg_get ath0_syscfg_index`" ]; then
		INF="ath0"
	elif [ "$SYSCFG" = "`syscfg_get ath10_syscfg_index`" ]; then
		INF="ath10"
	else
		INF="ath1"
	fi
	echo "$INF"
}
get_phy_interface_name_from_vap()
{
	PHY_IF=$1
	INF=""
	if [ "$PHY_IF" = "ath0" -o "$PHY_IF" = "ath2" -o "$PHY_IF" = "ath4" -o "$PHY_IF" = "ath5" ]; then
		INF="wifi0"
	elif [ "$PHY_IF" = "ath10" ]; then
		INF="wifi2"
	else
		INF="wifi1"
	fi
	echo "$INF"
}
get_wifi_validation() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	NET=`get_driver_network_mode "$PHY_IF"`
	SEC=`get_security_mode ${SYSCFG_INDEX}_security_mode`
	RET=0 #0/1 for false/true, default is true
	case $NET in
		"$NET_N_ONLY_24G"|"$NET_GN_MIXED"|"$NET_BGN_MIXED"|"$NET_AN_MIXED"|"$NET_N_ONLY_5G"|"$NET_BGNAC_MIXED"|"$NET_ANAC_MIXED") # n-mode, ac-mode and mixed mode
		    case $SEC in
				"2"|"3"|"5"|"6")
				    RET=1
				    ;;
				"1"|"4")
				    RET=2
				    ;;
				"7"|"8")
				    RET=2
				    ;;
				"0")
				    RET=1
				    ;;
				*)
				    RET=0
				    ;;
		    esac
		    ;;
		"$NET_B_ONLY"|"$NET_G_ONLY"|"$NET_BG_MIXED"|"$NET_A_ONLY") # Legalcy support wpa, wpa2, wpa/wpa2 mixed, radius, wep
			case $SEC in
				"1"|"2"|"3"|"4"|"5"|"6")
					RET=1
					;;
				"7"|"8")
					RET=1
					;;
				"0")
					RET=1
					;;
				*)
					RET=0
					;;
			esac
			;;
		*)
			RET=0
			;;
	esac
	return "$RET"
}
get_driver_network_mode() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	OPMODE=0
	SYSCFG_NETWORK_MODE=""
	if [ "Extender" = "$DEVICE_TYPE" ]; then
		if [ ! -z "$EXTENDER_RADIO_MODE" ] && [ $EXTENDER_RADIO_MODE = "1" ]; then
			SYSCFG_NETWORK_MODE=`syscfg_get wl1_network_mode`
		else
			SYSCFG_NETWORK_MODE=`syscfg_get wl0_network_mode`
		fi
		SYSCFG_INDEX=wl"$EXTENDER_RADIO_MODE"
	else
		SYSCFG_NETWORK_MODE=`syscfg_get "$SYSCFG_INDEX"_network_mode`
	fi
	case "$SYSCFG_NETWORK_MODE" in
		"11a")
			OPMODE="$NET_A_ONLY"
			;;
		"11b")
			OPMODE="$NET_B_ONLY"
			;;
		"11g")
			OPMODE="$NET_G_ONLY"
			;;
		"11n")
			if [ "$SYSCFG_INDEX" = "wl0" ]; then
				OPMODE="$NET_N_ONLY_24G"
			else
				OPMODE="$NET_N_ONLY_5G"
			fi
			;;
		"11b 11g")
			OPMODE="$NET_BG_MIXED"
			;;
		"11g 11n")
			OPMODE="$NET_GN_MIXED"
			;;
		"11a 11n")
			OPMODE="$NET_AN_MIXED"
			;;
		"11b 11g 11n")
			OPMODE="$NET_BGN_MIXED"
			;;
		"11b 11g 11n 11ac")
			OPMODE="$NET_BGNAC_MIXED"
			;;
		"11a 11n 11ac")
			OPMODE="$NET_ANAC_MIXED"
			;;
		"Mixed" | "mixed" | "MIXED")
			if [ "$SYSCFG_INDEX" = "wl0" ]; then
				OPMODE="$NET_BGNAC_MIXED"
			else
				OPMODE="$NET_ANAC_MIXED"
			fi
			;;
		*)
			if [ "$SYSCFG_INDEX" = "wl0" ]; then
				OPMODE="$NET_BGNAC_MIXED"
			else
				OPMODE="$NET_ANAC_MIXED"
			fi
			;;
	esac
	
	echo "$OPMODE"
}
get_wl_index() 
{
	wl_index=0
	if [ "Extender" = "$DEVICE_TYPE" ]; then
		if [ ! -z "$EXTENDER_RADIO_MODE" ] && [" $EXTENDER_RADIO_MODE" = "1" ]; then
			wl_index=1
		else
			wl_index=0
		fi
	else
		wl_index=`echo $1 | cut -c4`
	fi
	if [ "ath2" = "$1" ] || [ "ath4" = "$1" ] || [ "ath5" = "$1" ]; then
		wl_index=0
	elif [ "ath3" = "$1" ] || [ "ath6" = "$1" ] || [ "ath7" = "$1" ]; then
		wl_index=1
	elif [ "ath10" = "$1" ] ; then
		wl_index=2
	fi
	
	return "$wl_index"
}
get_security_mode() 
{
	SECURITY_MODE=""
	INDEX=0
	if [ "Extender" = "$DEVICE_TYPE" ]; then
		if [ ! -z "$EXTENDER_RADIO_MODE" ] && [ $EXTENDER_RADIO_MODE = "1" ]; then
			INDEX=1
		else
			INDEX=0
		fi
		MODE_STRING=`syscfg_get wl"$INDEX"_security_mode`
	else
		MODE_STRING=`syscfg_get $1`
	fi
	SUPPORT_TYPE="`syscfg get wl"$INDEX"_supported_sec_types`"
	if [ "" = "`echo "$SUPPORT_TYPE" |grep "$MODE_STRING"`" ]; then
		if [ "wpa3-open" = "$MODE_STRING" ];then
			MODE_STRING="disabled"
		elif [ "wpa3-mixed" = "$MODE_STRING" ];then
			MODE_STRING="wpa2-personal"
		fi
	fi
	
	if [ "wpa-personal" = "$MODE_STRING" ]; then
		SECURITY_MODE=1	
	elif [ "wpa2-personal" = "$MODE_STRING" ]; then
		SECURITY_MODE=2	
	elif [ "wpa-mixed" = "$MODE_STRING" ]; then
		SECURITY_MODE=3	
	elif [ "wpa-enterprise" = "$MODE_STRING" ]; then
		SECURITY_MODE=4	
	elif [ "wpa2-enterprise" = "$MODE_STRING" ]; then
		SECURITY_MODE=5	
	elif [ "wpa-enterprise-mixed" = "$MODE_STRING" ]; then
		SECURITY_MODE=6	
	elif [ "radius" = "$MODE_STRING" ]; then
		SECURITY_MODE=7	
	elif [ "wep" = "$MODE_STRING" ]; then
		SECURITY_MODE=8	
	elif [ "wep-auto" = "$MODE_STRING" ]; then
		SECURITY_MODE=8	
	elif [ "wep-open" = "$MODE_STRING" ]; then
		SECURITY_MODE=8	
	elif [ "wep-shared" = "$MODE_STRING" ]; then
		SECURITY_MODE=8
	elif [ "wpa2-personal-mpsk" = "$MODE_STRING" ]; then
		SECURITY_MODE=9		
	elif [ "wpa3-personal" = "$MODE_STRING" ]; then
		SECURITY_MODE=11	
	elif [ "wpa3-mixed" = "$MODE_STRING" ]; then
		SECURITY_MODE=12	
	elif [ "wpa3-enterprise" = "$MODE_STRING" ]; then
		SECURITY_MODE=13	
	elif [ "wpa3-open" = "$MODE_STRING" ]; then
		SECURITY_MODE=14
	elif [ "disabled" = "$MODE_STRING" ]; then
		SECURITY_MODE=0	
	else 
		SECURITY_MODE=0	
	fi
	echo "$SECURITY_MODE"	
}
get_encryption() 
{
	ENCRYPTION_MODE=""
	wl_index=""
	if [ "Extender" = "$DEVICE_TYPE" ]; then
		if [ ! -z "$EXTENDER_RADIO_MODE" ] && [ $EXTENDER_RADIO_MODE = "1" ]; then
			wl_index=1
		else
			wl_index=0
		fi
		ENCRYPTION_STRING=`syscfg_get wl"$INDEX"_encryption`
	else
		wl_index=`echo $1 | cut -c3`
		ENCRYPTION_STRING=`syscfg_get $1`
	fi
	SEC_MODE=`syscfg_get wl"$wl_index"_security_mode`
	if [ "wep" = "$SEC_MODE" ] || [ "wep-auto" = "$SEC_MODE" ] || [ "wep-open" = "$SEC_MODE" ] || [ "wep-shared" = "$SEC_MODE" ]; then
		TX_KEY=`syscfg_get wl"$wl_index"_tx_key`
		INDEX_KEY=`expr $TX_KEY - 1`
		CURRENT_KEY=`syscfg_get wl"$wl_index"_key_"$INDEX_KEY"`
		CURRENT_KL=`echo $CURRENT_KEY | wc -c`
		if [ 11 = `expr $CURRENT_KL` ] || [ 6 = `expr $CURRENT_KL` ]; then
			ENCRYPTION_MODE="64-bits"
		elif [ 27 = `expr $CURRENT_KL` ] || [ 14 = `expr $CURRENT_KL` ]; then
			ENCRYPTION_MODE="128-bits"
		fi
	else
		case "$ENCRYPTION_STRING" in
		"aes")
			ENCRYPTION_MODE="CCMP"
			;;
		"tkip")
			ENCRYPTION_MODE="TKIP"
			;;
		"tkip+aes")
			ENCRYPTION_MODE="TKIP CCMP"
			;;
		esac
	fi
	echo "$ENCRYPTION_MODE"	
}
get_ssid_broadcast() 
{
	SYSCFG_INDEX=$1
	if [ "Extender" = "$DEVICE_TYPE" ]; then
		if [ ! -z "$EXTENDER_RADIO_MODE" ] && [ $EXTENDER_RADIO_MODE = "1" ]; then
			SYSCFG_INDEX="wl1"
		else
			SYSCFG_INDEX="wl0"
		fi
	fi
	ssid_broadcast=`syscfg_get ${SYSCFG_INDEX}_ssid_broadcast`
	if [ -z "$ssid_broadcast" ]; then
		ssid_broadcast=1
	fi
	echo "$ssid_broadcast"
}
set_driver_mac_filter_enabled () 
{
	if_name=$1
	FILTER_OPTION=`syscfg_get wl_access_restriction`
	MAC_ENTRIES=`syscfg_get wl_mac_filter`
	if [ "$FILTER_OPTION" = "allow" ] || [ "$FILTER_OPTION" = "deny" ]; then
		if [ "$FILTER_OPTION" = "allow" ]; then
			iwpriv $if_name maccmd 1
		else
			iwpriv $if_name maccmd 2
		fi
		for MAC in $MAC_ENTRIES; do
			iwpriv $if_name addmac $MAC
		done
	fi
	return 0
}
set_driver_mac_filter_disabled() 
{
	if_name=$1
	iwpriv $if_name maccmd 3
	iwpriv $if_name maccmd 0
}
get_syscfg_interface_name()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$1"_syscfg_index`
	echo "$SYSCFG_INDEX"
}
add_guest_vlan_to_backhaul()
{
	INTF=$1
	VID=`syscfg_get guest_vlan_id`
	GUEST_BRIDGE=`syscfg_get guest_lan_ifname`
	vconfig set_name_type DEV_PLUS_VID_NO_PAD
	if [ ! -e /proc/net/vlan/$INTF.$VID ] ; then
		    vconfig add $INTF $VID
	fi
	add_interface_to_bridge $INTF.$VID $GUEST_BRIDGE
	ebtables -t broute -I BROUTING -i $INTF -p 802.1Q --vlan-id $VID -j DROP
	if [ "`cat /etc/product`" = "nodes"  -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
			ifconfig $INTF.$VID up
	fi
	return 0
}
delete_guest_vlan_from_backhaul()
{
	VID=`syscfg_get guest_vlan_id`
	BACKHAUL_IF_LIST=`sysevent get backhaul_ifname_list`
	for INTF in $BACKHAUL_IF_LIST; do
		vconfig rem $INTF.$VID
		ebtables -t broute -D BROUTING -i $INTF -p 802.1Q --vlan-id $VID -j DROP
	done
	return 0
}
add_interface_to_bridge()
{
	VAP=$1
	BRIDGE=$2
	if [ -z "$BRIDGE" ]; then	 
		ulog wlan status "${SERVICE_NAME}, add_interface_to_bridge(), bridge name is empty"
		return 1
	fi
	TEMP=`brctl show | grep ${BRIDGE} | awk '{print $1}'`
	if [ "$BRIDGE" = "$TEMP" ]; then
		MAC_1=`get_mac ${VAP}`
		if [ ! -z "$MAC_1" ]; then	 
			ip link set $VAP allmulticast on
			MAC_2=`brctl showmacs ${BRIDGE} | grep ${MAC_1} | awk '{print $2}'`
			if [ "${MAC_1}" = "${MAC_2}" ]; then
				brctl delif $BRIDGE $VAP
			fi
			brctl addif $BRIDGE $VAP
		fi
	fi 
	return 0
}
delete_interface_from_bridge()
{
	VAP=$1
	BRIDGE=$2
	ip link set $VAP allmulticast off
	if [ -z "$BRIDGE" ]; then	 
		ulog wlan status "${SERVICE_NAME}, delete_interface_to_bridge(), bridge name is empty"
		return 1
	fi
	TEMP=`brctl show | grep ${BRIDGE} | awk '{print $1}'`
	if [ "$BRIDGE" = "$TEMP" ]; then 
		MAC_1=`get_mac ${VAP}`
		if [ ! -z "$MAC_1" ]; then	 
			MAC_2=`brctl showmacs ${BRIDGE} | grep ${MAC_1} | awk '{print $2}'`
			if [ "${MAC_1}" = "${MAC_2}" ]; then
				brctl delif $BRIDGE $VAP
			fi
		fi
	fi 
	return 0
}
get_physical_interface_state() 
{
	PHY_IF=$1
	STATE=`ifconfig $PHY_IF | grep MTU | awk '/UP/ {print $1}'`
	if [ ! -z "$STATE" ] && [ "$STATE" = "UP" ]; then
		STATE="up"
	else
		STATE="down"
	fi
	echo "$STATE"
}
get_mac_address()
{
	PHY_IF=$1
	MAC=`ifconfig $PHY_IF | grep HWaddr | awk '{print $5}'`
	echo "$MAC"
}
set_countryie() 
{
	VIR_IF=$1
	if [ "1" = "`syscfg_get wifi::multiregion_support`" -a "1" = "`syscfg_get wifi::multiregion_enable`" -a "1" = "`get_multiregion_region_validation`" ] ; then
	    REGION=`syscfg get wifi::multiregion_region`
	else
	    REGION=`syscfg_get device::cert_region`
	fi
	if [ "$REGION" = "US" ]; then
		return 0
	else
		iwpriv $VIR_IF countryie 0 
	fi
}
set_11ngvhtintop() 
{
	VIR_IF=$1
	BRCM_IOT_ENABLED=`syscfg_get wl0_brcm_iot_enabled`
	if [ "1" = "$BRCM_IOT_ENABLED" ]; then
		iwpriv $VIR_IF 11ngvhtintop 1
	else
		iwpriv $VIR_IF 11ngvhtintop 0
	fi
}
qca_wifi_smp_affinity()
{
    if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "dallas" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
    	echo 2 > /proc/irq/174/smp_affinity
    fi
    echo 4 > /proc/irq/200/smp_affinity
    echo 8 > /proc/irq/201/smp_affinity
}
load_wifi_driver()
{
	ulog wlan status "${SERVICE_NAME}, loading Wi-Fi driver"
	echo "[utopia][init] Loading GMAC and WLAN drivers"
	if [ -e /lib/modules/`uname -r`/qca_da.ko ]; then
	 /sbin/modprobe qca_da
	 /sbin/modprobe qca_ol
	else		
	 /sbin/modprobe umac
	fi
	
	MODEL_NAME=`syscfg get device::model_base`
	if [ -z "$MODEL_NAME" ] ; then
		MODEL_NAME=`syscfg get device::modelNumber`
		MODEL_NAME=${MODEL_NAME%-*}	
	fi
    if [ "$MODEL_NAME" != "EA8500" ] && [ "$MODEL_NAME" != "EA7500" ] && [ "$MODEL_NAME" != "EA6350" ]; then
	    /sbin/modprobe shortcut-fe
    fi
	HW_ADDR=`syscfg get wl0_mac_addr`
	iwpriv wifi0 setHwaddr $HW_ADDR
	HW_ADDR=`syscfg get wl1_mac_addr`
	iwpriv wifi1 setHwaddr $HW_ADDR
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "dallas" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		HW_ADDR=`syscfg get wl2_mac_addr`
		iwpriv wifi2 setHwaddr $HW_ADDR
	fi
	echo "[utopia][init] Creating wifi devices"
	/usr/sbin/wlanconfig ath0 create wlandev wifi0 wlanmode ap
	/usr/sbin/wlanconfig ath1 create wlandev wifi1 wlanmode ap
	
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "dallas" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		/usr/sbin/wlanconfig ath10 create wlandev wifi2 wlanmode ap
		/sbin/ifconfig ath10 txqueuelen 1000
		/sbin/ifconfig wifi2 txqueuelen 1000
	fi
	/sbin/ifconfig ath0 txqueuelen 1000
	/sbin/ifconfig ath1 txqueuelen 1000
	/sbin/ifconfig wifi0 txqueuelen 1000
	/sbin/ifconfig wifi1 txqueuelen 1000
    qca_wifi_smp_affinity    
}
is_legalcy_mode()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_NETWORK_MODE=""
	RET_STR="false"
	
	SYSCFG_NETWORK_MODE=`syscfg_get "$SYSCFG_INDEX"_network_mode`
	case "$SYSCFG_NETWORK_MODE" in
		"11a")
			RET_STR="true"
			;;
		"11b 11g")
			RET_STR="true"
			;;
		"11b")
			RET_STR="true"
			;;
		"11g")
			RET_STR="true"
			;;
		*)
			RET_STR="false"
			;;
	esac
	echo "$RET_STR"
}
is_11ac_supported() 
{
	WL_SYSCFG=$1
	RET_CODE="0"
	CHIP_TYPE=`syscfg get "$WL_SYSCFG"_chip`
	if [ "$CHIP_TYPE" = "11ac" ]; then
		RET_CODE="1"
	fi
	echo "$RET_CODE"
}
set_driver_obss_rssi_threshold()
{
	PHY_IF=$1
	echo "wifi, setting obss rssi threshold ($PHY_IF)"
	INT=`get_phy_interface_name_from_vap "$PHY_IF"`
	ifconfig $INT down
	iwpriv $INT obss_rssi_th 35
	iwpriv $INT obss_rx_rssi_th 35
	ifconfig $INT up
	return 0
}
set_driver_enable_ol_stats()
{
	PHY_IF=$1
	INT=`get_phy_interface_name_from_vap "$PHY_IF"`
	iwpriv $INT enable_ol_stats 1
}
freq_to_band()
{
	local FREQ="$1"
	local BAND=""
	if [ "$FREQ" -ge "2412" -a "$FREQ" -le "2472" ];then
		BAND=0
	elif [ "$FREQ" -ge "5180" -a "$FREQ" -le "5320" ]; then
		BAND=1
	elif [ "$FREQ" -ge "5500" -a "$FREQ" -le "5825" ]; then
		BAND=2
	elif [ "$FREQ" -ge "5925" -a "$FREQ" -le "7125" ]; then
		BAND=3
	fi
	echo "$BAND"
}
freq_to_band_name()
{
	local FREQ="$1"
	local BAND_NAME=""
	local BAND
	local Support_5GH="`syscfg get configurable_wl_ifs |grep wl2`"
	BAND=$(freq_to_band $FREQ)
	case "$BAND" in
		"0")
			BAND_NAME="2.4G"
			;;
		"1")
			BAND_NAME="5GL"
			;;
		"2")
			if [ "" != "$Support_5GH" ];then
				BAND_NAME="5GH"
			else
				BAND_NAME="5GL"
			fi
			;;
		"3")
			BAND_NAME="6G"
			;;
	esac
	echo "$BAND_NAME"
}
change_freq_to_chan()
{
	UP_FREQ=$1
	case "$UP_FREQ" in
		"2412")
			UP_CHAN="1"
		;;
		"2417")
			UP_CHAN="2"
		;;
		"2422")
			UP_CHAN="3"
		;;
		"2427")
			UP_CHAN="4"
		;;
		"2432")
			UP_CHAN="5"
		;;
		"2437")
			UP_CHAN="6"
		;;
		"2442")
			UP_CHAN="7"
		;;
		"2447")
			UP_CHAN="8"
		;;
		"2452")
			UP_CHAN="9"
		;;
		"2457")
			UP_CHAN="10"
		;;
		"2462")
			UP_CHAN="11"
		;;
		"2467")
			UP_CHAN="12"
		;;
		"2472")
			UP_CHAN="13"
		;;
		"5180")
			UP_CHAN="36"
		;;
		"5200")
			UP_CHAN="40"
		;;
		"5220")
			UP_CHAN="44"
		;;
		"5240")
			UP_CHAN="48"
		;;
		"5260")
			UP_CHAN="52"
		;;
		"5280")
			UP_CHAN="56"
		;;
		"5300")
			UP_CHAN="60"
		;;
		"5320")
			UP_CHAN="64"
		;;
		"5500")
			UP_CHAN="100"
		;;
		"5520")
			UP_CHAN="104"
		;;
		"5540")
			UP_CHAN="108"
		;;
		"5560")
			UP_CHAN="112"
		;;
		"5580")
			UP_CHAN="116"
		;;
		"5600")
			UP_CHAN="120"
		;;
		"5620")
			UP_CHAN="124"
		;;
		"5640")
			UP_CHAN="128"
		;;
		"5660")
			UP_CHAN="132"
		;;
		"5680")
			UP_CHAN="136"
		;;
		"5700")
			UP_CHAN="140"
		;;
		"5720")
			UP_CHAN="144"
		;;
		"5745")
			UP_CHAN="149"
		;;
		"5765")
			UP_CHAN="153"
		;;
		"5785")
			UP_CHAN="157"
		;;
		"5805")
			UP_CHAN="161"
		;;
		"5825")
			UP_CHAN="165"
		;;
		*)
			echo "Can't find this channel $UP_FREQ"
			UP_CHAN="0"
		;;
	esac
	return $UP_CHAN
}
chan_to_freq()
{
	local UP_CHAN=$1
	case "$UP_CHAN" in
		"1")
			UP_FREQ=2412
		;;
		"2")
			UP_FREQ=2417
		;;
		"3")
			UP_FREQ=2422
		;;
		"4")
			UP_FREQ=2427
		;;
		"5")
			UP_FREQ=2432
		;;
		"6")
			UP_FREQ=2437
		;;
		"7")
			UP_FREQ=2442
		;;
		"8")
			UP_FREQ=2447
		;;
		"9")
			UP_FREQ=2452
		;;
		"10")
			UP_FREQ=2457
		;;
		"11")
			UP_FREQ=2462
		;;
		"12")
			UP_FREQ=2467
		;;
		"13")
			UP_FREQ=2472
		;;
		"36")
			UP_FREQ=5180
		;;
		"40")
			UP_FREQ=5200
		;;
		"44")
			UP_FREQ=5220
		;;
		"48")
			UP_FREQ=5240
		;;
		"52")
			UP_FREQ=5260
		;;
		"56")
			UP_FREQ=5280
		;;
		"60")
			UP_FREQ=5300
		;;
		"64")
			UP_FREQ=5320
		;;
		"100")
			UP_FREQ=5500
		;;
		"104")
			UP_FREQ=5520
		;;
		"108")
			UP_FREQ=5540
		;;
		"112")
			UP_FREQ=5560
		;;
		"116")
			UP_FREQ=5580
		;;
		"120")
			UP_FREQ=5600
		;;
		"124")
			UP_FREQ=5620
		;;
		"128")
			UP_FREQ=5640
		;;
		"132")
			UP_FREQ=5660
		;;
		"136")
			UP_FREQ=5680
		;;
		"140")
			UP_FREQ=5700
		;;
		"144")
			UP_FREQ=5720
		;;
		"149")
			UP_FREQ=5745
		;;
		"153")
			UP_FREQ=5765
		;;
		"157")
			UP_FREQ=5785
		;;
		"161")
			UP_FREQ=5805
		;;
		"165")
			UP_FREQ=5825
		;;
		*)
			UP_FREQ=0
		;;
	esac
	echo $UP_FREQ
}
is_dfs_chan()
{
	CHAN="$1"
	DFS_CHANS="52 56 60 64 100 104 108 112 116 120 124 128 132 136 140"
	NONDFS_CHANS_IN="52 56 60 64"
	RETVAL=0
	if [ "1" = "`syscfg_get wifi::multiregion_support`" -a "1" = "`syscfg_get wifi::multiregion_enable`" -a "1" = "`get_multiregion_region_validation`" ] ; then
	    REGION=`syscfg get wifi::multiregion_region`
	else
	    REGION=`syscfg_get device::cert_region`
	fi
	for ch in $DFS_CHANS; do
		if [ "$ch" = "$CHAN" ]; then
			RETVAL=1
			break
		fi
	done
	if [ "$REGION" = "IN" ]; then
		for ch in $NONDFS_CHANS_IN; do
			if [ "$ch" = "$CHAN" ]; then
				RETVAL=0
				break
			fi
		done
	fi
	echo $RETVAL
}
check_ap()
{
	IF=$1
	case "$IF" in
		"ath8")
			AP_IF="ath0"
		;;
		"ath9")
			AP_IF="ath1"
		;;
		"ath11")
			AP_IF="ath10"
		;;
		*)
			echo "Can't find this STA $IF" > /dev/console
			AP_IF="0"
		;;
	esac
	echo "$AP_IF"
}
wait_ap_bring_up()
{
	local INTF="$1"
	local WAIT_CNT_MAX="$2"
	local INTF_STATUS="`iwconfig $INTF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
	local WAIT_CNT=0
	local RET=0
	if [ -z "$WAIT_CNT_MAX" ]; then
		WAIT_CNT_MAX=20
	fi
	while [ "Not-Associated" = "$INTF_STATUS" -a "$WAIT_CNT" -lt "$WAIT_CNT_MAX" ]
	do	
		sleep 1
		WAIT_CNT=`expr $WAIT_CNT + 1`
		INTF_STATUS="`iwconfig $INTF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
	done
	if [ "$WAIT_CNT" -ge "$WAIT_CNT_MAX" ]; then
		RET=1
	fi
	return $RET
}
is_same_credential()
{
    
    if [ -z "$1" -o -z "$2" -o "${1:0:2}" != "wl" -o "${2:0:2}" != "wl" ]; then
        return 2
    fi
    local ssid_1=`syscfg get $1_ssid`
    local ssid_2=`syscfg get $2_ssid`
    local passphrase_1=`syscfg get $1_passphrase`
    local passphrase_2=`syscfg get $2_passphrase`
    local security_mode_1=`syscfg get $1_security_mode`
    local security_mode_2=`syscfg get $2_security_mode`
    if [ "$ssid_1" != "$ssid_2" ]; then
        return 0
    fi
    case "$security_mode_1" in 
        disabled)
            if [ "$security_mode_2" = "disabled" ]; then
                return 1
            fi
            ;;
        wpa2-personal)
            if [ "$security_mode_2" = "wpa-mixed" -o "$security_mode_2" = "wpa2-personal" ] && [ "$passphrase_1" = "$passphrase_2" ] ; then
                return 1
            fi
            ;;
        wpa-mixed)
            if [ "$security_mode_2" = "wpa-mixed" -o "$security_mode_2" = "wpa2-personal" ] && [ "$passphrase_1" = "$passphrase_2" ] ; then
                return 1
            fi
            ;;
        *)
            ;;
    esac
    return 0
}
config_scan_table_sharing_between_radios()
{
    
    local shareflag="0"
    is_same_credential wl0 wl1
    share_wl0_wl1="$?"
    is_same_credential wl0 wl2
    share_wl0_wl2="$?"
    is_same_credential wl1 wl2
    share_wl1_wl2="$?"
    if [ "$share_wl0_wl1" = "1" -a "$share_wl0_wl2" = "1" -a "$share_wl1_wl2" = "1" ]; then
        shareflag=7
    elif [ "$share_wl1_wl2" = "1" ]; then
        shareflag=6
    elif [ "$share_wl0_wl2" = "1" ]; then
        shareflag=5
    elif [ "$share_wl0_wl1" = "1" ]; then
        shareflag=3
    else
        shareflag=0
    fi
    wl0_if=`syscfg get wl0_physical_ifname`
    if [ -z "$wl0_if" ]; then
        echo "invalid wl0 interface, please check" > /dev/console
        exit 1
    fi
    iwpriv $wl0_if nrshareflag $shareflag
}
get_multiregion_region_validation() 
{
	REGION=`syscfg get wifi::multiregion_region`
	if [ "$REGION" = "CN" -o "$REGION" = "AH" -o "$REGION" = "HK" -o "$REGION" = "IN" -o "$REGION" = "ID" -o "$REGION" = "PH" -o "$REGION" = "SG" -o "$REGION" = "TH" -o "$REGION" = "JP" -o "$REGION" = "KR" -o "$REGION" = "AU" -o "$REGION" = "CA" -o "$REGION" = "EU" -o "$REGION" = "ME" -o "$REGION" = "US" ] ; then
		echo "1"
	else
		echo "0"
	fi
}
get_multiregion_selectedcountry_validation() 
{
	COUNTRY=`syscfg get wifi::multiregion_selectedcountry`
	if [ "$COUNTRY" = "CHN" -o "$COUNTRY" = "HKG" -o "$COUNTRY" = "IND" -o "$COUNTRY" = "IDN" -o "$COUNTRY" = "PHL" -o "$COUNTRY" = "SGP" -o "$COUNTRY" = "THA" -o "$COUNTRY" = "JPN" -o "$COUNTRY" = "KOR" -o "$COUNTRY" = "XAH" -o "$COUNTRY" = "AUS" -o "$COUNTRY" = "CAN" -o "$COUNTRY" = "EEE" -o "$COUNTRY" = "XME" -o "$COUNTRY" = "NZL" -o "$COUNTRY" = "SAU" -o "$COUNTRY" = "USA" -o "$COUNTRY" = "TWN" ] ; then
		echo "1"
	else
		echo "0"
	fi
}
contains()
{
	LIST="$1"
	TARGET="$2"
	for ITEM in $LIST; do
		if [ $ITEM = $TARGET ]; then
			return 0
		fi
	done
	return 1
}
