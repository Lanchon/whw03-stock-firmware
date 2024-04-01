#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/resolver_functions.sh
PID="($$)"
UDHCPC_PID_FILE=/var/run/bridge_udhcpc.pid
UDHCPC_SCRIPT=/etc/init.d/service_bridge/dhcp_link.sh
LOG_FILE="/tmp/udhcpc.log"
BRIDGE_DEBUG_SETTING=`syscfg get bridge_debug`
BBVERSION=`/bin/busybox | head -1 | awk '{print $2}' | sed -e 's/v//' | awk -F'.' '{print $1*10000+$2*100+$3}'`
DEBUG() 
{
    [ "$BRIDGE_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
service_init ()
{
   FOO=`utctx_cmd get lan_ifname hostname dhcpc_trusted_dhcp_server hardware_vendor_name bridge_mode lan_ethernet_physical_ifnames wifi_bridge::mode smart_mode::mode`
   eval $FOO
  if [ -n "$SYSCFG_dhcpc_trusted_dhcp_server" ]
  then
     DHCPC_EXTRA_PARAMS="-X $SYSCFG_dhcpc_trusted_dhcp_server"
  fi
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
   if [ "`syscfg get smart_mode::mode`" = "1" ] ; then
       /sbin/ip -4 addr show dev br0 | grep "inet " | awk '{system("/sbin/ip addr del " $2 " dev br0")}'
       do_random
   else
       ip -4 addr flush dev $SYSCFG_lan_ifname
   fi
   sysevent set current_ipv4_wan_state down
}
do_start_dhcp() {
    if [ $BBVERSION -ge 12501 ]; then
        HOSTNAME_OPT="-x hostname:$SYSCFG_hostname"
    else
        HOSTNAME_OPT="-h $SYSCFG_hostname"
    fi
    if [ ! -f "$UDHCPC_PID_FILE" ] ; then
      ulog dhcp_link status "starting dhcp client on bridge ($WAN_IFNAME)"
      service_init
      udhcpc -S -b -i $SYSCFG_lan_ifname $HOSTNAME_OPT -p $UDHCPC_PID_FILE --arping -s $UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
   elif [ "`cat $UDHCPC_PID_FILE`" != "`pidof udhcpc`" ] ; then
      echo "`pidof udhcpc`" |grep "`cat $UDHCPC_PID_FILE`"
      if [ $? = 1 ] ; then
          ulog dhcp_link status "dhcp client `cat $UDHCPC_PID_FILE` died"
          do_stop_dhcp
          ulog dhcp_link status "starting dhcp client on bridge ($SYSCFG_lan_ifname)"
          udhcpc -S -b -i $SYSCFG_lan_ifname $HOSTNAME_OPT -p $UDHCPC_PID_FILE --arping -s $UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
      else
          ulog dhcp_link status "dhcp client is already active on bridge ($SYSCFG_lan_ifname) as `cat $UDHCPC_PID_FILE`"
      fi
   else
      ulog dhcp_link status "dhcp client is already active on bridge ($SYSCFG_lan_ifname) as `cat $UDHCPC_PID_FILE`"
   fi
    sysevent set current_ipv4_wan_state up
}
do_release_dhcp() {
   ulog dhcp_link status "releasing dhcp lease on bridge"
   service_init
   if [ -f "$UDHCPC_PID_FILE" ] ; then
      kill -SIGUSR2 `cat $UDHCPC_PID_FILE`
   fi
   if [ "`syscfg get smart_mode::mode`" = "1" ] ; then
       /sbin/ip -4 addr show dev br0 | grep "inet " | awk '{system("/sbin/ip addr del " $2 " dev br0")}'
       do_random
   else
       ip -4 addr flush dev $SYSCFG_lan_ifname
   fi
}
do_renew_dhcp() {
    if [ $BBVERSION -ge 12501 ]; then
        HOSTNAME_OPT="-x hostname:$SYSCFG_hostname"
    else
        HOSTNAME_OPT="-h $SYSCFG_hostname"
    fi
   if [ "1" != "`syscfg get bridge_mode`" ] && [ "`cat /etc/product`" != "nodes" ] && [ "`cat /etc/product`" != "wraith" ] && [ "`cat /etc/product`" != "nodes-jr" ] && [ "`cat /etc/product`" != "dallas" ] && [ "`cat /etc/product`" != "rogue" ] && [ "`cat /etc/product`" != "lion" ] ; then
      ulog dhcp_link status "Requesting dhcp renew on ($WAN_IFNAME), but not provisioned for dhcp."
      return 0
   fi
   if [ "`syscfg get smart_mode::mode`" != "0" ] && [ "`syscfg get smart_mode::mode`" != "1" ] ; then
      ulog dhcp_link status "Requesting setup dhcp renew on ($WAN_IFNAME), but not provisioned for dhcp."
      return 0
   fi
   ulog dhcp_link status "renewing dhcp lease on bridge"
   if [ -f "$UDHCPC_PID_FILE" -a -d "/proc/$(cat $UDHCPC_PID_FILE)" ] ; then
        kill -SIGUSR1 `cat $UDHCPC_PID_FILE`
    else
       ulog dhcp_link status "restarting dhcp client on bridge"
       udhcpc -S -b -i $SYSCFG_lan_ifname $HOSTNAME_OPT -p $UDHCPC_PID_FILE --arping -s $UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
   fi
}
do_random() {
   ifname=$1
   if [ "$ifname" = "" ] ; then
      ifname="br0"
   fi
   BYTE3=0x`ip link show $ifname | grep link | awk '{print $2}' | awk 'BEGIN { FS = ":" } ; { printf ("%s", $6) }'`
   BYTE3=`echo $BYTE3 | awk ' {printf ("%d", $1)}'`
   
   BYTE2=0x`ip link show $ifname | grep link | awk '{print $2}' | awk 'BEGIN { FS = ":" } ; { printf ("%s", $5) }'`
   BYTE2=`echo $BYTE2 | awk ' {printf ("%d", $1)}'`
 
   RANDOM=`expr $BYTE3 \* $BYTE2`
   OCTET3=`expr $RANDOM % 256`
   RANDOM=`expr $RANDOM - $BYTE3`
   OCTET4=`expr $RANDOM % 255`
   if [ "0" -eq $OCTET4 ] ; then
      OCTET4=65
   fi
   /sbin/ip -4 addr add 169.254.$OCTET3.$OCTET4/255.255.0.0 dev $ifname
   /sbin/ip -4 link set dev $ifname up
}
[ -z "$1" ] && ulog dhcp_link status "$PID called with no parameters. Ignoring call" && exit 1
service_init
CURRENT_STATE=`sysevent get current_ipv4_wan_state`
PHYLINK_STATE=`sysevent get phylink_wan_state`
if [ -n "$broadcast" ] ; then
   BROADCAST="broadcast $broadcast"
else
   BROADCAST="broadcast +"
fi
[ -n "$subnet" ] && NETMASK="/$subnet"
ulog dhcp_link status "bridge dhcp_link, sysevent received: $1"
case "$1" in
   dhcp_client-stop)
      do_stop_dhcp
      ;;
   dhcp_client-start)
      do_start_dhcp
      ;;
   dhcp_client-restart)
      do_start_dhcp
      ;;
   dhcp_client-release)
      do_release_dhcp
      ;;
   dhcp_client-renew)
      do_renew_dhcp
      ;;
   phylink_wan_state)
		    ulog dhcp_link status "$PID physical link is $PHYLINK_STATE"
		    if [ "up" != "$PHYLINK_STATE" ] ; then
		        if [ "up" = "$CURRENT_STATE" ] ; then
		            ulog dhcp_link status "$PID physical link is down. Setting link down."
		            do_stop_dhcp
		            exit 0
		        else
		            ulog dhcp_link status "$PID physical link is down. Link is already down."
		            exit 0
		        fi
		    else
		        if [ "up" = "$CURRENT_STATE" ] ; then
		            ulog dhcp_link status "$PID physical link is up. Link is already up."
		        else
		            if [ "$SYSCFG_bridge_mode" = "1" ] ; then
		                ulog dhcp_link status "$PID starting dhcp client"
		                do_start_dhcp
		                exit 0
		            fi
		        fi
		    fi
        ;;
   leasefail)
      ulog dhcp_link status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router"
      ulog dhcp_link status "$PID wan dhcp lease renewal has failed"
      OLDIP=`/sbin/ip addr show dev $interface  | grep "inet " | awk '{split($2,foo, "/"); print(foo[1]);}'`
      OCTET1=`/sbin/ip -4 addr show dev $interface | grep "inet" | awk '{split($2,foo, "/"); print (foo[1]);}' | awk 'BEGIN {FS = "."};{print $1}'`
      OCTET2=`/sbin/ip -4 addr show dev $interface | grep "inet" | awk '{split($2,foo, "/"); print (foo[1]);}' | awk 'BEGIN {FS = "."};{print $2}'`
      OLDNETMASK=`/sbin/ip addr show dev $interface | grep "inet " | awk '{split($2, foo, "/"); print(foo[2]);}'`
      if [ -n "$OLDIP" ] ; then
         if [ "$OCTET1" != "169" -o "$OCTET2" != "254" ] ; then
            /sbin/ip -4 addr del $OLDIP/$OLDNETMASK dev $interface
         else
            ulog dhcp_link status "don't bring down br0"
         fi
      fi
      if [ "$OCTET1" != "169" -o "$OCTET2" != "254" ] ; then
         do_random $interface
      else
         ulog dhcp_link status "skip do_random"
         exit 0
      fi
      sysevent set wan_dhcp_lease
      sysevent set wan_dynamic_dns
      prepare_resolver_conf
      sysevent set lan-started
      sysevent set lan-errinfo
      sysevent set lan-status started
      ;;
   deconfig)
      ulog dhcp_link status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
      ulog dhcp_link status "$PID bridge dhcp lease has expired"
      rm -f $LOG_FILE
      sysevent set dhcpc_ntp_server1
      sysevent set dhcpc_ntp_server2
      sysevent set dhcpc_ntp_server3
      sysevent set ipv4_wan_ipaddr 0.0.0.0
      sysevent set ipv4_wan_subnet 0.0.0.0
      sysevent set default_router
      sysevent set wan_dhcp_lease
      sysevent set wan_dynamic_dns
      sysevent set dhcp_domain
      ;;
   renew|bound)
      ulog dhcp_link status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
      echo "interface     : $interface" > $LOG_FILE
      echo "ip address    : $ip"        >> $LOG_FILE
      echo "subnet mask   : $subnet"    >> $LOG_FILE
      echo "broadcast     : $broadcast" >> $LOG_FILE
      echo "lease time    : $lease"     >> $LOG_FILE
      echo "router        : $router"    >> $LOG_FILE
      echo "hostname      : $hostname"  >> $LOG_FILE
      echo "domain        : $domain"    >> $LOG_FILE
      echo "next server   : $siaddr"    >> $LOG_FILE
      echo "server name   : $sname"     >> $LOG_FILE
      echo "server id     : $serverid"  >> $LOG_FILE
      echo "tftp server   : $tftp"      >> $LOG_FILE
      echo "timezone      : $timezone"  >> $LOG_FILE
      echo "time server   : $timesvr"   >> $LOG_FILE
      echo "name server   : $namesvr"   >> $LOG_FILE
      echo "ntp server    : $ntpsvr"    >> $LOG_FILE
      echo "dns server    : $dns"       >> $LOG_FILE
      echo "wins server   : $wins"      >> $LOG_FILE
      echo "log server    : $logsvr"    >> $LOG_FILE
      echo "cookie server : $cookiesvr" >> $LOG_FILE
      echo "print server  : $lprsvr"    >> $LOG_FILE
      echo "swap server   : $swapsvr"   >> $LOG_FILE
      echo "boot file     : $boot_file" >> $LOG_FILE
      echo "boot file name: $bootfile"  >> $LOG_FILE
      echo "bootsize      : $bootsize"  >> $LOG_FILE
      echo "root path     : $rootpath"  >> $LOG_FILE
      echo "ip ttl        : $ipttl"     >> $LOG_FILE
      echo "mtu           : $mtuipttl"  >> $LOG_FILE
      if [ -n "$lease" ] ; then
         sysevent set wan_dhcp_lease $lease 
      fi
      if [ -n "$subnet" ] ; then
         sysevent set ipv4_wan_subnet $subnet 
      fi
      OLDIP=`/sbin/ip addr show dev $interface  | grep "inet " | awk '{split($2,foo, "/"); print(foo[1]);}'`
      if [ "$OLDIP" != "$ip" ] ; then
         RESULT=`arping -q -c 2 -w 3 -D -I $interface $ip`
         if [ "" != "$RESULT" ] &&  [ "0" != "$RESULT" ] ; then
            echo "[utopia][dhcp client script] duplicate address detected $ip on $interface." > /dev/console
            echo "[utopia][dhcp client script] ignoring duplicate ... hoping for the best" > /dev/console
         fi
         /sbin/ip -4 addr show dev $interface | grep "inet " | awk '{system("/sbin/ip addr del " $2 " dev $interface")}'
         /sbin/ip -4 addr add $ip$NETMASK $BROADCAST dev $interface 
      fi
      if [ -n "$router" ] ; then
            while ip -4 route del default dev $interface ; do
               :
            done
            for i in $router ; do
               ip -4 route add default dev $interface via $i      
               sysevent set default_router $i 
            done
            ip -4 route flush cache
      fi
      sysevent set dhcpc_ntp_server1 
      sysevent set dhcpc_ntp_server2 
      sysevent set dhcpc_ntp_server3 
      if [ -n "$domain" ] ; then
         sysevent set dhcp_domain "${domain}"
      fi
      if [ -n "$dns" ] ; then
         sysevent set wan_dynamic_dns "${dns}"
      fi
      prepare_resolver_conf
      NTPSERVER1=
      NTPSERVER2=
      for ii in $ntpsrv ; do
         if [ "" = "$NTPSERVER1" ] ; then
            NTPSERVER1=$ii
            `sysevent set dhcpc_ntp_server1 $NTPSERVER1`
         elif [ "" = "$NTPSERVER2" ] ; then
            NTPSERVER2=$ii
            `sysevent set dhcpc_ntp_server2 $NTPSERVER2`
         else
            `sysevent set dhcpc_ntp_server3 $ii`
         fi
      done
      WAN_IPADDR=`sysevent get ipv4_wan_ipaddr`
      WAN_NETMASK=`sysevent get ipv4_wan_netmask`
      WAN_GATEWAY=`sysevent get default_router`
      PRODUCT="$(cat /etc/product)"
      if [ "$ip" != "$WAN_IPADDR" ] || [ "$subnet" != "$WAN_NETMASK" ] || [ "$router" != "$WAN_GATEWAY" ] ; then
          sysevent set ipv4_wan_ipaddr $ip
          sysevent set ipv4_wan_netmask $subnet
          sysevent set default_router $router
          sysevent set firewall-restart
          LAST_DHCP_IP=""
          backhaul_intf=$(sysevent get backhaul::intf)
          if [ "$PRODUCT" = "nodes" ] || [ "$PRODUCT" = "nodes-jr" ] ; then
            if [ "$LAST_DHCP_IP" != "$ip" ] && [ "${SYSCFG_smart_mode_mode}" = "1" ] && [ "${backhaul_intf:0:3}" = "ath" ] && [ "$(sysevent get backhaul::media)" != "1" ]  ; then
                reset_ethernet_port_with_portnum "3 4"
            fi
          elif [  "$PRODUCT" = "dallas" ] || [  "$PRODUCT" = "rogue" ] || [  "$PRODUCT" = "lion" ] ; then
            if [ "$LAST_DHCP_IP" != "$ip" ] && [ "${SYSCFG_smart_mode_mode}" = "1" ] && [ "${backhaul_intf:0:3}" = "ath" ] && [ "$(sysevent get backhaul::media)" != "1" ] ; then
                reset_ethernet_port_with_portnum "0 1 2 3 4"
            elif [ "${SYSCFG_smart_mode_mode}" = "2" ] ; then
                reset_ethernet_ports
            fi
          else
              reset_ethernet_ports
          fi
          if [ "$LAST_DHCP_IP" = "" ] || [ "$LAST_DHCP_IP" != "$ip" ] ; then
              sysevent set last_dhcp_ip $ip
          fi          
          sysevent set wifi_renew_clients
          prepare_hostname
          sysevent set lan-started
          sysevent set lan-errinfo
          sysevent set lan-status started
          sysevent set wan-status started
          sysevent set wan-started
          if [ "$SYSCFG_wifi_bridge_mode" = "0" ] ; then
                sysevent set backhaul_ifname_list $SYSCFG_lan_ethernet_physical_ifnames
          fi
      fi
      ;;
   esac
exit 0
