#!/bin/sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
sysevent set smart_connect::setup_status START
if [ "`syscfg get smart_mode::mode`" != "0" ] ; then
    exit
else
    /etc/init.d/service_smartconnect.sh smart_connect::client_setup_start
fi
echo "smart connect client: start slave mode (`date`)" > /dev/console
SMART_CONNECT_SETUP_TIMEOUT=`syscfg get smart_connect::setup_duration`
sysevent set smart_connect::setup_duration_timeout "0"
SLEEP_CNT=0
while [ "$SLEEP_CNT" -lt "$SMART_CONNECT_SETUP_TIMEOUT" ];
do
	SLEEP_CNT=`expr $SLEEP_CNT + 1`
	sleep 1
done
sysevent set smart_connect::setup_duration_timeout "1"
