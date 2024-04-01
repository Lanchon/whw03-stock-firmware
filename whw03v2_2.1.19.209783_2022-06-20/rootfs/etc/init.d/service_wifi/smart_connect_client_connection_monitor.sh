#!/bin/sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
source /etc/init.d/syscfg_api.sh
SMART_MODE="$(syscfg get smart_mode::mode)"
if [ "1" != "$SMART_MODE" ] ; then
   exit 1
fi
wifi_status="$(sysevent get wifi-status)"
if [ "$wifi_status" != "started" ] ; then 
	exit 1
fi
DEFAULT_ROUTER="$(sysevent get default_router)"
MASTER_IP="$(sysevent get master::ip)"
LAN_IFNAME="$(syscfg get lan_ifname)"
do_ping()
{
	( ping -q -c1 -w5 $1 &> /dev/null ) &
	local pid=$!
    sleep 5
    if [ -d "/proc/$pid" ]; then
        ( kill -9 $pid ) 2> /dev/null
    fi
    wait $pid
    return $?
}
check_ip_connection()
{
	for i in 1 2 3; 
	do
	    MASTER_IP="$(sysevent get master::ip)"
    	    arping -I ${LAN_IFNAME} -f -w 1 ${MASTER_IP}
    	    if [ "$?" = "0" ]; then
        	return 0
   	    fi
	done
	for i in 1 2 3; 
	do
	    DEFAULT_ROUTER="$(sysevent get default_router)"
    	    arping -I ${LAN_IFNAME} -f -w 1 $DEFAULT_ROUTER
    	    if [ "$?" = "0" ]; then
        	return 0
   	    fi
   	    sleep 3
	done
	return 1
}
check_wifi_backhaul_monitor () {
    PROC_PID_LINE="`ps -w | grep "service_backhaul_switching" | grep -v grep`"
    if [ -n "$PROC_PID_LINE" ]; then
        return 1
    fi
    PROC_PID_LINE="`ps -w | grep "smart_connect_client_monitor" | grep -v grep`"
    PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
    if [ -z "$PROC_PID" ]; then
    	start_smart_connect_connection_monitor
        return 0
    else
        return 1
    fi
}
BACKHAUL_MEDIA="`sysevent get backhaul::media`"
if [ "$BACKHAUL_MEDIA" == "1" ] ; then
	check_ip_connection
	if [ "1" = "$?" ];then
		sysevent set dhcp_client-restart
		sysevent set setup_dhcp_client-restart
		sysevent set backhaul::status down
		sysevent set backhaul::media 2
		sysevent set lldp::root_accessible 0
		sysevent set lldp::root_intf
		echo "!!!detected ip connect down by wired backhaul, wireless backhaul will start" > /dev/console
		exit 1
	else
		exit 1
	fi
fi
if [ "$BACKHAUL_MEDIA" == "2" ]; then
	check_wifi_backhaul_monitor
fi
CURRENT_BACKHAUL="`sysevent get backhaul::intf`"
STATUS="`iwconfig $CURRENT_BACKHAUL | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
if [ "Not-Associated" != "$STATUS" ] && [ "$DEFAULT_ROUTER" != "" ] && [ "up" = "`sysevent get backhaul::status`" ]; then
	check_ip_connection
	if [ "1" = "$?" ];then
		echo "ip connect down, restart sta interface: $CURRENT_BACKHAUL " > /dev/console
		if [ "`echo $CURRENT_BACKHAUL | grep ath`" ]; then
		    ifconfig $CURRENT_BACKHAUL down
		fi
	fi
fi
