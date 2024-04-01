#!/bin/sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="guest_access"
SERVICE_FILE="/etc/init.d/service_guest_access.sh"
GUEST_ACCESS=guest-access
GA_PATH=/usr/sbin
GA_BIN=$GA_PATH/$GUEST_ACCESS
PMON=/etc/init.d/pmon.sh
PID_FILE=/var/run/$GUEST_ACCESS.pid
GUEST_UDHCPC_PID_FILE=/var/run/guest_udhcpc.pid
GUEST_UDHCPC_SCRIPT=/etc/init.d/service_bridge/guest_dhcp_link.sh
stop_guest_access()
{
	if [ -x $GA_BIN ] ; then
		pidof $GUEST_ACCESS > /dev/null
		if [ $? -eq 0  ] ; then
			ulog guest_access status "stopping $GUEST_ACCESS"
			$PMON unsetproc $SERVICE_NAME
			killall $GUEST_ACCESS > /dev/null 2>&1
			rm -f $PID_FILE
		fi
	fi
}
start_guest_access()
{
	if [ -x $GA_BIN ] ; then
		ulog guest_access status "starting $GUEST_ACCESS"
		$GA_BIN -d
		pidof $GUEST_ACCESS > $PID_FILE
		if [ $? -eq 0 ] ; then
			$PMON setproc $SERVICE_NAME $GUEST_ACCESS $PID_FILE "$SERVICE_FILE $SERVICE_NAME-restart"
		else
			ulog guest_access status "Failed to start $GUEST_ACCESS"
			rm -f $PID_FILE
		fi
	fi
}
do_start()
{
	ulog guest_access status "bringing up guest access control"
	ifconfig|grep -q $SYSCFG_guest_lan_ifname
	if [ $? = 1 -a "$GUEST_ENABLED" = "1" ] ; then
		brctl addbr $SYSCFG_guest_lan_ifname
		brctl setfd $SYSCFG_guest_lan_ifname 0
		if [ "$SYSCFG_bridge_mode" != "0" ] ; then
                    brctl stp $SYSCFG_guest_lan_ifname on
                    if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
			if [ "$SYSCFG_smart_mode_mode" = "1" ] ; then
			    brctl setbridgeprio $SYSCFG_guest_lan_ifname 0xFFFF
			elif [ "$SYSCFG_smart_mode_mode" = "2" ]; then
			    brctl setbridgeprio $SYSCFG_guest_lan_ifname 0xFFFE
			fi
                    fi
		else
			brctl stp $SYSCFG_guest_lan_ifname off
		fi
		
	fi
	brctl show|grep -q $SYSCFG_wl0_guest_vap
	if [ "$GUEST_WL0_ENABLED" = "1" -a $? = 1 ] ; then
		ifconfig|grep -q $SYSCFG_wl0_guest_vap
		if [ $? = 0 ] ; then
			enslave_a_interface $SYSCFG_wl0_guest_vap $SYSCFG_guest_lan_ifname
		fi
	fi
	brctl show|grep -q $SYSCFG_wl1_guest_vap
	if [ "$GUEST_WL1_ENABLED" = "1" -a $? = 1 ] ; then
		ifconfig|grep -q $SYSCFG_wl1_guest_vap
		if [ $? = 0 ] ; then
			enslave_a_interface $SYSCFG_wl1_guest_vap $SYSCFG_guest_lan_ifname
		fi
	fi
	if [ "$SYSCFG_bridge_mode" = 0 ] || [ "$SYSCFG_smart_mode_mode" = "2" ] ; then
        if [ -n "$SYSCFG_guest_lan_ipaddr" -a -n "$SYSCFG_guest_lan_netmask" ] ; then
        	ip addr add $SYSCFG_guest_lan_ipaddr/$SYSCFG_guest_lan_netmask broadcast + dev $SYSCFG_guest_lan_ifname
        fi
	fi
	MAC_ADDR=`syscfg get wl0.1_mac_addr`
	if [ -n "$MAC_ADDR" ] ; then 
            ifconfig $SYSCFG_guest_lan_ifname hw ether "$MAC_ADDR"
	fi	
	ip link set $SYSCFG_guest_lan_ifname up 
	ip link set $SYSCFG_guest_lan_ifname allmulticast on 
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
		if [ "$SYSCFG_bridge_mode" = "1" ] ; then
			if [ "$(sysevent get ETH::port_5_status)" = "up" ] || [ "$(sysevent get ETH::port_4_status)" = "up" ] ; then
				lan_interface=$(syscfg get switch::bridge_1::ifname)
				add_vlan_to_backhaul "${lan_interface}" $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname	
			fi
		else
			wan_intf_auto_detect_enabled=`syscfg get wan::intf_auto_detect_enabled`
			if [ "$wan_intf_auto_detect_enabled" = "1" ]; then
			   wan_intf=`sysevent get wan::detected_intf`
			   if [ -n "$wan_intf" ]; then
				   if [ "`syscfg get switch::router_1::ifname`" = "$wan_intf" ] ; then
					   lan_ether_intf=`syscfg get switch::router_2::ifname`
				   else
					   lan_ether_intf=`syscfg get switch::router_1::ifname`
				   fi
				   add_vlan_to_backhaul "$lan_ether_intf" "$SYSCFG_guest_vlan_id" "$SYSCFG_guest_lan_ifname"
			   fi
			else
			   add_vlan_to_backhaul "$SYSCFG_lan_ethernet_physical_ifnames" "$SYSCFG_guest_vlan_id" "$SYSCFG_guest_lan_ifname"
			fi
		fi
	else
	    add_vlan_to_backhaul $SYSCFG_lan_ethernet_physical_ifnames $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname
	fi
	for WL_INTF in $SYSCFG_lan_wl_physical_ifnames; do
	    ifconfig|grep -q $WL_INTF
	    if [ $? = 0 ] ; then
	        add_vlan_to_backhaul $WL_INTF $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname
	    fi
	done
	CURRENT_BACKHAUL="`sysevent get backhaul::intf`"
	add_vlan_to_backhaul $CURRENT_BACKHAUL $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname
	
	stop_guest_access 
	start_guest_access
	echo "Guest access control is up " > /dev/console
	STATUS=`sysevent get ipv6-status`
    if [ "started" = "$STATUS" ] ; then 
    	sysevent set ipv6-restart
    fi
}
cleanup_conntrack()
{
	while read LINE
	do
		IP=$(echo "$LINE"|awk '{print $3}')
		eval `ipcalc -n $IP $SYSCFG_guest_lan_netmask`
		if [ "$NETWORK" = "$SYSCFG_guest_subnet" ] ; then
			ulog guest_access status "cleanup conntrack for "$IP
			conntrack -D -s $IP
		fi
	done < /etc/dnsmasq.leases
}
do_stop()
{
	ulog guest_access status "bringing down guest access "
	ifconfig|grep -q $SYSCFG_guest_lan_ifname
	if [ $? = 0 ] ; then
		delete_vlan_from_backhaul $SYSCFG_lan_ethernet_physical_ifnames $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname
		if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "`syscfg get smart_mode::mode`" = "1" ] ; then
		    ifname0="$(syscfg get switch::router_2::physical_ifname)"
		    ifname1="$(syscfg get switch::router_1::physical_ifname)"
		    delete_vlan_from_backhaul $ifname0 $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname
		    delete_vlan_from_backhaul $ifname1 $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname
		fi
	    
		for WL_INTF in $SYSCFG_lan_wl_physical_ifnames; do
			ifconfig|grep -q $WL_INTF
			if [ $? = 0 ] ; then
				delete_vlan_from_backhaul $WL_INTF $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname
			fi
		done
		CURRENT_BACKHAUL="`sysevent get backhaul::intf`"
		delete_vlan_from_backhaul $CURRENT_BACKHAUL $SYSCFG_guest_vlan_id $SYSCFG_guest_lan_ifname
	
		brctl delif $SYSCFG_guest_lan_ifname $SYSCFG_wl0_guest_vap
		brctl delif $SYSCFG_guest_lan_ifname $SYSCFG_wl1_guest_vap
		ip link set $SYSCFG_guest_lan_ifname down
		ip addr flush dev $SYSCFG_guest_lan_ifname
		brctl delbr $SYSCFG_guest_lan_ifname
	fi
	
	cleanup_conntrack
	stop_guest_access
	echo "Guest access control is down " > /dev/console
}
status_change()
{
	if [ "started" = "`sysevent get wan-status`" ] && [ "started" = "`sysevent get wifi_user-status`" ] ; then
		service_start 
	else
		service_stop
	fi
}
service_init()
{
	SYSCFG_FAILED='false'
	FOO=`utctx_cmd get guest_enabled wl0_guest_enabled wl1_guest_enabled wl0_state wl1_state guest_lan_netmask guest_subnet guest_lan_ifname guest_lan_ipaddr guest_lan_netmask wl0_guest_vap wl1_guest_vap bridge_mode hostname guest_vlan_id lan_ethernet_physical_ifnames lan_wl_physical_ifnames smart_mode::mode`
	eval $FOO
	if [ $SYSCFG_FAILED = 'true' ] ; then
		ulog guest_access status "$PID utctx failed to get some configuration data"
		ulog guest_access status "$PID GUEST ACCESS CANNOT BE CONTROLLED"
		exit
	fi
}
service_start ()
{
	if [ "0" != "$SYSCFG_bridge_mode" -a "`syscfg get wifi_bridge::mode`" = "0" ] ; then
		if [ "`cat /etc/product`" != "nodes" ] && [ "`cat /etc/product`" != "nodes-jr" ] && [ "`cat /etc/product`" != "rogue" ] && [ "`cat /etc/product`" != "lion" ] ; then
        	ulog guest_access status "don't start ${SERVICE_NAME} in bridge mode"
        	return
		fi
	fi
	if [ "`syscfg get smart_mode::mode`" = "1" ] && [ -f /tmp/wl0_guest_settings.conf ] ; then
		GUEST_ENABLED=`grep -s "^guest_enabled" /tmp/wl0_guest_settings.conf`; GUEST_ENABLED=${GUEST_ENABLED#*: }
		if [ "1" != "$GUEST_ENABLED" ]; then
		    GUEST_ENABLED=`grep -s "^guest_enabled" /tmp/wl1_guest_settings.conf`; GUEST_ENABLED=${GUEST_ENABLED#*: }
		fi
                [ "1" != "$GUEST_ENABLED" ] && GUEST_ENABLED=0
		GUEST_WL0_ENABLED=`grep -s "^wl0_guest_enabled" /tmp/wl0_guest_settings.conf`; GUEST_WL0_ENABLED=${GUEST_WL0_ENABLED#*: }
		GUEST_WL1_ENABLED=`grep -s "^wl1_guest_enabled" /tmp/wl1_guest_settings.conf`; GUEST_WL1_ENABLED=${GUEST_WL1_ENABLED#*: }
	else
		GUEST_ENABLED=$SYSCFG_guest_enabled
		GUEST_WL0_ENABLED=$SYSCFG_wl0_guest_enabled
		GUEST_WL1_ENABLED=$SYSCFG_wl1_guest_enabled
	fi
	
	if [ "0" = "$GUEST_ENABLED" ] ; then
		sysevent set guest_access-status disabled
		return
	fi
	if [ "down" = "$SYSCFG_wl0_state" ] && [ "down" = "$SYSCFG_wl1_state" ] ; then	
		sysevent set guest_access-status stopped
		return
	fi
	wait_till_end_state ${SERVICE_NAME}
	STATUS=`sysevent get ${SERVICE_NAME}-status`
	if [ "started" != "$STATUS" ] ; then
		sysevent set ${SERVICE_NAME}-status starting
		do_start
		sysevent set ${SERVICE_NAME}-status started
		if [ "0" != "$GUEST_ENABLED" ] && [ "$SYSCFG_bridge_mode" != "0" ] ; then
			echo 1 > /proc/sys/net/ipv4/ip_forward
		fi
		sysevent set firewall-restart
	fi
}
service_stop ()
{
	wait_till_end_state ${SERVICE_NAME}
	STATUS=`sysevent get ${SERVICE_NAME}-status` 
	if [ "stopped" != "$STATUS" ] ; then
		sysevent set ${SERVICE_NAME}-status stopping
		do_stop
		sysevent set ${SERVICE_NAME}-status stopped
	fi
    sysevent set firewall-restart
}
ulog wlan status "${SERVICE_NAME}, sysevent received: $1"
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
	*)
        echo $1
		echo "Usage: service-${SERVICE_NAME} [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		exit 3
		;;
esac
