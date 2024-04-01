#!/bin/sh
source /etc/init.d/ulog_functions.sh
PID="($$)"
SETUP_UDHCPC_PID_FILE=/var/run/setup_udhcpc.pid
SETUP_UDHCPC_SCRIPT=/etc/init.d/service_bridge/setup_dhcp_link.sh
SETUP_LOG_FILE="/tmp/setup_udhcpc.log"
BRIDGE_DEBUG_SETTING=`syscfg get bridge_debug`
DEBUG() 
{
    [ "$BRIDGE_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
service_init ()
{
  FOO=`utctx_cmd get hostname dhcpc_trusted_dhcp_server svap_lan_ifname`
  eval $FOO
  
  if [ -n "$SYSCFG_dhcpc_trusted_dhcp_server" ]
  then
     DHCPC_EXTRA_PARAMS="-X $SYSCFG_dhcpc_trusted_dhcp_server"
  fi
  if [ -z "$SYSCFG_hostname" ] ; then
     SYSCFG_hostname="Linksys SmartConnect"
  fi
  
  if [ "$INPUT_INTERFACE" != "" ] && [ "`cat /etc/product`" = "wraith" ]; then
      echo "@@@@@@ input interface is not NULL, so use it as the udhcpc client bind interface @@@@@"
      SYSCFG_svap_lan_ifname=$INPUT_INTERFACE
  fi
}
setup_do_stop_dhcp() {
   ulog dhcp_link status "stopping setup dhcp client on smart connect bridge"
   if [ -f "$SETUP_UDHCPC_PID_FILE" ] ; then
      kill -USR2 `cat $SETUP_UDHCPC_PID_FILE` && kill `cat $SETUP_UDHCPC_PID_FILE`
      rm -f $SETUP_UDHCPC_PID_FILE
   fi
   rm -f $SETUP_LOG_FILE
}
setup_do_start_dhcp() {
    if [ ! -f "$SETUP_UDHCPC_PID_FILE" ] ; then
        ulog dhcp_link status "starting setup dhcp client on smart connect bridge"
        service_init
        udhcpc -S -b -i $SYSCFG_svap_lan_ifname -h $SYSCFG_hostname -p $SETUP_UDHCPC_PID_FILE --arping -s $SETUP_UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
    elif [ "`cat $SETUP_UDHCPC_PID_FILE`" != "`pidof udhcpc`" ] ; then
        echo "`pidof udhcpc`" |grep "`cat $SETUP_UDHCPC_PID_FILE`"
        if [ $? = 1 ] ; then
            ulog dhcp_link status "setup dhcp client `cat $SETUP_UDHCPC_PID_FILE` died"
            setup_do_stop_dhcp
            ulog dhcp_link status "starting setup dhcp client on bridge ($SYSCFG_svap_lan_ifname)"
            udhcpc -S -b -i $SYSCFG_svap_lan_ifname -h $SYSCFG_hostname -p $SETUP_UDHCPC_PID_FILE --arping -s $SETUP_UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
        else
            ulog dhcp_link status "setup dhcp client is already active on bridge ($SYSCFG_svap_lan_ifname) as `cat $SETUP_UDHCPC_PID_FILE`"
        fi
    else
        ulog dhcp_link status "setup dhcp client is already active on bridge ($SYSCFG_svap_lan_ifname) as `cat $SETUP_UDHCPC_PID_FILE`"
    fi
}
setup_do_release_dhcp() {
   ulog dhcp_link status "releasing setup dhcp lease on smart connect bridge"
   service_init
   if [ -f "$SETUP_UDHCPC_PID_FILE" ] ; then
      kill -SIGUSR2 `cat $SETUP_UDHCPC_PID_FILE`
   fi
   ip -4 addr flush dev $SYSCFG_svap_lan_ifname
}
setup_do_renew_dhcp() {
   if [ "`syscfg get smart_mode::mode`" != "0" ] && [ "`syscfg get smart_mode::mode`" != "1" ] ; then
      ulog dhcp_link status "Requesting setup dhcp renew on ($WAN_IFNAME), but not provisioned for dhcp."
      return 0
   fi
   ulog dhcp_link status "renewing setup dhcp lease on bridge"
   service_init
    if [ -f "$SETUP_UDHCPC_PID_FILE" -a -d "/proc/$(cat $SETUP_UDHCPC_PID_FILE)" ] ; then
        kill -SIGUSR1 `cat $SETUP_UDHCPC_PID_FILE`
    else
       ulog dhcp_link status "restarting setup dhcp client on bridge"
       udhcpc -S -b -i $SYSCFG_svap_lan_ifname -h $SYSCFG_hostname -p $SETUP_UDHCPC_PID_FILE --arping -s $SETUP_UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
   fi
}
[ -z "$1" ] && ulog dhcp_link status "$PID called with no parameters. Ignoring call" && exit 1
INPUT_INTERFACE=$2
service_init
if [ -n "$broadcast" ] ; then
   BROADCAST="broadcast $broadcast"
else
   BROADCAST="broadcast +"
fi
[ -n "$subnet" ] && NETMASK="/$subnet"
case "$1" in
    setup_dhcp_client-stop)
        setup_do_stop_dhcp
    ;;
    setup_dhcp_client-start)
        setup_do_start_dhcp
    ;;
    setup_dhcp_client-restart)
        setup_do_stop_dhcp
        setup_do_start_dhcp
    ;;
    setup_dhcp_client-renew)
        setup_do_renew_dhcp
    ;;
    setup_dhcp_client-release)
        setup_do_release_dhcp
    ;;        
    leasefail)
        ulog dhcp_link status "setup udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router"
        ulog dhcp_link status "$PID wan dhcp lease renewal has failed"
    ;;
    deconfig)
        ulog dhcp_link status "setup udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
        ulog dhcp_link status "$PID interface $interface dhcp lease has expired"
        sysevent set setup_default_router
        rm -f $SETUP_LOG_FILE
    ;;
    renew|bound)
        ulog dhcp_link status "setup udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
        echo "interface     : $interface" > $SETUP_LOG_FILE
        echo "ip address    : $ip"        >> $SETUP_LOG_FILE
        echo "subnet mask   : $subnet"    >> $SETUP_LOG_FILE
        echo "broadcast     : $broadcast" >> $SETUP_LOG_FILE
        echo "lease time    : $lease"     >> $SETUP_LOG_FILE
        echo "router        : $router"    >> $SETUP_LOG_FILE
        echo "hostname      : $hostname"  >> $SETUP_LOG_FILE
        echo "domain        : $domain"    >> $SETUP_LOG_FILE
        echo "next server   : $siaddr"    >> $SETUP_LOG_FILE
        echo "server name   : $sname"     >> $SETUP_LOG_FILE
        echo "server id     : $serverid"  >> $SETUP_LOG_FILE
        echo "tftp server   : $tftp"      >> $SETUP_LOG_FILE
        echo "timezone      : $timezone"  >> $SETUP_LOG_FILE
        echo "time server   : $timesvr"   >> $SETUP_LOG_FILE
        echo "name server   : $namesvr"   >> $SETUP_LOG_FILE
        echo "ntp server    : $ntpsvr"    >> $SETUP_LOG_FILE
        echo "dns server    : $dns"       >> $SETUP_LOG_FILE
        echo "wins server   : $wins"      >> $SETUP_LOG_FILE
        echo "log server    : $logsvr"    >> $SETUP_LOG_FILE
        echo "cookie server : $cookiesvr" >> $SETUP_LOG_FILE
        echo "print server  : $lprsvr"    >> $SETUP_LOG_FILE
        echo "swap server   : $swapsvr"   >> $SETUP_LOG_FILE
        echo "boot file     : $boot_file" >> $SETUP_LOG_FILE
        echo "boot file name: $bootfile"  >> $SETUP_LOG_FILE
        echo "bootsize      : $bootsize"  >> $SETUP_LOG_FILE
        echo "root path     : $rootpath"  >> $SETUP_LOG_FILE
        echo "ip ttl        : $ipttl"     >> $SETUP_LOG_FILE
        echo "mtu           : $mtuipttl"  >> $SETUP_LOG_FILE
        OLDIP=`/sbin/ip addr show dev $interface  | grep "inet " | awk '{split($2,foo, "/"); print(foo[1]);}'`
        if [ "$OLDIP" != "$ip" ] ; then
            RESULT=`arping -q -c 2 -w 3 -D -I $interface $ip`
            if [ "" != "$RESULT" ] &&  [ "0" != "$RESULT" ] ; then
                echo "[utopia][setup dhcp client script] duplicate address detected $ip on $interface." > /dev/console
                echo "[utopia][setup dhcp client script] ignoring duplicate ... hoping for the best" > /dev/console
            fi
            
            if [ -n "$router" ] ; then
                sysevent set setup_default_router "$router"
                if [ "$router" != "`syscfg get smart_connect::serverip`" ] ; then
                    syscfg set smart_connect::serverip "$router"
                fi
            fi
            /sbin/ip -4 addr show dev $interface | grep "inet " | awk '{system("/sbin/ip addr del " $2 " dev $interface")}'
            /sbin/ip -4 addr add $ip$NETMASK $BROADCAST dev $interface 
            syscfg set ldal_wl_setup_vap_ipaddr $ip
            eval `ipcalc -n $ip $subnet`
            syscfg set ldal_wl_setup_vap_subnet $NETWORK
            sysevent set firewall-restart
        fi
        if [ "`cat /etc/product`" = "wraith" ]; then
            ip -4 addr flush br0
            route del -net 192.168.1.0 netmask 255.255.255.0 dev br0
        fi        
    ;;
esac
exit 0
