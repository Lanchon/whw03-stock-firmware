#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/ipv6_functions.sh
source /etc/init.d/resolver_functions.sh
DESIRED_WAN_STATE=`sysevent get desired_ipv6_wan_state`
CURRENT_WAN_STATE=`sysevent get current_ipv6_wan_state`
CURRENT_LINK_STATE=`sysevent get current_ipv6_link_state`
PID="($$)"
PASS6_MODE_FILE='/proc/sys/net/edma/ipv6_passthru_mode'
service_init ()
{
   eval `utctx_cmd get ipv6_enable ipv6_verbose_logging lan_ifname`
   SYSEVENT_current_lan_ipv6address=`sysevent get current_lan_ipv6address`
   if [ "1" = "$SYSCFG_ipv6_verbose_logging" ] ; then
      LOG=/var/log/ipv6.log
   else
      LOG=/dev/null
   fi
}
bring_wan_down() {
   ulog ipv6 passthrough "passthrough_wan.sh: bring wan down"
   echo "passthrough_wan.sh: bring wan down" >> $LOG
   sysevent set ipv6_connection_state "ipv6 passthough going down"
   sysevent set ipv6-errinfo
   sysevent set ipv6-status stopping
   echo 0 > /proc/sys/net/ipv6/conf/$SYSCFG_lan_ifname/accept_ra
   echo 0 > /proc/sys/net/ipv6/conf/$SYSCFG_lan_ifname/accept_ra_defrtr
   echo 0 > /proc/sys/net/ipv6/conf/$SYSCFG_lan_ifname/accept_ra_pinfo
   echo 0 > /proc/sys/net/ipv6/conf/$SYSCFG_lan_ifname/autoconf
   if [ "1" != "`syscfg get ipv6::passthrough_done_in_hw`" ] ; then
       ulog ipv6 passthrough "unloading ipv6_passthrough.ko"
       echo "passthrough_wan.sh: unloading ipv6_passthrough.ko" >> $LOG
        
       modprobe -r ipv6_passthrough.ko
       WAN=`sysevent get current_wan_ipv6_ifname`
       LAN=`syscfg get lan_ifname`
       ulog ipv6 passthrough "turning off promiscuous mode for $WAN and $LAN"
       echo "passthrough_wan.sh: turning off promiscuous mode for $WAN and $LAN" >> $LOG
       ifconfig $LAN -promisc
       ifconfig $WAN -promisc
      else
       echo 0 > $PASS6_MODE_FILE
   fi
   sysevent set ipv6_connection_state "ipv6 passthrough down"
   ulog ipv6 passthrough "force clients to renew DHCP lease"
   reset_ethernet_ports
   sysevent set wifi_renew_clients
   sysevent set ipv6_firewall-restart
   sysevent set current_ipv6_wan_state down
   sysevent set ipv6-status stopped
}
bring_wan_up() {
   ulog ipv6 passthrough "passthrough_wan.sh: bring wan up"
   echo "passthrough_wan.sh: bring wan up" >> $LOG
   if [ "0" = "$SYSCFG_ipv6_enable" ] 
   then
      exit 0
   fi
   sysevent set ipv6_connection_state "ipv6 passthrough going up"
   echo 1 > /proc/sys/net/ipv6/conf/$SYSCFG_lan_ifname/accept_ra        # Accept RA even when forwarding is enabled
   echo 1 > /proc/sys/net/ipv6/conf/$SYSCFG_lan_ifname/accept_ra_defrtr # Accept default router (metric 1024)
   echo 1 > /proc/sys/net/ipv6/conf/$SYSCFG_lan_ifname/accept_ra_pinfo  # Accept prefix information for SLAAC
   echo 1 > /proc/sys/net/ipv6/conf/$SYSCFG_lan_ifname/autoconf         # Do SLAAC
   if [ "1" != "`syscfg get ipv6::passthrough_done_in_hw`" ] ; then
       WAN=`sysevent get current_wan_ipv6_ifname`
       LAN=`syscfg get lan_ifname`
       ulog ipv6 passthrough "loading ipv6_passthrough.ko wan=$WAN lan=$LAN"
       echo "passthrough_wan.sh: loading ipv6_passthrough.ko wan=$WAN lan=$LAN" >> $LOG
       modprobe ipv6_passthrough.ko wan=$WAN lan=$LAN
       ulog ipv6 passthrough "turning on promiscuous mode for $WAN and $LAN"
       echo "passthrough_wan.sh: turning on promiscuous mode for $WAN and $LAN" >> $LOG
       ifconfig $LAN promisc
       ifconfig $WAN promisc
   else
    case "$(sysevent get current_wan_ipv6_ifname)" in
     eth0)
      PASS6_MODE=1
      ;;
     eth1)
      PASS6_MODE=3
      ;;
    esac
    if [ -n "$PASS6_MODE" ] && [ $PASS6_MODE != "$(cat $PASS6_MODE_FILE)" ]; then
     echo $PASS6_MODE > $PASS6_MODE_FILE
    fi
   fi
   sysevent set ipv6_connection_state "ipv6 passthrough up"
   ulog ipv6 passthrough "force clients to renew DHCP lease"
   reset_ethernet_ports
   sysevent set wifi_renew_clients
   sysevent set current_ipv6_wan_state up
   sysevent set ipv6_firewall-restart
   sysevent set ipv6_wan_start_time `cat /proc/uptime | cut -d'.' -f1`
   sysevent set ipv6-status started
}
service_init
ulog ipv6 passthrough "passthrough_wan.sh: Entry: parameter=$1"
case "$1" in
   current_ipv6_link_state)
      ulog ipv6 passthrough "$PID ipv6 link state is $CURRENT_LINK_STATE"
      if [ "up" != "$CURRENT_LINK_STATE" ] ; then
         if [ "up" = "$CURRENT_WAN_STATE" ] ; then
            ulog ipv6 passthrough "$PID ipv6 link is down. Tearing down wan"
            bring_wan_down
            exit 0
         else
            ulog ipv6 passthrough "$PID ipv6 link is down. Wan is already down"
            exit 0
         fi
      else
         if [ "up" = "$CURRENT_WAN_STATE" ] ; then
            ulog ipv6 passthrough "$PID ipv6 link is up. Wan is already up"
            exit 0
         else
            if [ "up" = "$DESIRED_WAN_STATE" ] ; then
               bring_wan_up
               exit 0
            else
               ulog ipv6 passthrough "$PID ipv6 link is up. Wan is not requested up"
               exit 0
            fi
         fi
      fi
      ;;
   desired_ipv6_wan_state)
      CURRENT_IPV6_STATUS=`sysevent get ipv6_wan-status`
      if [ "up" = "$DESIRED_WAN_STATE" ] ; then
         if [ "up" = "$CURRENT_WAN_STATE" ] ; then
            ulog ipv6 passthrough "$PID wan is already up."
            exit 0
         else
            if [ "up" != "$CURRENT_LINK_STATE" ] ; then
               ulog ipv6 passthrough "$PID wan up request deferred until link is up"
               exit 0
            else
               bring_wan_up
               exit 0
            fi
         fi
      else
         if [ "up" != "$CURRENT_WAN_STATE" ] ; then
            ulog ipv6 passthrough "$PID wan is already down."
            if [ "stopped" != "$CURRENT_IPV6_STATUS" ] ; then
               sysevent set ipv6-status stopped
               sysevent set ipv6_firewall-restart
            fi
         else
            bring_wan_down
         fi
      fi
      ;;
 *)
      ulog ipv6 passthrough "$PID Invalid parameter $1 "
      exit 3
      ;;
esac
