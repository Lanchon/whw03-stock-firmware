#!/bin/sh
enabled=`syscfg get ipv6::passthrough_enable`
if [ "$enabled" = "1" ]
then
   WAN=`sysevent get current_wan_ipv6_ifname`
   LAN=`syscfg get lan_ifname`
   ifconfig $WAN | grep -q PROMISC
   if [ $? != 0 ]
   then
       echo "ipv6_passthrogh_monitor: Wan device $WAN is NOT in Promiscuous mode; setting Promiscuous on device" > /dev/console
       ifconfig $WAN promisc
   fi
   ifconfig $LAN | grep -q PROMISC
   if [ $? != 0 ]
   then
       echo "ipv6_passthrogh_monitor: Lan device $LAN is NOT in Promiscuous mode; setting Promiscuous on device" > /dev/console
       ifconfig $LAN promisc
   fi
fi 
