#!/bin/sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_user.sh
private_network_start()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${private_network} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${private_network} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	EVENT="$private_network"_"$PHY_IF"
	PRIVATE_VAP=`syscfg_get ${WIFI_PRIV_NAMESPACE}::${SYSCFG_INDEX}_vap`
	wait_till_end_state $EVENT
	ulog wlan status "${SERVICE_NAME}, private_network_start($PHY_IF)"
	echo "${SERVICE_NAME}, private_network_start($PHY_IF)"
	if [ "`syscfg get ${WIFI_PRIV_NAMESPACE}::enabled`" != "1" ]; then
		echo "${SERVICE_NAME}, private network is disabled, do not start private_network vap"
		ulog wlan status "${SERVICE_NAME}, private network is disabled, do not start private_network vap"
		return 1
	fi
	USER_STATE=`syscfg_get "$SYSCFG_INDEX"_state`
	if  [ "$USER_STATE" = "down" ]; then
		ulog wlan status "${SERVICE_NAME}, user vap is down, do not start private vap"
		return 1
	fi
	STATUS=`sysevent get $EVENT-status`
	if [ "started" = "$STATUS" ] || [ "starting" = "$STATUS" ] ; then
		echo "${SERVICE_NAME}, $private_network is already starting/started, ignore the request"
		ulog wlan status "${SERVICE_NAME}, $private_network is already starting/started, ignore the request"
		return 1
	fi
	sysevent set $EVENT-status starting
	private_vap_start $PHY_IF
	sysevent set ${SYSCFG_INDEX}_private_status "up"
	ulog ${SERVICE_NAME} status "${SERVICE_NAME}, private network private AP: $PRIVATE_VAP is up"
	echo "${SERVICE_NAME}, private network private AP: $PRIVATE_VAP is up " > /dev/console
	sysevent set $EVENT-status started
	return 0
}
private_network_stop()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${private_network} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${private_network} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	wait_till_end_state "$private_network"_"$PHY_IF"
	ulog wlan status "${SERVICE_NAME}, private_network_stop($PHY_IF)"
	echo "${SERVICE_NAME}, private_network_stop($PHY_IF)"
	STATUS=`sysevent get "$private_network"_"$PHY_IF"-status`
	if [ "stopped" = "$STATUS" ] || [ "stopping" = "$STATUS" ] || [ -z "$STATUS" ]; then
		echo "${SERVICE_NAME}, "$private_network"_"$PHY_IF" is already stopping/stopped, ignore this request"
		ulog wlan status "${SERVICE_NAME}, "$private_network"_"$PHY_IF" is already stopping/stopped, ignore this request"
		return 1
	fi
	sysevent set "$private_network"_"$PHY_IF"-status stopping
	CONF_IF=`syscfg_get ${WIFI_PRIV_NAMESPACE}::${SYSCFG_INDEX}_vap`
	BR_IFNAME=`syscfg_get ${WIFI_PRIV_NAMESPACE}::ifname`
	set_driver_mac_filter_disabled $CONF_IF
	delete_interface_from_bridge $CONF_IF $BR_IFNAME
	ifconfig $CONF_IF down
	
	sysevent set ${SYSCFG_INDEX}_private_status "down"
	sysevent set "$private_network"_"$PHY_IF"-status stopped
	return 0
}
private_network_restart()
{
	PHY_IF=$1
	echo "${SERVICE_NAME}, private_network_restart($PHY_IF)"
	private_network_stop $PHY_IF
	private_network_start $PHY_IF
	return 0
}
private_vap_start()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	CONF_IF=`syscfg_get ${WIFI_PRIV_NAMESPACE}::${SYSCFG_INDEX}_vap`
	BR_IFNAME=`syscfg_get ${WIFI_PRIV_NAMESPACE}::ifname`
	INT=`get_phy_interface_name_from_vap "$PHY_IF"`
	wlanconfig $CONF_IF create wlandev $INT wlanmode ap
	/sbin/ifconfig $CONF_IF txqueuelen 1000
	add_interface_to_bridge $CONF_IF $BR_IFNAME
	CONF_SSID=`syscfg_get ${WIFI_PRIV_NAMESPACE}::"$SYSCFG_INDEX"_ssid_ext`
	iwconfig $CONF_IF essid $CONF_SSID
	HOSTAPD_CONF="/tmp/hostapd-$CONF_IF.conf"
	CONF_PASSPHRASE="wpa_passphrase=`syscfg_get ${WIFI_PRIV_NAMESPACE}::"$SYSCFG_INDEX"_passphrase_ext`"
	CONF_SEC_MODE="`get_security_mode ${WIFI_PRIV_NAMESPACE}::${SYSCFG_INDEX}_security_mode`"
	CONF_RADIUS_SERVER="`syscfg_get ${WIFI_PRIV_NAMESPACE}::radius_server`"
	CONF_RADIUS_PORT="`syscfg_get ${WIFI_PRIV_NAMESPACE}::radius_port`"
	CONF_RADIUS_SHARED="`syscfg_get ${WIFI_PRIV_NAMESPACE}::radius_shared`"
	if [ "1" = "`syscfg get smart_mode::mode`" ]; then
		MASTER_IP=`sysevent get master::ip`
		if [ ! -z "$MASTER_IP" ]; then
			CONF_RADIUS_SERVER=$MASTER_IP
		fi
	fi
	if [ "4" = "$CONF_SEC_MODE" ] || [ "5" = "$CONF_SEC_MODE" ] || [ "6" = "$CONF_SEC_MODE" ]; then
		generate_hostapd_config_enterprise $CONF_IF "$CONF_SSID" "$CONF_SEC_MODE" "$CONF_RADIUS_SERVER" "$CONF_RADIUS_PORT" "$CONF_RADIUS_SHARED" "$BR_IFNAME"> $HOSTAPD_CONF
	else
		generate_hostapd_config $CONF_IF "$CONF_SSID" "$CONF_PASSPHRASE" "$CONF_SEC_MODE" "aes" "" "$BR_IFNAME" ""> $HOSTAPD_CONF
	fi
	wps_state=`syscfg_get "$SYSCFG_INDEX"_wps_state`
	if [ "disabled" = "$wps_state" ] ; then
		iwpriv $CONF_IF wps 0
	else
		iwpriv $CONF_IF wps 1
	fi
	
	if [ "configured" = "$wps_state" ]; then
		WPS_STATE=2
	elif [ "disabled" = "$wps_state" ]; then
		WPS_STATE=0
	else
		WPS_STATE=1
	fi
	generate_hostapd_wps_section $SYSCFG_INDEX >> $HOSTAPD_CONF
	driver_update_extra_virtual_settings $PHY_IF $CONF_IF
	iwpriv $CONF_IF shortgi 1
}
private_vap_start_ext()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	CONF_IF=`syscfg_get ${WIFI_PRIV_NAMESPACE}::${SYSCFG_INDEX}_vap_ext`
	BR_IFNAME=`syscfg_get ${WIFI_PRIV_NAMESPACE}::ifname`
	INT=`get_phy_interface_name_from_vap "$PHY_IF"`
	wlanconfig $CONF_IF create wlandev $INT wlanmode ap
	/sbin/ifconfig $CONF_IF txqueuelen 1000
	add_interface_to_bridge $CONF_IF $BR_IFNAME
	CONF_SSID=`syscfg_get ${WIFI_PRIV_NAMESPACE}::"$SYSCFG_INDEX"_ssid_ext`
	iwconfig $CONF_IF essid $CONF_SSID
	HOSTAPD_CONF="/tmp/hostapd-$CONF_IF.conf"
	CONF_PASSPHRASE="wpa_passphrase=`syscfg_get ${WIFI_PRIV_NAMESPACE}::"$SYSCFG_INDEX"_passphrase_ext`"
	generate_hostapd_config $CONF_IF "$CONF_SSID" "$CONF_PASSPHRASE" "2" "aes" "" "$BR_IFNAME" ""> $HOSTAPD_CONF
	wps_state=`syscfg_get "$SYSCFG_INDEX"_wps_state`
	if [ "disabled" = "$wps_state" ] ; then
		iwpriv $CONF_IF wps 0
	else
		iwpriv $CONF_IF wps 1
	fi
	
	if [ "configured" = "$wps_state" ]; then
		WPS_STATE=2
	elif [ "disabled" = "$wps_state" ]; then
		WPS_STATE=0
	else
		WPS_STATE=1
	fi
	generate_hostapd_wps_section $SYSCFG_INDEX >> $HOSTAPD_CONF
	driver_update_extra_virtual_settings $PHY_IF $CONF_IF
	iwpriv $CONF_IF shortgi 1
}
private_vap_start_main()
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	CONF_IF=`syscfg_get ${WIFI_PRIV_NAMESPACE}::${SYSCFG_INDEX}_vap_main`
	BR_IFNAME=`syscfg_get lan_ifname`
	INT=`get_phy_interface_name_from_vap "$PHY_IF"`
	wlanconfig $CONF_IF create wlandev $INT wlanmode ap
	/sbin/ifconfig $CONF_IF txqueuelen 1000
	add_interface_to_bridge $CONF_IF $BR_IFNAME
	CONF_SSID=`syscfg_get ${WIFI_PRIV_NAMESPACE}::"$SYSCFG_INDEX"_ssid_main`
	iwconfig $CONF_IF essid $CONF_SSID
	HOSTAPD_CONF="/tmp/hostapd-$CONF_IF.conf"
	CONF_SEC_MODE="`get_security_mode ${WIFI_PRIV_NAMESPACE}::${SYSCFG_INDEX}_security_mode`"
	CONF_RADIUS_SERVER="`syscfg_get ${WIFI_PRIV_NAMESPACE}::radius_server`"
	CONF_RADIUS_PORT="`syscfg_get ${WIFI_PRIV_NAMESPACE}::radius_port`"
	CONF_RADIUS_SHARED="`syscfg_get ${WIFI_PRIV_NAMESPACE}::radius_shared`"
	if [ "1" = "`syscfg get smart_mode::mode`" ]; then
		MASTER_IP=`sysevent get master::ip`
		if [ ! -z "$MASTER_IP" ]; then
			CONF_RADIUS_SERVER=$MASTER_IP
		fi
	fi
	generate_hostapd_config_enterprise $CONF_IF "$CONF_SSID" "5" "$CONF_RADIUS_SERVER" "$CONF_RADIUS_PORT" "$CONF_RADIUS_SHARED" "$BR_IFNAME"> $HOSTAPD_CONF
	wps_state=`syscfg_get "$SYSCFG_INDEX"_wps_state`
	if [ "disabled" = "$wps_state" ] ; then
		iwpriv $CONF_IF wps 0
	else
		iwpriv $CONF_IF wps 1
	fi
	
	if [ "configured" = "$wps_state" ]; then
		WPS_STATE=2
	elif [ "disabled" = "$wps_state" ]; then
		WPS_STATE=0
	else
		WPS_STATE=1
	fi
	generate_hostapd_wps_section $SYSCFG_INDEX >> $HOSTAPD_CONF
	driver_update_extra_virtual_settings $PHY_IF $CONF_IF
	iwpriv $CONF_IF shortgi 1
}
