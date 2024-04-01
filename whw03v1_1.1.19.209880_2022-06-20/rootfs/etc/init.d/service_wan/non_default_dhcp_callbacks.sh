#!/bin/sh 
source /etc/init.d/ulog_functions.sh
source /etc/init.d/resolver_functions.sh
source /etc/init.d/service_wan/wan_helper_functions
PID="($$)"
if [ -n "$interface" ] ; then
   NAMESPACE=`interface_to_syscfg_namespace $interface`
   if [ -n "$NAMESPACE" ] ; then
      wan_info_by_namespace $NAMESPACE
   fi
fi
case "$1" in
   leasefail)
      ulog non_default_dhcp_cb status "$PID wan $interface dhcp lease has failed"
      ;;
   deconfig)
      ulog non_default_dhcp_cb status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
      if [ -z "$interface" ] ; then
         ulog non_default_dhcp_cb status "Received a deconfig event with no interface. Ignoring" 
         return
      fi
      if [ "up" = "$SYSEVENT_desired_ipv4_link_state" ] && [ "up" = "$SYSEVENT_current_ipv4_link_state" ] ; then
         ulog non_default_dhcp_cb status "$PID $interface dhcp lease has expired"
         LOG_FILE="/tmp/"${NAMESPACE}"_udhcpc.log"
         rm -f $LOG_FILE
         sysevent set ${NAMESPACE}_current_ipv4_link_state down
         sysevent set ${NAMESPACE}_ipv4_wan_ipaddr 
         sysevent set ${NAMESPACE}_ipv4_wan_subnet
         sysevent set ${NAMESPACE}_ipv4_default_router
         STATIC_ROUTES=`sysevent get ${NAMESPACE}_static_routes`
         if [ -n "$STATIC_ROUTES" ] ; then
            delete_static_routes "$STATIC_ROUTES"
         fi
         sysevent set ${NAMESPACE}_static_routes
      fi
      ;;
   renew|bound)
      ulog non_default_dhcp_cb status "udhcpc $PID - cmd $1 interface $interface ip $ip broadcast $broadcast subnet $subnet router $router" 
      if [ -z "$interface" ] ; then
         ulog non_default_dhcp_cb status "Received a $1 event with no interface. Ignoring" 
         return
      fi
      if [ -n "$subnet" ] ; then
         sysevent set ${NAMESPACE}_ipv4_wan_subnet $subnet 
      fi
      LOG_FILE="/tmp/"${NAMESPACE}"_udhcpc.log"
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
      echo "6rd           : $sixrd"     >> $LOG_FILE
      echo "staticroutes  : $staticroutes" >> $LOG_FILE
      echo "vendorinfo    : $vendorinfo" >> $LOG_FILE
      echo "vendorspecific: $vendorspecific" >> $LOG_FILE
      if [ -n "$subnet" ] ; then
         NETMASK="/$subnet"
      fi
      if [ -n "$broadcast" ] ; then
         BROADCAST="broadcast $broadcast"
      else
         BROADCAST="broadcast +"
      fi
      OLDIP=`ip -4 addr show dev $interface  | grep "inet " | awk '{split($2,foo, "/"); print(foo[1]);}'`
      if [ "$OLDIP" != "$ip" ] ; then
         RESULT=`arping -q -c 2 -w 3 -D -I $interface $ip`
         if [ "" != "$RESULT" ] &&  [ "0" != "$RESULT" ] ; then
            echo "[utopia][dhcp client script] duplicate address detected $ip on $interface." > /dev/console
            echo "[utopia][dhcp client script] ignoring duplicate ... hoping for the best" > /dev/console
         fi
         if [ -n "$OLDIP" ] ; then
            ip -4 addr show dev $interface | grep "inet " | awk '{system("/sbin/ip addr del " $2 " dev $interface")}'
         fi
         ip -4 addr add $ip$NETMASK $BROADCAST dev $interface 
      fi
      if [ -n "$staticroutes" ] ; then
         sysevent set ${NAMESPACE}_static_routes "$staticroutes"
         add_static_routes "$staticroutes" "$interface"
      fi
      sysevent set ${NAMESPACE}_ipv4_wan_ipaddr $ip
      if [ -n "$router" ] ; then
         sysevent set ${NAMESPACE}_ipv4_default_router $router
      fi
      if [ -n "$vendorinfo" ] ; then
		ACSURL=`echo $vendorinfo | \
				awk ' { z = split( $0, array, ",") ; } ; \
					{ for(i=1;i<=z;i++) \
						{ \
							if (array[i++] == "1") \
								printf ("%s" , array[i]) ; \
							fi ; \
						} ; \
					} ;' \
				`
		if [ -n "$ACSURL" ] ; then
			SYSCFG_acs_discovery_url=`syscfg get acs_discovery_url`
			if [ "$SYSCFG_acs_discovery_url" != "$ACSURL" ] ; then
				syscfg set acs_discovery_url $ACSURL
				syscfg commit
				sysevent set acs_url_changed 
				ulog non_default_dhcp_cb info "++++ set ccsp-restart by new url: $ACSURL"
			fi
		fi
      fi
      if [ -n "vendorspecific" ] ; then
		GTW_OUI=`echo $vendorspecific | \
				awk ' { z = split( $0, array, ",") ; } ; \
					{ for(i=1;i<=z;i++) \
						{ \
							if (array[i++] == "4") \
								printf ("%s" , array[i]) ; \
							fi ; \
						} ; \
					} ;' \
				`
		SYSEVENT_gateway_OUI=`sysevent get gateway_OUI`
		if [ -n "$GTW_OUI" ] ; then
			if [ "$SYSEVENT_gateway_OUI" != "$GTW_OUI" ] ; then
				sysevent set gateway_OUI $GTW_OUI
				ulog non_default_dhcp_cb info "set GatewayManufacturerOUI: $GTW_OUI"
			fi
		else
			if [ -n "$SYSEVENT_gateway_OUI" ] ; then
				sysevent set gateway_OUI
				ulog non_default_dhcp_cb info "unset GatewayManufacturerOUI"
			fi
		fi
		GTW_SN=`echo $vendorspecific | \
				awk ' { z = split( $0, array, ",") ; } ; \
					{ for(i=1;i<=z;i++) \
						{ \
							if (array[i++] == "5") \
								printf ("%s" , array[i]) ; \
							fi ; \
						} ; \
					} ;' \
				`
		SYSEVENT_gateway_SN=`sysevent get gateway_SN`
		if [ -n "$GTW_SN" ] ; then
			if [ "$SYSEVENT_gateway_SN" != "$GTW_SN" ] ; then
				sysevent set gateway_SN $GTW_SN
				ulog non_default_dhcp_cb info "set GatewaySerialNumber: $GTW_SN"
			fi
		else
			if [ -n "$SYSEVENT_gateway_SN" ] ; then
				sysevent set gateway_SN
				ulog non_default_dhcp_cb info "unset GatewaySerialNumber"
			fi
		fi
		GTW_CLASS=`echo $vendorspecific | \
				awk ' { z = split( $0, array, ",") ; } ; \
					{ for(i=1;i<=z;i++) \
						{ \
							if (array[i++] == "6") \
								printf ("%s" , array[i]) ; \
							fi ; \
						} ; \
					} ;' \
				`
		SYSEVENT_gateway_CLASS=`sysevent get gateway_CLASS`
		if [ -n "$GTW_CLASS" ] ; then
			if [ "$SYSEVENT_gateway_CLASS" != "$GTW_CLASS" ] ; then
				sysevent set gateway_CLASS $GTW_CLASS
				ulog non_default_dhcp_cb info "set GatewayProductClass: $GTW_CLASS"
			fi
		else
			if [ -n "$SYSEVENT_gateway_CLASS" ] ; then
				sysevent set gateway_CLASS
				ulog non_default_dhcp_cb info "unset GatewayProductClass"
			fi
		fi
      fi
      if [ -n "$serverid" ] ; then
         sysevent set dhcp_server_id $serverid
      fi 
      if [ -n "$domain" ] ; then
         syscfg set router_dns_domain $domain
      fi 
      LINK_STATE=`sysevent get ${NAMESPACE}_current_ipv4_link_state`
      if [ "up" != "$LINK_STATE" ] ; then
         ulog non_default_dhcp_cb status "$PID setting ${NAMESPACE}_current_ipv4_link_state to up"
         sysevent set ${NAMESPACE}_current_ipv4_link_state up
      fi
      ;;
esac
exit 0
