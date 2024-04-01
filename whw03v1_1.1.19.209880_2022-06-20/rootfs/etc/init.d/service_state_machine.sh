#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="state_machine"
NAMESPACE=$SERVICE_NAME
service_start ()
{
	wait_till_end_state ${SERVICE_NAME}
	check_err $? "Couldnt handle start"
	sysevent set ${SERVICE_NAME}-status started
	ulog ${SERVICE_NAME} status "now started"
}
service_stop ()
{
  wait_till_end_state ${SERVICE_NAME}
	check_err $? "Couldnt handle stop"
	sysevent set ${SERVICE_NAME}-status stopped
	ulog ${SERVICE_NAME} status "now stopped"
}
smart_connect_prepare ()
{
   if [ "`cat /etc/product`" = "wraith" ] && [ "`syscfg get smart_mode::mode`" = "1" -o  "`syscfg get smart_mode::mode`" = "0" ]; then
		/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-start ath8
		return
   fi
   if [ "`syscfg get smart_mode::mode`" = "1" ] || [ "`syscfg get smart_mode::mode`" = "0" ]; then
	   if [ "`sysevent get smart_connect::prepared`" != "1" ]; then
			ifconfig|grep -q br2
			if [ $? = 1 ] ; then
				brctl addbr br2
				brctl setfd br2 0
				brctl stp br2 on
			fi   
			if [ -n "`syscfg get wl0_mac_addr`" ] ; then
				ifconfig br2 hw ether "`syscfg get wl0_mac_addr`"
			fi		
			ip link set br2 up 
			ip link set br2 allmulticast off
			if [ "`sysevent get smart_connect::setup_mode`" != "wired" ] ; then 
			    /etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-start
			fi
			sysevent set smart_connect::prepared 1
		fi
   fi
}
smart_connect_error_handler ()
{
	if [ "`syscfg get smart_mode::mode`" = "0" ] ; then
		echo "smart_connect::setup_lasterror `sysevent get smart_connect::setup_lasterror`" >> /dev/console
		sleep 1
		while [ "`sysevent get smart_connect::setup_duration_timeout`" != "1" ] ;
		do
			sleep 1
		done 
		sysevent set smart_connect::setup_status READY
	fi
}
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
	smart_connect::setup_status)
		case "`sysevent get smart_connect::setup_status`" in
			READY)
				echo "state_machine entering READY" >> /dev/console
			;;
			START)
				echo "state_machine entering START" >> /dev/console
				smart_connect_prepare
			;;
			TEMP-AUTH)
				echo "state_machine entering TEMP-AUTH" >> /dev/console
			;;
			AUTH) 
				echo "state_machine entering AUTH" >> /dev/console
			;;
			DONE)
				echo "state_machine entering DONE" >> /dev/console
			;;
			ERROR)
				echo "state_machine entering ERROR" >> /dev/console
				smart_connect_error_handler
			;;
		esac
		;;
	backhaul::status)
		case "`sysevent get backhaul::status`" in
			up)
				if [ "`syscfg get smart_mode::mode`" = "1" ] ; then
					echo "backhaul up(`date`)" >> /dev/console
					echo "backhaul::intf=`sysevent get backhaul::intf`" >> /dev/console
					echo "backhaul::preferred_bssid=`sysevent get backhaul::preferred_bssid`" >> /dev/console
					echo "backhaul::preferred_chan=`sysevent get backhaul::preferred_chan`" >> /dev/console
					echo "smart_connect::setup_status=`sysevent get smart_connect::setup_status`" >> /dev/console
				fi
			;;
			down)
				if [ "`syscfg get smart_mode::mode`" = "1" ] ; then
					echo "backhaul down(`date`)" >> /dev/console
				fi
			;;
		esac
		;;
	smart_connect::setup_lasterror)
		echo "smart_connect::setup_lasterror `sysevent get smart_connect::setup_lasterror`" >> /dev/console
		;;
	*)
		echo "error : $1 unknown" > /dev/console 
		echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		exit 3
		;;
esac
