#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/resolver_functions.sh
PID="($$)"
UDHCPC_PID_FILE=/var/run/master_search_udhcpc.pid
UDHCPC_SCRIPT=/etc/init.d/service_smartconnect/ms_dhcp_link.sh
LOG_FILE="/tmp/ms_udhcpc.log"
BRIDGE_DEBUG_SETTING=`syscfg get bridge_debug`
DEBUG() 
{
    [ "$BRIDGE_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
service_init ()
{
   FOO=`utctx_cmd get lan_ifname hostname dhcpc_trusted_dhcp_server hardware_vendor_name bridge_mode lan_ethernet_physical_ifnames wifi_bridge::mode smart_mode::mode`
   eval $FOO
  if [ -z "$SYSCFG_hostname" ] ; then
     SYSCFG_hostname="Utopia"
  fi
}
do_stop_dhcp() {
   ulog dhcp_link status "stopping dhcp client on bridge"
   if [ -f "$UDHCPC_PID_FILE" ] ; then
      kill -USR2 `cat $UDHCPC_PID_FILE` && kill `cat $UDHCPC_PID_FILE`
      rm -f $UDHCPC_PID_FILE
   else
      killall -USR2 udhcpc && killall udhcpc
      rm -f $UDHCPC_PID_FILE
   fi
   rm -f $LOG_FILE
}
do_start_dhcp() {
   if [ ! -f "$UDHCPC_PID_FILE" ] ; then
      ulog dhcp_link status "starting dhcp client on interface (ath8)"
      service_init
      udhcpc -S -b -i ath8 -p $UDHCPC_PID_FILE --arping -s $UDHCPC_SCRIPT
   elif [ "`cat $UDHCPC_PID_FILE`" != "`pidof udhcpc`" ] ; then
      echo "`pidof udhcpc`" |grep "`cat $UDHCPC_PID_FILE`"
      if [ $? = 1 ] ; then
          ulog dhcp_link status "dhcp client `cat $UDHCPC_PID_FILE` died"
          do_stop_dhcp
          ulog dhcp_link status "starting dhcp client on bridge (ath8)"
          udhcpc -S -b -i ath8 -p $UDHCPC_PID_FILE --arping -s $UDHCPC_SCRIPT
      else
          ulog dhcp_link status "dhcp client is already active on bridge (ath8) as `cat $UDHCPC_PID_FILE`"
      fi
   else
      ulog dhcp_link status "dhcp client is already active on bridge (ath8) as `cat $UDHCPC_PID_FILE`"
   fi
}
do_release_dhcp() {
   ulog dhcp_link status "releasing dhcp lease on ath8"
   service_init
   ip -4 addr flush dev ath8
   if [ -f "$UDHCPC_PID_FILE" ] ; then
      kill -SIGUSR2 `cat $UDHCPC_PID_FILE`
      RET=$?
      if [ "$RET" != "0" ] ; then
          rm -f $UDHCPC_PID_FILE
      fi      
   fi
}
do_renew_dhcp() {
   if [ "`syscfg get smart_mode::mode`" != "2" ] ; then
      ulog dhcp_link status "Requesting setup dhcp renew on (ath8), but not provisioned for dhcp."
      return 0
   fi
   ulog dhcp_link status "renewing dhcp lease on bridge"
   if [ -f "$UDHCPC_PID_FILE" ] ; then
        kill -SIGUSR1 `cat $UDHCPC_PID_FILE`
        RET=$?
        if [ "$RET" != "0" ] ; then
            rm -f $UDHCPC_PID_FILE
            do_start_dhcp
        fi
   else
       ulog dhcp_link status "restarting dhcp client on bridge"
       udhcpc -S -b -i ath8 -p $UDHCPC_PID_FILE --arping -s $UDHCPC_SCRIPT
   fi
}
[ -z "$1" ] && ulog dhcp_link status "$PID called with no parameters. Ignoring call" && exit 1
service_init
if [ -n "$broadcast" ] ; then
   BROADCAST="broadcast $broadcast"
else
   BROADCAST="broadcast +"
fi
[ -n "$subnet" ] && NETMASK="/$subnet"
ulog dhcp_link status "ms dhcp_link, sysevent received: $1"
case "$1" in
   ms_dhcp_client-stop)
      do_stop_dhcp
      ;;
   ms_dhcp_client-start)
      do_start_dhcp
      ;;
   ms_dhcp_client-release)
      do_release_dhcp
      ;;
   ms_dhcp_client-renew)
      do_renew_dhcp
      ;;
   leasefail)
      ulog dhcp_link status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router"
      ulog dhcp_link status "$PID wan dhcp lease renewal has failed"
      ip -4 addr flush dev ath8
      sysevent set ms_ip_addr
      sysevent set master_search_gateway
      ;;
   deconfig)
      ulog dhcp_link status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
      ulog dhcp_link status "$PID bridge dhcp lease has expired"
      rm -f $LOG_FILE
      ip -4 addr flush dev ath8
      sysevent set ms_ip_addr
      sysevent set master_search_gateway
      ;;
   renew|bound)
      ulog dhcp_link status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
      /sbin/ip -4 addr add $ip$NETMASK $BROADCAST dev $interface 
      sysevent set ms_ip_addr $ip
      sysevent set master_search_gateway $router
      ;;
   esac
exit 0
