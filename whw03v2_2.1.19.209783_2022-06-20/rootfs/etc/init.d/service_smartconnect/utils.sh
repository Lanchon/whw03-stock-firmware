#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
SERVICE_NAME="smart_connect"
DEBUG_SETTING=$(syscfg get ${SERVICE_NAME}_debug)
DEBUG() 
{
    [ "$DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
wifi_setup_start ()
{
	echo "Wifi setup start..."
    ulog smart_connect status "Wifi setup start..."
	wired_setup_stop
	start_smart_connect_connection_monitor
}
wifi_setup_stop ()
{
	echo "Wifi setup stopping..."
    ulog smart_connect status "Wifi setup stopping..."
	stop_smart_connect_connection_monitor
}
wired_setup_start ()
{
	echo "Wired setup start..."
    ulog smart_connect status "Wired setup start..."	
	PROC_PID_LINE="`ps -w | grep "smartconnect_wired_slave" | grep -v grep`"
	PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
	if [ -z "$PROC_PID" ]; then
		/etc/init.d/service_smartconnect/smartconnect_wired_slave.sh &
		echo "smartconnect wired setup started"
		ulog smart_connect status "smartconnect wired setup started"
	else
		echo "smartconnect wired setup is already running"
		ulog smart_connect status "smartconnect wired setup is already running"
	fi
}
wired_setup_stop ()
{
	echo "Wired setup stopping..."
    ulog smart_connect status "Wired setup stopping..."	
	PROC_PID_LINE="`ps -w | grep "smartconnect_wired_slave" | grep -v grep`"
	PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
	if [ ! -z "$PROC_PID" ]; then
		kill -9 "$PROC_PID"
		echo "smart connect client wired setup stopped"
	fi
}
wifi_monitor_is_running () {
    PROC_PID_LINE="`ps -w | grep "smart_connect_client_monitor" | grep -v grep`"
    PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
    if [ -z "$PROC_PID" ]; then
        return 0
    else
        return 1
    fi
}
check_ip_connection()
{
    local mode="$(syscfg get smart_mode::mode)"
    if [ "${mode}" == "1" ]; then
        local LAN_IFNAME="$(syscfg get lan_ifname)"
    elif [ "${mode}" == "0" ] ; then
        local LAN_IFNAME="$(sysevent get wan::detected_intf)"
        [ -z "$LAN_IFNAME" ] && LAN_IFNAME="$(syscfg get uplink_ifname)"
        [ -z "$LAN_IFNAME" ] && LAN_IFNAME="$(syscfg get wan_physical_ifname)"
    else
        return 1
    fi
    for i in 1 2 3; 
    do
        OMSG_IP="$(sysevent get master::ip)"
        if [ "${OMSG_IP}" != "" ] ; then
            arping -I ${LAN_IFNAME} -f -w 1 ${OMSG_IP}
            if [ "$?" = "0" ]; then
                return 0
            fi
        fi
    done
    for i in 1 2 3; 
    do
        DEFAULT_ROUTER="$(sysevent get default_router)"
        if [ "${DEFAULT_ROUTER}" != "" ]; then
            arping -I ${LAN_IFNAME} -f -w 1 $DEFAULT_ROUTER
            if [ "$?" = "0" ]; then
                return 0
            fi
        fi
    done
    echo "check connection, arping to gateway unreachable..."
    ulog smart_connect status "check connection, arping to gateway unreachable..."    
    return 1
}
