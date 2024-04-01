#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="pppoe_passthrough"
SELF_NAME="`basename $0`"
BIN=/sbin/pppoe-relay
check_service_enabled()
{
    if [ "$(syscfg get pppoe_passthrough_enabled)" != "1" ]; then
        ulog ${SERVICE_NAME} status "pppoe passthrough disabled"
        return 1
    fi
    if [ "$(syscfg get bridge_mode)" != "0" ]; then
        ulog ${SERVICE_NAME} status "pppoe passthrough disabled in bridge mode"
        return 1
    fi
    
    ulog ${SERVICE_NAME} status "pppoe passthrough enabled"
    return 0
}
service_start () 
{
    wait_till_end_state $SERVICE_NAME
    ulog ${SERVICE_NAME} status "starting ${SERVICE_NAME} service" 
    WAN_IFNAME="`syscfg get wan_1::ifname`"
    LAN_IFNAME=`syscfg get lan_ifname`
    if [ "$(sysevent get wan-status)" = "started" ] && [ "$(sysevent get lan-status)" = "started" ] && [ ! -z "$WAN_IFNAME" ] ; then
        [ -n "$(pidof $(basename $BIN))" ] && killall $(basename $BIN) > /dev/null 2>&1
        pppoe-relay -S $WAN_IFNAME -C $LAN_IFNAME 
        sysevent set ${SERVICE_NAME}-errinfo
        sysevent set ${SERVICE_NAME}-status "started"
    fi
}
service_stop () 
{
    wait_till_end_state $SERVICE_NAME
    ulog ${SERVICE_NAME} status "stopping ${SERVICE_NAME} service"
    killall $(basename $BIN) > /dev/null 2>&1
    sysevent set ${SERVICE_NAME}-errinfo
    sysevent set ${SERVICE_NAME}-status "stopped"
}
case "$1" in
    ${SERVICE_NAME}-start)
        check_service_enabled
        [ $? -eq 0 ] && service_start
        ;;
    ${SERVICE_NAME}-stop)
        service_stop
        ;;
    ${SERVICE_NAME}-restart)
        service_stop
        check_service_enabled
        [ $? -eq 0 ] && service_start
        ;;
    wan-status|lan-status)
        if [ "started" == "$2" ] ; then
            check_service_enabled
            [ $? -eq 0 ] && service_start
        elif [ "stopped" == "$2" ] ; then
            service_stop
        fi
        ;;
    *)
        echo "Usage: $SELF_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart | wan-status started/stopped | lan-status started/stopped]" >&2
        exit 3
        ;;
esac
