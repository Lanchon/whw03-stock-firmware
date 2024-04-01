#!/bin/sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_user.sh
wifi_smart_setup_start()
{
	SMART_MODE=`syscfg get smart_mode::mode`
	if [ ! $SMART_MODE ] || [ "$SMART_MODE" = "0" ] ; then
		echo "${SERVICE_NAME}, smart::mode is unconfigured do not start smart connect setup and config wifi" > /dev/console
		ulog wlan status "${SERVICE_NAME}, smart::mode is unconfigured do not start smart connect setup and config wifi"
        	return 1
	fi
	PHY_IF=$1
	IF_UP=$2
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${WIFI_SMART_SETUP} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_SMART_SETUP} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	wait_till_end_state "$WIFI_SMART_SETUP"_"$PHY_IF"
	ulog wlan status "${SERVICE_NAME}, wifi_smart_setup_start($PHY_IF)"
	echo "${SERVICE_NAME}, wifi_smart_setup_start($PHY_IF)"
	SETUP_VAP=`syscfg_get smart_connect::${SYSCFG_INDEX}_setup_vap`
	SMART_CONNECT_ENABLED=`syscfg_get smart_connect::server_enabled`
	if [ "$SMART_CONNECT_ENABLED" != "1" ]; then
		echo "${SERVICE_NAME}, $WIFI_SMART_CONNECT is disabled, do not start setup vap"
		ulog wlan status "${SERVICE_NAME}, $WIFI_SMART_CONNECT is disabled, do not start setup vap"
		return 1
	fi
	USER_STATE=`syscfg_get "$SYSCFG_INDEX"_state`
	if  [ "$USER_STATE" = "down" ]; then
		ulog wlan status "${SERVICE_NAME}, user vap is down, do not start setup vap"
		return 1
	fi
	if [ "`syscfg_get smart_connect::${SYSCFG_INDEX}_enabled`" != "1" ]; then
		echo "${SERVICE_NAME}, smart connect is not enabled for $PHY_IF"
		return 1
	fi
	STATUS=`sysevent get "$WIFI_SMART_SETUP"_"$PHY_IF"-status`
	if [ "started" = "$STATUS" ] || [ "starting" = "$STATUS" ] ; then
		echo "${SERVICE_NAME}, $WIFI_SMART_SETUP is already starting/started, ignore the request"
		ulog wlan status "${SERVICE_NAME}, $WIFI_SMART_SETUP is already starting/started, ignore the request"
		return 1
	fi
	sysevent set "$WIFI_SMART_SETUP"_"$PHY_IF"-status starting
	setup_vap_start $PHY_IF
	if [ "$IF_UP" = "up" ]; then
		SETUP_VAP_STATE=`ifconfig $SETUP_VAP | grep "UP" | awk {'print $1'}`
		if [ "$SETUP_VAP_STATE" != "UP" ] ; then
			hostapd_cli -i $SETUP_VAP -p /var/run/hostapd enable
		fi
	fi
	sysevent set ${SYSCFG_INDEX}_setup_status "up"
	ulog ${SERVICE_NAME} status "${SERVICE_NAME}, smart connect setup AP: $SETUP_VAP is up"
	echo "${SERVICE_NAME}, smart connect setup AP: $SETUP_VAP is up " > /dev/console
	sysevent set "$WIFI_SMART_SETUP"_"$PHY_IF"-status started
	return 0
}
wifi_smart_setup_restart()
{
	PHY_IF=$1
	echo "${SERVICE_NAME}, wifi_smart_setup_restart($PHY_IF)"
	wifi_smart_setup_stop $PHY_IF
	wifi_smart_setup_start $PHY_IF
	return 0
}
setup_vap_start()
{
	PHY_IF=$1
	ulog wlan status "${SERVICE_NAME}, setup_vap_start($PHY_IF) "
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	SMART_SETUP_VAP=`syscfg_get smart_connect::${SYSCFG_INDEX}_setup_vap`
	if [ "`cat /etc/product`" = "wraith" ] ; then
	   SMART_SETUP_BRIDGE=`syscfg_get lan_ifname`
	else
	    SMART_SETUP_BRIDGE=`syscfg_get svap_lan_ifname`
	fi
	INT=`get_phy_interface_name_from_vap "$PHY_IF"`
	if [ ! -e /sys/class/net/$SMART_SETUP_VAP ]; then
		wlanconfig $SMART_SETUP_VAP create wlandev $INT wlanmode ap
	fi
	/sbin/ifconfig $SMART_SETUP_VAP txqueuelen 1000
	add_interface_to_bridge $SMART_SETUP_VAP $SMART_SETUP_BRIDGE
	configure_smart_setup $PHY_IF
	return 0
}
configure_smart_connect_bridge()
{
	SETUP_BRIDGE=$1
	brctl addbr $SETUP_BRIDGE
	brctl setfd $SETUP_BRIDGE 0
	brctl stp $SETUP_BRIDGE off
	ip link set $SETUP_BRIDGE allmulticast on
	ifconfig $SETUP_BRIDGE up
	if [ "`syscfg get smart_mode::mode`" == "2" ]; then
	    SETUP_VAP_IP=`syscfg_get ldal_wl_setup_vap_ipaddr`
	    ifconfig $SETUP_BRIDGE $SETUP_VAP_IP
	fi
}
configure_smart_setup()
{
	PHY_IF=$1
	ulog wlan status "${SERVICE_NAME}, configure_smart_setup($PHY_IF) "
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	SETUP_VAP=`syscfg_get smart_connect::${SYSCFG_INDEX}_setup_vap`
	SETUP_SSID=`syscfg_get smart_connect::setup_vap_ssid`
	iwconfig $SETUP_VAP essid "$SETUP_SSID"
	iwpriv $SETUP_VAP hide_ssid 0
	set_countryie $SETUP_VAP
	if [ "wl0" = "$SYSCFG_INDEX" ]; then
		set_11ngvhtintop $SETUP_VAP
	fi
	CONF_PASSPHRASE="wpa_passphrase=`syscfg_get smart_connect::setup_vap_ssid`"
	HOSTAPD_CONF="/tmp/hostapd-$SETUP_VAP.conf"
	generate_hostapd_config $SETUP_VAP "$SETUP_SSID" "$CONF_PASSPHRASE" "2" "aes" "" "" ""> $HOSTAPD_CONF
	generate_hostapd_IE_section $WIFI_IE_SC_SETUP >> $HOSTAPD_CONF
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		iwpriv $SETUP_VAP wds 1
	fi
	iwpriv $SETUP_VAP shortgi 1
	return 0
}
wifi_smart_configured_start()
{
	PHY_IF=$1
	IF_UP=$2
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	SMART_MODE=`syscfg get smart_mode::mode`
	if [ ! $SMART_MODE ] || [ "$SMART_MODE" = "0" ] ; then
		echo "${SERVICE_NAME}, smart::mode is unconfigured do not start smart connect setup and config wifi" > /dev/console
		ulog wlan status "${SERVICE_NAME}, smart::mode is unconfigured do not start smart connect setup and config wifi"
        	return 1
	fi
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${WIFI_SMART_CONFIGURED} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_SMART_CONFIGURED} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	EVENT="$WIFI_SMART_CONFIGURED"_"$PHY_IF"
	wait_till_end_state $EVENT
	ulog wlan status "${SERVICE_NAME}, wifi_smart_configured_start($PHY_IF)"
	echo "${SERVICE_NAME}, wifi_smart_configured_start($PHY_IF)"
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	CONFIGURED_VAP=`syscfg_get smart_connect::${SYSCFG_INDEX}_configured_vap`
	SMART_CONNECT_ENABLED=`syscfg_get smart_connect::server_enabled`
	if [ "$SMART_CONNECT_ENABLED" != "1" ]; then
		echo "${SERVICE_NAME}, $WIFI_SMART_CONNECT is disabled, do not start configured vap"
		ulog wlan status "${SERVICE_NAME}, $WIFI_SMART_CONNECT is disabled, do not start setup vap"
		return 1
	fi
	USER_STATE=`syscfg_get "$SYSCFG_INDEX"_state`
	if  [ "$USER_STATE" = "down" ]; then
		ulog wlan status "${SERVICE_NAME}, user vap is down, do not start configured vap"
		return 1
	fi
	if [ "`syscfg_get smart_connect::${SYSCFG_INDEX}_enabled`" != "1" ]; then
		echo "${SERVICE_NAME}, smart connect is not enabled for $PHY_IF"
		return 1
	fi
	STATUS=`sysevent get $EVENT-status`
	if [ "started" = "$STATUS" ] || [ "starting" = "$STATUS" ] ; then
		echo "${SERVICE_NAME}, $WIFI_SMART_CONFIGURED is already starting/started, ignore the request"
		ulog wlan status "${SERVICE_NAME}, $WIFI_SMART_CONFIGURED is already starting/started, ignore the request"
		return 1
	fi
	sysevent set $EVENT-status starting
	configured_vap_start $PHY_IF
	setup_vap_start $PHY_IF
	if [ "$IF_UP" = "up" ]; then
		CONFIGURED_VAP_STATE=`ifconfig $CONFIGURED_VAP | grep "UP" | awk {'print $1'}`
		if [ "$CONFIGURED_VAP_STATE" != "UP" ] ; then
			hostapd_cli -i $CONFIGURED_VAP -p /var/run/hostapd enable
		fi
	fi
	sysevent set ${SYSCFG_INDEX}_configured_status "up"
	ulog ${SERVICE_NAME} status "${SERVICE_NAME}, smart connect configured AP: $CONFIGURED_VAP is up"
	echo "${SERVICE_NAME}, smart connect configured AP: $CONFIGURED_VAP is up " > /dev/console
	sysevent set $EVENT-status started
	return 0
}
wifi_smart_configured_stop()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${WIFI_SMART_CONFIGURED} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_SMART_CONFIGURED} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	wait_till_end_state "$WIFI_SMART_CONFIGURED"_"$PHY_IF"
	ulog wlan status "${SERVICE_NAME}, wifi_smart_configured_stop($PHY_IF)"
	echo "${SERVICE_NAME}, wifi_smart_configured_stop($PHY_IF)"
	STATUS=`sysevent get "$WIFI_SMART_CONFIGURED"_"$PHY_IF"-status`
	if [ "stopped" = "$STATUS" ] || [ "stopping" = "$STATUS" ] || [ -z "$STATUS" ]; then
		echo "${SERVICE_NAME}, "$WIFI_SMART_CONFIGURED"_"$PHY_IF" is already stopping/stopped, ignore this request"
		ulog wlan status "${SERVICE_NAME}, "$WIFI_SMART_CONFIGURED"_"$PHY_IF" is already stopping/stopped, ignore this request"
		return 1
	fi
	sysevent set "$WIFI_SMART_CONFIGURED"_"$PHY_IF"-status stopping
	configured_vap_stop $PHY_IF
	sysevent set ${SYSCFG_INDEX}_configured_status "down"
	sysevent set "$WIFI_SMART_CONFIGURED"_"$PHY_IF"-status stopped
	return 0
}
wifi_smart_setup_stop()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	SETUP_IF=`syscfg_get smart_connect::${SYSCFG_INDEX}_setup_vap`
	if [ "$SETUP_IF" = "" ]; then
		return 1
	fi
	if [ "`cat /etc/product`" = "wraith" ] ; then
	    BR_IFNAME=`syscfg_get lan_ifname`
	else
	    BR_IFNAME=`syscfg_get svap_lan_ifname`
	fi
	sysevent set "$WIFI_SMART_SETUP"_"$PHY_IF"-status stopping
	if [ "" != "`ifconfig $SETUP_IF 2>/dev/null`" ];then
		set_driver_mac_filter_disabled $SETUP_IF
		delete_interface_from_bridge $SETUP_IF $BR_IFNAME
		hostapd_cli -i $SETUP_IF -p /var/run/hostapd disable
	fi
	sysevent set "$WIFI_SMART_SETUP"_"$PHY_IF"-status stopped
	sysevent set ${SYSCFG_INDEX}_setup_status "down"
	ulog ${SERVICE_NAME} status "${SERVICE_NAME}, smart connect setup AP: $SETUP_IF is down"
	echo "${SERVICE_NAME}, smart connect setup AP: $SETUP_IF is down " > /dev/console
	PROC_PID_LINE=`ps -w | grep "smart_connect_setup.sh" | grep -v grep`
	PROC_PID=`echo $PROC_PID_LINE |  awk '{print $1}'`
	if [ -n "$PROC_PID" ]; then
		echo "${SERVICE_NAME}, stop process: ${PROC_PID_LINE} on ${VIR_IF}"
		kill $PROC_PID > /dev/null 2>&1
	fi
	return 0
}
wifi_smart_configured_restart()
{
	PHY_IF=$1
	echo "${SERVICE_NAME}, wifi_smart_configured_restart($PHY_IF)"
	wifi_smart_configured_stop $PHY_IF
	wifi_smart_configured_start $PHY_IF
	return 0
}
configured_vap_start()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	CONF_IF=`syscfg_get smart_connect::${SYSCFG_INDEX}_configured_vap`
	if [ "`cat /etc/product`" = "wraith" ] ; then
	    BR_IFNAME=`syscfg_get lan_ifname`
	else
	    BR_IFNAME=`syscfg_get svap_lan_ifname`
	fi
	INT=`get_phy_interface_name_from_vap "$PHY_IF"`
	if [ ! -e /sys/class/net/$CONF_IF ]; then
		wlanconfig $CONF_IF create wlandev $INT wlanmode ap
	fi
	/sbin/ifconfig $CONF_IF txqueuelen 1000
	add_interface_to_bridge $CONF_IF $BR_IFNAME
	CONF_SSID=`syscfg_get smart_connect::configured_vap_ssid`
	iwconfig $CONF_IF essid $CONF_SSID
	HOSTAPD_CONF="/tmp/hostapd-$CONF_IF.conf"
	CONF_PASSPHRASE="wpa_passphrase=`syscfg_get smart_connect::configured_vap_passphrase`"
	generate_hostapd_config $CONF_IF "$CONF_SSID" "$CONF_PASSPHRASE" "2" "aes" "" "" ""> $HOSTAPD_CONF
	driver_update_extra_virtual_settings $PHY_IF $CONF_IF
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		iwpriv $CONF_IF wds 1
	fi
	iwpriv $CONF_IF hide_ssid 1
	iwpriv $CONF_IF shortgi 1
}
configured_vap_stop()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ "wl0" != "$SYSCFG_INDEX" ]; then
		return 1
	fi
	CONF_IF=`syscfg_get smart_connect::${SYSCFG_INDEX}_configured_vap`
	if [ "`cat /etc/product`" = "wraith" ] ; then
	    BR_IFNAME=`syscfg_get lan_ifname`
	else
	    BR_IFNAME=`syscfg_get svap_lan_ifname`
	fi
	set_driver_mac_filter_disabled $CONF_IF
	delete_interface_from_bridge $CONF_IF $BR_IFNAME
	hostapd_cli -i $CONF_IF -p /var/run/hostapd disable
}
start_lsc_server()
{
    BIN=lsc_server
    SERVER=/usr/sbin/${BIN}
    PID_FILE=/var/run/${BIN}.pid
    PMON=/etc/init.d/pmon.sh
    SMART_CONNECT_SERVICE_NAME=smart_connect
	SMART_CONNECT_ENABLED=`syscfg get smart_connect::server_enabled`
	if [ "$SMART_CONNECT_ENABLED" != "1" ]; then
		echo "${SERVICE_NAME}, smart connect server is disabled, do not start lsc_server"
		ulog lan status "${SERVICE_NAME}, smart connect server is disabled, do not start lsc_server"
		return 1
	fi
	PROC_PID_LINE=`ps | grep "lsc_server" | grep -v grep`
	PROC_PID=`echo $PROC_PID_LINE |  awk '{print $1}'`
	if [ -z "$PROC_PID" ]; then
		ulog wlan status "${SERVICE_NAME}, starting lsc_server as daemon"
		echo "${SERVICE_NAME}, starting lsc_server as daemon(`date`)"
        rm -f $PID_FILE
        $SERVER -d 
        pidof $BIN > $PID_FILE
        $PMON setproc ${SMART_CONNECT_SERVICE_NAME} $BIN $PID_FILE "/etc/init.d/service_smartconnect.sh ${SMART_CONNECT_SERVICE_NAME}-restart"
	fi
}
stop_lsc_server()
{
	PROC_PID_LINE="`ps -w | grep "lsc_server" | grep -v grep`"
	if [ ! -z "$PROC_PID_LINE" ]; then
			echo "${SERVICE_NAME}, stop lsc_server (`date`)"
			killall -9 lsc_server
	fi
}
test_setup()
{
	if [ "1" != "`syscfg_get smart_connect::server_enabled`" ]; then
		return 0
	fi
	if [ "" = "`syscfg_get smart_connect::configured_vap_ssid`" ]; then
		SSID="`syscfg_get tc_vap_ssid`"
		PASSPHRASE="`syscfg_get tc_vap_passphrase`"
		syscfg_set smart_connect::configured_vap_ssid "$SSID"
		syscfg_set smart_connect::configured_vap_passphrase "$PASSPHRASE"
	fi
	if [ "" = "`syscfg_get smart_connect::setup_vap_ssid`" ]; then
		DEFAULTSSID=`syscfg_get wl_default_ssid`
		SETUP_VAP_SSID="${DEFAULTSSID}-SCS"
		syscfg_set smart_connect::setup_vap_ssid "$SETUP_VAP_SSID"
	fi
}
