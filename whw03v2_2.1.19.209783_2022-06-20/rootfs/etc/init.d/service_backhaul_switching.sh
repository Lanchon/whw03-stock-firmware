#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/service_backhaul_switching/backhaul_utils.sh
BACKHAUL_SWITCHING_MGR_HANDLER="/etc/init.d/service_backhaul_switching/backhaul_switching_mgr.sh"
SRV_NAME="backhaul_switching"
PID="$$"
EVENT=$1
if [ "$(syscfg get ${SRV_NAME}_debug)" = "1" ]; then
    set -x
fi
unregister_event_handler () 
{
   asyncid=`sysevent get ${SERVICE_NAME}_async_id_2`;
   if [ -n "$asyncid" ] ; then
      sysevent rm_async $asyncid
      sysevent set ${SERVICE_NAME}_async_id_2
   fi
   asyncid=`sysevent get ${SERVICE_NAME}_async_id_3`;
   if [ -n "$asyncid" ] ; then
      sysevent rm_async $asyncid
      sysevent set ${SERVICE_NAME}_async_id_3
   fi    
   asyncid=`sysevent get ${SERVICE_NAME}_async_id_4`;
   if [ -n "$asyncid" ] ; then
      sysevent rm_async $asyncid
      sysevent set ${SERVICE_NAME}_async_id_4
   fi
   asyncid=`sysevent get ${SERVICE_NAME}_async_id_5`;
   if [ -n "$asyncid" ] ; then
      sysevent rm_async $asyncid
      sysevent set ${SERVICE_NAME}_async_id_5
   fi
   asyncid=`sysevent get ${SERVICE_NAME}_async_id_6`;
   if [ -n "$asyncid" ] ; then
      sysevent rm_async $asyncid
      sysevent set ${SERVICE_NAME}_async_id_6
   fi
   asyncid=`sysevent get ${SERVICE_NAME}_async_id_7`;
   if [ -n "$asyncid" ] ; then
      sysevent rm_async $asyncid
      sysevent set ${SERVICE_NAME}_async_id_7
   fi
}
register_event_handler ()
{
    unregister_event_handler
    asyncid=`sysevent async ETH::port_1_status "$BACKHAUL_SWITCHING_MGR_HANDLER"`;
    sysevent set ${SERVICE_NAME}_async_id_2 "$asyncid"
    asyncid=`sysevent async ETH::port_2_status "$BACKHAUL_SWITCHING_MGR_HANDLER"`;
    sysevent set ${SERVICE_NAME}_async_id_3 "$asyncid"
    asyncid=`sysevent async ETH::port_3_status "$BACKHAUL_SWITCHING_MGR_HANDLER"`;
    sysevent set ${SERVICE_NAME}_async_id_4 "$asyncid"
    asyncid=`sysevent async ETH::port_4_status "$BACKHAUL_SWITCHING_MGR_HANDLER"`;
    sysevent set ${SERVICE_NAME}_async_id_5 "$asyncid"
    asyncid=`sysevent async ETH::port_5_status "$BACKHAUL_SWITCHING_MGR_HANDLER"`;
    sysevent set ${SERVICE_NAME}_async_id_6 "$asyncid"
    asyncid=`sysevent async wifi-status "$BACKHAUL_SWITCHING_MGR_HANDLER"`;
    sysevent set ${SERVICE_NAME}_async_id_7 "$asyncid"    
}
bootup_initialize_once ()
{
    local current_backhaul_media="$(sysevent get backhaul::media)"
    register_event_handler
    initial_vlan_for_linkup_interface
    sleep 2
    if [ "$current_backhaul_media" == "" -o "$current_backhaul_media" == "0" ] ; then
        sysevent set backhaul::media 2
        sleep 10
    else
        do_backhaul_check
    fi
}
ulog $SRV_NAME status "event $EVENT received"
echo $SRV_NAME status "event $EVENT received"
if [ "$(syscfg get smart_mode::mode)" != "1" ] ; then
    exit 1
fi
case $EVENT in
    system_state-normal)
        bootup_initialize_once
        ;;     
    *)
        echo "Event $EVENT received, no handler for this" > /dev/console
        exit 1
        ;;
esac
