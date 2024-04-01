#!/bin/sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
echo "wifi, start_wps.sh"
if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "dallas" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
	HOSTAPD_IFNAMES="ath0 ath1 ath10"
elif [ "`cat /etc/product`" = "nodes-jr" ] ; then
	HOSTAPD_IFNAMES="ath0 ath1"
else
	HOSTAPD_IFNAMES=`ls /var/run/hostapd | xargs echo`
fi
WPS_METHOD=
PIN=
if [ "wps_pin" != $1 ] && [ "wps_pbc" != $1 ];then
	display_help
else
	WPS_METHOD=$1
fi 
if [ "wps_pin" == $WPS_METHOD ]; then
	if [ ! -z $2 ]; then
		PIN_LEN=`expr length "$2"`
		if [ $PIN_LEN = 4 ] || [ $PIN_LEN = 8 ]; then
			PIN="$2"
		else
			display_help
		fi
	else
		display_help
	fi
fi
sysevent set wps_process incomplete
for if_name in $HOSTAPD_IFNAMES
do
	get_wl_index $if_name
	WL_INDEX=$?
	WPS_STATE=`syscfg_get wl"$WL_INDEX"_wps_state`
	if [ "$WPS_STATE" = "disabled" ]; then
		continue
	fi
	if [ "`sysevent get backhaul::intf`" = "ath9" -a "`cat /etc/product`" != "nodes-jr" ] && [ "$WL_INDEX" = "1" ] ; then
		echo "do not start WPS on the backhaul wifi1"
		continue
	fi
	if [ "`sysevent get backhaul::intf`" = "ath11" ] && [ "$WL_INDEX" = "2" ] ; then
		echo "do not start WPS on the backhaul wifi2"
		continue
	fi
	if [ "wps_pin" == $WPS_METHOD ]; then
		hostapd_cli -p/var/run/hostapd -i$if_name $WPS_METHOD any "$PIN" 120 > /dev/null
	fi
	if [ "wps_pbc" == $WPS_METHOD ]; then
		hostapd_cli -p/var/run/hostapd -i$if_name $WPS_METHOD > /dev/null
	fi
done
sysevent set wps-running
display()
{
	echo "Usage start wps pin or pbc"
	echo "start_wps wps_pin pin"
	echo "start_wps wps_pbc"
	exit
}
