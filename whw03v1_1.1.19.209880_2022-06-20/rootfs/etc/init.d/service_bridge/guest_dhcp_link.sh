#!/bin/sh
source /etc/init.d/ulog_functions.sh
PID="($$)"
GUEST_UDHCPC_PID_FILE=/var/run/guest_udhcpc.pid
GUEST_UDHCPC_SCRIPT=/etc/init.d/service_bridge/guest_dhcp_link.sh
GUEST_LOG_FILE="/tmp/guest_udhcpc.log"
BRIDGE_DEBUG_SETTING=`syscfg get bridge_debug`
DEBUG() 
{
    [ "$BRIDGE_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
service_init ()
{
   FOO=`utctx_cmd get hostname dhcpc_trusted_dhcp_server hardware_vendor_name bridge_mode guest_lan_ifname`
   eval $FOO
  if [ -n "$SYSCFG_dhcpc_trusted_dhcp_server" ]
  then
     DHCPC_EXTRA_PARAMS="-X $SYSCFG_dhcpc_trusted_dhcp_server"
  fi
  if [ -z "$SYSCFG_hostname" ] ; then
     SYSCFG_hostname="Utopia"
  fi
}
guest_do_stop_dhcp() {
   ulog dhcp_link status "stopping dhcp client on guest bridge"
   if [ -f "$GUEST_UDHCPC_PID_FILE" ] ; then
      kill -USR2 `cat $GUEST_UDHCPC_PID_FILE` && kill `cat $GUEST_UDHCPC_PID_FILE`
      rm -f $GUEST_UDHCPC_PID_FILE
   fi
   rm -f $GUEST_LOG_FILE
}
guest_do_start_dhcp() {
    if [ ! -f "$GUEST_UDHCPC_PID_FILE" ] ; then
        ulog dhcp_link status "starting dhcp client on guest bridge"
        service_init
        udhcpc -S -b -i $SYSCFG_guest_lan_ifname -h $SYSCFG_hostname -p $GUEST_UDHCPC_PID_FILE --arping -s $GUEST_UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
    elif [ "`cat $GUEST_UDHCPC_PID_FILE`" != "`pidof udhcpc`" ] ; then
        echo "`pidof udhcpc`" |grep "`cat $GUEST_UDHCPC_PID_FILE`"
        if [ $? = 1 ] ; then
            ulog dhcp_link status "dhcp client `cat $GUEST_UDHCPC_PID_FILE` died"
            guest_do_stop_dhcp
            ulog dhcp_link status "starting dhcp client on bridge ($SYSCFG_guest_lan_ifname)"
            udhcpc -S -b -i $SYSCFG_guest_lan_ifname -h $SYSCFG_hostname -p $GUEST_UDHCPC_PID_FILE --arping -s $GUEST_UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
        else
            ulog dhcp_link status "dhcp client is already active on bridge ($SYSCFG_guest_lan_ifname) as `cat $GUEST_UDHCPC_PID_FILE`"
        fi
    else
        ulog dhcp_link status "dhcp client is already active on bridge ($SYSCFG_guest_lan_ifname) as `cat $GUEST_UDHCPC_PID_FILE`"
    fi
}
guest_do_release_dhcp() {
   ulog dhcp_link status "releasing dhcp lease on guest bridge"
   service_init
   if [ -f "$GUEST_UDHCPC_PID_FILE" ] ; then
      kill -SIGUSR2 `cat $GUEST_UDHCPC_PID_FILE`
   fi
   ip -4 addr flush dev $SYSCFG_guest_lan_ifname
}
guest_do_renew_dhcp() {
   if [ "1" != "`syscfg get bridge_mode`" ] ; then
      ulog dhcp_link status "Requesting dhcp renew on ($WAN_IFNAME), but not provisioned for dhcp."
      return 0
   fi
   ulog dhcp_link status "renewing dhcp lease on bridge"
    if [ -f "$GUEST_UDHCPC_PID_FILE" ] ; then
        kill -SIGUSR1 `cat $GUEST_UDHCPC_PID_FILE`
    else
       ulog dhcp_link status "restarting dhcp client on bridge"
       udhcpc -S -b -i $SYSCFG_guest_lan_ifname -h $SYSCFG_hostname -p $GUEST_UDHCPC_PID_FILE --arping -s $GUEST_UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
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
case "$1" in
    guest_dhcp_client-stop)
        guest_do_stop_dhcp
    ;;
    guest_dhcp_client-start)
        guest_do_start_dhcp
    ;;
    guest_dhcp_client-restart)
        guest_do_stop_dhcp
        guest_do_start_dhcp
    ;;
    leasefail)
        ulog dhcp_link status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router"
        ulog dhcp_link status "$PID wan dhcp lease renewal has failed"
    ;;
    deconfig)
        ulog dhcp_link status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
        ulog dhcp_link status "$PID interface $interface dhcp lease has expired"
        rm -f $GUEST_LOG_FILE
    ;;
    bound)
        ulog dhcp_link status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
        echo "interface     : $interface" > $GUEST_LOG_FILE
        echo "ip address    : $ip"        >> $GUEST_LOG_FILE
        echo "subnet mask   : $subnet"    >> $GUEST_LOG_FILE
        echo "broadcast     : $broadcast" >> $GUEST_LOG_FILE
        echo "lease time    : $lease"     >> $GUEST_LOG_FILE
        echo "router        : $router"    >> $GUEST_LOG_FILE
        echo "hostname      : $hostname"  >> $GUEST_LOG_FILE
        echo "domain        : $domain"    >> $GUEST_LOG_FILE
        echo "next server   : $siaddr"    >> $GUEST_LOG_FILE
        echo "server name   : $sname"     >> $GUEST_LOG_FILE
        echo "server id     : $serverid"  >> $GUEST_LOG_FILE
        echo "tftp server   : $tftp"      >> $GUEST_LOG_FILE
        echo "timezone      : $timezone"  >> $GUEST_LOG_FILE
        echo "time server   : $timesvr"   >> $GUEST_LOG_FILE
        echo "name server   : $namesvr"   >> $GUEST_LOG_FILE
        echo "ntp server    : $ntpsvr"    >> $GUEST_LOG_FILE
        echo "dns server    : $dns"       >> $GUEST_LOG_FILE
        echo "wins server   : $wins"      >> $GUEST_LOG_FILE
        echo "log server    : $logsvr"    >> $GUEST_LOG_FILE
        echo "cookie server : $cookiesvr" >> $GUEST_LOG_FILE
        echo "print server  : $lprsvr"    >> $GUEST_LOG_FILE
        echo "swap server   : $swapsvr"   >> $GUEST_LOG_FILE
        echo "boot file     : $boot_file" >> $GUEST_LOG_FILE
        echo "boot file name: $bootfile"  >> $GUEST_LOG_FILE
        echo "bootsize      : $bootsize"  >> $GUEST_LOG_FILE
        echo "root path     : $rootpath"  >> $GUEST_LOG_FILE
        echo "ip ttl        : $ipttl"     >> $GUEST_LOG_FILE
        echo "mtu           : $mtuipttl"  >> $GUEST_LOG_FILE
        OLDIP=`/sbin/ip addr show dev $interface  | grep "inet " | awk '{split($2,foo, "/"); print(foo[1]);}'`
        if [ "$OLDIP" != "$ip" ] ; then
            RESULT=`arping -q -c 2 -w 3 -D -I $interface $ip`
            if [ "" != "$RESULT" ] &&  [ "0" != "$RESULT" ] ; then
                echo "[utopia][dhcp client script] duplicate address detected $ip on $interface." > /dev/console
                echo "[utopia][dhcp client script] ignoring duplicate ... hoping for the best" > /dev/console
            fi
            /sbin/ip -4 addr show dev $interface | grep "inet " | awk '{system("/sbin/ip addr del " $2 " dev $interface")}'
            /sbin/ip -4 addr add $ip$NETMASK $BROADCAST dev $interface 
            syscfg set guest_lan_ipaddr $ip
            eval `ipcalc -n $ip $subnet`
            syscfg set guest_subnet $NETWORK
            sysevent set firewall-restart
        fi
    ;;
esac
exit 0
