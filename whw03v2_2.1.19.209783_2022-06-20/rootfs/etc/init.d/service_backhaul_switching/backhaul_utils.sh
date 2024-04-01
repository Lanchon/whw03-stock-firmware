#!/bin/sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
bridge_intf="`syscfg get switch::bridge_1::ifname`"
lan_ifname=$(syscfg get lan_ifname)
svap_vlan_id="$(syscfg get svap_vlan_id)"
hk_ifname="$(syscfg get lrhk::ifname)"
hk_vlan_id="$(syscfg get lrhk::vlan_id)"
svap_lan_ifname="$(syscfg get svap_lan_ifname)"
guest_vlan_id="$(syscfg get guest_vlan_id)"
guest_lan_ifname="$(syscfg get guest_lan_ifname)"        
guest_enabled="$(syscfg get guest_enabled)"
smart_mode="$(syscfg get smart_mode::mode)"
ip_connection_down ()
{
    master_ip="$(sysevent get master::ip)"
    if [ "${master_ip}" == "" ] ; then
        master_ip="$(sysevent get default_router)"
    fi
    arping -I ${lan_ifname} -f -w 1 ${master_ip}
    if [ "$?" = "0" ]; then
        return 1
    fi
    return 0
}
wifi_config_sync () {
    ulog smart_connect status "Try to do WiFi Configure Sync...."
    echo "Try to do WiFi Configure Sync...."
    /etc/init.d/service_wifi/smart_connect_client_utils.sh get_server_primary_info wired
    RET=$?
    if [ "1" = "$RET" ];then
        echo "Succeed on WiFi Configure Sync...."
        syscfg commit
	/etc/init.d/service_wifi/service_wifi.sh wifi_config_changed
    fi
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
wifi_monitor_is_running () {
    PROC_PID_LINE="`ps -w | grep "smart_connect_client_monitor" | grep -v grep`"
    PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
    if [ -z "$PROC_PID" ]; then
        return 0
    else
        return 1
    fi
}
wifi_backhaul_interface_down ()
{
    SVAP_BR=$(syscfg get svap_lan_ifname)
    GA_BR=$(syscfg get guest_lan_ifname)
    BR=$(syscfg get lan_ifname)
    ifconfig|grep -q ath8
    if [ $? = 0 ]; then
        killall -9 wpa_supplicant
        sleep 2
        ifconfig ath8 down
        brctl delif $SVAP_BR ath8
        sysevent set wifi_sta_up 0
    fi
    
    ifconfig|grep -q ath9
    if [ $? = 0 ]; then
        killall -9 wpa_supplicant
        sleep 2
        ifconfig ath9 down
        brctl delif $SVAP_BR ath9.4
        brctl delif $GA_BR ath9.3
        brctl delif $BR ath9
        sysevent set wifi_sta_up 0
    fi
    ifconfig|grep -q ath11
    if [ $? = 0 ]; then
        killall -9 wpa_supplicant
        sleep 2
        ifconfig ath11 down
        brctl delif $SVAP_BR ath11.4
        brctl delif $GA_BR ath11.3
        brctl delif $BR ath11
        sysevent set wifi_sta_up 0
    fi
}
wifi_backhaul_disconnect ()
{
	echo "Wireless backhaul disconnect"
    ulog smart_connect status "Wireless backhaul disconnect"
	stop_smart_connect_connection_monitor
	wifi_backhaul_interface_down
	BACKHAUL_INTERFACE=$(sysevent get backhaul::intf)
	if [ "`echo $BACKHAUL_INTERFACE | grep ath`" ] ; then
	   sysevent set backhaul::status down
	fi
}
wifi_backhaul_connect ()
{
	if [ "$(sysevent get wifi-status)" != "started" ] ; then
	    echo "Wireless backhaul connect is canceled, as wifi-status is not started, will start later..."
        ulog smart_connect status "Wireless backhaul connect is canceled, as wifi-status is not started, will start later..."
        return 0
	fi
	echo "Wireless backhaul connect"
    ulog smart_connect status "Wireless backhaul connect"
    wired_backhaul_disconnect
	start_smart_connect_connection_monitor
    if [ "$(sysevent get backhaul::status)" == "up" ] ; then
        add_vlan_to_backhaul "$(sysevent get backhaul::intf)" "$svap_vlan_id" "$svap_lan_ifname"
        if [ "$guest_enabled" = "1" ] ; then
            add_vlan_to_backhaul "$(sysevent get backhaul::intf)" "$guest_vlan_id" "$guest_lan_ifname"
        fi   
        if [ -n "$hk_ifname" ] ; then
            add_vlan_to_backhaul "$(sysevent get backhaul::intf)" "$hk_vlan_id" "$hk_ifname"
        fi 
    fi
}
wired_backhaul_disconnect ()
{
    BACKHAUL_INTERFACE=$(sysevent get backhaul::intf)
    if [ "`echo $BACKHAUL_INTERFACE | grep eth`" ]; then
        sysevent set backhaul::status down
    fi	
}
wired_backhaul_connect ()
{
	current_backhaul="$(sysevent get backhaul::intf)"
	current_backhaul_status="$(sysevent get backhaul::status)"
	   
	uplink_intf=$1
	wifi_monitor_is_running
	wifi_is_running=$?
	if [ "$wifi_is_running" = "1" ] ; then
        	wait_till_end_state "wifi"
        	if [ "$(sysevent get backhaul::media)" = "1"  ] ; then
        	    wifi_backhaul_disconnect
        	else
        	    echo "BM is $(sysevent get backhaul::media), will keep wireless backhaul"
        	    ulog smart_connect status "BM is $(sysevent get backhaul::media), will keep wireless backhaul"
        	    return
        	fi
	else
	    wifi_backhaul_interface_down
	fi
    sysevent set backhaul::preferred_bssid "00:00:00:00:00:00"
    if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "DONE" != "`sysevent get smart_connect::setup_status`" ];then
        sysevent set smart_connect::setup_status DONE
    fi
	wan_ip="$(sysevent get ipv4_wan_ipaddr)"
	if [ "${wan_ip}" == "" -o "${wan_ip}" == "0.0.0.0" ] ; then
		/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-release
		sleep 2
		/etc/init.d/service_bridge/dhcp_link.sh dhcp_client-renew
	fi
	if [ "$current_backhaul" == "$bridge_intf" ]  && [ "$current_backhaul_status" == "up" ] ; then
		echo "Wired backhaul is already connected!"
		return
	fi
	echo "Wired backhaul connect"
	ulog smart_connect status "Wired backhaul connect"
    
	ap_intf=$(check_ap "$(sysevent get backhaul::intf)")
	sysevent set backhaul::pre_ap_intf "$ap_intf"
	if [ "`sysevent get backhaul::intf`" = "ath9" -o "`sysevent get backhaul::intf`" = "ath11" ]; then
		sysevent set smart_connect::backhaul_switch 1
	fi
	sysevent set backhaul::intf ${bridge_intf}
	sysevent set backhaul::status up
	wifi_config_sync
}
do_backhaul_check ()
{
    local backhaul_media="$(sysevent get backhaul::media)"
    local uplink_intf="$(sysevent get lldp::root_intf)"
    if [ "${backhaul_media}" = "2" ] ; then
        wifi_backhaul_connect
    elif [ "${backhaul_media}" = "1" ] ; then
        sysevent set dhcp_client-renew
        sysevent set setup_dhcp_client-renew
        wired_backhaul_connect ${bridge_intf}
    else
    	wifi_backhaul_connect
    fi
}
stop_backhaul_connect ()
{
    wired_backhaul_disconnect
    wifi_backhaul_disconnect
}
initial_vlan_for_linkup_interface ()
{
    if [ "$(sysevent get ETH::port_1_status)" == "up" ] || [ "$(sysevent get ETH::port_2_status)" == "up" ] || [ "$(sysevent get ETH::port_3_status)" == "up" ] || [ "$(sysevent get ETH::port_4_status)" == "up" ] || [ "$(sysevent get ETH::port_5_status)" == "up" ]; then
        if [ "$guest_enabled" = "1" ] ; then
            add_vlan_to_backhaul "${bridge_intf}" "$guest_vlan_id" "$guest_lan_ifname"
        fi         
        add_vlan_to_backhaul "${bridge_intf}" "$svap_vlan_id" "$svap_lan_ifname"
        if [ -n "$hk_ifname" ] ; then
            add_vlan_to_backhaul "$(sysevent get backhaul::intf)" "$hk_vlan_id" "$hk_ifname"
        fi
    fi 
}
