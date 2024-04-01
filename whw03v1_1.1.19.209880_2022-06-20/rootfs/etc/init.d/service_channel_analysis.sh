#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="channel_analysis"
ACS_BIN="acs"
DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
service_init ()
{
    eval `utctx_cmd get wl0_physical_ifname wl1_physical_ifname`
}
start_acs ()
{
   echo "do acs on interface $1"
   echo "waiting for it complete..."
}
acs_complete ()
{
   sysevent set ca_channel_recommend_2G "13"
   sysevent set ca_channel_recommend_5G "142"
   sysevent set ${SERVICE_NAME}-errinfo
   sysevent set ${SERVICE_NAME}-status "finnished"
}
ca_channel_accept ()
{
    24GCHANNEL=`sysevent get ca_channel_recommend_2G`
    5GCHANNEL=`sysevent get ca_channel_recommend_5G`
    sysevent set ca_channel_accept_2G $24GCHANNEL
    sysevent set ca_channel_accept_5G $5GCHANNEL
    sysevent set wifi-restart
}
service_start ()
{
   start_acs $SYSCFG_wl0_physical_ifname
   start_acs $SYSCFG_wl1_physical_ifname
   sysevent set ${SERVICE_NAME}-errinfo
   sysevent set ${SERVICE_NAME}-status "starting"
}
service_stop () 
{
   ulog ${SERVICE_NAME} status "stopping ${SERVICE_NAME} service" 
   sysevent set ${SERVICE_NAME}-errinfo
   sysevent set ${SERVICE_NAME}-status "stopped"
}
service_restart () 
{
   service_stop
   service_start
}
service_init
case "$1" in
  ${SERVICE_NAME}-start)
     service_start
     ;;
  ${SERVICE_NAME}-stop)
     echo "Not support yet.."
     ;;
  ${SERVICE_NAME}-restart)
     echo "Not support this method.."
     ;;
  acs_complete)
     acs_complete
     ;;
  ca_channel_accept)
     ca_channel_accept
     ;;     
  *)
     echo "Usage: $SELF_NAME [${SERVICE_NAME}-start|${SERVICE_NAME}-stop|${SERVICE_NAME}-restart]" >&2
     exit 3
     ;;
esac
