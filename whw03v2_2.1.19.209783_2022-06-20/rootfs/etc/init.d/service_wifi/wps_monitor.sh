#!/bin/sh
echo "wifi, start wps_monitor.sh"
STATUS_FILE="/tmp/wpsstatus"
CLIENT_MAC=""
INTERFACE=""
TIMEOUT="true"
MAXWAIT=120
CNT=0;
while [ $CNT -lt $MAXWAIT ]
do
	STATE=`sysevent get wps_process`
	if [ "completed" = "$STATE" ]; then
		sysevent set wl_wps_status "success"
		sysevent set wps-success
		TIMEOUT="false"
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
		break;
	fi
	sleep 2;
	CNT=`expr $CNT + 2`
	sysevent set wl_wps_progress $CNT
done
if [ "true" = "$TIMEOUT" ]; then
	sysevent set wl_wps_status "failed"
	sysevent set wps-failed
fi
