#!/bin/sh
source /etc/init.d/syscfg_api.sh
MODEL=`syscfg get device::modelNumber`
COUNTRY=`echo $MODEL | awk -F"-" '{print $2}'`
if [ -z $COUNTRY ] || [ "US" = $COUNTRY ]; then
	echo "Updating NTP Servers if necessary"
	if [ -z "$(syscfg_get ntp_server1)" ]; then
		syscfg_set ntp_server1 0.pool.ntp.org
	fi
	if [ -z "$(syscfg_get ntp_server2)" ]; then
		syscfg_set ntp_server2 1.pool.ntp.org
	fi
	if [ -z "$(syscfg_get ntp_server3)" ]; then
		syscfg_set ntp_server3 2.pool.ntp.org
	fi
else
	echo "NTP Servers do not need to be updated"
fi
