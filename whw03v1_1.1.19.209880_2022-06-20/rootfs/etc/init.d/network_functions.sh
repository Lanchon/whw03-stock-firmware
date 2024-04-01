#!/bin/sh
make_ip_using_subnet()
{
   if [ -z "$3" -o -z "$2" -o -z "$1" ] ; then
      CREATED_IP_ADDRESS=
      return 
   fi
   TEST=`echo ${3} | cut -d'.' -f4`
   if [ "$3" = "$TEST" ] ; then
      PREFIX_OCTETS="0.0.0."
   elif [ -n "$TEST" ] ; then
      PREFIX_OCTETS=
   else
      TEST=`echo ${3} | cut -d'.' -f3`
      if [ -n "$TEST" ] ; then
         PREFIX_OCTETS="0."
      else
         TEST=`echo ${3} | cut -d'.' -f2`
         if [ -n "$TEST" ] ; then
            PREFIX_OCTETS="0.0."
         else 
            PREFIX_OCTETS="0.0.0."
         fi
      fi
   fi
   eval `ip6calc -4 ${PREFIX_OCTETS}${3}`
   IPv6_STYLE_ADDRESS=$IPv4_MAPPED
   eval `ipcalc -n ${1}/${2}`
   eval `ip6calc -4 $NETWORK`
   IPv6_STYLE_SUBNET=$IPv4_MAPPED
   eval `ip6calc -4 255.255.255.255`
   IPv6_STYLE_FULL_NETMASK=$IPv4_MAPPED 
   eval `ipcalc -m ${1}/${2}`
   eval `ip6calc -4 $NETMASK`
   IPv6_STYLE_SUBNET_NETMASK=$IPv4_MAPPED 
   eval `ip6calc -x $IPv6_STYLE_FULL_NETMASK $IPv6_STYLE_SUBNET_NETMASK` 
   IPv6_STYLE_HOST_MASK=$XOR
   eval `ip6calc -a $IPv6_STYLE_HOST_MASK $IPv6_STYLE_ADDRESS`
   IPv6_STYLE_ADDRESS=$AND
   eval `ip6calc -o $IPv6_STYLE_SUBNET $IPv6_STYLE_ADDRESS`
   CREATED_IP_ADDRESS=`echo $OR | cut -d':' -f3`
}
make_random_subnets()
{
   if [ -z "$4" -o -z "$3" -o -z "$2" -o -z "$1" ] ; then
      RANDOM_SUBNET=
      return 
   fi
   if [ -n "$5" ]
   then
      FORBIDDEN_FIRST_OCTET=`echo $5 | awk 'BEGIN { FS = "." } ; { printf ($1) }'` 
      if [ "192" = "$FORBIDDEN_FIRST_OCTET" ] ; then
         OCTET1A=10
         OCTET1B=172
      elif [ "172" = "$FORBIDDEN_FIRST_OCTET" ] ; then
         OCTET1A=10
         OCTET1B=192
      elif [ "10" = "$FORBIDDEN_FIRST_OCTET" ] ; then
         OCTET1A=172
         OCTET1B=192
      else
         RANDOM=`expr $1 \* $3`
         NETWORK=`expr $RANDOM % 99`
         if [ "1" = "$NETWORK" ] 
         then
            OCTET1A=192
            OCTET1B=172
         elif [ "11" -gt "$NETWORK" ]
         then
            OCTET1A=172
            OCTET1B=192
         else
            OCTET1A=10
            OCTET1B=192
         fi 
      fi
   else
      RANDOM=`expr $1 \* $3`
      NETWORK=`expr $RANDOM % 99`
      if [ "1" = "$NETWORK" ] 
      then
         OCTET1A=192
         OCTET1B=172
      elif [ "11" -gt "$NETWORK" ]
      then
         OCTET1A=172
         OCTET1B=192
      else
         OCTET1A=10
         OCTET1B=192
      fi 
   fi
   if [ "192" = "$OCTET1A" ]
   then
      OCTET2A=168
   elif [ "172" = "$OCTET1A" ]
   then
      RANDOM=`expr $RANDOM + $2`
      OCTET2A=`expr $RANDOM % 49`
      if [ "32" -lt "$OCTET2A" ]
      then
         OCTET2A=`expr $OCTET2A - 16`
      elif [ "16" -gt "$OCTET2A" ] 
      then
         OCTET2A=`expr $OCTET2A + 16`
      fi
   else 
      RANDOM=`expr $RANDOM + $2`
      OCTET2A=`expr $RANDOM % 256`
   fi
   RANDOM=`expr $RANDOM + $2`
   OCTET3A=`expr $RANDOM % 256`
   RANDOM=`expr $RANDOM - $3`
   OCTET4A=`expr $RANDOM % 255`
   if [ "0" -eq $OCTET4A ]
   then
      OCTET4A=65
   fi
   if [ "192" = "$OCTET1B" ]
   then
      OCTET2B=168
   elif [ "172" = "$OCTET1B" ]
   then
      RANDOM=`expr $RANDOM + $2`
      OCTET2B=`expr $RANDOM % 49`
      if [ "32" -lt "$OCTET2B" ]
      then
         OCTET2B=`expr $OCTET2B - 16`
      elif [ "16" -gt "$OCTET2B" ]
      then
         OCTET2B=`expr $OCTET2B + 16`
      fi
   else
      RANDOM=`expr $RANDOM + $2`
      OCTET2B=`expr $RANDOM % 256`
   fi
   RANDOM=`expr $RANDOM + $2`
   OCTET3B=`expr $RANDOM % 256`
   RANDOM=`expr $RANDOM - $3`
   OCTET4B=`expr $RANDOM % 255`
   if [ "0" -eq $OCTET4B ]
   then
      OCTET4B=27
   fi
   eval `ipcalc -n ${OCTET1A}.${OCTET2A}.${OCTET3A}.${OCTET4A}/${4}`
   RANDOM_SUBNET_1=$NETWORK
   eval `ipcalc -n ${OCTET1B}.${OCTET2B}.${OCTET3B}.${OCTET4B}/24`
   RANDOM_SUBNET_2=$NETWORK
}
is_network_conflict()
{
   if [ -z "$4" -o -z "$3" -o -z "$2" -o -z "$1" ] ; then
      return 0
   fi
   local OCTET_1_ADDR1="`echo $1 | cut -d'.' -f1 | tr -d [:digit:]`"
   local OCTET_1_ADDR2="`echo $3 | cut -d'.' -f1 | tr -d [:digit:]`"
   if [ -n "$OCTET_1_ADDR1" -o -n "$OCTET_1_ADDR2" ]; then
       return 0
   fi
   if [ "$2" -lt "$4" ] ; then
      TEST_NET_LEN=$2
   else
      TEST_NET_LEN=$4
   fi
   eval `ipcalc -n ${1}/${TEST_NET_LEN}`
   NET1=$NETWORK
   eval `ipcalc -n ${3}/${TEST_NET_LEN}`
   NET2=$NETWORK
   if [ "$NET1" = "$NET2" ] ; then
      return 1
   else
      return 0
   fi
}
check_networks_conflict()
{
    PROHIBITED_ADDR=$1
    PROHIBITED_ADDR_NETMASK=$2
    if [ -z "$SYSCFG_lan_ipaddr" ] ; then
        return 0
    fi
    TEST=`echo ${PROHIBITED_ADDR_NETMASK} | awk 'BEGIN { FS = "." } ; { printf ($2) }'`
    if [ -n "$TEST" ] ; then
        eval `ipcalc -p $PROHIBITED_ADDR $PROHIBITED_ADDR_NETMASK`
        PROHIBITED_PREFIX_LEN=$PREFIX
    else
        PROHIBITED_PREFIX_LEN=$PROHIBITED_ADDR_NETMASK
    fi
    wan=`echo ${PROHIBITED_ADDR} | awk 'BEGIN { FS = "." } ; { printf ($2) }'`
    lan=`echo ${SYSCFG_lan_ipaddr} | awk 'BEGIN { FS = "." } ; { printf ($2) }'`
    guest=`echo ${SYSCFG_guest_lan_ipaddr} | awk 'BEGIN { FS = "." } ; { printf ($2) }'`
    setup=`echo ${SYSCFG_setup_ip} | awk 'BEGIN { FS = "." } ; { printf ($2) }'`
    hk=`echo ${SYSCFG_hk_ip} | awk 'BEGIN { FS = "." } ; { printf ($2) }'`
    lan_changed=0
    guest_changed=0
    setup_changed=0 
    hk_changed=0
    is_network_conflict $SYSCFG_lan_ipaddr $LAN_PREFIX_LEN $PROHIBITED_ADDR $PROHIBITED_PREFIX_LEN
    if [ "$?" = "1" ] ; then
        WAN_CONFLICT=1
        gen_random_with_prohibited_range $wan $lan $guest $setup $hk
        lan=$?
        lan_changed=1
    fi
    is_network_conflict $SYSCFG_guest_lan_ipaddr $GUEST_LAN_PREFIX_LEN $PROHIBITED_ADDR $PROHIBITED_PREFIX_LEN
    if [ "$?" = "1" ] ; then
        WAN_CONFLICT=1
        gen_random_with_prohibited_range $wan $lan $guest $setup $hk
        guest=$?
        guest_changed=1
    fi
    scs_enabled=`syscfg get smart_connect::server_enabled`
    if [ "$scs_enabled" = "1" ] ; then
		is_network_conflict $PROHIBITED_ADDR $PROHIBITED_PREFIX_LEN $SYSCFG_setup_ip $SETUP_PREFIX
		if [ "$?" = "1" ] ; then
		    WAN_CONFLICT=1
		    gen_random_with_prohibited_range $wan $lan $guest $setup $hk
		    setup=$?
		    setup_changed=1
		fi
    fi
    if [ "`syscfg get lrhk::enabled`" = "1" ] && [ -e /tmp/cedar_support ] ; then
        is_network_conflict $PROHIBITED_ADDR $PROHIBITED_PREFIX_LEN $SYSCFG_hk_ip $HK_PREFIX
        if [ "$?" = "1" ] ; then
            WAN_CONFLICT=1
            gen_random_with_prohibited_range $wan $lan $guest $setup $hk
            hk=$?
            hk_changed=1
        fi
    fi
    is_network_conflict $SYSCFG_lan_ipaddr $LAN_PREFIX_LEN $SYSCFG_guest_lan_ipaddr $GUEST_LAN_PREFIX_LEN
    if [ "$?" = "1" ] ; then
        LAN_CONFLICT=1
        gen_random_with_prohibited_range $wan $lan $guest $setup $hk
        guest=$?
        guest_changed=1
    fi
    if [ "$scs_enabled" = "1" ] ; then
		is_network_conflict $SYSCFG_lan_ipaddr $LAN_PREFIX_LEN $SYSCFG_setup_ip $SETUP_PREFIX
		if [ "$?" = "1" ] ; then
		    LAN_CONFLICT=1
		    gen_random_with_prohibited_range $wan $lan $guest $setup $hk
		    setup=$?
		    setup_changed=1
		fi
    fi
    if [ "`syscfg get lrhk::enabled`" = "1" ] && [ -e /tmp/cedar_support ] ; then
        is_network_conflict $SYSCFG_lan_ipaddr $LAN_PREFIX_LEN $SYSCFG_hk_ip $HK_PREFIX
        if [ "$?" = "1" ] ; then
            LAN_CONFLICT=1
            gen_random_with_prohibited_range $wan $lan $guest $setup $hk
            hk=$?
            hk_changed=1
        fi
    fi
    if [ $lan_changed -eq 1 -o $guest_changed -eq 1 -o $setup_changed -eq 1 -o $hk_changed -eq 1 ] ; then
        return 1
    else
        return 0
    fi    
}
gen_random_with_prohibited_range()
{
    while [ 1 ] ; do
        numb=`expr $RANDOM % 255`
        matched=0
        for TOKEN in $* ; do
            if [ $numb -eq $TOKEN ] ; then
                matched=1
                break
            fi
        done
        if [ $matched -eq 0 ] ; then
            return $numb
        fi
    done
}
calculate_bridge_networks ()
{
    PROHIBITED_ADDR=$1
    PROHIBITED_ADDR_NETMASK=$2
    if [ -n "$PROHIBITED_ADDR" -a -z "$PROHIBITED_ADDR_NETMASK" ] ; then
        PROHIBITED_ADDR_NETMASK=255.255.255.0
    fi    
    
    TEST=`echo ${PROHIBITED_ADDR_NETMASK} | awk 'BEGIN { FS = "." } ; { printf ($2) }'`
    if [ -n "$TEST" ] ; then
        eval `ipcalc -p $PROHIBITED_ADDR $PROHIBITED_ADDR_NETMASK`
        PROHIBITED_PREFIX_LEN=$PREFIX
    else
        PROHIBITED_PREFIX_LEN=$PROHIBITED_ADDR_NETMASK
    fi
    
    SYSCFG_guest_lan_ipaddr=`syscfg get guest_lan_ipaddr`
    SYSCFG_guest_lan_netmask=`syscfg get guest_lan_netmask`
    GUEST_LAN_PREFIX_LEN=$SYSCFG_guest_lan_netmask
    eval `ipcalc -p 0.0.0.0 $GUEST_LAN_PREFIX_LEN`
    GUEST_LAN_PREFIX_LEN=$PREFIX
    SYSCFG_setup_ip=`syscfg get ldal_wl_setup_vap_ipaddr`
    SETUP_PREFIX=`syscfg get ldal_wl_setup_vap_netmask`
    eval `ipcalc -p 0.0.0.0 $SETUP_PREFIX`
    SETUP_PREFIX=$PREFIX
    if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
        is_network_conflict $PROHIBITED_ADDR $PROHIBITED_PREFIX_LEN $SYSCFG_setup_ip $SETUP_PREFIX
        if [ "$?" = "1" ] ; then
            /etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-restart
        else
            /etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew
        fi
    fi
}
calculate_lan_networks()
{
   SYSCFG_lan_ipaddr=`syscfg get lan_ipaddr`
   SYSCFG_lan_netmask=`syscfg get lan_netmask`
   LAN_PREFIX_LEN=$SYSCFG_lan_netmask
   eval `ipcalc -p 0.0.0.0 $LAN_PREFIX_LEN`
   LAN_PREFIX_LEN=$PREFIX
   SYSCFG_guest_lan_ipaddr=`syscfg get guest_lan_ipaddr`
   SYSCFG_guest_lan_netmask=`syscfg get guest_lan_netmask`
   GUEST_LAN_PREFIX_LEN=$SYSCFG_guest_lan_netmask
   eval `ipcalc -p 0.0.0.0 $GUEST_LAN_PREFIX_LEN`
   GUEST_LAN_PREFIX_LEN=$PREFIX
   SYSCFG_guest_enabled=`syscfg get guest_enabled`
   SYSCFG_smart_mode=`syscfg get smart_mode::mode`
   
    SYSCFG_setup_ip=`syscfg get ldal_wl_setup_vap_ipaddr`
    SETUP_PREFIX=`syscfg get ldal_wl_setup_vap_netmask`
    eval `ipcalc -p 0.0.0.0 $SETUP_PREFIX`
    SETUP_PREFIX=$PREFIX
    SYSCFG_hk_ip=`syscfg get lrhk::ipaddr`
    HK_PREFIX=`syscfg get lrhk::netmask`
    eval `ipcalc -p 0.0.0.0 $HK_PREFIX`
    HK_PREFIX=$PREFIX
   if [ "0.0.0.0" = "$SYSCFG_lan_ipaddr" ] ; then 
      SYSCFG_lan_ipaddr=
   fi
    if [ -n "$PROHIBITED_ADDR" -a -z "$PROHIBITED_ADDR_NETMASK" ] ; then
        PROHIBITED_ADDR_NETMASK=255.255.255.0
    fi
    check_networks_conflict $1 $2
    if [ "$?" = "1" ] ; then
        if [ $lan_changed -eq 1 ] ; then
            SYSCFG_lan_ipaddr=10.$lan.1.1
            syscfg set lan_ipaddr 10.$lan.1.1
        fi
        if [ $guest_changed -eq 1 ] ; then
            syscfg set guest_lan_ipaddr 10.$guest.3.1
            syscfg set guest_subnet 10.$guest.3.0
            make_ip_using_subnet 10.$guest.3.1 24 1
            sysevent set firewall-restart
            sysevent set guest_access-restart
            sysevent set wifi_renew_clients
        fi
        if [ $setup_changed -eq 1 ] ; then 
            syscfg set ldal_wl_setup_vap_ipaddr 10.$setup.20.1
            syscfg set ldal_wl_setup_vap_subnet 10.$setup.20.0
            syscfg set smart_connect::serverip 10.$setup.20.1
            make_ip_using_subnet 10.$setup.20.1 24 1
            sysevent set firewall-restart
        fi
        if [ $hk_changed -eq 1 ] ; then 
            syscfg set lrhk::ipaddr 10.$hk.50.1
            syscfg set lrhk::subnet 10.$hk.50.0
            make_ip_using_subnet 10.$hk.50.1 $HK_PREFIX 1
            sysevent set firewall-restart
            sysevent set lrhk-restart
        fi
        syscfg commit
    fi
    make_ip_using_subnet $SYSCFG_lan_ipaddr $LAN_PREFIX_LEN 1
    sysevent set lan_ipaddr $SYSCFG_lan_ipaddr
    eval `ipcalc -p 0.0.0.0 $SYSCFG_lan_netmask`
    sysevent set lan_prefix_len $PREFIX
    eval `ipcalc -n $SYSCFG_lan_ipaddr $SYSCFG_lan_netmask`
    sysevent set lan_network $NETWORK
    if [ $lan_changed -eq 1 ] || [ "$guest_changed" = "1" -a "$SYSCFG_guest_enabled" = "1" ] || [ "$setup_changed" = "1" -a "$SYSCFG_smart_mode" = "2" ] || [ -e /tmp/cedar_support -a $hk_changed -eq 1 -a "`syscfg get lrhk::enabled`" = "1" ] ; then
        wait_till_end_state lan
        STATUS=`sysevent get lan-status`
        if [ "started" = "$STATUS" ] ; then
            sysevent set wan_conflict_resolved 1
            if [ "$setup_changed" = "1" -a "$SYSCFG_smart_mode" = "2" ] ; then
                sysevent set smart_connect::setup_conflict_resolved 1
            fi    
			if [ "`cat /etc/product`" != "nodes" ] && [ "`cat /etc/product`" != "nodes-jr" ] && [ "`cat /etc/product`" != "rogue" ] && [ "`cat /etc/product`" != "lion" ] && [ "0" = "`syscfg get smart_mode::mode`" ] && [ "START" = "`sysevent get smart_connect::setup_status`" ] ; then
                echo "@@@smart connect run on br0, skip lan-restart(`date`)" > /dev/console
                return 1
            fi      
            if [ "1" = "`syscfg get bridge_mode`" ] ; then
                sysevent set bridge-restart
            else
                sysevent set lan-restart
            fi
        fi
        return 1
    else
        return 0
    fi
}
