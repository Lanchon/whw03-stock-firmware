#!/bin/sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/network_functions.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/resolver_functions.sh
if [ -f /etc/init.d/brcm_ethernet_helper.sh ]; then
    source /etc/init.d/brcm_ethernet_helper.sh
fi
if [ -f /etc/init.d/brcm_wlan.sh ]; then
    source /etc/init.d/brcm_wlan.sh
fi
SERVICE_NAME="bridge"
BRIDGE_DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
BBVERSION=`/bin/busybox | head -1 | awk '{print $2}' | sed -e 's/v//' | awk -F'.' '{print $1*10000+$2*100+$3}'`
DEBUG() 
{
    [ "$BRIDGE_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
UDHCPC_PID_FILE=/var/run/bridge_udhcpc.pid
UDHCPC_SCRIPT=/etc/init.d/service_bridge/dhcp_link.sh
HANDLER="$UDHCPC_SCRIPT"
AUTO_BRIDGING=/usr/sbin/auto_bridging
unregister_dhcp_client_handlers() {
   asyncid=`sysevent get ${SERVICE_NAME}_async_id_1`;
   if [ -n "$asyncid" ] ; then
      sysevent rm_async $asyncid
      sysevent set ${SERVICE_NAME}_async_id_1
   fi
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
}
register_dhcp_client_handlers() {
   unregister_dhcp_client_handlers
   asyncid=`sysevent async dhcp_client-start "$HANDLER"`;
   sysevent setoptions dhcp_client-start $TUPLE_FLAG_EVENT
   sysevent set ${SERVICE_NAME}_async_id_1 "$asyncid"
   asyncid=`sysevent async dhcp_client-stop "$HANDLER"`;
   sysevent setoptions dhcp_client-stop $TUPLE_FLAG_EVENT
   sysevent set ${SERVICE_NAME}_async_id_2 "$asyncid"
   asyncid=`sysevent async dhcp_client-restart "$HANDLER"`;
   sysevent setoptions dhcp_client-restart $TUPLE_FLAG_EVENT
   sysevent set ${SERVICE_NAME}_async_id_3 "$asyncid"
   asyncid=`sysevent async dhcp_client-release "$HANDLER"`;
   sysevent setoptions dhcp_client-release $TUPLE_FLAG_EVENT
   sysevent set ${SERVICE_NAME}_async_id_4 "$asyncid"
   asyncid=`sysevent async dhcp_client-renew "$HANDLER"`;
   sysevent setoptions dhcp_client-renew $TUPLE_FLAG_EVENT
   sysevent set ${SERVICE_NAME}_async_id_5 "$asyncid"
}
bringup_ethernet_interfaces() {
    ip link set $SYSCFG_lan_ethernet_physical_ifnames down
    ip link set $SYSCFG_lan_ethernet_physical_ifnames addr $SYSCFG_lan_mac_addr
    ip link set $SYSCFG_lan_ethernet_physical_ifnames up
    ip link set $SYSCFG_wan_physical_ifname down
    ip link set $SYSCFG_wan_physical_ifname addr $SYSCFG_wan_mac_addr
    ip link set $SYSCFG_wan_physical_ifname up
    return 0
}
teardown_ethernet_interfaces() { 
   if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
       for loop in $LAN_IFNAMES
       do
           ip link set $loop down
       done
   else
       for loop in $SYSCFG_lan_ethernet_physical_ifnames
       do
           ip link set $loop down
       done
   fi
}
teardown_wireless_interfaces() {
    /etc/init.d/service_wifi/service_wifi.sh wifi-stop
}
register_handlers() {
    register_dhcp_client_handlers
    asyncid=`sysevent async phylink_wan_state /etc/init.d/service_bridge/dhcp_link.sh`
    sysevent set phylink_wan_state_asyncid "$asyncid"
}
unregister_handlers()
{
    local phylink_wan_state_asyncid="`sysevent get phylink_wan_state_asyncid`"
    if [ -n "$phylink_wan_state_asyncid" ]; then
        sysevent rm_async $phylink_wan_state_asyncid
        sysevent set phylink_wan_state_asyncid
    fi    
}
do_start()
{
   ulog bridge status "bringing up lan interface in bridge mode"
   if [ "$ModelNumber" != "WHW01P" ]; then
       bringup_ethernet_interfaces
   fi
   
   brctl setfd $SYSCFG_lan_ifname 0
   if [ "$SYSCFG_smart_mode_mode" = "1" ] ; then
       brctl stp $SYSCFG_lan_ifname on
       brctl setbridgeprio $SYSCFG_lan_ifname 0xFFFF
   elif [ "$SYSCFG_smart_mode_mode" = "2" ]; then
       brctl stp $SYSCFG_lan_ifname off
       brctl setbridgeprio $SYSCFG_lan_ifname 0xFFFE
   fi
    which nvram > /dev/null
    if [ $? = 0 ] ; then
        if [ "$SYSCFG_wan_virtual_ifnum" != "" -a -n "`nvram get vlan${SYSCFG_wan_virtual_ifnum}ports`" ] ; then
            enslave_a_interface vlan$SYSCFG_wan_virtual_ifnum $SYSCFG_lan_ifname
        fi
    elif [ "$SYSCFG_hardware_vendor_name" = "Marvell" ] ; then
        wan_mac=`syscfg get wan_mac_addr`
        if [ -n "wan_mac" ] ; then
            ip link set dev $SYSCFG_wan_physical_ifname down
            ip link set dev $SYSCFG_wan_physical_ifname address $wan_mac
            ip link set dev $SYSCFG_wan_physical_ifname up
        fi
        if [ "`cat /etc/product`" != "cobra" ] && [ "`cat /etc/product`" != "caiman" ]; then
            enslave_a_interface $SYSCFG_wan_physical_ifname $SYSCFG_lan_ifname
        fi
    fi
   
   if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then 
       if [ "$ModelNumber" != "WHW01P" ]; then
           enslave_a_interface eth1 $SYSCFG_lan_ifname
       fi
   else
      for loop in $LAN_IFNAMES
      do
          grep -q "root=/dev/nfs .*$loop" /proc/cmdline
          nfs=$?
          if [ ! \( $nfs = "0" \) ]; then
              enslave_a_interface $loop $SYSCFG_lan_ifname
          fi
      done
   fi
   
   if [ "`cat /etc/product`" = "wraith" ] ; then
       enslave_a_interface $SYSCFG_wan_physical_ifname $SYSCFG_lan_ifname
   fi
   ip link set $SYSCFG_lan_ifname up 
   ip link set $SYSCFG_lan_ifname allmulticast on 
    
   prepare_hostname
    start_broadcom_emf
   if [ "3" = "$SYSCFG_bridge_mode" ] ; then
      sysevent set lan-errinfo
      sysevent set lan-status starting
    elif [ "2" = "$SYSCFG_bridge_mode" ] ; then
        if [ -n "$SYSCFG_bridge_ipaddr_start" -a -n "$SYSCFG_bridge_ipaddr_range" ] ; then
            start_ip=$SYSCFG_bridge_ipaddr_start
            start=`echo $start_ip | cut -f 4 -d '.'`
            prefix=`echo $start_ip | cut -f 1-3 -d '.'`
            i=1
            sleep 5
            while [ $i -le $SYSCFG_bridge_ipaddr_range ]
            do
                arping -D -q -I $SYSCFG_lan_ifname -c 4 $prefix.$start
                DAD=`echo $?`
                if [ "$DAD" != "0" ] ; then
                    ulog dhcp_link status "Duplicated address detected $prefix.$start. Try the next one."
                    i=`expr $i + 1`
                    start=`expr $start + 1`
                else
                    SYSCFG_bridge_ipaddr=$prefix.$start
                    syscfg set bridge_ipaddr $SYSCFG_bridge_ipaddr
                    break
                fi
            done
        fi
      if [ -n "$SYSCFG_bridge_ipaddr" -a -n "$SYSCFG_bridge_netmask" -a -n "$SYSCFG_bridge_default_gateway" ]; then
          ip -4 addr add $SYSCFG_bridge_ipaddr/$SYSCFG_bridge_netmask broadcast + dev $SYSCFG_lan_ifname
          ip -4 route add default dev $SYSCFG_lan_ifname via $SYSCFG_bridge_default_gateway
          sysevent set ipv4_wan_ipaddr $SYSCFG_bridge_ipaddr
          sysevent set ipv4_wan_subnet $SYSCFG_bridge_netmask
          sysevent set default_router $SYSCFG_bridge_default_gateway
          sysevent set firewall-restart
          prepare_resolver_conf
          sysevent set lan-started
          sysevent set lan-errinfo
          sysevent set lan-status started
          sysevent set wan-status started
          sysevent set wan-started
      fi
   else
      if [ -n "$SYSCFG_bridge_ipaddr" -a  -n "$SYSCFG_bridge_netmask" ] ; then
         ip -4 addr add  $SYSCFG_bridge_ipaddr/$SYSCFG_bridge_netmask broadcast + dev $SYSCFG_lan_ifname
         sysevent set lan-errinfo
         sysevent set lan-status starting
      fi
        register_handlers
        if [ $BBVERSION -ge 12501 ]; then
            HOSTNAME_OPT="-x hostname:$SYSCFG_hostname"
        else
            HOSTNAME_OPT="-h $SYSCFG_hostname"
        fi
      udhcpc -S -b -i $SYSCFG_lan_ifname $HOSTNAME_OPT -p $UDHCPC_PID_FILE  --arping -s $UDHCPC_SCRIPT $DHCPC_EXTRA_PARAMS
        sysevent set current_ipv4_wan_state up
   fi
   ulog bridge status "switch off bridge pkts to iptables (bridge-nf-call-arptables)"
   echo 0 > /proc/sys/net/bridge/bridge-nf-call-arptables
   echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables
   echo 0 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
   echo 0 > /proc/sys/net/bridge/bridge-nf-filter-vlan-tagged
   echo 0 > /proc/sys/net/bridge/bridge-nf-filter-pppoe-tagged
   
   if [ "$SYSCFG_guest_enabled" = "1" ] || [ "$SYSCFG_smart_mode_mode" = "1" ] ; then
      echo 1 > /proc/sys/net/ipv4/ip_forward
   fi
   if [ "`syscfg get gmac3_enable`" = "1" ] ; then
      ip link set fwd0 up 
      ip link set fwd0 allmulticast on
      ip link set fwd0 promisc on
      ip link set fwd1 up 
      ip link set fwd1 allmulticast on
      ip link set fwd1 promisc on
   fi
   if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
	   if [ "`syscfg get smart_mode::mode`" != "0" ] || [ "`cat /etc/product`" = "rogue" ] ; then
       BRS="$SYSCFG_svap_lan_ifname $SYSCFG_lrhk_ifname"
       for br_ifname in $BRS ; do 
			ifconfig|grep -q $br_ifname
			if [ $? = 1 ] ; then
				brctl addbr $br_ifname
				brctl setfd $br_ifname 0
				brctl stp $br_ifname on
				if [ "$SYSCFG_smart_mode_mode" = "1" ] ; then
				    brctl setbridgeprio $br_ifname 0xFFFF
				elif [ "$SYSCFG_smart_mode_mode" = "2" ] ; then
				    brctl setbridgeprio $br_ifname 0xFFFE
				fi
			fi   
			if [ -n "$SYSCFG_wl0_mac_addr" ] ; then
				ifconfig $br_ifname hw ether "$SYSCFG_wl0_mac_addr"
			fi		
			ip link set $br_ifname up 
			ip link set $br_ifname allmulticast off
       done
	   fi
   fi
   ulog bridge status "lan interface up"
   sysevent set ${SERVICE_NAME}-errinfo
   sysevent set ${SERVICE_NAME}-status up
   
   if [ "$(syscfg get smart_mode::mode)" = "2" ] ; then
       if [ -n "$SYSCFG_ldal_wl_setup_vap_ipaddr" -a -n "$SYSCFG_ldal_wl_setup_vap_netmask" ] ; then
          ip addr add $SYSCFG_ldal_wl_setup_vap_ipaddr/$SYSCFG_ldal_wl_setup_vap_netmask broadcast + dev $SYSCFG_svap_lan_ifname
       fi   
      if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
          if [ "$ModelNumber" != "WHW01P" ]; then
              add_vlan_to_backhaul "eth1" $SYSCFG_svap_vlan_id $SYSCFG_svap_lan_ifname
              if [ -n "$SYSCFG_lrhk_ifname" ] ; then
                 add_vlan_to_backhaul "eth1" "$SYSCFG_lrhk_vlan_id" "$SYSCFG_lrhk_ifname"
              fi
              if [ "$SYSCFG_guest_enabled" = "1" ] ; then
                  add_vlan_to_backhaul "eth1" $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname
              fi
          fi
      else
        add_vlan_to_backhaul "$SYSCFG_lan_ethernet_physical_ifnames" "$SYSCFG_svap_vlan_id" "$SYSCFG_svap_lan_ifname"
        if [ -n "$SYSCFG_lrhk_ifname" ] ; then
           add_vlan_to_backhaul "$SYSCFG_lan_ethernet_physical_ifnames" "$SYSCFG_lrhk_vlan_id" "$SYSCFG_lrhk_ifname"
        fi
        if [ "$SYSCFG_guest_enabled" = "1" ] ; then
          add_vlan_to_backhaul "$SYSCFG_lan_ethernet_physical_ifnames" "$SYSCFG_guest_vlan_id" "$SYSCFG_guest_lan_ifname"
        fi   
      fi        
   fi
   if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`cat /etc/product`" = "nodes"  -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
      if [ "$(sysevent get ETH::port_1_status)" = "up" ] || [ "$(sysevent get ETH::port_2_status)" = "up" ] || [ "$(sysevent get ETH::port_3_status)" = "up" ] || [ "$(sysevent get ETH::port_4_status)" = "up" ] || [ "$(sysevent get ETH::port_5_status)" = "up" ]; then
        add_vlan_to_backhaul "eth1" $SYSCFG_svap_vlan_id $SYSCFG_svap_lan_ifname
        if [ -n "$SYSCFG_lrhk_ifname" ] ; then
           add_vlan_to_backhaul "eth1" "$SYSCFG_lrhk_vlan_id" "$SYSCFG_lrhk_ifname"
        fi
      fi
      
       /etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-start
   fi
   sysevent set dhcp_client-start
}
do_stop()
{
   unregister_dhcp_client_handlers
   unregister_handlers
   sysevent set dhcp_client-stop
   if [ "0" != "`syscfg get bridge_mode`" ] && [ -f /etc/init.d/service_wifi/service_wifi_sta.sh ] ; then
      /etc/init.d/service_wifi/service_wifi_sta.sh wifi_sta-stop
   fi
   teardown_wireless_interfaces
   if [ "$ModelNumber" != "WHW01P" ]; then
       teardown_ethernet_interfaces
   fi
   ip link set $SYSCFG_lan_ifname down
   ip addr flush dev $SYSCFG_lan_ifname
   for loop in $LAN_IFNAMES
   do
      ip link set $loop down
      brctl delif $SYSCFG_lan_ifname $loop
   done
   if [ "$ModelNumber" != "WHW01P" ]; then
       ip link set $SYSCFG_wan_physical_ifname down
   fi
   ip link set $SYSCFG_lan_ifname down
   if [ "`syscfg get gmac3_enable`" = "1" ] ; then
      ip link set fwd0 down
      ip link set fwd1 down
   fi
   
   if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
   ifconfig|grep -q $SYSCFG_svap_lan_ifname
   if [ $? = 0 ] ; then   
        ip link set $SYSCFG_svap_lan_ifname down
        ip addr flush dev $SYSCFG_svap_lan_ifname
        brctl delbr $SYSCFG_svap_lan_ifname
   fi
   fi
   sysevent set ${SERVICE_NAME}-errinfo
   sysevent set ${SERVICE_NAME}-status down
}
service_init ()
{
   ModelNumber=$(skuapi -g model_sku | cut -d'=' -f2 | tr -d ' ')
   SYSCFG_FAILED='false'
   FOO=`utctx_cmd get bridge_mode lan_mac_addr wan_mac_addr lan_ifname lan_ethernet_virtual_ifnums lan_ethernet_physical_ifnames lan_wl_physical_ifnames lan_wl_virtual_ifnames wan_virtual_ifnum wan_physical_ifname bridge_ipaddr bridge_netmask bridge_default_gateway bridge_nameserver1 bridge_nameserver2 bridge_nameserver3 bridge_domain hostname hardware_vendor_name dhcpc_trusted_dhcp_server guest_enabled bridge_ipaddr_start bridge_ipaddr_range svap_lan_ifname wl0_mac_addr svap_vlan_id ldal_wl_setup_vap_ipaddr ldal_wl_setup_vap_netmask smart_mode::mode guest_vlan_id guest_lan_ifname lrhk::ifname lrhk::vlan_id`
   eval $FOO
  if [ $SYSCFG_FAILED = 'true' ] ; then
     ulog bridge status "$PID utctx failed to get some configuration data"
     ulog bridge status "$PID BRIDGE CANNOT BE CONTROLLED"
     exit
  fi
  if [ -n "$SYSCFG_dhcpc_trusted_dhcp_server" ]
  then
     DHCPC_EXTRA_PARAMS="-X $SYSCFG_dhcpc_trusted_dhcp_server"
  fi
  if [ -z "$SYSCFG_hostname" ] ; then
     SYSCFG_hostname="Utopia"
  fi 
    case $SYSCFG_hardware_vendor_name in
        "Broadcom")
            LAN_IFNAMES=vlan$SYSCFG_lan_ethernet_virtual_ifnums
            ;;
        "Marvell")
            LAN_IFNAMES="$SYSCFG_lan_ethernet_physical_ifnames"
            ;;
        "MediaTek")
            LAN_IFNAMES="$SYSCFG_lan_ethernet_physical_ifnames"
            ;;
        "QCA")
            if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
                if [ "$ModelNumber" != "WHW01P" ]; then
                    LAN_IFNAMES="`syscfg get switch::bridge_1::physical_ifname`"
                else
                    LAN_IFNAMES=""
                fi
            else
                LAN_IFNAMES="$SYSCFG_lan_ethernet_physical_ifnames"
            fi
            ;;
    esac
}
service_start ()
{
   wait_till_end_state lan
   STATUS=`sysevent get lan-status`
   if [ "started" != "$STATUS" ] ; then
      do_start
      ERR=$?
      if [ "$ERR" -ne "0" ] ; then
         check_err $? "Unable to bringup bridge"
      else
         sysevent set system_state-normal
      fi
   fi
}
service_stop ()
{
   wait_till_end_state lan
   STATUS=`sysevent get lan-status` 
   if [ "stopped" != "$STATUS" ] ; then
      do_stop
      ERR=$?
      if [ "$ERR" -ne "0" ] ; then
         check_err $ERR "Unable to teardown bridge"
      else
         sysevent set lan-stopped
         sysevent set lan-errinfo
         sysevent set lan-status stopped
      fi
   fi
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
      sysevent set lan-restarting 1
      service_stop
      service_start
      sysevent set lan-restarting 0
      ;;
   ipv4_wan_ipaddr)
      if [ "$SYSCFG_bridge_mode" = "1" ] ; then
         SYSEVENT_ipv4_wan_ipaddr=`sysevent get ipv4_wan_ipaddr`
         SYSEVENT_ipv4_wan_subnet=`sysevent get ipv4_wan_subnet`
         if [ -n "$SYSEVENT_ipv4_wan_ipaddr" -a "0.0.0.0" != "$SYSEVENT_ipv4_wan_ipaddr" ] ; then
            if [ -z "$SYSEVENT_ipv4_wan_subnet" -o "0.0.0.0" = "$SYSEVENT_ipv4_wan_subnet" ] ; then
               SYSEVENT_ipv4_wan_subnet=255.255.255.0
            fi
            if [ "$SYSCFG_smart_mode_mode" = "2" ]; then
                calculate_lan_networks $SYSEVENT_ipv4_wan_ipaddr $SYSEVENT_ipv4_wan_subnet
            else
                calculate_bridge_networks $SYSEVENT_ipv4_wan_ipaddr $SYSEVENT_ipv4_wan_subnet
            fi
         fi
      fi
      ;;      
   *)
      echo "Usage: service-${SERVICE_NAME} [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
      exit 3
      ;;
esac
