#!/bin/sh
echo "wifi, start ssid_monitor.sh"
check_ip_connection()
{
	LAN_IFNAME="$(syscfg get lan_ifname)"
	for i in 1 2 3; 
	do
	    MASTER_IP="$(sysevent get master::ip)"
    	    arping -I ${LAN_IFNAME} -f -w 1 ${MASTER_IP}
    	    if [ "$?" = "0" ]; then
        	return 0
   	    fi
	done
	for i in 1 2 3; 
	do
	    DEFAULT_ROUTER="$(sysevent get default_router)"
    	    arping -I ${LAN_IFNAME} -f -w 1 $DEFAULT_ROUTER
    	    if [ "$?" = "0" ]; then
        	return 0
    	    fi
   	    sleep 3
	done
	return 1
}
while [ 1 ]
do
    sleep 10;
	MODE=`syscfg get smart_mode::mode`
	if [ "2" = "$MODE" ] && [ "`sysevent get wifi-status`" = "started" ] ; then
		/etc/led/show_internet_state_after.sh 0 &
		break;
	fi
    
	if [ "1" = "$MODE" ] && [ "`sysevent get wifi-status`" = "started" ] && [ "`sysevent get backhaul::status`" = "up" ] ; then
		check_ip_connection
		if [ "1" = "$?" ];then
			continue;
		fi
		sysevent set wifi_interrupt_led
		/etc/led/show_internet_state_after.sh 0 &
		break;
	fi
done
