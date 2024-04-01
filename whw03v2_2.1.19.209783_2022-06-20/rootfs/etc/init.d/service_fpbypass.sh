#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="fastpath"
DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
switch_nss_on ()
{
   if [ -e /etc/init.d/qca-nss-ecm ] ; then
       /etc/init.d/qca-nss-ecm start
   fi
   if [ -f /etc/sysctl.d/qca-nss-ecm.conf ] ; then
       sysctl -p /etc/sysctl.d/qca-nss-ecm.conf
   fi  
    if [ "$NSS_BYPASS_SUPPORTED" = "1" ]; then
	echo 0 > /proc/sys/net/ecm/fpbypass_all
	(sleep 1; /etc/init.d/fpbypass_build_bypass.sh build_bypass) &
    fi
}
switch_nss_off ()
{
    if [ "$NSS_BYPASS_SUPPORTED" = "1" ]; then
	echo 1 > /proc/sys/net/ecm/fpbypass_all
    fi
    if [ -e /etc/init.d/qca-nss-ecm ] ; then
        /etc/init.d/qca-nss-ecm stop
    fi
}
service_init ()
{
    eval `utctx_cmd get fastpath_enable parental_control_enabled qos_enable User_Accepts_WiFi_Is_Unsecure` 
    qos_enabled=`sysevent get qos_enabled`
    bridge_status=`sysevent get bridge-status`
    if [ -f /proc/sys/net/ecm/fpbypass_all ] ; then
	NSS_BYPASS_SUPPORTED=1
    else
	NSS_BYPASS_SUPPORTED=0
    fi
}
service_start ()
{
    wait_till_end_state ${SERVICE_NAME}
    if [ "`syscfg get smart_mode::mode`" != "1" ] && [ "$SYSCFG_fastpath_enable" != "1" -o \
         "$qos_enabled" = "1"  -o \
         "$SYSCFG_User_Accepts_WiFi_Is_Unsecure" != "1" ] ; then
       switch_nss_off
       sysevent set ${SERVICE_NAME}-status "stopped"
       return
    fi  
    sysevent set ${SERVICE_NAME}-status "starting"
    ulog ${SERVICE_NAME} status "starting ${SERVICE_NAME} service"
    switch_nss_on
    sysevent set ${SERVICE_NAME}-status "started"
}
service_stop () 
{
    wait_till_end_state ${SERVICE_NAME}
    
    sysevent set ${SERVICE_NAME}-status "stopping"
    ulog ${SERVICE_NAME} status "stopping ${SERVICE_NAME} service"
    switch_nss_off
    
    sysevent set ${SERVICE_NAME}-status "stopped"
}
service_restart () 
{
   service_stop
   service_start
}
echo "${SERVICE_NAME}, sysevent received: $1"
service_init
case "$1" in
  ${SERVICE_NAME}-start)
     service_start
     ;;
  ${SERVICE_NAME}-stop)
     service_stop
     ;;
  ${SERVICE_NAME}-restart)
     service_restart
     ;;
  qos_enabled)
     service_start
     ;;
  bridge-status)
     if [ "up" = "$bridge_status" ]; then
        service_start
     fi
     ;;
  backhaul::status)
     if [ "up" = "$2" -a "$(sysevent get fastpath-status)" != "started" ]; then
        service_start
     fi  
     ;;
  *)
     echo "Usage: $SELF_NAME [${SERVICE_NAME}-start|${SERVICE_NAME}-stop|${SERVICE_NAME}-restart]" >&2
     exit 3
     ;;
esac
