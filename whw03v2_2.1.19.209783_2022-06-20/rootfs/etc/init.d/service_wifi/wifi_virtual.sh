#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_user.sh
source /etc/init.d/service_wifi/wifi_guest.sh
source /etc/init.d/service_wifi/smart_connect_server_utils.sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
source /etc/init.d/service_wifi/smart_connect_unconfig_ap.sh
source /etc/init.d/service_wifi/private_network_utils.sh
wifi_virtual_start ()
{
	ulog wlan status "${SERVICE_NAME}, wifi_virtual_start($1)"
	echo "${SERVICE_NAME}, wifi_virtual_start($1)"
	PHY_IF=$1
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	
	VIRTUAL_EVENT=${WIFI_VIRTUAL}_${PHY_IF}
	wait_till_end_state ${VIRTUAL_EVENT}
	STATUS=`sysevent get ${VIRTUAL_EVENT}-status`
	if [ "started" = "$STATUS" ] || [ "starting" = "$STATUS" ] ; then
		ulog wlan status "${SERVICE_NAME}, ${WIFI_VIRTUAL} is starting/started, ignore the request"
		return 1
	fi
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	USER_STATE=`syscfg_get ${SYSCFG_INDEX}_state`
	if [ "$USER_STATE" = "down" ]; then
		VIR_IF=`syscfg_get "$SYSCFG_INDEX"_user_vap`
		echo "${SERVICE_NAME}, ${SYSCFG_INDEX}_state=$USER_STATE, do not start virtual $VIR_IF"
		return 1
	fi
	
	if [ -z "$SYSEVENT_BACKHAUL_INTF" ] ; then
		SYSEVENT_BACKHAUL_INTF=`sysevent get backhaul::intf`
	fi
	if [ "$SYSEVENT_BACKHAUL_INTF" = "ath9" -a "`cat /etc/product`" != "nodes-jr" ] && [ "$SYSCFG_INDEX" = "wl1" ] ; then
		echo "${SERVICE_NAME}, ${SYSCFG_INDEX}_state=$USER_STATE, do not start virtual on the backhaul $VIR_IF"
		return 1
	fi
	if [ "$SYSEVENT_BACKHAUL_INTF" = "ath11" ] && [ "$SYSCFG_INDEX" = "wl2" ] ; then
		echo "${SERVICE_NAME}, ${SYSCFG_INDEX}_state=$USER_STATE, do not start virtual on the backhaul $VIR_IF"
		return 1
	fi
	sysevent set ${VIRTUAL_EVENT}-status starting
	wifi_user_start $PHY_IF
	ERR=$?
	if [ "$ERR" = "0" ] ; then
		wifi_simpletap_start $PHY_IF
		wifi_guest_start $PHY_IF
		wifi_smart_configured_start $PHY_IF
		if [ "`syscfg get xconnect::vap_enabled`" = "1" ]; then
			wifi_unconfig_ap_start $PHY_IF
		fi
		sysevent set ${VIRTUAL_EVENT}-status started
	else
		sysevent set ${VIRTUAL_EVENT}-status stopped
		check_err $? "Unable to bringup user wifi"
	fi
	return 0
}
wifi_virtual_stop ()
{
	ulog wlan status "${SERVICE_NAME}, wifi_virtual_stop($1)"
	echo "${SERVICE_NAME}, wifi_virtual_stop($1)"
	PHY_IF=$1
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	wait_till_end_state ${WIFI_VIRTUAL}_${PHY_IF}
	STATUS=`sysevent get ${WIFI_VIRTUAL}_${PHY_IF}-status`
	if [ "stopped" = "$STATUS" ] || [ "stopping" = "$STATUS" ] || [ -z "$STATUS" ]; then
		ulog wlan status "${SERVICE_NAME}, ${WIFI_VIRTUAL} is already stopping/stopped, ignore the request"
		return 1
	fi
	sysevent set ${WIFI_VIRTUAL}_${PHY_IF}-status stopping
	wifi_guest_stop $PHY_IF
	wifi_smart_configured_stop $PHY_IF
	if [ "`syscfg get xconnect::vap_enabled`" = "1" ]; then
		wifi_unconfig_ap_stop $PHY_IF
	fi
	if [ ! -z "`syscfg get ${WIFI_PRIV_NAMESPACE}::enabled`" ] && [ -e /tmp/cedar_support ]; then
		private_network_stop $PHY_IF
	fi
	wifi_smart_setup_stop $PHY_IF
	wifi_simpletap_stop $PHY_IF
	wifi_user_stop $PHY_IF
	ERR=$?
	if [ "$ERR" -ne "0" ] ; then
		check_err $ERR "Unable to teardown user wifi"
	else
		sysevent set ${WIFI_VIRTUAL}-errinfo
		sysevent set ${WIFI_VIRTUAL}_${PHY_IF}-status stopped
	fi
	return 0
}
wifi_virtual_restart()
{
	ulog wlan status "${SERVICE_NAME}, wifi_virtual_restart()"
	echo "${SERVICE_NAME}, wifi_virtual_restart()"
	for PHY_IF in $PHYSICAL_IF_LIST; do
		wifi_virtual_stop $PHY_IF
		wifi_virtual_start $PHY_IF
	done
	return 0
}
