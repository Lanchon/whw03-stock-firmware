#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_physical.sh
source /etc/init.d/service_wifi/wifi_virtual.sh
source /etc/init.d/service_wifi/wifi_guest.sh
source /etc/init.d/service_wifi/smart_connect_server_utils.sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
PROG_NAME="$(basename $0)"
WIFI_DEBUG_SETTING=`syscfg_get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
WIFI_HOSTAPD_DEBUG_SETTING=`syscfg_get ${SERVICE_NAME}_hostapd_debug`
HOSTAPD_DEBUG()
{
    [ "$WIFI_HOSTAPD_DEBUG_SETTING" = "1" ] && $@
}
hostapd_status () {
    sysevent get hostapd_status
}
echo "${SERVICE_NAME}, sysevent received: $1 (`date`)"
LOCK_FILE=/tmp/${SERVICE_NAME}.lock
lock $LOCK_FILE
STA_PHY_IF=""
service_init()
{
	ulog wlan status "${SERVICE_NAME}, service_init()"
	SYSCFG_FAILED='false'
	FOO=`utctx_cmd get device::deviceType wl_wmm_support lan_wl_physical_ifnames wl0_ssid wl1_ssid lan_ifname guest_enabled guest_lan_ifname guest_wifi_phy_ifname wl0_guest_vap guest_ssid_suffix guest_ssid guest_ssid_broadcast guest_lan_ipaddr guest_lan_netmask wl0_state guest_vlan_id extender_radio_mode`
	eval $FOO
	if [ $SYSCFG_FAILED = 'true' ] ; then
		ulog wlan status "$PID utctx failed to get some configuration data required by service-forwarding"
		ulog wlan status "$PID THE SYSTEM IS NOT SANE"
		echo "${SERVICE_NAME}, [utopia] utctx failed to get some configuration data required by service-system" > /dev/console
		echo "${SERVICE_NAME}, [utopia] THE SYSTEM IS NOT SANE" > /dev/console
		sysevent set ${SERVICE_NAME}-status error
		sysevent set ${SERVICE_NAME}-errinfo "Unable to get crucial information from syscfg"
		exit
	fi
	RECONFIGURE="false"
	STA_PHY_IF=`syscfg_get wifi_sta_phy_if`
	return 0
}
service_start()
{
	ulog wlan status "${SERVICE_NAME}, service_start()"
	STATUS=`sysevent get ${SERVICE_NAME}-status`
	if [ "started" = "$STATUS" ] || [ "starting" = "$STATUS" ]; then
		echo "${SERVICE_NAME} is starting/started, ignore the request"
		ulog wlan status "${SERVICE_NAME} is starting/started, ignore the request"
		return 1
	fi
	if [ "0" = "`syscfg_get bridge_mode`" ] && [ "started" != "`sysevent get lan-status`" ] ; then
		ulog wlan status "${SERVICE_NAME}, LAN is not started,ignore the request"
		return 1
	fi
	echo "${SERVICE_NAME}, service_start()"
	sysevent set ${SERVICE_NAME}-status starting
	wifi_onetime_setting
	if [ -f /etc/init.d/service_wifi/wifi_button.sh ]; then
		/etc/init.d/service_wifi/wifi_button.sh
	fi
	SYSCFG_INDEX_LIST=`syscfg_get configurable_wl_ifs`
	for SYSCFG_INDEX in $SYSCFG_INDEX_LIST ; do
		update_wifi_cache "physical" "$SYSCFG_INDEX"
		update_wifi_cache "virtual" "$SYSCFG_INDEX"
		update_wifi_cache "guest" "$SYSCFG_INDEX"
	done
	if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "wraith" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
		if [ "`syscfg get smart_mode::mode`" = "1" ] ; then
			/etc/init.d/service_guest_access.sh guest_access-start
		fi
	fi
	for PHY_IF in $PHYSICAL_IF_LIST; do
		wifi_physical_start $PHY_IF
		wifi_virtual_start $PHY_IF
	done
	start_hostapd
	if [ "`syscfg get smart_mode::mode`" = "2" ]; then
	    start_lsc_server
	fi
	if [ "`syscfg get smart_mode::mode`" = "1" ] || [ "`syscfg get smart_mode::mode`" = "2" ]; then
		wifi_smart_connect_setup_stop
	fi
	if [ "`syscfg get smart_mode::mode`" = "2" ] ; then 
		sysevent set smart_connect::setup_status READY
	fi
	if [ "$(syscfg get smart_mode::mode)" = "0" ] ; then
		if [ "$(sysevent get smart_connect::setup_status)" = "START" ] && [ "$(sysevent get smart_connect::setup_mode)" = "wired" ] ; then
			ulog wlan status "${SERVICE_NAME} Wired setup is startted, keep the smart_connect::setup_status"
		else
			sysevent set smart_connect::setup_status READY
		fi
	fi
	if [ "`syscfg_get wl_wmm_support`" = "enabled" ] && [ "`syscfg_get wl0_network_mode`" = "11b" ]; then
        	VAP_IF=`syscfg_get wl0_physical_ifname`
        	iwpriv $VAP_IF setwmmparams 1 0 1 4
        	iwpriv $VAP_IF setwmmparams 1 1 1 4
        	iwpriv $VAP_IF setwmmparams 1 2 1 3
        	iwpriv $VAP_IF setwmmparams 1 3 1 2
        	iwpriv $VAP_IF setwmmparams 2 0 1 10
        	iwpriv $VAP_IF setwmmparams 2 1 1 10
        	iwpriv $VAP_IF setwmmparams 2 2 1 4
        	iwpriv $VAP_IF setwmmparams 2 3 1 3
	fi
	if [ "0" != "`syscfg get bridge_mode`" ] && [ -f /etc/init.d/service_wifi/wifi_repeater.sh ] && [ "2" = "`syscfg_get wifi_bridge::mode`" ] && [ "1" != "`syscfg get smart_mode::mode`" ]; then
		echo "service_wifi service_start, repeater mode enabled"
		/etc/init.d/service_wifi/wifi_repeater.sh
	fi
	if [ "0" != "`syscfg get bridge_mode`" ] && [ -f /etc/init.d/service_wifi/wifi_sta_setup.sh ] && [ "1" = "`syscfg get wifi_bridge::mode`" ]; then
		/etc/init.d/service_wifi/wifi_sta_setup.sh
		source /etc/init.d/service_wifi/wifi_utils.sh
	fi
    if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
        config_scan_table_sharing_between_radios
    fi
	for INTF in $IF_STATE_CHECK_LIST; do
		wait_ap_bring_up $INTF
		if [ $? -ne 0 ]; then
			echo "${SERVICE_NAME}, Timeout, $INTF is not up!!"
		fi
	done
	enable_rps_wifi=0
	for PHY_IF in $PHYSICAL_IF_LIST; do
	    set_driver_txpower $PHY_IF
	    phy=`get_phy_interface_name_from_vap "$PHY_IF"`
	    if [ $(iwpriv "$phy" get_rxchainmask | awk -F ':' '{ print $2 }') -gt 3 ]; then
	        echo d > /sys/class/net/$PHY_IF/queues/rx-0/rps_cpus
	        enable_rps_wifi=1
		fi
	    if [ "$(cat /etc/product)" = nodes ]; then
		set_driver_enable_ol_stats $PHY_IF
	    fi
	done
	if [ $enable_rps_wifi == 1 ]; then
		echo "0" > /proc/qrfs/enable 
	fi
	if [ "`syscfg get smart_mode::mode`" = "0" -a "`syscfg get xconnect::vap_enabled`" = "1" ]; then
		wifi_unconfig_ap_configure_ip
	fi
	sysevent set ${SERVICE_NAME}-status started
	if [ "`syscfg get smart_mode::mode`" = "1" ]; then
		if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
	    	/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release
	    	/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew
		else
	    	/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-release
	    	/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-renew
		fi
	fi
	if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`sysevent get autochannel-quiet`" = "1" ]; then
		BACKHAUL_INTF="`sysevent get backhaul::intf`"
		if [ "${BACKHAUL_INTF:0:3}" = "eth" ]; then
			sysevent set wifi_channel_refreshed
		fi
	fi
		
	return 0
}
service_stop()
{
	ulog wlan status "${SERVICE_NAME}, service_stop()"
	STATUS=`sysevent get ${SERVICE_NAME}-status`
	if [ "stopped" = "$STATUS" ] || [ "stopping" = "$STATUS" ] || [ -z "$STATUS" ]; then
		echo "${SERVICE_NAME} is stopping/stopped, ignore the request"
		ulog wlan status "${SERVICE_NAME} is stopping/stopped, ignore the request"
		return 1
	fi
	
	echo "${SERVICE_NAME}, service_stop()"
	sysevent set ${SERVICE_NAME}-status stopping
	if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "wraith" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		if [ "`syscfg get smart_mode::mode`" = "2" ] ; then
			sysevent set smart_connect-stop
			stop_lsc_server
		elif [ "`syscfg get smart_mode::mode`" = "1" ] ; then
			PROC_PID_LINE="`ps -w | grep "wpa_supplicant" | grep -v grep`"
			if [ ! -z "$PROC_PID_LINE" ]; then
				killall -9 wpa_supplicant
			fi
			stop_smart_connect_connection_monitor
		fi
	fi
	
	for PHY_IF in $PHYSICAL_IF_LIST; do
		wifi_guest_stop $PHY_IF
		wifi_virtual_stop $PHY_IF
		stop_hostapd $PHY_IF
		wifi_physical_stop $PHY_IF
	done
	sysevent set ${SERVICE_NAME}-status stopped
	return 0
}
service_restart()
{
	ulog wlan status "${SERVICE_NAME}, service_restart()"
	service_stop
	service_start
}
wifi_onetime_setting()
{
	ONE_TIME=`sysevent get wifi-onetime-setting`
	if [ "$ONE_TIME" != "TRUE" ] ; then
		ulog wlan status "${SERVICE_NAME}, wifi_onetime_setting()"
		sysevent set wifi-onetime-setting "TRUE"
		sysevent set wl0_status "down"
		sysevent set wl0_guest_status "down"
		sysevent set wl0_tc_status "down"
		sysevent set wl1_status "down"
		sysevent set wl1_guest_status "down"
		sysevent set wl1_tc_status "down"
		sysevent set wl2_guest_status "down"	
		if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "dallas" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
			sysevent set wl2_status "down"
		fi
		load_wifi_driver            
		/etc/init.d/service_wifi/WiFi_info_set.sh &	
		create_files
		test_setup
		if [ -f "/etc/init.d/service_wifi/smart_connect_client_utils.sh" ]; then
			/etc/init.d/service_wifi/smart_connect_client_utils.sh create_client_data
		fi
	
	fi
	return 0
}
wifi_config_changed_handler()
{
	EXT_ARG="$1"
	ulog wlan status "${SERVICE_NAME}, wifi_config_changed_handler()"
	echo "${SERVICE_NAME}, wifi_config_changed_handler(), arg=${EXT_ARG:-N/A}"
	
	if [ -f /etc/init.d/service_wifi/wifi_button.sh ]; then
		/etc/init.d/service_wifi/wifi_button.sh
	fi
	if [ "0" = "`syscfg_get bridge_mode`" ] && [ "started" != "`sysevent get lan-status`" ] ; then
		ulog wlan status "${SERVICE_NAME}, LAN is not started,ignore the request"
		echo "${SERVICE_NAME}, LAN is not started,ignore the request"
		return 1
	fi
	if [ "`syscfg get smart_mode::mode`" = "1" ]; then
		br2_ip="`ifconfig br2 | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}'`"
		if [ "$br2_ip" != "" ] ; then
			sc_serverip="`syscfg get smart_connect::serverip`"
			br2_ip_3octets="`echo ${br2_ip} | awk -F. '{ print $1 $2 $3 }'`"
			sc_serverip_3octets="`echo ${sc_serverip} | awk -F. '{ print $1 $2 $3 }'`"
			if [ "$br2_ip_3octets" != "$sc_serverip_3octets" ] ; then
				sysevent set setup_dhcp_client-restart
			fi
		fi
	fi
	STATUS=`sysevent get ${SERVICE_NAME}-status`
	if [ "starting" = "$STATUS" ] || [ "stopping" = "$STATUS" ] || [ -z "$STATUS" ] || [ "stopped" = "$STATUS" ]; then
		echo "${SERVICE_NAME} is stopping/starting, ignore the request"
		ulog wlan status "${SERVICE_NAME} is stopping/starting, ignore the request"
		sysevent_enqueue wifi_config_changed
		return 1
	fi
	
	sysevent set ${SERVICE_NAME}-status starting
	if [ -f $CHANGED_FILE ]; then
		mv $CHANGED_FILE $CHANGED_FILE".prev"
	fi
	sysevent set wifi_cache_updating 1
	PHY_LIST_RESTART=""
	VIR_LIST_RESTART=""
	GUEST_LIST_RESTART=""
	for PHY_IF in $PHYSICAL_IF_LIST; do
		SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
		restart_required "physical" ${SYSCFG_INDEX}
		PHY_RESTART="$?"
		update_wifi_cache "physical" ${SYSCFG_INDEX}
		if [ "$PHY_RESTART" = "1" ] ; then
			ulog wlan status "${SERVICE_NAME}, physical changes detected: $PHY_IF"
			echo "${SERVICE_NAME}, physical changes detected: $PHY_IF"
			PHY_LIST_RESTART="`echo $PHY_LIST_RESTART` $PHY_IF"
			update_wifi_cache "virtual" ${SYSCFG_INDEX}
			update_wifi_cache "guest" ${SYSCFG_INDEX}
		else	
			restart_required "virtual" ${SYSCFG_INDEX}
			VIR_RESTART="$?"
			update_wifi_cache "virtual" ${SYSCFG_INDEX}
			if [ "`sysevent get smart_connect::backhaul_switch`" = "1" ] && [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
				VIR_RESTART="1"
			fi
			if [ "`syscfg get ${WIFI_PRIV_NAMESPACE}::enabled`" = "1" ] && [ -e /tmp/cedar_support ]; then
				current_ssid=`syscfg_get ${SYSCFG_INDEX}_ssid`
				current_pass=`syscfg_get ${SYSCFG_INDEX}_passphrase`
				ath0_wl=`syscfg_get ath0_syscfg_index`
				ath0_pass=`syscfg_get ${ath0_wl}_passphrase`
				ath0_ssid=`syscfg_get ${ath0_wl}_ssid`
				if [ "$current_pass" != "$ath0_pass" -o "$current_ssid" != "$ath0_ssid" ]; then
					VIR_RESTART="1"
				fi
			fi
			if [ "$VIR_RESTART" = "1" ] ; then
				ulog wlan status "${SERVICE_NAME}, virtual changes detected: $PHY_IF"
				echo "${SERVICE_NAME}, virtual changes detected: $PHY_IF"
				VIR_LIST_RESTART="`echo $VIR_LIST_RESTART` $PHY_IF"
				update_wifi_cache "guest" ${SYSCFG_INDEX}
			else
				restart_required "guest" ${SYSCFG_INDEX}
				GUEST_RESTART="$?"
				update_wifi_cache "guest" ${SYSCFG_INDEX}
				if [ "$GUEST_RESTART" = "1" ]; then
					ulog wlan status "${SERVICE_NAME}, guest changes detected: $PHY_IF"
					echo "${SERVICE_NAME}, guest changes detected: $PHY_IF"
					GUEST_LIST_RESTART="`echo $GUEST_LIST_RESTART` $PHY_IF"
				fi
			fi
		fi
	done
	sysevent set wifi_cache_updating 0
	if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`sysevent get smart_connect::backhaul_switch`" = "1" ]; then
		sysevent set smart_connect::backhaul_switch 0
	fi
	if [ -z "$PHY_LIST_RESTART" ] && [ -z "$VIR_LIST_RESTART" ] && [ -z "$GUEST_LIST_RESTART" ]; then
		ulog wlan status "${SERVICE_NAME}, no wifi config changes detected,ignore the request"
		echo "${SERVICE_NAME}, no wifi config changes detected,ignore the request"
		sysevent set wifi_button_cnt 0
		sysevent set ${SERVICE_NAME}-status started
		return 1
	fi
	if [ ! -z "$PHY_LIST_RESTART" ] ; then
		if [ "1" = "`syscfg get wl1_dfs_enabled`" ] && [ "36,40,44,48,52,56,60,64" != "`syscfg get wl1_available_channels`" ] ; then
			/etc/init.d/service_wifi/WiFi_info_set.sh &
		fi
		if [ "0" = "`syscfg get wl1_dfs_enabled`" ] && [ "36,40,44,48,52,56,60,64" = "`syscfg get wl1_available_channels`" ] ; then
			/etc/init.d/service_wifi/WiFi_info_set.sh &
		fi
	fi
	if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "wraith" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
		if [ "`syscfg get smart_mode::mode`" = "2" ] ; then
	        stop_lsc_server
		elif [ "`syscfg get smart_mode::mode`" = "1" ] ; then
			if [ "$EXT_ARG" != "cli_monitor" ]; then
				stop_smart_connect_connection_monitor
			fi
		fi
		if [ "`syscfg get smart_mode::mode`" = "1" ] ; then
	        /etc/init.d/service_guest_access.sh guest_access-restart
		fi
	fi
	SYSEVENT_BACKHAUL_INTF=`sysevent get backhaul::intf`
	for PHY_IF in $PHY_LIST_RESTART; do
		ulog wlan status "${SERVICE_NAME}, physical interface is required to restart: $PHY_IF"
		echo "${SERVICE_NAME}, physical interface is required to restart: $PHY_IF"
		sysevent set wifi_interrupt_led 1
		wifi_virtual_stop $PHY_IF
		stop_hostapd $PHY_IF
		wifi_physical_stop $PHY_IF
		wifi_physical_start $PHY_IF
		wifi_virtual_start $PHY_IF
		set_driver_txpower $PHY_IF
	done
	for PHY_IF in $VIR_LIST_RESTART; do
		SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
		VIR_IF=`syscfg_get "$SYSCFG_INDEX"_user_vap`
		if [ ! -z "$VIR_IF" ]; then
			ulog wlan status "${SERVICE_NAME}, virtual interface is required to restart: $PHY_IF"
			echo "${SERVICE_NAME}, virtual interface is required to restart: $PHY_IF"
			sysevent set wifi_interrupt_led 1
			wifi_virtual_stop $PHY_IF
			stop_hostapd $PHY_IF
			wifi_virtual_start $PHY_IF
		fi
	done
	for PHY_IF in $GUEST_LIST_RESTART; do
		SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
		VIR_IF=`syscfg_get "$SYSCFG_INDEX"_guest_vap`
		if [ ! -z "$VIR_IF" ]; then
			ulog wlan status "${SERVICE_NAME}, guest interface is required to restart: $PHY_IF"
			echo "${SERVICE_NAME}, guest interface is required to restart: $PHY_IF"
			sysevent set wifi_interrupt_led 1
			if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
				killall hostapd > /dev/null 2>&1
			fi
			wifi_guest_restart $PHY_IF
		fi
	done	
	SLEEP_WAIT=0
	SLEEP_TIMEOUT=3
	while [ "$SLEEP_WAIT" -lt "$SLEEP_TIMEOUT" ]
	do
		if [ -z "`ps | grep ' hostapd ' | grep -v grep`" ]; then
			break
		fi
		sleep 1
		SLEEP_WAIT=`expr $SLEEP_WAIT + 1`
	done
	
	if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
		if [ "" != "$PHY_LIST_RESTART" ] || [ "" != "$VIR_LIST_RESTART" ] || [ "" != "$GUEST_LIST_RESTART" ] ; then
			start_hostapd
		fi
	elif [ "" != "$PHY_LIST_RESTART" ] || [ "" != "$VIR_LIST_RESTART" ] ; then
		start_hostapd
	fi
	SYSEVENT_BACKHAUL_INTF=""
	if [ "`syscfg get smart_mode::mode`" = "1" ] || [ "`syscfg get smart_mode::mode`" = "2" ]; then
		wifi_smart_connect_setup_stop
	fi
	if [ "`syscfg get smart_mode::mode`" = "2" ]; then
		start_lsc_server
	fi
	if [ "`syscfg get smart_mode::mode`" = "2" ] || [ "`syscfg get smart_mode::mode`" = "0" ] ; then
		sysevent set smart_connect::setup_status READY
	fi
	if [ "`syscfg_get wl_wmm_support`" = "enabled" ] && [ "`syscfg_get wl0_network_mode`" = "11b" ]; then
        	VAP_IF=`syscfg_get wl0_physical_ifname`
        	iwpriv $VAP_IF setwmmparams 1 0 1 4
        	iwpriv $VAP_IF setwmmparams 1 1 1 4
        	iwpriv $VAP_IF setwmmparams 1 2 1 3
        	iwpriv $VAP_IF setwmmparams 1 3 1 2
        	iwpriv $VAP_IF setwmmparams 2 0 1 10
        	iwpriv $VAP_IF setwmmparams 2 1 1 10
        	iwpriv $VAP_IF setwmmparams 2 2 1 4
        	iwpriv $VAP_IF setwmmparams 2 3 1 3
	fi
	if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
		config_scan_table_sharing_between_radios
	fi
	for INTF in $IF_STATE_CHECK_LIST; do
		wait_ap_bring_up $INTF
		if [ $? -ne 0 ]; then
			echo "${SERVICE_NAME}, Timeout, $INTF is not up!!"
		fi
	done
	sysevent set ${SERVICE_NAME}-status started
	if [ "`syscfg get smart_mode::mode`" = "1" ]; then
		if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
	    		/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release
	    		/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew
		else
	    		/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release ath8
	    		/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew ath8
		fi
	fi	
	
	CNT=`sysevent get wifi_button_cnt`
	sysevent set wifi_button_cnt 1
	if [ "" = "${CNT}" ] || [ "0" = "${CNT}" ]; then
		sysevent set wifi_button_cnt 0
	else
		CNT=`expr $CNT % 2`
		if [ "0" = "${CNT}" ]; then
			echo 'valid wifi button event' > /dev/console
			sysevent set wifi_button-status pressed
			sysevent set wifi_config_changed
			sysevent set wifi_button_cnt 1
		else
			sysevent set wifi_button_cnt 0
		fi
	fi
	return 0
}
wifi_mpsk_changed_handler()
{
	if [ -e /tmp/cedar_support ];then
		echo "${SERVICE_NAME}, detected mpsk change: reloading hostapd configuration.."
		MPSK="`syscfg get ${WIFI_PRIV_NAMESPACE}::wl0_passphrase_ext`"
		generate_mpsk_config "$MPSK" "/tmp/hostapd.mpsk"
		MYPID="`pidof hostapd`"
		if [ "$MYPID" != "" ] ; then
			echo "sending SIG_HUP to hostapd process id $MYPID"
			kill -HUP $MYPID
		else
			echo "no hostapd process found"
		fi		
	fi
}
start_hostapd()
{
	ulog wlan status "${SERVICE_NAME}, start_hostapd()"
	echo "${SERVICE_NAME}, start_hostapd()"
	USE_HOSTAPD=`syscfg_get wl_use_hostapd`
	HOSTAPD_CONF_LIST=""
	GUEST_START_LIST=""
	IF_STATE_CHECK_LIST=""
	if [ "1" = "$USE_HOSTAPD" ]; then
		WL0STATE=`syscfg_get wl0_state`
		WL1STATE=`syscfg_get wl1_state`
		WL2STATE=`syscfg_get wl2_state`
		if [ -z "$SYSEVENT_BACKHAUL_INTF" ] ; then
			SYSEVENT_BACKHAUL_INTF=`sysevent get backhaul::intf`
		fi
		if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "`syscfg get smart_mode::mode`" = "1" ] && [ "$SYSEVENT_BACKHAUL_INTF" = "ath9" ] ; then
			WL1STATE="down"
		fi
		if [ "`cat /etc/product`" = "wraith" ] && [ "`syscfg get smart_mode::mode`" = "1" ] && [ "$SYSEVENT_BACKHAUL_INTF" = "ath9" ] ; then
			WL1STATE="down"
		fi
		if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "`syscfg get smart_mode::mode`" = "1" ] && [ "$SYSEVENT_BACKHAUL_INTF" = "ath11" ] ; then
			WL2STATE="down"
		fi
		WL0SEC_MODE=`get_security_mode wl0_security_mode`
		WL1SEC_MODE=`get_security_mode wl1_security_mode`
		WL2SEC_MODE=`get_security_mode wl2_security_mode`
		if [ "up" = "$WL0STATE" ] && [ "8" != "$WL0SEC_MODE" ] && [ ! -z "`echo $PHYSICAL_IF_LIST | grep ath0`" ]; then
			IF_STATE_CHECK_LIST="ath0"
			HOSTAPD_CONF_LIST="/tmp/hostapd-ath0.conf"
			PROC_PID_LINE=`ps | grep "hostapd-mon -v -0 /tmp/hostapd-ath0.conf" | grep -v grep`
			PROC_PID=`echo $PROC_PID_LINE |  awk '{print $1}'`
			if [ -z "$PROC_PID" ]; then
				hostapd-mon -v -0 /tmp/hostapd-ath0.conf &
			fi
			iwpriv ath0 authmode 5
			ulog wlan status "${SERVICE_NAME}, add ath0 to hostapd_conf_list, starting hostapd-mon for ath0"
		fi
		if [ "up" = "$WL1STATE" ] && [ "8" != "$WL1SEC_MODE" ] && [ ! -z "`echo $PHYSICAL_IF_LIST | grep ath1`" ]; then
			IF_STATE_CHECK_LIST="`echo $IF_STATE_CHECK_LIST` ath1"
			HOSTAPD_CONF_LIST="`echo $HOSTAPD_CONF_LIST` /tmp/hostapd-ath1.conf"
			PROC_PID_LINE=`ps | grep "hostapd-mon -v -1 /tmp/hostapd-ath1.conf" | grep -v grep`
			PROC_PID=`echo $PROC_PID_LINE |  awk '{print $1}'`
			if [ -z "$PROC_PID" ]; then
				hostapd-mon -v -1 /tmp/hostapd-ath1.conf &
			fi
			iwpriv ath1 authmode 5
			ulog wlan status "${SERVICE_NAME}, add ath1 to hostapd_conf_list, starting hostapd-mon for ath1"
		fi
		if [ "up" = "$WL2STATE" ] && [ "8" != "$WL2SEC_MODE" ] && [ ! -z "`echo $PHYSICAL_IF_LIST | grep ath10`" ]; then
			IF_STATE_CHECK_LIST="`echo $IF_STATE_CHECK_LIST` ath10"
			HOSTAPD_CONF_LIST="`echo $HOSTAPD_CONF_LIST` /tmp/hostapd-ath10.conf"
			PROC_PID_LINE=`ps | grep "hostapd-mon -v -2 /tmp/hostapd-ath10.conf" | grep -v grep`
			PROC_PID=`echo $PROC_PID_LINE |  awk '{print $1}'`
			if [ -z "$PROC_PID" ]; then
				hostapd-mon -v -2 /tmp/hostapd-ath10.conf &
			fi
			iwpriv ath10 authmode 5
			ulog wlan status "${SERVICE_NAME}, add ath10 to hostapd_conf_list, starting hostapd-mon for ath1"
		fi
		GUEST_ENABLED=`grep -s "^guest_enabled" /tmp/wl0_guest_settings.conf`; GUEST_ENABLED=${GUEST_ENABLED#*: }
		if [ "1" != "$GUEST_ENABLED" ]; then
		    GUEST_ENABLED=`grep -s "^guest_enabled" /tmp/wl1_guest_settings.conf`; GUEST_ENABLED=${GUEST_ENABLED#*: }
		fi
		[ "1" != "$GUEST_ENABLED" ] && GUEST_ENABLED=0
		GUEST_WL0_ENABLED=`grep -s "^wl0_guest_enabled" /tmp/wl0_guest_settings.conf`; GUEST_WL0_ENABLED=${GUEST_WL0_ENABLED#*: }
		GUEST_WL1_ENABLED=`grep -s "^wl1_guest_enabled" /tmp/wl1_guest_settings.conf`; GUEST_WL1_ENABLED=${GUEST_WL1_ENABLED#*: }
		GUEST_WL2_ENABLED=`grep -s "^wl2_guest_enabled" /tmp/wl2_guest_settings.conf`; GUEST_WL2_ENABLED=${GUEST_WL2_ENABLED#*: }
		if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "up" = "$WL0STATE" ] && [ "1" = "$GUEST_ENABLED" ] && [ "1" = "$GUEST_WL0_ENABLED" ]; then
			GUEST_IF=`syscfg_get wl0_guest_vap`
			GUEST_START_LIST="`echo $GUEST_START_LIST` $GUEST_IF"
			CONF_FILE=/tmp/hostapd-${GUEST_IF}.conf
			if [ -f $CONF_FILE ] ; then
				HOSTAPD_CONF_LIST="`echo $HOSTAPD_CONF_LIST` $CONF_FILE"
			fi	
		fi 
		if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "up" = "$WL1STATE" ] && [ "1" = "$GUEST_ENABLED" ] && [ "1" = "$GUEST_WL1_ENABLED" ]; then
			GUEST_IF=`syscfg_get wl1_guest_vap`
			GUEST_START_LIST="`echo $GUEST_START_LIST` $GUEST_IF"
			CONF_FILE=/tmp/hostapd-${GUEST_IF}.conf
			if [ -f $CONF_FILE ] ; then
				HOSTAPD_CONF_LIST="`echo $HOSTAPD_CONF_LIST` $CONF_FILE"
			fi	
		fi
		if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "up" = "$WL2STATE" ] && [ "1" = "$GUEST_ENABLED" ] && [ "1" = "$GUEST_WL2_ENABLED" ]; then
			GUEST_IF=`syscfg_get wl2_guest_vap`
			GUEST_START_LIST="`echo $GUEST_START_LIST` $GUEST_IF"
			CONF_FILE=/tmp/hostapd-${GUEST_IF}.conf
			if [ -f $CONF_FILE ] ; then
				HOSTAPD_CONF_LIST="`echo $HOSTAPD_CONF_LIST` $CONF_FILE"
			fi	
		fi
		if [ "up" = "$WL0STATE" ] && [ "1" = "`syscfg_get smart_connect::wl0_enabled`" ]; then
			SMART_MODE=`syscfg get smart_mode::mode`
			if [ "$SMART_MODE" = "1" ] || [ "$SMART_MODE" = "2" ] ; then
				CONF24_IF=`syscfg_get smart_connect::wl0_configured_vap`
				IF_STATE_CHECK_LIST="`echo $IF_STATE_CHECK_LIST $CONF24_IF`"
				HOSTAPD_CONF_LIST="`echo $HOSTAPD_CONF_LIST` /tmp/hostapd-${CONF24_IF}.conf"
				CONF24_IF=`syscfg_get smart_connect::wl0_setup_vap`
				HOSTAPD_CONF_LIST="`echo $HOSTAPD_CONF_LIST` /tmp/hostapd-${CONF24_IF}.conf"
			fi
			if [ "$SMART_MODE" = "0" -a "`syscfg get xconnect::vap_enabled`" = "1" ];then
				CONF24_IF="ath4"
				IF_STATE_CHECK_LIST="`echo $IF_STATE_CHECK_LIST $CONF24_IF`"
				HOSTAPD_CONF_LIST="`echo $HOSTAPD_CONF_LIST` /tmp/hostapd-${CONF24_IF}.conf"
			fi
		fi
		if [ "" != "$HOSTAPD_CONF_LIST" ]; then
			ulog wlan status "${SERVICE_NAME}, starting hostapd with $HOSTAPD_CONF_LIST"
			HOSTAPD_DEBUG=`syscfg_get wl_hostapd_debug`
			if [ ! -z "$HOSTAPD_DEBUG" ]; then
				HOSTAPD_CONF_LIST="`echo $HOSTAPD_DEBUG` `echo $HOSTAPD_CONF_LIST`"
			fi
			sysevent set hostapd_status start
			if [ "`syscfg get ${WIFI_PRIV_NAMESPACE}::enabled`" = "1" ] && [ -e /tmp/cedar_support ]; then
				AUTH_PASS="`syscfg get smart_connect::configured_vap_passphrase`"
				hostapd $HOSTAPD_CONF_LIST -p $AUTH_PASS -C &
			else
				hostapd $HOSTAPD_CONF_LIST &
			fi
			echo "${SERVICE_NAME}, start hostapd (`date`)" > /dev/console
			SLEEP_WAIT=0
			SLEEP_TIMEOUT=60
			SLEEP_INCREMENT=5
			HOSTAPD_DEBUG echo "${SERVICE_NAME}: Waiting ${SLEEP_TIMEOUT}s for hostapd_status == 'running'" > /dev/console
			while [ "$SLEEP_WAIT" -lt $SLEEP_TIMEOUT ] && [ "running" != "$(hostapd_status)" ]
			do
				SLEEP_WAIT=`expr $SLEEP_WAIT + $SLEEP_INCREMENT`
				sleep $SLEEP_INCREMENT
				HOSTAPD_DEBUG echo "${SERVICE_NAME} has waited ${SLEEP_WAIT}s; hostapd_status: $(hostapd_status)" > /dev/console
			done
			if [ "running" != "$(hostapd_status)" ] ; then
				echo "${SERVICE_NAME}, !!!!!!Serious!!!!!! hostapd not running correctly (`date`)" > /dev/console
				reboot
				exit
			fi
			HOSTAPD_DEBUG echo "${SERVICE_NAME}: hostapd_status is 'running' after ${SLEEP_WAIT}s" > /dev/console
			sysevent set hostapd_status started
		fi
		if [ "up" = "$WL0STATE" ] && [ "0" = "$WL0SEC_MODE" ] && [ ! -z "`echo $PHYSICAL_IF_LIST | grep ath0`" ]; then
			iwconfig ath0 key off
		fi
		if [ "up" = "$WL1STATE" ] && [ "0" = "$WL1SEC_MODE" ] && [ ! -z "`echo $PHYSICAL_IF_LIST | grep ath1`" ]; then
			iwconfig ath1 key off
		fi
		if [ "up" = "$WL2STATE" ] && [ "0" = "$WL2SEC_MODE" ] && [ ! -z "`echo $PHYSICAL_IF_LIST | grep ath10`" ]; then
			iwconfig ath10 key off
		fi
		if [ "1" = "$GUEST_ENABLED" ] && [ "1" = "$GUEST_WL1_ENABLED" ] ; then
			GUEST_VAP=`syscfg_get wl1_guest_vap`
			SYSCFG_CHANNEL=`syscfg_get wl1_channel`
			if [ "auto" = $SYSCFG_CHANNEL -o "0" = $SYSCFG_CHANNEL ] ; then
				iwconfig $GUEST_VAP freq 0
			else
				iwconfig $GUEST_VAP channel `expr $SYSCFG_CHANNEL`
			fi
		fi
		if [ "1" = "$GUEST_ENABLED" ] && [ "1" = "$GUEST_WL2_ENABLED" ] ; then
			GUEST_VAP=`syscfg_get wl2_guest_vap`
			SYSCFG_CHANNEL=`syscfg_get wl2_channel`
			if [ "auto" = $SYSCFG_CHANNEL -o "0" = $SYSCFG_CHANNEL ] ; then
				iwconfig $GUEST_VAP freq 0
			else
				iwconfig $GUEST_VAP channel `expr $SYSCFG_CHANNEL`
			fi
		fi
		if [ "1" = "$GUEST_ENABLED" ] && [ "1" = "$GUEST_WL0_ENABLED" ] ; then 
			GUEST_VAP=`syscfg_get wl0_guest_vap`
			SYSCFG_CHANNEL=`syscfg_get wl0_channel`
			if [ "auto" = $SYSCFG_CHANNEL -o "0" = $SYSCFG_CHANNEL ] ; then
				iwconfig $GUEST_VAP freq 0
			else
				iwconfig $GUEST_VAP channel `expr $SYSCFG_CHANNEL`
			fi
		fi
		IF_STATE_CHECK_LIST="`echo $IF_STATE_CHECK_LIST $GUEST_START_LIST`"
	fi
}
stop_hostapd()
{
	PHY_IF=$1
	killall hostapd > /dev/null 2>&1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	VIR_IF=`syscfg_get ${SYSCFG_INDEX}_user_vap`
	if [ -z "$VIR_IF" ]; then
		return 1
	fi
	get_wl_index $PHY_IF
	WL_INDEX=$?			 
	PROC_PID_LINE=`ps | grep "hostapd-mon -v -${WL_INDEX} /tmp/hostapd-${VIR_IF}.conf" | grep -v grep`
	PROC_PID=`echo $PROC_PID_LINE |  awk '{print $1}'`
	if [ -n "$PROC_PID" ]; then
		echo "${SERVICE_NAME}, stop process: ${PROC_PID_LINE} on ${VIR_IF}"
		kill -9 $PROC_PID > /dev/null 2>&1
	fi
	CONF_FILE=/tmp/hostapd-$VIR_IF.conf
	if [ -f $CONF_FILE ]; then
		mv $CONF_FILE ${CONF_FILE}.bak
	fi
	rm -f /tmp/hostapd-$VIR_IF.log		
	return 0	
}
wifi_smart_connect_setup_stop()
{
	ulog wlan status "${SERVICE_NAME}, smart_connect_setup-stop"
	echo "${SERVICE_NAME}, smart_connect_setup-stop"
    if [ "`syscfg get smart_mode::mode`" = "2" ]; then
		sysevent set smart_connect::setup_status READY
	fi
	for PHY_IF in $PHYSICAL_IF_LIST; do
		wifi_smart_setup_stop $PHY_IF
	done
}
ulog wlan status "${SERVICE_NAME}, sysevent received: $1"
service_init 
case "$1" in
	wifi-start)
		service_start
		;;
	wifi-stop)
		service_stop
		;;
	wifi-restart)
		service_restart
		;;
	wifi_user-start)
		if [ "`sysevent get ${SERVICE_NAME}-status`" = "started" ]; then
			wifi_user_start $2
		fi
		;;
	wifi_user-stop)
		if [ "`sysevent get ${SERVICE_NAME}-status`" = "started" ]; then
			wifi_user_stop $2
		fi
		;;
	wifi_user-restart)
		if [ "`sysevent get ${SERVICE_NAME}-status`" = "started" ]; then
			wifi_user_restart $2
		fi
		;;
	wifi_guest-start)
		if [ "`sysevent get ${SERVICE_NAME}-status`" = "started" ]; then
			wifi_guest_start $2
		fi
		;;
	wifi_guest-stop)
		if [ "`sysevent get ${SERVICE_NAME}-status`" = "started" ]; then
			wifi_guest_stop $2
		fi
		;;
	wifi_guest-restart)
		if [ "`sysevent get ${SERVICE_NAME}-status`" = "started" ]; then
			if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
				killall hostapd > /dev/null 2>&1
			fi
			if [ "$2" = "NULL" ]; then
				for PHY_IF in $PHYSICAL_IF_LIST; do
					wifi_guest_restart $PHY_IF
				done
			else
				wifi_guest_restart $2
			fi
			if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
				start_hostapd
				wifi_smart_connect_setup_stop
			fi
		fi
		;;
	wifi_config_changed)
		wifi_config_changed_handler $2
		;;
	lan-started)
		service_start
		;;
	mac_filter_changed)
		wifi_config_changed_handler
		;;
	master::ip)
		if [ "`syscfg get smart_mode::mode`" = "1" ] ; then
			if [ "`sysevent get record_master_ip`" != "$2" ] ; then
				echo "${SERVICE_NAME}, needs restart hostapd when Master change IP/subnet $2" > /dev/console
				sysevent set record_master_ip "$2"
				sysevent set smart_connect::backhaul_switch 1
				wifi_config_changed_handler
			else
				echo "${SERVICE_NAME}, no need to handle wifi-config-changed for event '$1 $2'" > /dev/console
			fi
		fi
		;;
	*)
	echo "Usage: service-${SERVICE_NAME} [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		;;
esac
syscfg_commit
unlock $LOCK_FILE
