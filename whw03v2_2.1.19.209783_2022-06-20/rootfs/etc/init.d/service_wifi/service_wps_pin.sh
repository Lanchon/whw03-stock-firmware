#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/syscfg_api.sh
SERVICE_NAME="wps_pin"
echo "wifi, ${SERVICE_NAME}, sysevent received: $1"
WIFI_DEBUG_SETTING=`syscfg_get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
wps_pin_method_start() {
	ulog ${SERVICE_NAME} status "wps pin service start"
	/etc/init.d/service_wifi/start_wps.sh wps_pin $1 &
	sysevent set wl_wps_status running
	nohup /etc/init.d/service_wifi/wps_monitor.sh >& /dev/null </dev/null &
	return 0
}
wps_pin_method_stop() {
	ulog ${SERVICE_NAME} status "wps pin service stop" 
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "dallas" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		HOSTAPD_IFNAMES="ath0 ath1 ath10"
	elif [ "`cat /etc/product`" = "nodes-jr" ] ; then
		HOSTAPD_IFNAMES="ath0 ath1"
	else
		HOSTAPD_IFNAMES=`ls /var/run/hostapd | xargs echo`
	fi
	for if_name in $HOSTAPD_IFNAMES
	do
		hostapd_cli -i$if_name wps_cancel > /dev/null
	done
	sysevent set wl_wps_status failed
	sysevent set wps-stopped
}
service_init() {
	ulog ${SERVICE_NAME} status "wps pbc service init"
	SYSCFG_FAILED='false'
	FOO=`utctx_cmd get wl0_ssid wl1_ssid`
	eval $FOO
	if [ $SYSCFG_FAILED = 'true' ] ; then
		ulog ${SERVICE_NAME} status "$PID utctx failed to get some configuration data required by service $SERVICE_NAME"
		sysevent set ${SERVICE_NAME}-status error 
		sysevent set ${SERVICE_NAME}-errinfo "failed to get crucial information from syscfg"
		exit
	fi
}
service_init
case "$1" in
	WPS::pin-start)
		wps_pin_method_start $2
		;;
	WPS::pin-cancel)
		wps_pin_method_stop
		;;
	*)
		echo "Usage: $SELF_NAME WPS::pin-start|WPS::pin-cancel" >&2
		exit 3
		;;
esac
