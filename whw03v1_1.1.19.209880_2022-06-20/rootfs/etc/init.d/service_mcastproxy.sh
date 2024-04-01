#!/bin/sh
source /etc/init.d/ulog_functions.sh
SERVICE_NAME="mcastproxy"
SELF_NAME="`basename $0`"
BIN=igmpproxy
CONF_FILE=/tmp/igmpproxy.conf
DEBUG() 
{
  [ "$(syscfg get mcastproxy_debug)" == "1" ] && $@
}
DEBUG set -x
generate_altnet_ip() {
    ifname=$1
    [ "$ifname" = "" ] && return
    OLDIPS=`/sbin/ip addr show dev "$ifname" | grep "inet " | awk '{split($2,foo, "/"); print(foo[1]);}'`
    for OLDIP in $OLDIPS
    do
        OCTET1=`echo $OLDIP | awk 'BEGIN {FS = "."};{print $1}'`
        OCTET2=`echo $OLDIP | awk 'BEGIN {FS = "."};{print $2}'`
	[ "$OCTET1" = "169" -a "$OCTET2" = "254" ] && return
    done
    NEWIP=""
    for idx in 1 2 3
    do
        if [ -n "$NEWIP" ]; then
            OCTET3=`echo $NEWIP | awk 'BEGIN {FS = "."};{print $3}'`
            OCTET4=`echo $NEWIP | awk 'BEGIN {FS = "."};{print $4}'`
	    OCTET3=`expr $OCTET3 + 1`
	    OCTET3=`expr $OCTET3 % 256`
	else
            MAC6=0x`ip link show $ifname | grep link | awk '{print $2}' | awk 'BEGIN { FS = ":" } ; { printf ("%s", $6) }'`
            MAC6=`echo $MAC6 | awk ' {printf ("%d", $1)}'`
            MAC5=0x`ip link show $ifname | grep link | awk '{print $2}' | awk 'BEGIN { FS = ":" } ; { printf ("%s", $5) }'`
            MAC5=`echo $MAC5 | awk ' {printf ("%d", $1)}'`
            RAND=`expr $MAC6 \* $MAC5`
            OCTET3=`expr $RAND % 256` 
            RAND=`expr $RAND - $MAC6`
            OCTET4=`expr $RAND % 255`
            [ "0" -eq $OCTET4 ] && OCTET4=65
        fi
        NEWIP="169.254.$OCTET3.$OCTET4"
        arping -I "$ifname" -q -f -w 1 "$NEWIP"
        if [ "$?" != "0" ]; then
	    [ "$ifname" = "$SYSCFG_lan_ifname" ] && break
            arping -I "$SYSCFG_lan_ifname" -q -f -w 1 "$NEWIP"
            [ "$?" != "0" ] && break
	fi
    done
    /sbin/ip addr add "$NEWIP"/255.255.0.0 dev "$ifname"
}
clear_altnet_ip() {
    ifname=$1
    [ "$ifname" = "" ] && return
    OLDIPS=`/sbin/ip addr show dev "$ifname" | grep "inet " | awk '{split($2,foo, "/"); print(foo[1]);}'`
    for OLDIP in $OLDIPS
    do
        OCTET1=`echo $OLDIP | awk 'BEGIN {FS = "."};{print $1}'`
        OCTET2=`echo $OLDIP | awk 'BEGIN {FS = "."};{print $2}'`
	if [ "$OCTET1" = "169" -a "$OCTET2" = "254" ]; then
	    /sbin/ip addr del "$OLDIP"/255.255.0.0 dev "$ifname"
        fi
    done
}
do_start_igmpproxy () {
   LOCAL_CONF_FILE=/tmp/igmpproxy.conf$$
   killall $BIN > /dev/null 2>&1
   
   if [ "$SYSCFG_hardware_vendor_name" = "Broadcom" ] ; then
       if [ -f /usr/sbin/igmp ]; then
           ulog ${SERVICE_NAME} status "killall -q igmp" 
           killall -q igmp > /dev/null 2>&1
       fi
   fi
   rm -rf $LOCAL_CONF_FILE
   if [ "$SYSCFG_igmpproxy_nowtv_enabled" = "1" ]; then
       WAN_BASE_IFNAME=`sysevent get wan::detected_intf`
       ALTNET_LAN="`syscfg get igmpproxy_altnet_lan`"
       [ -z "$ALTNET_LAN" ] && ALTNET_LAN="169.254.1.1/16"
       echo "quickleave" >> $LOCAL_CONF_FILE
       if [ "$SYSCFG_wan_proto" = "pppoe" ]; then
	   echo "phyint $WAN_IFNAME disabled" >> $LOCAL_CONF_FILE
           echo "phyint $WAN_BASE_IFNAME upstream" >> $LOCAL_CONF_FILE
       else
           echo "phyint $WAN_IFNAME upstream" >> $LOCAL_CONF_FILE
       fi
       echo "blacklist 239.255.255.250/32" >> $LOCAL_CONF_FILE
       echo "phyint $SYSCFG_svap_lan_ifname disabled" >> $LOCAL_CONF_FILE
       echo "phyint $SYSCFG_lan_ifname downstream" >> $LOCAL_CONF_FILE
       [ -n "$ALTNET_LAN" ] && echo "altnet $ALTNET_LAN" >> $LOCAL_CONF_FILE
   else
       echo "quickleave" >> $LOCAL_CONF_FILE
       echo "phyint $WAN_IFNAME upstream" >> $LOCAL_CONF_FILE
       echo "blacklist 239.255.255.250/32" >> $LOCAL_CONF_FILE
       echo "phyint $SYSCFG_lan_ifname downstream" >> $LOCAL_CONF_FILE
   fi
   if [ "$SYSCFG_igmpproxy_nowtv_enabled" = "1" ]; then
       WAN_BASE_IFNAME=`sysevent get wan::detected_intf`
       if [ "$SYSCFG_wan_proto" = "pppoe" ]; then
           generate_altnet_ip "$WAN_BASE_IFNAME"
	   sysevent set firewall-restart
       fi
       echo 2 > /proc/sys/net/ipv4/conf/all/force_igmp_version
   fi
   cat $LOCAL_CONF_FILE > $CONF_FILE
   rm -f $LOCAL_CONF_FILE
   ulog ${SERVICE_NAME} status "start $BIN $CONF_FILE"
   TRIES=1
   WAN_STATUS_EVENT="${WAN_IFNAME}-status"
   [ "$SYSCFG_igmpproxy_nowtv_enabled" = "1" -a "$SYSCFG_wan_proto" = "pppoe" ] && WAN_STATUS_EVENT="${WAN_BASE_IFNAME}-status"
   while [ "30" -gt "$TRIES" ] ; do
       STATUS=`sysevent get ${WAN_STATUS_EVENT}`
       [ "started" = "$STATUS" ] && break
       ulog ${SELF_NAME} status "Waiting for ${WAN_STATUS_EVENT} to change from $STATUS. Try ${TRIES} of 30"
       sleep 1
       TRIES=`expr $TRIES + 1`
   done
   $BIN $CONF_FILE &
   sleep 2
   if [ "$SYSCFG_hardware_vendor_name" = "Broadcom" ] ; then
       if [ -f /usr/sbin/igmp ]; then
           ulog ${SERVICE_NAME} status "start igmp $WAN_IFNAME" 
           /usr/sbin/igmp $WAN_IFNAME 
       fi
   fi
}
service_init ()
{
   eval `utctx_cmd get igmpproxy_enabled lan_ifname svap_lan_ifname wan_virtual_ifname wan_proto block_multicast hardware_vendor_name igmpproxy_nowtv_enabled`
   CURRENT_WAN_STATUS=`sysevent get wan-status`
   CURRENT_LAN_STATUS=`sysevent get lan-status`
   CURRENT_IGMPPROXY_STATUS=`sysevent get ${SERVICE_NAME}-status`	
   WAN_IFNAME=`sysevent get current_wan_ifname`
   START_SERVICE=0
   STOP_SERVICE=0
   if [ "$CURRENT_WAN_STATUS" = "started" ] && [ "$CURRENT_LAN_STATUS" = "started" ] && [ ! -z "$WAN_IFNAME" ] && [ "1" = "$SYSCFG_igmpproxy_enabled" ] && [ "0" = "$SYSCFG_block_multicast" ] ; then
      START_SERVICE=1
   elif [ "$CURRENT_IGMPPROXY_STATUS" = "started" ] ; then
      STOP_SERVICE=1
   fi
}
service_start () 
{
   ulog ${SERVICE_NAME} status "starting ${SERVICE_NAME} service" 
   if [ "$CURRENT_WAN_STATUS" = "started" ] && [ "$CURRENT_LAN_STATUS" = "started" ] && [ ! -z "$WAN_IFNAME" ] && [ "1" = "$SYSCFG_igmpproxy_enabled" ] && [ "0" = "$SYSCFG_block_multicast" ] ; then
      do_start_igmpproxy
      sysevent set ${SERVICE_NAME}-errinfo
      sysevent set ${SERVICE_NAME}-status "started"
   fi
}
service_stop () 
{
   ulog ${SERVICE_NAME} status "stopping ${SERVICE_NAME} service" 
   killall $BIN > /dev/null 2>&1
   rm -rf $CONF_FILE
   if [ "`syscfg get igmpproxy_nowtv_enabled`" = "1" ]; then
       WAN_BASE_IFNAME=`sysevent get wan::detected_intf`
       [ "$SYSCFG_wan_proto" = "pppoe" ] && clear_altnet_ip "$WAN_BASE_IFNAME"
       echo 0 > /proc/sys/net/ipv4/conf/all/force_igmp_version
   fi
   if [ "$SYSCFG_hardware_vendor_name" = "Broadcom" ]; then
       if [ -f /usr/sbin/igmp ]; then
           ulog ${SERVICE_NAME} status "killall -q igmp" 
           killall -q igmp > /dev/null 2>&1
       fi
   fi
   sysevent set ${SERVICE_NAME}-errinfo
   sysevent set ${SERVICE_NAME}-status "stopped"
}
if [ "$(syscfg get smart_mode::mode)" = "2" -a "$(syscfg get bridge_mode)" = "1" -a "$(sysevent get lan-status)" = "started" ]; then
      if [ -f /sys/devices/virtual/net/br0/bridge/multicast_querier ]; then
         echo 1 > /sys/devices/virtual/net/br0/bridge/multicast_querier
         echo 1 > /sys/devices/virtual/net/br0/bridge/multicast_query_use_ifaddr
      fi
else
      if [ -f /sys/devices/virtual/net/br0/bridge/multicast_querier ]; then
         echo 0 > /sys/devices/virtual/net/br0/bridge/multicast_querier
         echo 0 > /sys/devices/virtual/net/br0/bridge/multicast_query_use_ifaddr
      fi
fi
service_init
case "$1" in
  ${SERVICE_NAME}-start)
      service_start
      ;;
  ${SERVICE_NAME}-stop)
      service_stop
      ;;
  ${SERVICE_NAME}-restart)
      service_stop
      service_start
      ;;
  wan-status)
      if [ "1" == "$START_SERVICE" ] ; then
         service_start
      elif [ "1" == "$STOP_SERVICE" ] ; then
         service_stop
      fi 
      ;;
  lan-status)
      if [ "1" == "$START_SERVICE" ] ; then
         service_start
      elif [ "1" == "$STOP_SERVICE" ] ; then
         service_stop
      fi 
      ;;
  *)
      echo "Usage: $SELF_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart | wan-status | lan-status ]" >&2
      exit 3
      ;;
esac
