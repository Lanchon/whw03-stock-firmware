#!/bin/sh
source /etc/init.d/service_wifi/wifi_physical.sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
source /etc/init.d/service_wifi/wifi_sta_utils.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_wifi/wifi_utils.sh
SERVICE_NAME="wifi_smart_connect_client"
WIFI_DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
COMMAND=$1
WPA_DEBUG="`syscfg get wpa_debug`"
OPMODE=""
STAMODE=""
STA_SSID=""
STA_SECURITY=""
STA_PASSPHRASE=""
SERVER_SETUP_PORT=6048
SERVER_CONFIG_PORT=6049
SETUP_AP_LIST='/tmp/setup_ap_list'
AP_LIST='/tmp/ap_list'
AP_LIST_SORT='/tmp/ap_list_sort'
SC_DIR="/tmp/smartconnect"
DB_DIR="/tmp/var/config/smartconnect"
HOSTAP_IE_FILE="/tmp/hostapd_IE_payload"
HOSTAPD_IE_SETUP="dd0808863b00${WIFI_IE_SC_SETUP}"
HOSTAPD_IE_MASTER="dd0808863b00${WIFI_IE_SC_MASTER}"
HOSTAPD_IE_SLAVE="dd0808863b00${WIFI_IE_SC_SLAVE}"
SETUP_LAN_IFNAME=`syscfg get svap_lan_ifname`
SETUP_NETMASK=`syscfg get ldal_wl_setup_vap_netmask`
SETUP_SUBNET=`syscfg get ldal_wl_setup_vap_subnet`
is_ipaddr_valid ()
{
    INPUT_INTERFACE=$1
    if [ "$INPUT_INTERFACE" = "ath8" ] && [ "`cat /etc/product`" = "wraith" ] ; then
        SETUP_LAN_IFNAME=$INPUT_INTERFACE
    fi
    SETUP_SUBNET=`syscfg get ldal_wl_setup_vap_subnet`
	CURRENT_IP=`/sbin/ip addr show dev $SETUP_LAN_IFNAME  | grep "inet " | awk '{split($2,foo, "/"); print(foo[1]);}'`	
	eval `ipcalc -n $CURRENT_IP $SETUP_NETMASK`
	if [ "$NETWORK" = "$SETUP_SUBNET" ] ; then
	    echo 1
	else
	    echo 0
	fi
}
get_ip()
{
	value="`ifconfig br0 |grep "inet " | awk '{print $2}'|awk -F ":" '{print $2}'|cut -d '.' -f1-2`"
	if [ "169.254" = "$value" ] || [ "" = "$value" ];then
		echo 0
	else
		echo 1
	fi 
}
connect_setup_VAP()
{
    INPUT_INT=$1
	if [ "" != "`syscfg get smart_connect::setup_ap`" ];then
		SETUP_AP="`syscfg get smart_connect::setup_ap`"
		SETUP_AP_SET="1"
	fi
	echo "smart connect client: scan setup ap(`date`)" > /dev/console 
	search_ap_pre "$AP_LIST"
	if [ "1" != "$SETUP_AP_SET" ];then
		search_apv2 "2.4G" "" "" "$AP_LIST"
	else
		search_apv2 "2.4G" "$SETUP_AP" "" "$AP_LIST"
	fi
	search_ap_fin "$AP_LIST"
	if [ -e $AP_LIST_SORT ]; then
		while read line
		do
			if [ "1" != "$SETUP_AP_SET" ];then
				tmp="`echo "$line"|awk '{print $1" "$2" "$3" "$4" "}'`"
				SETUP_AP="`echo "$line"|sed 's/'"$tmp"'//g'`"
				SETUP_AP="${SETUP_AP%#}"
			else
				tmp="`echo "$line"|awk '{print $1" "$2" "$3" "$4" "}'`"
				tmp_AP="`echo "$line"|sed 's/'"$tmp"'//g'`"
				tmp_AP="${tmp_AP%#}"
				if [ "$SETUP_AP" != "$tmp_AP" ] || [ "${SETUP_AP##*-}" != "SCS" ];then
					continue
				fi
			fi
			SETUP_MAC="`echo $line | awk '{print $1}'`"
			SETUP_FREQ="`echo $line | awk '{print $2}'`"
			change_freq_to_chan $SETUP_FREQ
			SETUP_CHAN=$?
			sysevent set smart_connect::setup_ssid "$SETUP_AP"
			sysevent set smart_connect::setup_mac "$SETUP_MAC"
			sysevent set smart_connect::setup_chan "$SETUP_CHAN"
			client_connect 
			if [ "1" != "`sysevent get wifi_sta_up`" ]; then
				continue
			fi
			if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
				/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release
				/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew
			else
				/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release ath8
				/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew ath8
			fi
			sleep 1
			S_COUNTER=0
			IS_VALID=`is_ipaddr_valid $INPUT_INT`				
			while [ "$IS_VALID" = "0" ] && [ "$S_COUNTER" -lt 2 ]; 
			do
				if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
				    /etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release
					/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew
				else
				    /etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release ath8
					/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew ath8
				fi
				echo "smart connect client: waiting for setup IP(`date`)" > /dev/console
				S_COUNTER=`expr $S_COUNTER + 1`
				IS_VALID=`is_ipaddr_valid $INPUT_INT`
				S_CNT=0
				while [ "$IS_VALID" = "0" ] && [ "$S_CNT" -lt 15 ]; 
				do
					S_CNT=`expr $S_CNT + 1`
					IS_VALID=`is_ipaddr_valid $INPUT_INT`
					sleep 1
				done
			done
			IS_VALID=`is_ipaddr_valid $INPUT_INT`
			if [ "$IS_VALID" = "0" ]; then
				ifconfig br2
				echo "smart connect client: Fail to get setup IP(`date`)" > /dev/console
				continue
			fi
			check_ip_connection
			if [ "1" = "$?" ];then
				echo "smart connect client:can't ping the server,try next" > /dev/console
				continue
			fi
			sysevent set smart_connect::pin_used 1
			echo "smart connect client:try to get configVAP info (`date`)" > /dev/console 
			get_server_config_info
			RET_VAL=$?
			S_COUNTER=0
			while [ "$RET_VAL" = 1 ] && [ "$S_COUNTER" -lt 1 ]; 
			do
				echo "ERROR getting server config info! will retry..." > /dev/console 
				S_COUNTER=`expr $S_COUNTER + 1`
				sleep 2
				get_server_config_info
				RET_VAL=$?
			done
			if [ "$RET_VAL" = 1 ]; then
				echo "smart connect client: Fail to get the config settings(`date`)" > /dev/console
				continue
			fi
			if [ "$RET_VAL" != 1 ]; then
				echo "smart connect client: get the config settings successfully(`date`)" > /dev/console
				syscfg set smart_connect::setup_vap_ssid "$SETUP_AP"
				return 1				
			fi
		done < $AP_LIST_SORT
	fi # scan
	return 0
}
connect_config_VAP()
{
    INPUT_INT=$1
	CONFIG_SCAN_SSID="`syscfg_get smart_connect::configured_vap_ssid`"
	CONFIG_CNT=0
	while [ "$CONFIG_CNT" -lt 3 ];
	do
		CONFIG_CNT=`expr $CONFIG_CNT + 1`
		echo "smart connect client: scan config ap(`date`)" > /dev/console 
		search_ap_pre "$AP_LIST"
		search_apv2 "2.4G" "$CONFIG_SCAN_SSID" "" "$AP_LIST"
		search_ap_fin "$AP_LIST"
		if [ -e $AP_LIST_SORT ]; then
			while read line
			do
				echo "smart connect client:try to connect to the config VAP(`date`)" > /dev/console 
				CONFIG_AP_MAC="`echo $line | awk '{print $1}'`"
				CONFIG_AP_FREQ="`echo $line | awk '{print $2}'`"
				change_freq_to_chan $CONFIG_AP_FREQ
				CONFIG_AP_CHAN=$?
				sysevent set smart_connect::conf_mac $CONFIG_AP_MAC
				sysevent set smart_connect::conf_chan $CONFIG_AP_CHAN
				client_connect
				if [ "1" != "`sysevent get wifi_sta_up`" ]; then
					continue
				fi
				if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		   			/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release
		   			/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew
				else
		   			/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release ath8
		   			/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew ath8
				fi
				sleep 2
				C_COUNTER=0
				IS_VALID=`is_ipaddr_valid $INPUT_INT`
				while [ "$IS_VALID" = "0" ] && [ "$C_COUNTER" -lt 2 ]; 
				do
					if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
						/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release
						/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew
					else
						/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release ath8
						/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew ath8
					fi
					echo "smart connect client: waiting for config IP(`date`)" > /dev/console 
					C_COUNTER=`expr $C_COUNTER + 1`
					IS_VALID=`is_ipaddr_valid $INPUT_INT`
					S_CNT=0
					while [ "$IS_VALID" = "0" ] && [ "$S_CNT" -lt 15 ]; 
					do
						S_CNT=`expr $S_CNT + 1`
						IS_VALID=`is_ipaddr_valid $INPUT_INT`
						sleep 1
					done
				done
				IS_VALID=`is_ipaddr_valid $INPUT_INT`
				if [ "$IS_VALID" = "0" ]; then
					ifconfig br2
					echo "smart connect client: Fail to get config IP(`date`)" > /dev/console
					continue
				fi
				/etc/init.d/service_wifi/smart_connect_client_utils.sh get_server_primary_info
				RET=$?
				if [ "1" != "$RET" ];then
					continue
				else
					return 1
				fi
			done < $AP_LIST_SORT
		fi
	done
	return 0
}
backhaul_selector()
{
	USER_SCAN_SSID_L="`syscfg_get wl1_ssid`"
	USER_SCAN_SSID_H="`syscfg_get wl2_ssid`"
	U_COUNTER=0
	sysevent set wifi_sta_up 0
	I_MAC="`sysevent get backhaul::preferred_bssid | tr [:upper:] [:lower:]`"
	local scan_fail=0
	search_backhaul
	while [ "$U_COUNTER" -lt 2 ];
	do
		U_COUNTER=`expr $U_COUNTER + 1`
		if [ ! -e $AP_LIST_SORT ]; then
			scan_fail=1
		fi
		if [ -e $AP_LIST_SORT ]; then
			scan_fail=0
			while read line
			do
				USER_AP_MAC="`echo $line | awk '{print $1}'`"
				if [ "$USER_AP_MAC" = "$I_MAC" ];then
					echo "smart connect client:have already try to connect this BSSID at reconnect mode,ignore it... " > /dev/console 
					continue
				fi
				USER_AP_FREQ="`echo $line | awk '{print $2}'`"
				change_freq_to_chan $USER_AP_FREQ
				USER_AP_CHAN=$?
				sysevent set smart_connect::tmp_mac $USER_AP_MAC
				sysevent set smart_connect::tmp_chan $USER_AP_CHAN
				client_connect 
				if [ "1" != "`sysevent get wifi_sta_up`" ]; then
					continue
				fi
				CNT=0
				/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-release
				/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-renew
				sleep 2			
				TEMP_IP=`get_ip`
				while [ "0" = "$TEMP_IP" ] && [ "$CNT" -lt 3 ];
				do
					echo "smart connect client: waiting for regular IP(`date`)" > /dev/console 
					/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-renew
					CNT=`expr $CNT + 1`
					TEMP_IP=`get_ip`
					S_CNT=0
					while [ "0" = "$TEMP_IP" ] && [ "$S_CNT" -lt 30 ]; 
					do
						if [ "WPA_WRONG_KEY" = "`sysevent get backhaul::progress`" ];then
							echo "smart connect client: backhaul_selector WRONG KEY,change to AUTH,relearning wifi credentials(`date`)" > /dev/console
							sysevent set backhaul::progress IDLE
							return 0
						fi
						S_CNT=`expr $S_CNT + 1`
						TEMP_IP=`get_ip`
						sleep 1
					done
				done
				if [ "0" = "$TEMP_IP" ];then
					if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
						if [ "$USER_AP_CHAN" -le "13" ];then
							SIF="ath8"
						elif [ "$USER_AP_CHAN" -ge "36" -a "$USER_AP_CHAN" -lt "65" ];then
							SIF="ath9"
						else
							SIF="ath11"
						fi
					else
						if [ "$USER_AP_CHAN" -le "13" ];then
							SIF="ath8"
						else
							SIF="ath9"
						fi
					fi
					ifconfig $SIF down
					continue
				fi
				break
			done < $AP_LIST_SORT
			TEMP_IP=`get_ip`
			if [ "0" = "$TEMP_IP" ];then
				if [ "1" != "`sysevent get wifi_sta_up`" ]; then
					iwconfig ath8
					iwconfig ath9
					iwconfig ath11
					echo "smart connect client: connection failed, do scan again(`date`)" > /dev/console 
				else
					ifconfig br0
					echo "smart connect client: Fail to get regular ip, do scan again(`date`)" > /dev/console 
				fi
				continue
			fi
			break
		fi
	done
	TEMP_IP=`get_ip`
	if [ "1" != "`sysevent get wifi_sta_up`" ] || [ "0" = "$TEMP_IP" ] || [ "1" = "$scan_fail" ];then
		echo "smart connect client: Fail to connect to any scan results(user VAP),change to AUTH,relearning wifi credentials(`date`)" > /dev/console
		return 0
	fi
	return 1
}
connect_user_VAP()
{
	sysevent set smart_connect::tmp_mac "$1"
	sysevent set smart_connect::tmp_chan "$2"
	client_connect 
	U_COUNTER=0
	while [ "1" != "`sysevent get wifi_sta_up`" ] && [ "$U_COUNTER" -lt 2 ]; 
	do
		client_connect 
		U_COUNTER=`expr $U_COUNTER + 1`
	done
	if [ "1" = "`sysevent get wifi_sta_up`" ]; then
		/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-release
		/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-renew
		sleep 2
		U_COUNTER=0
		CURRENT_IP=`get_ip`
		while [ "0" = "$CURRENT_IP" ] && [ "$U_COUNTER" -lt 3 ]; 
		do
			/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-renew
			echo "smart connect client: waiting for regular IP during $3(`date`)" > /dev/console 
			U_COUNTER=`expr $U_COUNTER + 1`
			CURRENT_IP=`get_ip`
			S_CNT=0
			while [ "0" = "$CURRENT_IP" ] && [ "$S_CNT" -lt 30 ] && [ "WPA_WRONG_KEY" != "`sysevent get backhaul::progress`" ]; 
			do
				S_CNT=`expr $S_CNT + 1`
				CURRENT_IP=`get_ip`
				sleep 1
			done
		done
					
		if [ "0" = "$CURRENT_IP" ]; then
			ifconfig br0
			echo "smart connect client:get ip fail,try to reconnect(`date`)" > /dev/console 
			sysevent set wifi_sta_up 0
		fi
	fi
					
	if [ "1" = "`sysevent get wifi_sta_up`" ]; then
		echo "	smart connect client: connected($3)! (`date`)" > /dev/console
		sysevent set backhaul::status up 
			
		PROC_PID_LINE="`ps -ww|grep hostapd |grep -v grep |grep -v mon`"
		if [ ! -z "$PROC_PID_LINE" ]; then
			echo "smart connect client: turn up AP interfaces"
			AP_interface_up
		fi	
		echo "smart connect client:backhaul up, do WiFi config change(`date`)" > /dev/console
		/etc/init.d/service_wifi/service_wifi.sh wifi_config_changed
		Refresh_channel
		bh_repeater_refresh_and_wait "`sysevent get backhaul::intf`"
		return 1
	fi
	return 0
}
do_ping()
{
	PING_LOCATION="`syscfg get smart_connect::serverip`"
    ( ping -q -c1 -w5 "$PING_LOCATION" &> /dev/null ) &
    local pid=$!
   	PING_CNT=0
    while [ "$PING_CNT" -lt 5 ] && [ -d "/proc/$pid" ]; 
	do
		PING_CNT=`expr $PING_CNT + 1`
		sleep 1
    done
    if [ -d "/proc/$pid" ]; then
        ( kill -9 $pid ) 2> /dev/null
    fi
    wait $pid
    return $?
}
check_ip_connection()
{
   	do_ping
   	if [ "$?" = "0" ]; then
       	return 0
	fi
	return 1
}
add_mac_filter()
{
	WORKING_RADIO="$2"
	WORKING_IF="$1"
	if [ "2.4GHz" = "$WORKING_RADIO" ];then
		return 0
	fi
	if [ "ath11" = "$WORKING_IF" ];then
		FILTER_MAC="`ifconfig ath11 |grep "HWaddr"|awk '{print $5}' |tr [:upper:] [:lower:]`"
		iwpriv  ath1 maccmd 3
		iwpriv  ath1 maccmd 2
		iwpriv  ath1 addmac "$FILTER_MAC"
	else
		FILTER_MAC="`ifconfig ath9 |grep "HWaddr"|awk '{print $5}' |tr [:upper:] [:lower:]`"
		iwpriv  ath10 maccmd 3
		iwpriv  ath10 maccmd 2
		iwpriv  ath10 addmac "$FILTER_MAC"
	fi
	return 0
}
wifi_sta_prepare()
{
	MODE=`sysevent get smart_connect::setup_status`
	STA_SSID=""
	STA_SECURITY=""
	STA_PASSPHRASE=""
	if [ "START" = "$MODE" ]; then
		STA_SSID="`sysevent get smart_connect::setup_ssid`"
		DESIRE_MAC="`sysevent get smart_connect::setup_mac`"
		DESIRE_CHAN="`sysevent get smart_connect::setup_chan`"
		STA_SECURITY="wpa2-personal"
		STA_PASSPHRASE="$STA_SSID"
		STA_BRIDGE=`syscfg get svap_lan_ifname`
		STA_RADIO="2.4G"
	elif [ "TEMP-AUTH" = "$MODE" ] || [ "AUTH" = "$MODE" ] ; then
		STA_SSID="`syscfg_get smart_connect::configured_vap_ssid`"
		STA_SECURITY="`syscfg get smart_connect::configured_vap_security_mode`"
		if [ "wpa-mixed" = "$STA_SECURITY" ]; then
			STA_SECURITY="wpa2-personal"
		fi
		STA_PASSPHRASE="`syscfg get smart_connect::configured_vap_passphrase`"
		DESIRE_MAC="`sysevent get smart_connect::conf_mac`"
		DESIRE_CHAN="`sysevent get smart_connect::conf_chan`"
		STA_BRIDGE=`syscfg get svap_lan_ifname`
		STA_RADIO="2.4G"
	elif [ "DONE" = "$MODE" ]; then
		STA_BRIDGE=`syscfg get lan_ifname`
		DESIRE_MAC="`sysevent get smart_connect::tmp_mac`"
		DESIRE_CHAN="`sysevent get smart_connect::tmp_chan`"
		if [ "$DESIRE_CHAN" -le "13" ];then
			STA_RADIO="2.4G"
		elif [ "$DESIRE_CHAN" -ge "36" -a "$DESIRE_CHAN" -lt "65" ]; then
			STA_RADIO="5GL"
		else
			STA_RADIO="5GH"
		fi
	fi
	return 0
}
wifi_sta_init()
{
    MODE=`sysevent get smart_connect::setup_status`
	case "$STA_RADIO" in
		"2.4G")
			OPMODE="11NGHT40"
			PHY_IF="wifi0"
			STA_IF="ath8"
			USER_IF="ath0"
			USER_IF_2="ath5"
			if [ "DONE" = "$MODE" ]; then
				STA_SSID="`syscfg get wl0_ssid`"
				STA_SECURITY="`syscfg get wl0_security_mode`"
				if [ "wpa-mixed" = "$STA_SECURITY" ]; then
					STA_SECURITY="wpa2-personal"
				fi
				STA_PASSPHRASE="`syscfg get wl0_passphrase`"
			fi
			;;
		"5GL")
			OPMODE="11ACVHT80"
			if [ "DONE" = "$MODE" ];then
				PHY_IF="wifi1"
				STA_IF="ath9"
				USER_IF="ath1"
				STA_SSID="`syscfg get wl1_ssid`"
				STA_SECURITY="`syscfg get wl1_security_mode`"
				if [ "wpa-mixed" = "$STA_SECURITY" ]; then
					STA_SECURITY="wpa2-personal"
				fi
				STA_PASSPHRASE="`syscfg get wl1_passphrase`"
				if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
					if [ "`syscfg get WiFi::5GHz_40MHZ`" = "1" ] ; then
						SIDEBAND=`get_sideband ath1`
						OPMODE=11ACVHT40"$SIDEBAND"
					fi
				fi
			fi
			;;
		"5GH")
			OPMODE="11ACVHT80"
			if [ "DONE" = "$MODE" ];then
				if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
					PHY_IF="wifi2"
					STA_IF="ath11"
					USER_IF="ath10"
					STA_SSID="`syscfg get wl2_ssid`"
					STA_SECURITY="`syscfg get wl2_security_mode`"
					if [ "wpa-mixed" = "$STA_SECURITY" ]; then
						STA_SECURITY="wpa2-personal"
					fi
					STA_PASSPHRASE="`syscfg get wl2_passphrase`"
					if [ "`syscfg get WiFi::5GHz_40MHZ`" = "1" ] ; then
						SIDEBAND=`get_sideband ath10`
						OPMODE=11ACVHT40"$SIDEBAND"
					fi
				else 
					PHY_IF="wifi1"
					STA_IF="ath9"
					USER_IF="ath1"
					STA_SSID="`syscfg get wl1_ssid`"
					STA_SECURITY="`syscfg get wl1_security_mode`"
					if [ "wpa-mixed" = "$STA_SECURITY" ]; then
						STA_SECURITY="wpa2-personal"
					fi
					STA_PASSPHRASE="`syscfg get wl1_passphrase`"
				fi
			fi
			;;
		*)
		echo "Invaild radio type: $STA_RADIO" > /dev/console 
	esac
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		if [ "wpa3-mixed" = "$STA_SECURITY"  ];then
			STA_SECURITY="wpa2-personal"
		elif [ "wpa3-open" = "$STA_SECURITY" ];then
			STA_SECURITY="disabled"
		fi
	fi
	echo "${SERVICE_NAME}, smart connect is in $MODE mode, connect to SSID - $STA_SSID, MAC - $DESIRE_MAC, CHANNEL - $DESIRE_CHAN (`date`)" > /dev/console 
	sysevent set wifi_sta_up 0
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
	
	DFS=$(is_dfs_chan $DESIRE_CHAN)
	if [ "$DFS" = "1" ]; then
		echo "${SERVICE_NAME}, target is DFS channel $DESIRE_CHAN" > /dev/console 
		hostapd_cli -i $USER_IF -p /var/run/hostapd disable
	fi
	echo "${SERVICE_NAME}, init()" > /dev/console 
	echo "${SERVICE_NAME}, creating STA vap $STA_IF" > /dev/console 
	ifconfig $STA_IF down
	if [ ! -e /sys/class/net/$STA_IF ]; then
		wlanconfig $STA_IF create wlandev $PHY_IF wlanmode sta nosbeacon
	fi
	iwpriv $STA_IF mode $OPMODE
	iwconfig $STA_IF essid "$STA_SSID" mode managed ap "$DESIRE_MAC"
	
	iwpriv $STA_IF wds 1
	if [ "DONE" = "$MODE" ]; then
	    iwpriv $STA_IF vlan_tag 1
	fi
	iwpriv $STA_IF rrm 1
	iwpriv $STA_IF vhtsubfee 1
	iwpriv $STA_IF implicitbf 1
	iwpriv $STA_IF shortgi 1
	if [ "2.4G" = "$STA_RADIO" ]; then
		qca_24_amsdu_performance_fix $STA_IF
	fi
	if [ "5GL" = "$STA_RADIO" -o "5GH" = "$STA_RADIO" ]; then
		iwpriv $STA_IF vhtmubfee 1
	fi
	if [ $(iwpriv "$PHY_IF" get_rxchainmask | awk -F ':' '{ print $2 }') -gt 3 ]; then
	    echo d > /sys/class/net/$STA_IF/queues/rx-0/rps_cpus
	fi
	if [ "$STA_IF" = "ath8" ] ; then
		if [ "`cat /etc/product`" = "wraith" ]; then
			echo "@@@@@ for wraith please do not add ath8 to br0"
		elif [ "$MODE" = "DONE" ]; then
			brctl delif `syscfg get svap_lan_ifname` $STA_IF
			brctl addif $STA_BRIDGE $STA_IF
		else
			brctl delif `syscfg get lan_ifname` $STA_IF
			brctl addif $STA_BRIDGE $STA_IF
		fi
	else
		brctl addif $STA_BRIDGE $STA_IF
		if [ "$STA_IF" = "ath9" -o "$STA_IF" = "ath11" ]  && [ "`syscfg get smart_mode::mode`" = "1" ]; then
		    brctl setpathcost $STA_BRIDGE $STA_IF 100
		    brctl setportprio $STA_BRIDGE $STA_IF 255
		fi		
	fi
}
wifi_sta_connect()
{
	iwconfig $USER_IF channel $DESIRE_CHAN
	if [ "ath5" = "$USER_IF_2" ] && [ "started" = "`sysevent get wifi_smart_configured_ath0-status`" ] ; then
		iwconfig $USER_IF_2 channel $DESIRE_CHAN
	fi
	iwconfig $STA_IF channel $DESIRE_CHAN
	
	echo "${SERVICE_NAME}, connect()" > /dev/console 
	echo "${SERVICE_NAME}, bring up STA vap $STA_IF (`date`)" > /dev/console 
	sleep 1
	
	generate_wpa_supplicant "$STA_IF" "$STA_SSID" "$STA_SECURITY" "$STA_PASSPHRASE" "$DESIRE_MAC" > $WPA_SUPPLICANT_CONF
	if [ "ath9" = "$STA_IF" ] || [ "ath11" = "$STA_IF" ] ; then
		if [ ! -z "$WPA_DEBUG" ];then
			wpa_supplicant $WPA_DEBUG -c $WPA_SUPPLICANT_CONF -i $STA_IF -b $STA_BRIDGE &
		else
			wpa_supplicant -B -c $WPA_SUPPLICANT_CONF -i $STA_IF -b $STA_BRIDGE
		fi
	else
		wpa_supplicant -B -c $WPA_SUPPLICANT_CONF -i $STA_IF -b $STA_BRIDGE
	fi
}
wifi_sta_verify_connection()
{
	COUNTER=0
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
			sysevent set wifi_sta_up 1
			echo "${SERVICE_NAME}, verify_connection(), $STA_IF associated to $STA_SSID  $DESIRE_MAC successfully(`date`)" > /dev/console 
			
			if [ "DONE" = "$MODE" ]; then
				if [ "$STA_IF" != "`sysevent get backhaul::intf`" ];then
					sysevent set smart_connect::backhaul_switch 1
					PRE_STA="`sysevent get backhaul::intf`"
					PRE_AP="`check_ap $PRE_STA`"
					sysevent set backhaul::pre_ap_intf $PRE_AP
				fi
				hostapd_cli -i $USER_IF -p /var/run/hostapd disable
				sysevent set backhaul::intf "$STA_IF"
				sysevent set backhaul::intf_AP "$USER_IF"
				VID=`syscfg_get svap_vlan_id`
				BRIDGE=`syscfg_get svap_lan_ifname`
				add_vlan_to_backhaul "$STA_IF" "$VID" "$BRIDGE"
				
				if [ "`syscfg_get guest_enabled`" = "1" ] ; then
				    GA_VID=`syscfg_get guest_vlan_id`
				    GA_BRIDGE=`syscfg_get guest_lan_ifname`
				    add_vlan_to_backhaul "$STA_IF" "$GA_VID" "$GA_BRIDGE"
				fi
			fi
			return 0
		fi
	done
	sysevent set wifi_sta_up 0
	echo "${SERVICE_NAME}, verify_connection(), $STA_IF unable to connect to $STA_SSID(`date`)" > /dev/console 
	ifconfig $STA_IF down
	return 1
}
client_connect()
{
	PROC_PID_LINE="`ps -ww | grep "smart_connect_client_connection_monitor.sh" | grep -v grep`"
	PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
	if [ ! -z "$PROC_PID" ]; then
		kill -9 "$PROC_PID"
		echo "smart connect client connection monitor stopped"
	fi
	wifi_sta_prepare
	wifi_sta_init
	wifi_sta_connect
	wifi_sta_verify_connection
}
filter_ap()
{
	F_IF="$1"	
	F_SSID="$2"
	F_RADIO="$3"
	F_FILE="$4"
	F_SCAN_OPTION="$5"
	
	ENCODE_F_SSID="`wl_ssid_grep "$F_SSID"`"
	FNUM="`wc -l /tmp/scan_result | awk '{print $1}'`"
	INDEX=2
	local CURRENT_CNT=$SCAN_CNT
	local F_MARK=0
	local FL_MASTER_CNT=0
	echo "wifi_smart_connect_client: scanning for "$F_SSID"(encode="$ENCODE_F_SSID") on $F_IF...(`date`) search option=$F_SCAN_OPTION" > /dev/console
	while [ $INDEX -le $FNUM ];do
		F_MARK=0
		LINE="` sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null`"
		tmp="`sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null |awk '{print $1"\t"$2"\t"$3"\t"$4"\t"}'|sed 's/\[/\\\[/g'|sed 's/\]/\\\]/g'`"
		SSID="`sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null |sed 's#'"$tmp"'##g'`"
		FREQUENCY="`sed -n ''$INDEX'p' /tmp/scan_result 2>/dev/null | awk '{print $2}'`"
		let "INDEX=INDEX+1"
		if [ "START" != "`sysevent get smart_connect::setup_status`" ] && [ "$SSID" != "$ENCODE_F_SSID" ];then
			continue
		fi
		if [ -z "$SSID" ] || [ -z "$LINE" ] || [ -z "$FREQUENCY" ] ;then
			continue
		fi
		if [ "$F_RADIO" = "5GL" ]; then
			change_freq_to_chan "$FREQUENCY"
			TMP_CHAN=$?
			if [ "$TMP_CHAN" -gt "65" ] || [ "$TMP_CHAN" = "0" ];then
				continue
			fi
		elif [ "$F_RADIO" = "5GH" ]; then
			change_freq_to_chan "$FREQUENCY"
			TMP_CHAN=$?
			if [ "$TMP_CHAN" -lt "65" ] || [ "$TMP_CHAN" = "0" ];then
				continue
			fi
		fi
		BSSID="`echo $LINE | awk '{print $1}'`"
		SNR="`echo $LINE | awk '{print $3}'`"
		if [ "$SNR" -eq "0" ]; then
			echo "Warning: AP $BSSID signal 0 detected!!" > /dev/console
		fi
		if [ "1" = "$F_SCAN_OPTION" ];then
			T_NF="`iwconfig $F_IF|grep Noise |awk -F 'Noise' '{print $2}'|awk -F '-' '{print $2}'|awk '{print $1}'`"
			T_RSSI="`syscfg get master_AP::threshold`"
			if [ -z "$T_RSSI" ]; then
				T_RSSI=-60
			fi
			echo "Scanning master rssi: `expr $SNR - $T_NF`, master AP filtering threshold: $T_RSSI" > /dev/consol
			T_SNR=`expr $T_NF + $T_RSSI`
			if [ "$SNR" -ge "$T_SNR" ];then
				FL_MASTER_CNT=`expr $FL_MASTER_CNT + 1`
				F_MARK=1
			fi
		fi 
		echo $LINE | awk '{print $1" "$2" "$3" '"$F_MARK"' '"${SSID}#"'"}' >> $F_FILE
		let "SCAN_CNT+=1"
	done
	rm -rf "/tmp/scan_result"
	if [ "$FL_MASTER_CNT" -gt "0" ];then
		return 2
	fi
	if [ "$SCAN_CNT" -gt "$CURRENT_CNT" ];then
		return 1
	else
		return 0
	fi
}
search_backhaul()
{
	WL="`sysevent get backhaul::set_intf`"
	BH_24G_ENABLED="`syscfg_get backhaul::24G_enabled`"
	USER_SCAN_SSID_24="`syscfg_get wl0_ssid`"
	USER_SCAN_SSID_L="`syscfg_get wl1_ssid`"
	USER_SCAN_SSID_H="`syscfg_get wl2_ssid`"
	echo "smart connect client: do scan on ${WL:-default} (`date`)" > /dev/console
	SCAN_COUNT=0
	while [ "$SCAN_COUNT" -lt 3 ];
	do
		SCAN_COUNT=`expr $SCAN_COUNT + 1`
		search_ap_pre "$AP_LIST"
		if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
			case "$WL" in
				"5GL")
					search_apv2 "5GL" "$USER_SCAN_SSID_L" "5GL" "$AP_LIST"
				;;
				"5GH")
					search_apv2 "5GH" "$USER_SCAN_SSID_H" "5GH" "$AP_LIST"
				;;
				"2.4G")
				;;
				"5G" | "5GL:5GH")
					search_apv2 "5GL" "$USER_SCAN_SSID_L" "5GL" "$AP_LIST"
					search_apv2 "5GH" "$USER_SCAN_SSID_H" "5GH" "$AP_LIST"
				;;
				*)
					search_apv2 "5GL" "$USER_SCAN_SSID_L" "5GL" "$AP_LIST"
					search_apv2 "5GH" "$USER_SCAN_SSID_H" "5GH" "$AP_LIST"
				;;
			esac
		elif [ "`cat /etc/product`" = "nodes-jr" ]; then
			case "$WL" in
				"2.4G")
					if [ "$BH_24G_ENABLED" = "1" ]; then
						search_apv2 "2.4G" "$USER_SCAN_SSID_24" "" "$AP_LIST"
					fi
				;;
				"5G" | "5GL:5GH")
					search_apv2 "5G" "$USER_SCAN_SSID_L" "" "$AP_LIST"
				;;
				"5GL")
					search_apv2 "5G" "$USER_SCAN_SSID_L" "5GL" "$AP_LIST"
				;;
				"5GH")
					search_apv2 "5G" "$USER_SCAN_SSID_L" "5GH" "$AP_LIST"
				;;
				*)
					search_apv2 "5G" "$USER_SCAN_SSID_L" "" "$AP_LIST"
					if [ "$BH_24G_ENABLED" = "1" ]; then
						search_apv2 "2.4G" "$USER_SCAN_SSID_24" "" "$AP_LIST"
					fi
				;;
			esac
		else
			case "$WL" in
				"2.4G")
					search_apv2 "2.4G" "$USER_SCAN_SSID_24" "" "$AP_LIST"
				;;
				"5G" | "5GL:5GH")
					search_apv2 "5G" "$USER_SCAN_SSID_L" "" "$AP_LIST"
				;;
				"5GL")
					search_apv2 "5G" "$USER_SCAN_SSID_L" "5GL" "$AP_LIST"
				;;
				"5GH")
					search_apv2 "5G" "$USER_SCAN_SSID_L" "5GH" "$AP_LIST"
				;;
				*)
					search_apv2 "5G" "$USER_SCAN_SSID_L" "" "$AP_LIST"
					search_apv2 "2.4G" "$USER_SCAN_SSID_24" "" "$AP_LIST"
				;;
			esac
		fi
		search_ap_fin "$AP_LIST"
		if [ -e $AP_LIST_SORT ]; then
			break
		fi
	done
	
	if [ -e $AP_LIST_SORT ]; then
		RET="`wc -l $AP_LIST_SORT | awk '{print $1}'`"
		if [ "1" = "$RET" ];then
			I_MAC="`sysevent get backhaul::preferred_bssid | tr [:upper:] [:lower:]`"
			SCAN_MAC="`cat $AP_LIST_SORT | awk '{print $1}'`"
			if [ "$I_MAC" = "$SCAN_MAC" ];then
				echo "smart connect client: the BSSID is the old one, try scan on the other interface (`date`)" > /dev/console
			fi
		fi
	fi
}
search_ap()
{
	:
}
search_ap_pre()
{
	local O_FILE="$1"
	SCAN_CNT=0
	if [ -e $O_FILE ]; then
		rm -f $O_FILE
	fi
	if [ -e $AP_LIST_SORT ]; then
		rm -f $AP_LIST_SORT
	fi
}
search_apv2()
{
	RADIO="$1"
	IF=""
	DESIRED_SSID="$2"
	DESIRED_RADIO="`echo "$3" | tr [:lower:] [:upper:]`"
	S_FILE="$4"
	S_MODE="`sysevent get smart_connect::setup_status`"
	if [ "1" = "`syscfg_get wifi::multiregion_support`" -a "1" = "`syscfg_get wifi::multiregion_enable`" -a "1" = "`get_multiregion_region_validation`" ] ; then
	    REGION=`syscfg get wifi::multiregion_region`
	else
	    REGION=`syscfg_get device::cert_region`
	fi
	S_RADIO="`echo "$RADIO" | tr [:lower:] [:upper:]`"
	WPA_TIMEOUT=15
	case "$S_RADIO" in
		"2.4G")
			IF="ath8"
			PHY_IF="wifi0"
			USER_IF="ath0"
			if [ "EU" != "$REGION" ];then
				DFS="`syscfg get wl0_dfs_enabled`"
			else 
				DFS="1"
			fi
			;;
		"5G")
			IF="ath9"
			PHY_IF="wifi1"
			USER_IF="ath1"
			if [ "EU" != "$REGION" -a "ME" != "$REGION" -a "JP" != "$REGION" ];then
				DFS="`syscfg get wl1_dfs_enabled`"
			else 
				DFS="1"
			fi
			;;
		"5GL")
			IF="ath9"
			PHY_IF="wifi1"
			USER_IF="ath1"
			if [ "EU" != "$REGION" -a "ME" != "$REGION" -a "JP" != "$REGION" ];then
				DFS="`syscfg get wl1_dfs_enabled`"
			else 
				DFS="1"
			fi
			;;
		"5GH")
			IF="ath11"
			PHY_IF="wifi2"
			USER_IF="ath10"
			if [ "EU" != "$REGION" -a "ME" != "$REGION" -a "JP" != "$REGION" ];then
				DFS="`syscfg get wl2_dfs_enabled`"
			else 
				DFS="1"
			fi
			;;
		*)
		echo "site survey error: invalid radio" > /dev/console 
	esac
	if [ "$DFS" = "1" ] && [ "" != "`ifconfig $USER_IF |grep "UP"`" ];then
		IF_STATE_CHANGE="1"
		hostapd_cli -i $USER_IF -p /var/run/hostapd disable
	fi
	if [ ! -e /sys/class/net/$IF ]; then
		wlanconfig $IF create wlandev $PHY_IF wlanmode sta nosbeacon
	fi
	
	if [ "DONE" = "`sysevent get smart_connect::setup_status`" ]; then
		PROC_PID_LINE="`ps -w | grep "wpa_supplicant" | grep -v grep`"
		if [ ! -z "$PROC_PID_LINE" ]; then
			killall -9 wpa_supplicant
		fi
		CONF_FILE=/tmp/var/run/wpa_supplicant_$IF/$IF
		if [ -e $CONF_FILE ]; then
			rm -f $CONF_FILE
		fi
   		generate_wpa_supplicant "$IF" "none" "none" "" "" > "/tmp/wpa_supplicant_$IF.conf"
		if [ ! -z "$WPA_DEBUG" ]; then
   			wpa_supplicant $WPA_DEBUG -c "/tmp/wpa_supplicant_$IF.conf" -i $IF -b br0 &
		else
   			wpa_supplicant -B -c "/tmp/wpa_supplicant_$IF.conf" -i $IF -b br0
		fi
	else #config VAP is a hidden VAP
		killall -9 wpa_supplicant
		CONF_FILE=/tmp/var/run/wpa_supplicant_$IF/$IF
		if [ -e $CONF_FILE ]; then
			rm -f $CONF_FILE
		fi
   		generate_wpa_supplicant "$IF" "$DESIRED_SSID" "none" "" "" > "/tmp/wpa_supplicant_$IF.conf"
   		wpa_supplicant -B -c "/tmp/wpa_supplicant_$IF.conf" -i $IF -b br0
	fi
	if [ "$DFS" = "1" ]; then
		WPA_TIMEOUT=20
	fi
	sysevent set smart_connect::scan_done 0
	sleep 1
	WPA_CNT=0
	while [ "1" != "`sysevent get smart_connect::scan_done`" ] && [ "$WPA_CNT" -lt "$WPA_TIMEOUT" ];
	do 
		WPA_CNT=`expr $WPA_CNT + 1`
		sleep 1
	done
	if [ ! -z "$WPA_DEBUG" -a "$WPA_CNT" -ge "$WPA_TIMEOUT" ]; then
		echo "Warning: Waiting for wpa_supplicant scanning timeout!" > /dev/console
	fi
	sysevent set smart_connect::scan_done 0
	if [ "START" = "$S_MODE" ];then
		rm -rf $HOSTAP_IE_FILE
		echo "$HOSTAPD_IE_SETUP" > $HOSTAP_IE_FILE
		wpa_cli -p /var/run/wpa_supplicant_$IF -i $IF scan_results_belkin > "/tmp/scan_result"
		filter_ap "$IF" "$DESIRED_SSID" "$DESIRED_RADIO" "$S_FILE"
	elif [ "DONE" = "$S_MODE" ];then
		rm -rf $HOSTAP_IE_FILE
		echo "$HOSTAPD_IE_MASTER" > $HOSTAP_IE_FILE
		wpa_cli -p /var/run/wpa_supplicant_$IF -i $IF scan_results_belkin > "/tmp/scan_result"
		filter_ap "$IF" "$DESIRED_SSID" "$DESIRED_RADIO" "$S_FILE" "1"
		RET=$?
		if [ "2" != "$RET" ]; then
			rm -rf $HOSTAP_IE_FILE
			echo "$HOSTAPD_IE_SLAVE" > $HOSTAP_IE_FILE
			wpa_cli -p /var/run/wpa_supplicant_$IF -i $IF scan_results_belkin > "/tmp/scan_result"
			filter_ap "$IF" "$DESIRED_SSID" "$DESIRED_RADIO" "$S_FILE"
		fi
		if [ ! -e $S_FILE ] ;then
			wpa_cli -p /var/run/wpa_supplicant_$IF -i $IF scan_results > "/tmp/scan_result"
			filter_ap "$IF" "$DESIRED_SSID" "$DESIRED_RADIO" "$S_FILE"
		fi
	else
		wpa_cli -p /var/run/wpa_supplicant_$IF -i $IF scan_results > "/tmp/scan_result"
		filter_ap "$IF" "$DESIRED_SSID" "$S_RADIO" "$S_FILE"
	fi
	
	killall -9 wpa_supplicant
	sleep 2
	ifconfig $IF down
	if [ "$IF_STATE_CHANGE" = "1" ];then
		hostapd_cli -i $USER_IF -p /var/run/hostapd enable
	fi
}
search_ap_fin()
{
	local F_FILE="$1"
	if [ "0" != "$SCAN_CNT" ];then 
		echo "wifi_smart_connect_client scan results: $SCAN_CNT AP(s)" > /dev/console 
		sort -n -r -k 4 -k 3 $F_FILE > $AP_LIST_SORT
		FMT="%-20s%-12s%-12s%-8s%s\n"
		echo "  Scan results:" > /dev/console
		printf "$FMT" "MAC" "Frequency" "SNR/RSSI" "FLAG" "SSID"
		printf "$FMT" "--------" "--------" "--------" "----" "--------"
		cat $AP_LIST_SORT | awk '{printf '\"$FMT\"', $1, $2, $3"/"$3-95, $4, substr($5, 0, length($5)-1)}'
	else
		echo "wifi_smart_connect_client: no desired AP found...(`date`)" > /dev/console 
	fi
}
lsc_client_unique_check ()
{
    PROC_PID_LINE=`ps -w | grep "lsc_client" | grep -v grep`
    PROC_PID=`echo $PROC_PID_LINE |  awk '{print $1}'`
    if [ -n "$PROC_PID" ]; then
        echo "${SERVICE_NAME}, stop process: ${PROC_PID_LINE}"
        kill -9 $PROC_PID > /dev/null 2>&1
    fi
}
omsg_serverip () {
    sysevent get master::ip
}
get_server_config_info()
{
	setup_mode="$1"
	SERVERIP="`syscfg_get smart_connect::serverip`"
	local OMSG_SERVERIP="$(omsg_serverip)"
	if [ "$setup_mode" = "wired" ] && [ "$OMSG_SERVERIP" != "" ] ; then
		SERVERIP="$OMSG_SERVERIP"
	fi
    lsc_client_unique_check
    /usr/sbin/lsc_client --ip $SERVERIP --cmd setup > /var/lsc_client.err &
    S_CNT=0
    sleep 1
    while [ "$S_CNT" -lt 120 ]
    do
        PROC_LINE=`ps -w | grep lsc_client | grep -v grep`
        if [ -z "$PROC_LINE" ] ; then
            sleep 2
            PROC_LINE=`ps -w | grep lsc_client | grep -v grep`
            [ -z "$PROC_LINE" ] && break
        fi
        sleep 1
        S_CNT=`expr $S_CNT + 1`
    done
    if [ -z "$PROC_LINE" ] && [ "Error" != "`cat /var/lsc_client.err | sed -n 1p | awk -F':' '{print $1}'`" ] ; then
        return 0
    fi
    cat /var/lsc_client.err > /dev/console
	return 1
}
get_server_pre_auth()
{
	setup_mode="$1"
	SERVERIP="`syscfg_get smart_connect::serverip`"
	local OMSG_SERVERIP="$(omsg_serverip)"
	if [ "$setup_mode" = "wired" ] && [ "$OMSG_SERVERIP" != "" ] ; then
		SERVERIP="$OMSG_SERVERIP"
	fi
	echo "smart connect client:try to get the pre_auth(`date`)" > /dev/console
	P_CNT=0
	lsc_client_unique_check
	while [ "$P_CNT" -lt 3 ]
	do
        /usr/sbin/lsc_client --ip $SERVERIP --cmd pre_auth > /var/lsc_client.err &
        S_CNT=0
        sleep 1
        while [ "$S_CNT" -lt 60 ]
        do
            PROC_LINE=`ps -w | grep lsc_client | grep -v grep`
            if [ -z "$PROC_LINE" ] ; then
                sleep 2
                PROC_LINE=`ps -w | grep lsc_client | grep -v grep`
                [ -z "$PROC_LINE" ] && break
            fi
            sleep 1
            S_CNT=`expr $S_CNT + 1`
        done
        if [ -z "$PROC_LINE" ] && [ "Error" != "`cat /var/lsc_client.err | sed -n 1p | awk -F':' '{print $1}'`" ] ; then
            break
        fi
        cat /var/lsc_client.err > /dev/console
        echo "ERROR getting server config info! will retry..." > /dev/console 
        sleep 2
        lsc_client_unique_check
        P_CNT=`expr $P_CNT + 1`
        continue
	done
	[ "$P_CNT" = "3" ] && return 0
	echo "smart connect client:get the pre_auth successfully (`date`)" > /dev/console 
	return 1
}
get_server_primary_info()
{
	setup_mode="$1"
	SERVERIP="`syscfg_get smart_connect::serverip`"
	local OMSG_SERVERIP="$(omsg_serverip)"
	if [ "$setup_mode" = "wired" ] && [ "$OMSG_SERVERIP" != "" ] ; then
		SERVERIP="$OMSG_SERVERIP"
	fi
	echo "smart connect client:try to get the server primary wifi info(`date`)" > /dev/console
	P_CNT=0
	lsc_client_unique_check
	while [ "$P_CNT" -lt 3 ]
	do
        /usr/sbin/lsc_client --ip $SERVERIP --cmd auth > /var/lsc_client.err &
        S_CNT=0
        sleep 1
        while [ "$S_CNT" -lt 60 ]
        do
            PROC_LINE=`ps -w | grep lsc_client | grep -v grep`
            if [ -z "$PROC_LINE" ] ; then
                sleep 2
                PROC_LINE=`ps -w | grep lsc_client | grep -v grep`
                [ -z "$PROC_LINE" ] && break
            fi
            sleep 1
            S_CNT=`expr $S_CNT + 1`
        done
        if [ -z "$PROC_LINE" ] && [ "Error" != "`cat /var/lsc_client.err | sed -n 1p | awk -F':' '{print $1}'`" ] ; then
            break
        fi
        cat /var/lsc_client.err > /dev/console
        echo "ERROR getting server primary wifi info! will retry..." > /dev/console
        sleep 5
        lsc_client_unique_check
        P_CNT=`expr $P_CNT + 1`
        continue
	done
	[ "$P_CNT" = "3" ] && return 0
	CLIENT_SQL="$DB_DIR/client.sql"
	if [ -f "$CLIENT_SQL" ]; then
		echo "smart connect client: successfully retrieved primary vap info from lsc server(`date`)" > /dev/console 
		break
	else
		echo "ERROR smart connect client: file $CLIENT_WIFI does not exist" > /dev/console 
		return 0
	fi
	echo "smart connect client:get the the server primary wifi info successfully (`date`)" > /dev/console 
	return 1
}
generate_client_device_data()
{
	PIN="`syscfg_get smart_connect::client_pin`"
	if [ -z "$PIN" ]; then
		WPS_PIN=`syscfg get device::wps_pin`
		PIN=`echo ${WPS_PIN:4}`
		syscfg_set smart_connect::client_pin "$PIN"
	fi
	MAC="`syscfg_get device::mac_addr`"
	SERIAL="`syscfg_get device::serial_number`"
	VENDOR="`syscfg_get device::manufacturer`"
	MODEL="`syscfg_get device::modelNumber`"
	DESC="`syscfg_get device::modelDescription`"
    cat <<EOF
pin=$PIN
mac=$MAC
serial=$SERIAL
vendor=$VENDOR
model=$MODEL
desc=$DESC
EOF
}
client_data_setup()
{
	CLIENT_DEVICE_DATA="$SC_DIR/client_data"
	if [ ! -d "$SC_DIR" ]; then
		mkdir $SC_DIR
	fi
	echo "smart connect client, generating client device data" > /dev/console 
	generate_client_device_data > $CLIENT_DEVICE_DATA
}
print_help()
{
	echo "Usage: wifi_smart_connect_client <option>" > /dev/console 
	echo "valid options:" > /dev/console 
	echo "	scan_setup_ap" > /dev/console 
	echo "	create_client_data" > /dev/console 
	echo "	connect" > /dev/console 
	echo "	get_server_config_info" > /dev/console 
	echo "	get_server_primary_info" > /dev/console 
	exit
}
case "`echo $COMMAND`" in
	"scan_setup_ap")
		scan_setup_ap "$2"
		;;
	"create_client_data")
		client_data_setup
		;;
	"connect")
		client_connect
		;;
	"get_server_config_info")
		get_server_config_info "$2"
		;;
	"get_server_pre_auth")
		get_server_pre_auth "$2"
		;;
	"get_server_primary_info")
		get_server_primary_info "$2"
		;;
	"search_ap")
		WPA_DEBUG="$2"
		search_ap_pre "$AP_LIST"
		search_apv2 "5G" "`syscfg_get wl1_ssid`" "" "$AP_LIST"
		search_ap_fin "$AP_LIST"
		;;
	"connect_setup_VAP")
		connect_setup_VAP "$2"
		;;
	"connect_config_VAP")
		connect_config_VAP "$2"
		;;
	"backhaul_selector")
		backhaul_selector
		;;
	"connect_user_VAP")
		connect_user_VAP "$2" "$3" "$4"
		;;
	*)
		print_help
esac
