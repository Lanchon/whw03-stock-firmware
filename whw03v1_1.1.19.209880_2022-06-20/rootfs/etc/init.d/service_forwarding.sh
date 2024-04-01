#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="forwarding"
PID="($$)"
service_init ()
{
   echo 2 > /proc/sys/net/ipv4/conf/all/arp_ignore
   SYSCFG_FAILED='false'
   FOO=`utctx_cmd get bridge_mode ldal_wl_lego_device_type lan_ifname`
   eval $FOO
   if [ $SYSCFG_FAILED = 'true' ] ; then
      ulog forwarding status "$PID utctx failed to get some configuration data required by service-forwarding"
      ulog forwarding status "$PID THE SYSTEM IS NOT SANE"
      echo "[utopia] utctx failed to get some configuration data required by service-system" > /dev/console
      echo "[utopia] THE SYSTEM IS NOT SANE" > /dev/console
      sysevent set ${SERVICE_NAME}-status error
      sysevent set ${SERVICE_NAME}-errinfo "Unable to get crucial information from syscfg"
      exit
   fi
}
service_start ()
{
   wait_till_end_state ${SERVICE_NAME}
   STATUS=`sysevent get ${SERVICE_NAME}-status`
   if [ "started" != "$STATUS" ] ; then
      ulog forwarding status "$PID forwarding is starting"
      sysevent set ${SERVICE_NAME}-status starting 
      sysevent set ${SERVICE_NAME}-errinfo 
      STATUS=`sysevent get guest_access-status`
      if [ "started" != "$STATUS" ] ; then
            ulog forwarding status "starting guest_access"
            sysevent set guest_access-start
      fi 
      brctl addbr $SYSCFG_lan_ifname
      LAN_MAC=`syscfg get lan_mac_addr`
      LAN_HWADDR=`ifconfig $SYSCFG_lan_ifname | grep HWaddr | awk '{print $5}'`
      if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ -n "$LAN_MAC" ] && [ "$LAN_MAC" != "$LAN_HWADDR" ] ; then
         ifconfig $SYSCFG_lan_ifname hw ether "$LAN_MAC"
      fi
      sysevent set lrhk-start
      if [ "1" = "$SYSCFG_bridge_mode" ] || [ "2" = "$SYSCFG_bridge_mode" ] ; then
         ulog forwarding status "starting bridge"
         sysevent set bridge-start
      else
         if [ "LegoExtender" != "$SYSCFG_ldal_wl_lego_device_type" ]; then
	     ulog forwarding status "starting wan"
    	     sysevent set wan-start
	     fi
         
         STATUS=`sysevent get lan-status`
         if [ "started" != "$STATUS" ] ; then
            ulog forwarding status "starting lan"
            sysevent set lan-start
            sleep 1 
         fi
    	 wait_till_end_state lan
         
         if [ "LegoExtender" = "$SYSCFG_ldal_wl_lego_device_type" ]; then
            MAXWAIT=30               
            CNT=0           
            while [ $CNT -lt $MAXWIAT ]
            do
                STATUS=`sysevent get ldal_station_connect`
                if [ "started" = "$STATUS" ] ; then 
                	break                             
                fi                    
                sleep 1                    
                CNT=`expr $CNT + 1`          
            done
         fi
         STATUS=`sysevent get firewall-status`
         if [ "stopped" = "$STATUS" ] ; then
            ulog forwarding status "starting firewall"
            sysevent set firewall-restart
         fi
      fi
      ulog forwarding status "starting ipv6"
      sysevent set ipv6-start
      if [ "LegoPlus" = "$SYSCFG_ldal_wl_lego_device_type" ]; then
         echo "Start EDAL Server" > /dev/console
         sysevent set edal_server-start
      fi
      sysevent set ${SERVICE_NAME}-status started 
      ulog forwarding status "$PID forwarding is started"
   fi
}
service_stop ()
{
   sysevent set lrhk-stop
   sysevent set ipv6-stop
   ulog forwarding status "$PID wan/bridge is stopping"
   sysevent set ${SERVICE_NAME}-status stopping 
   sysevent set edal_server-stop
   /etc/init.d/service_lan.sh lan-stop
   sysevent set bridge-stop
   sysevent set wan-stop
   sysevent set smart_connect-stop
   sleep 1
   wait_till_end_state lan
   wait_till_end_state bridge
   wait_till_end_state wan
   sysevent set ${SERVICE_NAME}-status stopped 
   ulog forwarding status "$PID forwarding is stopped"
}
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
      if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "wraith" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
          /usr/sbin/vlan_setup.sh
      fi
      service_start
      ;;
   *)
      echo "Usage: service-${SERVICE_NAME} [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
      exit 3
      ;;
esac
