#!/bin/sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
WPS_STATE=1
if [ "`cat /etc/product`" = "wraith" ] || [ "`cat /etc/product`" = "macan" ] || [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "dallas" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
    dump_file_line=""
else
    dump_file_line="dump_file=/tmp/hostapd.dump"
fi
wifi_user_start()
{
	echo "${SERVICE_NAME}, wifi_user_start($1)"
	PHY_IF=$1
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	USER_VAP=`syscfg_get "$SYSCFG_INDEX"_user_vap`
	wait_till_end_state ${WIFI_USER}_${PHY_IF}
	ulog wlan status "${SERVICE_NAME}, wifi_user_start($PHY_IF)"
	USER_STATE=`syscfg_get ${SYSCFG_INDEX}_state`
	if [ "$USER_STATE" = "down" ]; then
		return 1
	fi
	STATUS=`sysevent get ${WIFI_USER}_${PHY_IF}-status`
	if [ "started" = "$STATUS" ] ; then
		echo "${SERVICE_NAME}, ${WIFI_USER} is already starting/started, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_USER} is already starting/started, ignore the request"
		return 1
	fi
	sysevent set ${WIFI_USER}_${PHY_IF}-status starting
	user_start $PHY_IF
	RET_CODE=$?
	sysevent set ${SYSCFG_INDEX}_status "up"
	ulog wlan status "${SERVICE_NAME}, primary AP: $USER_VAP is up"
	echo "${SERVICE_NAME}, primary AP: $USER_VAP is up (`date`)"		
	sysevent set ${WIFI_USER}_${PHY_IF}-status started
	return $RET_CODE
}
wifi_user_stop()
{
	echo "${SERVICE_NAME}, wifi_user_stop($1)"
	PHY_IF=$1
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	wait_till_end_state ${WIFI_USER}_${PHY_IF}
	ulog wlan status "${SERVICE_NAME}, wifi_user_stop($PHY_IF)"
	STATUS=`sysevent get ${WIFI_USER}_${PHY_IF}-status`
	if [ "stopped" = "$STATUS" ] || [ -z "$STATUS" ]; then
		echo "${SERVICE_NAME}, ${WIFI_USER} is already stopping/stopped, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_USER} is already stopping/stopped, ignore the request"
		return 1
	fi
	sysevent set ${WIFI_USER}_${PHY_IF}-status stopping
	user_stop $PHY_IF
	sysevent set ${WIFI_USER}_${PHY_IF}-status stopped
	return 0
}
wifi_user_restart()
{
	PHY_IF=$1
	echo "${SERVICE_NAME}, wifi_user_restart($PHY_IF)"
	wifi_user_stop $PHY_IF
	wifi_user_start $PHY_IF
	return 0
}
user_start()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	VIR_IF=`syscfg_get "$SYSCFG_INDEX"_user_vap`
	
	if [ "true" = "$RECONFIGURE" ]; then
		return 1
	fi
	REPEATER_DISABLED=`syscfg_get repeater_disabled`
	if [ ! -z "$REPEATER_DISABLED" ] && [ "1" = "$REPEATER_DISABLED" ]; then
		syscfg_set ${SYSCFG_INDEX}_state "down"
		return 1
	fi
	LAN_IFNAME=`syscfg_get lan_ifname`
	add_interface_to_bridge $VIR_IF $LAN_IFNAME
	set_wps_state ${SYSCFG_INDEX}
	if [ "disabled" = "`syscfg_get "$SYSCFG_INDEX"_wps_state`" ]; then
		iwpriv $VIR_IF wps 0
	else
		iwpriv $VIR_IF wps 1
	fi
	iwpriv $VIR_IF wds 1
	iwpriv $VIR_IF vlan_tag 1
	iwpriv $VIR_IF rrm 1
	scan_entry_age=`syscfg get wifi_scan_entry_age`
	if [ -z "$scan_entry_age" ]; then
	    iwpriv $VIR_IF scanentryage 3600
	else
	    iwpriv $VIR_IF scanentryage $scan_entry_age
	fi
	VIR_SSID=`syscfg_get "$SYSCFG_INDEX"_ssid`
	iwconfig $VIR_IF essid "$VIR_SSID"
	SEC_MODE=`get_security_mode "$SYSCFG_INDEX"_security_mode`
	USE_HOSTAPD=`syscfg_get wl_use_hostapd`
	if [ "1" = "$USE_HOSTAPD" ] && [ "8" != "$SEC_MODE" ]; then
		configure_hostapd $PHY_IF $VIR_IF
		ret=$?
	else
		configure_user $PHY_IF $VIR_IF
		ret=$?
	fi
	SMART_MODE=`syscfg_get smart_mode::mode`
	if [ "$SMART_MODE" = "1" ] || [ "$SMART_MODE" = "2" ] ; then
        	SVAP_BRIDGE=`syscfg_get svap_lan_ifname`
        	SVAP_VLAN_ID=`syscfg_get svap_vlan_id`
        	add_vlan_to_backhaul "$VIR_IF" "$SVAP_VLAN_ID" "$SVAP_BRIDGE"
	fi
    
	if [ "`syscfg_get guest_enabled`" = "1" ] ; then
        	GA_BRIDGE=`syscfg_get guest_lan_ifname`
        	GA_VLAN_ID=`syscfg_get guest_vlan_id`
        	add_vlan_to_backhaul "$VIR_IF" "$GA_VLAN_ID" "$GA_BRIDGE"
	fi
	set_countryie $VIR_IF
	if [ "wl0" = "$SYSCFG_INDEX" ]; then
		set_11ngvhtintop $VIR_IF
	fi
	unsecure_page
	
	RET_CODE="0"
	if [ "true" = "$RECONFIGURE" ]; then
		ulog wlan status "$VIR_IF is preparing to reconfigure due to incompatible mode"
		RET_CODE="2"
	else
		RET_CODE="0"
	fi
	return $RET_CODE
}
user_stop() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	VIR_IF=`syscfg_get "$SYSCFG_INDEX"_user_vap`
	if [ -z "$VIR_IF" ]; then
		return 1
	fi
	SMART_MODE=`syscfg_get smart_mode::mode`
	if [ "$SMART_MODE" = "1" ] || [ "$SMART_MODE" = "2" ] ; then
	    SVAP_BRIDGE=`syscfg_get svap_lan_ifname`
	    SVAP_VLAN_ID=`syscfg_get svap_vlan_id`
	    delete_vlan_from_backhaul "$VIR_IF" "$SVAP_VLAN_ID" "$SVAP_BRIDGE"
	fi
    
	GA_BRIDGE=`syscfg_get guest_lan_ifname`
	GA_VLAN_ID=`syscfg_get guest_vlan_id`
	delete_vlan_from_backhaul "$VIR_IF" "$GA_VLAN_ID" "$GA_BRIDGE"
	set_driver_mac_filter_disabled $VIR_IF
	LAN_IFNAME=`syscfg_get lan_ifname`
	delete_interface_from_bridge $VIR_IF $LAN_IFNAME
	hostapd_cli -i $VIR_IF -p /var/run/hostapd disable
	sysevent set ${SYSCFG_INDEX}_status "down"
	ulog wlan status "${SERVICE_NAME}, primary AP: $VIR_IF is down"
	echo "${SERVICE_NAME}, primary AP: $VIR_IF is down"		
	return 0
}
configure_user() 
{
	PHY_IF=$1
	VIR_IF=$2
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	USER_SSID=`syscfg_get $SYSCFG_INDEX"_ssid"`
	SEC_MODE=`get_security_mode "$SYSCFG_INDEX"_security_mode`
	
	if [ -z $USER_SSID ]; then 
		ulog wlan status "User VAP ssid  $SYSCFG_INDEX is empty"
		return 1
	fi
	if [ $SEC_MODE != "8" ]; then 
		ulog wlan status "For un WEP, please use hostapd"
		return 1
	fi
	driver_update_extra_virtual_settings $PHY_IF $VIR_IF
	set_driver_mac_filter_enabled $VIR_IF
	iwconfig $VIR_IF essid "$USER_SSID"
	ENC_TYPE=`get_encryption ${SYSCFG_INDEX}"_encryption"` #64-bits or 128-bits
	if [ "$ENC_TYPE" != "64-bits" ] && [ "$ENC_TYPE" != "128-bits" ]; then
		ulog wlan status "Encryption type error"
		return 1
	fi
	WEP_KEY_1=`syscfg_get "$SYSCFG_INDEX"_key_0`
	WEP_KEY_2=`syscfg_get "$SYSCFG_INDEX"_key_1`
	WEP_KEY_3=`syscfg_get "$SYSCFG_INDEX"_key_2`
	WEP_KEY_4=`syscfg_get "$SYSCFG_INDEX"_key_3`
	TX_KEY=`syscfg_get "$SYSCFG_INDEX"_tx_key`
	if [ -z "$TX_KEY" ] || [ "0" = "$TX_KEY" ]; then
		TX_KEY=1 #Default if user for get to set
	fi
	AUTH_TYPE=`syscfg_get "$SYSCFG_INDEX"_authentication_type`
	QCA_AUTH_TYPE=""
	if [ "shared_key" = "$AUTH_TYPE" ]; then
		QCA_AUTH_TYPE="2"
	else
		QCA_AUTH_TYPE="4"
	fi
	KL_1=`echo $WEP_KEY_1 | wc -c`
	KL_2=`echo $WEP_KEY_2 | wc -c`
	KL_3=`echo $WEP_KEY_3 | wc -c`
	KL_4=`echo $WEP_KEY_4 | wc -c`
	if [ "$ENC_TYPE" = "64-bits" ]; then
		if [ 11 = `expr $KL_1` ]; then
			WEP_KEY_1=`echo $WEP_KEY_1 | sed -r 's/^(.{4})(.{4})(.{2})$/\1-\2-\3/g'`
			iwconfig $VIR_IF key [1] $WEP_KEY_1
		elif [ 6 = `expr $KL_1` ]; then
			iwconfig $VIR_IF key [1] "s:"$WEP_KEY_1
		fi
		if [ 11 = `expr $KL_2` ]; then
			WEP_KEY_2=`echo $WEP_KEY_2 | sed -r 's/^(.{4})(.{4})(.{2})$/\1-\2-\3/g'`
			iwconfig $VIR_IF key [2] $WEP_KEY_2
		elif [ 6 = `expr $KL_2` ]; then
			iwconfig $VIR_IF key [2] "s:"$WEP_KEY_2
		fi
		if [ 11 = `expr $KL_3` ]; then
			WEP_KEY_3=`echo $WEP_KEY_3 | sed -r 's/^(.{4})(.{4})(.{2})$/\1-\2-\3/g'`
			iwconfig $VIR_IF key [3] $WEP_KEY_3
		elif [ 6 = `expr $KL_3` ]; then
			iwconfig $VIR_IF key [3] "s:"$WEP_KEY_3
		fi
		if [ 11 = `expr $KL_4` ]; then
			WEP_KEY_4=`echo $WEP_KEY_4 | sed -r 's/^(.{4})(.{4})(.{2})$/\1-\2-\3/g'`
			iwconfig $VIR_IF key [4] $WEP_KEY_4
		elif [ 6 = `expr $KL_4` ]; then
			iwconfig $VIR_IF key [4] "s:"$WEP_KEY_4
		fi
		iwconfig $VIR_IF key [$TX_KEY]
		iwpriv $VIR_IF authmode "$QCA_AUTH_TYPE"
		syscfg_set $SYSCFG_INDEX"_encryption" "64-bits"
	elif [ "$ENC_TYPE" = "128-bits" ]; then
		if [ 27 = `expr $KL_1` ]; then
			WEP_KEY_1=`echo $WEP_KEY_1 | sed -r 's/^(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})(.{2})$/\1-\2-\3-\4-\5-\6-\7/g'`
			iwconfig $VIR_IF key [1] $WEP_KEY_1
		elif [ 14 = `expr $KL_1` ]; then
			iwconfig $VIR_IF key [1] "s:"$WEP_KEY_1
		fi
		if [ 27 = `expr $KL_2` ]; then
			WEP_KEY_2=`echo $WEP_KEY_2 | sed -r 's/^(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})(.{2})$/\1-\2-\3-\4-\5-\6-\7/g'`
			iwconfig $VIR_IF key [2] $WEP_KEY_2
		elif [ 14 = `expr $KL_2` ]; then
			iwconfig $VIR_IF key [2] "s:"$WEP_KEY_2
		fi
		if [ 27 = `expr $KL_3` ]; then
			WEP_KEY_3=`echo $WEP_KEY_3 | sed -r 's/^(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})(.{2})$/\1-\2-\3-\4-\5-\6-\7/g'`
			iwconfig $VIR_IF key [3] $WEP_KEY_3
		elif [ 14 = `expr $KL_3` ]; then
			iwconfig $VIR_IF key [3] "s:"$WEP_KEY_3
		fi
		if [ 27 = `expr $KL_4` ]; then
			WEP_KEY_4=`echo $WEP_KEY_4 | sed -r 's/^(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})(.{2})$/\1-\2-\3-\4-\5-\6-\7/g'`
			iwconfig $VIR_IF key [4] $WEP_KEY_4
		elif [ 14 = `expr $KL_4` ]; then
			iwconfig $VIR_IF key [4] "s:"$WEP_KEY_4
		fi
		iwconfig $VIR_IF key [$TX_KEY]
		iwpriv $VIR_IF authmode "$QCA_AUTH_TYPE"
		syscfg_set $SYSCFG_INDEX"_encryption" "128-bits"
	else
		RET=1
	fi
	return $RET
}
configure_hostapd() 
{
	PHY_IF=$1
	VIR_IF=$2
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	USER_SSID=`syscfg_get $SYSCFG_INDEX"_ssid"`
	SEC_MODE=`get_security_mode "$SYSCFG_INDEX"_security_mode`
	USER_PASSPHRASE=""
	RADIUS_SERVER=""
	RADIUS_PORT=""
	RADIUS_SHARED=""
	ENC_MODE=""
	TX_KEY=""
	if [ -z "$USER_SSID" ]; then
		USER_SSID=`syscfg_get hostname`
	fi
	if [ "1" = $SEC_MODE ] || [ "2" = $SEC_MODE ] || [ "3" = $SEC_MODE ]; then
		WL_PASSPHRASE=`syscfg_get "$SYSCFG_INDEX"_passphrase`
		if [ ${#WL_PASSPHRASE} = 64 ]; then 
			USER_PASSPHRASE="wpa_psk=${WL_PASSPHRASE}"
		else
			USER_PASSPHRASE="wpa_passphrase=${WL_PASSPHRASE}"
		fi
	elif [ "11" = $SEC_MODE ]; then
		WL_PASSPHRASE=`syscfg_get "$SYSCFG_INDEX"_passphrase`
		USER_PASSPHRASE="sae_password=${WL_PASSPHRASE}"
	elif [ "12" = $SEC_MODE ]; then
		WL_PASSPHRASE=`syscfg_get "$SYSCFG_INDEX"_passphrase`
		USER_PASSPHRASE="wpa_passphrase=${WL_PASSPHRASE}"$'\n'"sae_password=${WL_PASSPHRASE}"
	elif [ "4" = $SEC_MODE ] || [ "5" = $SEC_MODE ] || [ "6" = $SEC_MODE ]; then
		RADIUS_SERVER=`syscfg_get $SYSCFG_INDEX"_radius_server"`
		RADIUS_PORT=`syscfg_get $SYSCFG_INDEX"_radius_port"`
		RADIUS_SHARED=`syscfg_get $SYSCFG_INDEX"_shared"`
	elif [ "7" = $SEC_MODE ]; then
		RADIUS_SERVER=`syscfg_get $SYSCFG_INDEX"_radius_server"`
		RADIUS_PORT=`syscfg_get $SYSCFG_INDEX"_radius_port"`
		RADIUS_SHARED=`syscfg_get $SYSCFG_INDEX"_shared"`
	elif [ "8" = $SEC_MODE ]; then
		ENC_MODE=`syscfg_get $SYSCFG_INDEX"_encryption"`
		USER_PASSPHRASE=`syscfg_get $SYSCFG_INDEX"_passphrase"`
		TX_KEY=`syscfg_get $SYSCFG_INDEX"_tx_key"`
	fi
	if [ "1" = $SEC_MODE ] || [ "4" = $SEC_MODE ]; then
		syscfg_set $SYSCFG_INDEX"_encryption" "tkip"
	elif [ "2" = $SEC_MODE ] || [ "5" = $SEC_MODE ]; then
		syscfg_set $SYSCFG_INDEX"_encryption" "aes"
	elif [ "3" = $SEC_MODE ] || [ "6" = $SEC_MODE ]; then
		syscfg_set $SYSCFG_INDEX"_encryption" "tkip+aes"
	fi
	ulog wlan status "Bring up hostapd for $VIR_IF"
	USER_ENCRYPTION=`get_encryption $SYSCFG_INDEX"_encryption"`
	HOSTAPD_CONF="/tmp/hostapd-$VIR_IF.conf"
	wps_state=`syscfg_get "$SYSCFG_INDEX"_wps_state`
	if [ "configured" = "$wps_state" ]; then
		WPS_STATE=2
	elif [ "disabled" = "$wps_state" ]; then
		WPS_STATE=0
	else
		WPS_STATE=1
	fi
	if [ "4" = "$SEC_MODE" ] || [ "5" = "$SEC_MODE" ] || [ "6" = "$SEC_MODE" ]; then
		generate_hostapd_config_enterprise $VIR_IF "$USER_SSID" $SEC_MODE "$RADIUS_SERVER" "$RADIUS_PORT" "$RADIUS_SHARED"> $HOSTAPD_CONF
	else
		generate_hostapd_config $VIR_IF "$USER_SSID" "$USER_PASSPHRASE" $SEC_MODE "$USER_ENCRYPTION" "$RADIUS_SERVER" "$RADIUS_PORT" "$RADIUS_SHARED"> $HOSTAPD_CONF
	fi
	generate_hostapd_wps_section $SYSCFG_INDEX >> $HOSTAPD_CONF
	if [ "2" = "`syscfg get smart_mode::mode`" ] ; then 
		generate_hostapd_IE_section $WIFI_IE_SC_MASTER >> $HOSTAPD_CONF
	elif [ "1" = "`syscfg get smart_mode::mode`" ] ; then
		generate_hostapd_IE_section $WIFI_IE_SC_SLAVE >> $HOSTAPD_CONF
	fi
	driver_update_extra_virtual_settings $PHY_IF $VIR_IF
	set_driver_mac_filter_enabled $VIR_IF
	return 0
}
generate_default_mpsk_config()
{
local psk="$1"
local psk_file="$2"
cat <<EOF > $psk_file
00:00:00:00:00:00 "$psk"
EOF
}
generate_mpsk_config()
{
	local MPSK="$1"
	local MPSK_FILE="$2"
	local M_CFG_MAX=50
	local M_TUPLE=""
	local M_CFG
	local M_MAC
	local M_PSK
	for i in `seq 1 $M_CFG_MAX`; do
		M_CFG="`syscfg get ${WIFI_PRIV_NAMESPACE}::mpsk$i`"
		if [ ! -z "$M_CFG" ]; then
			M_MAC="`echo $M_CFG | cut -d, -f1`"
			M_PSK="`echo $M_CFG | cut -d, -f2-`"
			M_TUPLE="$M_TUPLE"$'\n'"$M_MAC $M_PSK"
		fi
	done
cat <<EOF > $MPSK_FILE
00:00:00:00:00:00 $MPSK
$M_TUPLE
EOF
}
generate_hostapd_config() 
{
    interface=$1
    ssid="$2"
    passphrase=$3
    wpa=$4
    auth_server_addr=""
    auth_server_port=""
    auth_server_shared_secret=""
    get_wl_index $interface
    CURRENT_INDEX=$?
    wl_index=wl$CURRENT_INDEX
    hw_mode=""
    eap_server=1
    WIFI_FREQ="2.4GHz and 5GHz"
    sae_groups=""
    sae_anti_clogging_th=""
    if [ -e /tmp/cedar_support ];then
    	lrhk_enabled="`syscfg get ${WIFI_PRIV_NAMESPACE}::enabled`"
    fi
    mpsk=0
    remote_auth_info=""
    if [ "$interface" = "`syscfg_get smart_connect::wl0_configured_vap`" ] || [ "$interface" = "`syscfg_get smart_connect::wl0_setup_vap`" ] ; then
		if [ "0" = "`syscfg get smart_mode::mode`" ];then
			bridge="`syscfg_get lan_ifname`"
		else
			bridge="`syscfg_get svap_lan_ifname`"
		fi
    elif [ "$interface" = "`syscfg_get wl0_guest_vap`" ] ||  [ "$interface" = "`syscfg_get wl1_guest_vap`" ] ||  [ "$interface" = "`syscfg_get wl2_guest_vap`" ] ;then
		bridge="`syscfg_get guest_lan_ifname`"
    elif [ "$7" != "" ] ; then
		bridge=$7
    else 
		bridge="`syscfg_get lan_ifname`"
    fi 
	if [ "$interface" = "`syscfg get ${WIFI_PRIV_NAMESPACE}::"$wl_index"_vap`" -o "$interface" = "`syscfg get ${WIFI_PRIV_NAMESPACE}::"$wl_index"_vap_ext`" ] ; then
		own_ip_addr="own_ip_addr=`syscfg_get ${WIFI_PRIV_NAMESPACE}::ipaddr`"
	fi
    wpa2_pairwise="wpa_pairwise=CCMP"
    wpa_pairwise="wpa_pairwise=TKIP"
    wpa_mixed_pairwise="wpa_pairwise=CCMP TKIP"
    wpa_key_mgmt="wpa_key_mgmt=WPA-PSK"
    cfg_sae_groups="`syscfg get sae_groups`"
    cfg_sae_anti_clogging_th="`syscfg get sae_anti_clogging_threshold`"
    if [ ! -z "$cfg_sae_groups" ]; then
        sae_groups="sae_groups=$cfg_sae_groups"
    else
        sae_groups="sae_groups=19"
    fi
    if [ ! -z "$cfg_sae_anti_clogging_th" ]; then
        sae_anti_clogging_th="sae_anti_clogging_threshold=$cfg_sae_anti_clogging_th"
    fi
    if [ "0" != "$wpa" ]; then
    	wpa_group_rekey="wpa_group_rekey=`syscfg_get $wl_index"_key_renewal"`"
    fi
    if [ "enabled" = "`syscfg_get "$wl_index"_pmf`" ]; then
    	PMF="ieee80211w=1"
    else
    	PMF="ieee80211w=0"
    fi
    if [ "$wpa" = "0" ]; then
        security="wpa=0"
        ieee8021x_set=0  
    else
        wl_value=`syscfg_get ${interface}_syscfg_index`
        default_pass=`syscfg_get ${wl_value}_passphrase`
        athx_ssid=`syscfg_get ${wl_value}_ssid`
        if [ "$wpa" = "1" ]; then
            security="wpa=1"$'\n'"$wpa_pairwise"
        elif [ "$wpa" = "2" ]; then
            security="wpa=2"$'\n'"$wpa2_pairwise"
            if [ "$lrhk_enabled" = "1"  ]; then
                if [ "$interface" = "ath0" ]; then
                    mpsk=1
                fi
                if [ "$interface" = "ath1" -o "$interface" = "ath10" ]; then
                    ath0_wl=`syscfg_get ath0_syscfg_index`
                    ath0_pass=`syscfg_get ${ath0_wl}_passphrase`
                    ath0_ssid=`syscfg_get ${ath0_wl}_ssid`
                    if [ "$default_pass" = "$ath0_pass" -a "$athx_ssid" = "$ath0_ssid" ]; then
                        mpsk=1
                    fi
                fi
            fi
        elif [ "$wpa" = "9" ]; then
            security="wpa=2"$'\n'"$wpa2_pairwise"
            mpsk=1
        elif [ "$wpa" = "11" ]; then
            PMF="ieee80211w=2"
            security="wpa=2"$'\n'"$wpa2_pairwise"
            wpa_key_mgmt="wpa_key_mgmt=SAE"$'\n'"$sae_groups"$'\n'"$sae_anti_clogging_th"
        elif [ "$wpa" = "12" ]; then
            PMF="ieee80211w=1"
            security="wpa=2"$'\n'"$wpa2_pairwise"
            wpa_key_mgmt="wpa_key_mgmt=WPA-PSK SAE"$'\n'"$sae_groups"$'\n'"$sae_anti_clogging_th"
        else
            security="wpa=3"$'\n'"$wpa_mixed_pairwise"
        fi
        if [ "$mpsk" = "1" ]; then
            psk="`echo $passphrase | sed 's/[^=]*=//'`"
            mpsk_file="/tmp/hostapd.mpsk"
            generate_default_mpsk_config $psk $mpsk_file
            local LRHK_UTIL="/usr/sbin/lrhk_util"
            if [ -x "$LRHK_UTIL" ]; then
                $LRHK_UTIL -g >/dev/null
            fi
            passphrase="wpa_psk_file=$mpsk_file"
            passphrase="$passphrase"$'\n'"default_passphrase=$default_pass"
            mode=`syscfg_get smart_mode::mode`
            master_ip=`sysevent get master::ip`
            remote_auth_info="device_mode=$mode"$'\n'"master_ip=$master_ip"
        fi
        ieee8021x_set=0
        security="$security"$'\n'"$passphrase"$'\n'"$wpa_key_mgmt"$'\n'"$wpa_group_rekey"
    fi
	
    if [ "0" = "$CURRENT_INDEX" ]; then
		hw_mode="hw_mode=g"
    elif [ "1" = "$CURRENT_INDEX" ] || [ "2" = "$CURRENT_INDEX" ]; then
		hw_mode="hw_mode=a"
    else 
		hw_mode=""
    fi
    cat <<EOF
interface=$interface
bridge=$bridge
driver=atheros
logger_syslog=127
logger_syslog_level=2
logger_stdout=127
logger_stdout_level=2
$dump_file_line
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
ssid=$ssid
$hw_mode
macaddr_acl=0
auth_algs=1
ieee8021x=$ieee8021x_set
eapol_key_index_workaround=0
eap_server=$eap_server
$own_ip_addr
$auth_server_addr
$auth_server_port
$auth_server_shared_secret
$PMF
$security
$remote_auth_info
EOF
}
generate_hostapd_IE_section() 
{
	LEN="08"
	APP="$1"
	IE=dd"$LEN"08863B00"$APP"
	cat <<EOF
vendor_elements=$IE
EOF
}
generate_hostapd_wps_section() 
{
	UUID=`syscfg_get device::uuid`
	uuid="uuid=$UUID"
	upnp="upnp_iface=br0"
	AP_PIN=`syscfg_get device::wps_pin`
	SN=`syscfg_get device::serial_number`
	MODEL_BASE=`syscfg_get device::model_base`
	MODEL_DESC=`syscfg_get device::modelDescription`
	MANUFACTOURER=`syscfg_get device::manufacturer`
	if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] ; then
	    CONFIG_METHODS="label push_button virtual_push_button keypad"
	else
	    CONFIG_METHODS="label push_button virtual_push_button physical_push_button keypad"
	fi
	REAL_DEVICE_NAME=`syscfg_get hostname`
	DEVICE_NAME_LEN=`echo "$REAL_DEVICE_NAME" | wc -c`
	if [ `expr $DEVICE_NAME_LEN` -gt 32 ]; then
		QN_DEVICE_NAME=`echo "$REAL_DEVICE_NAME" | cut -c1-32`
	else
		QN_DEVICE_NAME="$REAL_DEVICE_NAME"
	fi
	cat <<EOF
wps_state=$WPS_STATE
wps_independent=1
ap_setup_locked=0
wps_pin_requests=/var/run/hostapd_wps_pin_requests
device_name=$QN_DEVICE_NAME
manufacturer=$MANUFACTOURER
$uuid
model_name=$MODEL_BASE
model_number=$MODEL_BASE
device_type=6-0050F204-1
serial_number=$SN
config_methods=$CONFIG_METHODS
ap_pin=$AP_PIN
$upnp
friendly_name=$REAL_DEVICE_NAME
model_description=$MODEL_DESC
EOF
}
generate_hostapd_config_enterprise() 
{
	interface=$1
	ssid=$2
	wpa=$3
	get_wl_index $interface
	CURRENT_INDEX=$?
	wl_index=wl$CURRENT_INDEX
	ieee8021x_set=1
	eap_server=1
	if [ "enabled" = "`syscfg_get "$wl_index"_pmf`" ]; then
		PMF="ieee80211w=1"
	else
		PMF="ieee80211w=0"
	fi
	own_ip_addr="own_ip_addr=`syscfg_get lan_ipaddr`"
	if [ "$interface" = "`syscfg get ${WIFI_PRIV_NAMESPACE}::"$wl_index"_vap`" -o "$interface" = "`syscfg get ${WIFI_PRIV_NAMESPACE}::"$wl_index"_vap_ext`" ] ; then
		own_ip_addr="own_ip_addr=`syscfg_get ${WIFI_PRIV_NAMESPACE}::ipaddr`"
	fi
	auth_server_addr="auth_server_addr=$4"
	auth_server_port="auth_server_port=$5"
	auth_server_shared_secret="auth_server_shared_secret=$6"
	bridge=$7
	if [ -z "$bridge" ]; then
		bridge="br0"
	fi
	wpa2_pairwise="wpa_pairwise=CCMP"
	wpa_pairwise="wpa_pairwise=TKIP"
	wpa_mixed_pairwise="wpa_pairwise=CCMP TKIP"
	wpa_key_mgmt="wpa_key_mgmt=WPA-EAP"
	wpa_group_rekey="wpa_group_rekey=`syscfg_get $wl_index"_key_renewal"`"
	if [ "$wpa" = "4" ]; then
		security="wpa=1"$'\n'"$wpa_pairwise"
	elif [ "$wpa" = "5" ]; then
		security="wpa=2"$'\n'"$wpa2_pairwise"
	else
		security="wpa=3"$'\n'"$wpa_mixed_pairwise"
	fi
	security="$security"$'\n'"$wpa_key_mgmt"$'\n'"$wpa_group_rekey"
	cat <<EOF
interface=$interface
bridge=$bridge
driver=atheros
logger_syslog=127
logger_syslog_level=2
logger_stdout=127
logger_stdout_level=2
$dump_file_line
ssid=$ssid
ieee8021x=$ieee8021x_set
eapol_key_index_workaround=0
$own_ip_addr
$auth_server_addr
$auth_server_port
$auth_server_shared_secret
$PMF
$security
EOF
}
set_wps_state() 
{
	SYSCFG_INDEX=$1
	wps_state="unconfigured"
	sec_mode=`get_security_mode "$SYSCFG_INDEX"_security_mode`
	ssid_broadcast=`get_ssid_broadcast $SYSCFG_INDEX`
	if [ 1 = $sec_mode ] || [ 4 = $sec_mode ] ||  
	   [ 5 = $sec_mode ] || [ 6 = $sec_mode ] ||
	   [ 7 = $sec_mode ] || [ 8 = $sec_mode ] ||
	   [ 0 = $ssid_broadcast ]; then
		wps_state="disabled"
	fi
	if [ "disabled" != "$wps_state" ]; then
		ssid=`syscfg_get ${SYSCFG_INDEX}_ssid`
		
		if [ "$ssid" != "`syscfg get ${SYSCFG_INDEX}_default_ssid`" ] && [ "$ssid" != "`syscfg get wl_default_ssid`" ] ; then
			wps_state="configured"
		else
			if [ 0 != $sec_mode ]; then
				wps_state="configured"
			fi
		fi
	fi	
	WL_MACFILTER_ENABLED=`syscfg_get wl_access_restriction`
	if [ "$WL_MACFILTER_ENABLED" = "allow" ] || [ "$WL_MACFILTER_ENABLED" = "deny" ]; then
		wps_state="disabled"
	fi
	WPS_USER_SETTING=`syscfg_get wps_user_setting`
	if [ "disabled" = "$WPS_USER_SETTING" ]; then
		wps_state="disabled"
	fi
	if [ "$SYSCFG_INDEX" = "wl2" ] ; then
		wps_state="disabled"
	fi
	sys_wps_state=`syscfg_get ${SYSCFG_INDEX}_wps_state`
	if [ "$sys_wps_state" != "$wps_state" ]; then
		syscfg_set ${SYSCFG_INDEX}_wps_state $wps_state
	fi
	sysevent set ${SYSCFG_INDEX}_wps_status $wps_state
}
driver_update_extra_virtual_settings() 
{
	PHY_IF=$1
	VIR_IF=$2
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	iwconfig $VIR_IF key off
	SSID_BROADCAST=`get_ssid_broadcast $SYSCFG_INDEX`
	if [ "1" = $SSID_BROADCAST ]; then
		iwpriv $VIR_IF hide_ssid 0
	else
		iwpriv $VIR_IF hide_ssid 1
	fi
	SEC_ENABLED="false"
	LOCAL_SEC_MODE=`syscfg_get $SYSCFG_INDEX"_security_mode"`
	if [ "wpa-personal" = "$LOCAL_SEC_MODE" ] || [ "wpa2-personal" = "$LOCAL_SEC_MODE" ] || [ "wpa-mixed" = "$LOCAL_SEC_MODE" ]; then
		SEC_ENABLED="true"
	fi
	 	
	if [ "true" = "$SEC_ENABLED" ]; then
		USE_HOSTAPD=`syscfg_get wl_use_hostapd`
		if [ "1" != "$USE_HOSTAPD" ]; then
			REKEY_TIME=`syscfg_get $SYSCFG_INDEX"_key_renewal"`
			iwpriv $VIR_IF grouprekey `expr $REKEY_TIME`
		fi
	fi
	AP_ISOLATION=`syscfg_get $SYSCFG_INDEX"_ap_isolation"`
	if [ "disabled" = "$AP_ISOLATION" ]; then
		L2TIF=0
	else
		L2TIF=1
	fi
	iwpriv $VIR_IF l2tif $L2TIF
	DTIM_INTERVAL=`syscfg_get $SYSCFG_INDEX"_dtim_interval"`
	if [ -z "$DTIM_INTERVAL" ] || [ $DTIM_INTERVAL -lt 1 ] || [ $DTIM_INTERVAL -gt 255 ]; then
		ulog wlan status "invalid wifi dtim_interval $DTIM_INTERVAL"
		DTIM_INTERVAL=1
	fi
	iwpriv $VIR_IF dtim_period $DTIM_INTERVAL
	AMSDU_SETTING=`syscfg_get $SYSCFG_INDEX"_amsdu_enabled"`
	iwpriv $VIR_IF amsdu $AMSDU_SETTING
	TXBF=`syscfg_get "$SYSCFG_INDEX"_txbf_enabled`
	if [ "1" = "$TXBF" ]; then
		iwpriv $VIR_IF vhtsubfer 1
		iwpriv $VIR_IF vhtsubfee 1
		iwpriv $VIR_IF implicitbf 1
		echo "wifi_user, $VIR_IF TxBF enabled"
	else
		iwpriv $VIR_IF vhtsubfer 0
		iwpriv $VIR_IF vhtsubfee 0
		iwpriv $VIR_IF implicitbf 0
	fi
	MU_MIMO=`syscfg_get wifi::$SYSCFG_INDEX"_mumimo_enabled"`
	if [ "1" = "$MU_MIMO" ]; then
		iwpriv $VIR_IF vhtmubfer 1
		iwpriv $VIR_IF vhtsubfer 1
		iwpriv $VIR_IF vhtsubfee 1
		iwpriv $VIR_IF implicitbf 1
		echo "wifi_user, $VIR_IF MU-MIMO enabled"
	else
		iwpriv $VIR_IF vhtmubfer 0
	fi
	if [ "`cat /etc/product`" = "lion" ] ; then
		iwpriv $VIR_IF vhtsubfee 0
	fi
	if [ "1" = "$MU_MIMO" ] || [ "1" = "$TXBF" ]; then
		if [ "wl0" = "$SYSCFG_INDEX" ]; then
			if [ "1" = "`syscfg_get wifi::multiregion_support`" -a "1" = "`syscfg_get wifi::multiregion_enable`" -a "1" = "`get_multiregion_region_validation`" ] ; then
			    REGION=`syscfg get wifi::multiregion_region`
			    if [ "`cat /etc/product`" = "nodes" ] ; then
			    	if [ -f /tmp/nodes_hw_version ] && [ "`cat /tmp/nodes_hw_version`" = "2" ] ; then
			    		REGION=`syscfg_get wifi::multiregion_region`
			    	else
			    		if [ "$REGION" = "CN" ] ; then
			    			REGION="AH" 
			    		fi
			    		if [ "$REGION" = "SG" ] ; then
			    			REGION="AH" 
			    		fi
			    	fi
			    fi
			else
			    REGION=`syscfg_get device::cert_region`
			fi
			if [ "EU" = "$REGION" ] || [ "AH" = "$REGION" ] ; then
				wifitool $VIR_IF beeliner_fw_test 36 1
			else
				wifitool $VIR_IF beeliner_fw_test 36 0
			fi
		else
			wifitool $VIR_IF beeliner_fw_test 36 0
		fi
	fi
	if [ "wl0" = "$SYSCFG_INDEX" ]; then
		wifitool $VIR_IF beeliner_fw_test 85 1
		wifitool $VIR_IF beeliner_fw_test 86 66
		wifitool $VIR_IF beeliner_fw_test 87 70
	fi
	return 0
}
