#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/service_wifi/wifi_utils.sh
SERVICE_NAME="wifi_monitor"
WIFI_DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
if [ "`sysevent get wifi-status`" != "started" ]; then
	return 0
fi
if [ "1" = "`syscfg get smart_mode::mode`" ] && [ "up" != "`sysevent get backhaul::status`" ]; then
	return 0
fi
if [ "0" = "`syscfg get smart_mode::mode`" ] && [ "READY" != "`sysevent get smart_connect::setup_status`" ]; then
	return 0
fi
for PHY_IF in $PHYSICAL_IF_LIST; do
	if [ "`sysevent get backhaul::intf`" = "$PHY_IF" ]; then
		continue
	fi
	VENDOR_NAME=`syscfg get hardware_vendor_name`
	WL_SYSCFG=`get_syscfg_interface_name $PHY_IF`
	case "$VENDOR_NAME" in
		Broadcom)
			DRIVER_STATUS=`wl -i $PHY_IF isup`
			;;
		Marvell)
			VIR_IF=`syscfg get "$WL_SYSCFG"_user_vap`
			IF_STATE=`ifconfig $VIR_IF | grep UP | awk '{print $1}'`
			if [ "$IF_STATE" = "UP" ]; then
				DRIVER_STATUS=1
			else
				DRIVER_STATUS=0
			fi
			;;
		QCA)
			IF_STATE=`ifconfig $PHY_IF | grep UP | awk '{print $1}'`
			if [ "$IF_STATE" = "UP" ]; then
				DRIVER_STATUS=1
			elif [ "$(sysevent get blocking::${PHY_IF})" != "" ] ; then
				DRIVER_STATUS=1
			else
				DRIVER_STATUS=0
			fi
			;;
		*)
			echo "wifi, error: unknow hardware vendor name"
			return 1
			;;
	esac
	if [ "`sysevent get ${WL_SYSCFG}_status`" = "up" ] && [ "$DRIVER_STATUS" = "0" ] && [ "`sysevent get wifi_renew_clients-status`" != "starting" ] && [ "`sysevent get wifi_renew_VAP-status`" != "starting" ] && [ "`sysevent get autochannel-status`" != "running" ] && [ "`sysevent get autochannel-quiet`" != "1" ] && [ "`sysevent get smart_connect::master_search_client_status`" != "RUNNING" ]; then
		ulog ${SERVICE_NAME} status "${SERVICE_NAME}, ERROR: why $PHY_IF is currently down... wifi monitor brings it back up (`date`)"
		echo "${SERVICE_NAME}, ERROR: why $PHY_IF is currently down... wifi monitor brings it back up (`date`)" > /dev/console
		sysevent set wifi-restart
		break
	fi	
done
return 0
