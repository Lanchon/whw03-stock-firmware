#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/lldp_funcs.sh
SERVICE_NAME="lldpd"
NAMESPACE=$SERVICE_NAME
SYSTEM_NAME="LinksysVelopNode.v1"
SMART_MODE="`syscfg get smart_mode::mode`"
CLIENT_CONF="/tmp/lldpcli.conf"
MONITOR_CONF="/tmp/lldpcli_monitor.conf"
OUI="EC,1A,59"
UUID_ORIG=`syscfg get device::uuid | tr -d "-" | fold -w2` 
UUID=`echo $UUID_ORIG | sed "s/ /,/g"`
MY_IP="`sysevent get lan_ipaddr`"
LLDP_INFO_DIR=/tmp/nb
UPDATE_CALLBACK="/var/config/lldp_dev_update.sh"
DELETE_CALLBACK="/var/config/lldp_dev_delete.sh"
ADD_CALLBACK="/var/config/lldp_dev_added.sh"
INTERFACE_LLDP_LENGTH=18
if [ "$(syscfg get lldpd_debug)" = "1" ]; then
    set -x
fi
def_lldp_ena="1"
if [ "`syscfg get lldpd::enabled`" == "" ] ; then
	syscfg set lldpd::enabled "$def_lldp_ena"
fi
create_config ()
{
	if [ "`sysevent get lldpd-reconfiguring`" == "1" ] ; then
		echo "lldpd configuration already running" >> /dev/console
		exit 0
	else
		sysevent set lldpd-reconfiguring 1
	fi
	
	echo "pause" > $CLIENT_CONF
	echo "configure system hostname `hostname`" >> $CLIENT_CONF
	echo "configure system description Velop" >> $CLIENT_CONF
	
	echo "unconfigure med fast-start" >> $CLIENT_CONF
	echo "unconfigure system ip management pattern" >> $CLIENT_CONF
	echo "unconfigure lldp custom-tlv oui $OUI subtype 1" >> $CLIENT_CONF
	echo "unconfigure lldp custom-tlv oui $OUI subtype 2" >> $CLIENT_CONF
	echo "unconfigure lldp custom-tlv oui $OUI subtype 3" >> $CLIENT_CONF
	ROOT_IPADDR="`sysevent get lldp::root_address`"
	if [ "$ROOT_IPADDR" ] ; then
		echo "unconfigure lldp custom-tlv oui $OUI subtype 4" >> $CLIENT_CONF
	fi
	echo "unconfigure lldp custom-tlv" >> $CLIENT_CONF
	if [ "$SMART_MODE" = "1" ]; then
	    ip="$(sysevent get ipv4_wan_ipaddr)"
	        if [ -n "$ip" -a "$ip" != "0.0.0.0" ]; then
	            echo "configure system ip management pattern $ip" >> $CLIENT_CONF
	        fi
	else
        bridge_mode=$(syscfg get bridge_mode)
        if [ "$bridge_mode" = "0" ]; then
	    ip="$(syscfg get lan_ipaddr)"
        else
            ip="$(sysevent get ipv4_wan_ipaddr)"
        fi
        if [ -n "$ip" -a "$ip" != "0.0.0.0" ]; then
	        echo "configure system ip management pattern $ip" >> $CLIENT_CONF
	    fi
	fi
	echo "configure lldp custom-tlv oui $OUI subtype 1 oui-info $UUID" >> $CLIENT_CONF
	echo "configure lldp custom-tlv oui $OUI subtype 2 oui-info $SMART_MODE" >> $CLIENT_CONF
	ROOT_ACCESS="`sysevent get lldp::root_accessible`"
	if [ "$SMART_MODE" == "2" ] ; then
		if [ "`syscfg get bridge_mode`" = "0" ] ; then
		    ROOT_IPADDR="`syscfg get lan_ipaddr`"
		else
		    ROOT_IPADDR="`sysevent get ipv4_wan_ipaddr`"
		fi
		if [ "`sysevent get lldp::root_accessible`" ] ; then
			update_RA ""
			sysevent set lldp::root_intf ""
		fi
	else
		ROOT_ACCESS="`sysevent get lldp::root_accessible`"
		if [ ! "$ROOT_ACCESS" ] ; then
			echo "setting root_accessible to 0 by default" >> /dev/console
			update_RA 0
			sysevent set lldp::root_intf ""
		fi
	fi
	if [ "$SMART_MODE" != "2" ] ; then
		ROOT_IPADDR="`sysevent get lldp::root_address`"
		ROOT_ACCESS="`sysevent get lldp::root_accessible`"
		echo "configure lldp custom-tlv oui $OUI subtype 3 oui-info $ROOT_ACCESS" >> $CLIENT_CONF
	else
		echo "configure lldp custom-tlv oui $OUI subtype 3 oui-info 1" >> $CLIENT_CONF
	fi
	if [ "$ROOT_IPADDR" ] ; then
		NEW_IP=`echo $ROOT_IPADDR | sed "s/\./,/g"`
		seg1="`echo $NEW_IP | cut -d ',' -f1`"
		seg2="`echo $NEW_IP | cut -d ',' -f2`"
		seg3="`echo $NEW_IP | cut -d ',' -f3`"
		seg4="`echo $NEW_IP | cut -d ',' -f4`"
		hseg1=`printf "%x" $seg1`
		hseg2=`printf "%x" $seg2`
		hseg3=`printf "%x" $seg3`
		hseg4=`printf "%x" $seg4`
		echo "configure lldp custom-tlv oui $OUI subtype 4 oui-info $hseg1,$hseg2,$hseg3,$hseg4" >> $CLIENT_CONF
	fi
	echo "resume" >> $CLIENT_CONF
	echo "update" >> $CLIENT_CONF
	echo "watch" > $MONITOR_CONF
	if [ ! -f "/var/config/lldp_mon.sh" ] ; then
		echo "#!/bin/sh" > /var/config/lldp_mon.sh
		echo "echo \"RA=\`sysevent get lldp::root_accessible\`\"" >> /var/config/lldp_mon.sh
		echo "echo \"BM=\`sysevent get backhaul::media\`\"" >> /var/config/lldp_mon.sh
		echo "echo \"RI=\`sysevent get lldp::root_intf\`\"" >> /var/config/lldp_mon.sh
		echo "echo \"BI=\`sysevent get backhaul::intf\`\"" >> /var/config/lldp_mon.sh
		chmod +x /var/config/lldp_mon.sh
	fi
	sysevent set lldpd-reconfiguring 0
}
reload_lldp_config ()
{
	if [ "$(sysevent get ${SERVICE_NAME}-status)" == "started" ] ; then
		if [ -S "/tmp/lldpd.sock" ]; then
			create_config
			/usr/bin/lldpcli -c $CLIENT_CONF
		else
			service_stop
			service_start
		fi
	else
		service_stop
		service_start
	fi
}
lldp_update()
{
    if [ "$(sysevent get ${SERVICE_NAME}-status)" == "started" ] && [ -S "/tmp/lldpd.sock" ] ; then
    	echo "unconfigure lldp custom-tlv oui $OUI subtype 5" > /tmp/ud.conf
        echo "configure lldp custom-tlv oui $OUI subtype 5 oui-info `expr $RANDOM % 99`" >> /tmp/ud.conf
        /usr/bin/lldpcli -c /tmp/ud.conf
    fi
}
service_start ()
{
	wait_till_end_state ${SERVICE_NAME}
	create_config
	if [ ! -d $LLDP_INFO_DIR ]; then
			mkdir $LLDP_INFO_DIR
	fi
	if [ ! "`sysevent get lldp::scripts_updated`" ] ; then
  		echo "lldp updating callback scripts"
		cp /etc/lldp_scripts/lldp_dev_update.sh $UPDATE_CALLBACK
		chmod +x $UPDATE_CALLBACK
		cp /etc/lldp_scripts/lldp_dev_delete.sh $DELETE_CALLBACK
		chmod +x $DELETE_CALLBACK
		cp /etc/lldp_scripts/lldp_dev_added.sh $ADD_CALLBACK
		chmod +x $ADD_CALLBACK
		sysevent set lldp::scripts_updated 1
	fi
	
	if [ "`sysevent get backhaul::media`" == "" ] ; then
		update_BM 0
	fi
	
	start_check="0"
	
	/usr/bin/lldpd -I eth*
	if [ "$?" != "0" ] ; then
		echo ">> LLDPD - ERROR STARTING DAEMON" >> /dev/console
		start_check="1"
	fi
	/usr/bin/lldpcli -c $CLIENT_CONF
	if [ "$?" != "0" ] ; then
		echo ">> LLDPD - ERROR STARTING CLIENT" >> /dev/console
		start_check="2"
	fi
	/usr/bin/lldpcli -f keyvalue -l $LLDP_INFO_DIR -U $UPDATE_CALLBACK -D $DELETE_CALLBACK -A $ADD_CALLBACK  watch details &
	if [ "$?" != "0" ] ; then
		echo ">> LLDPD - ERROR STARTING CLIENT 2" >> /dev/console
		start_check="3"
	fi
	if [ "$start_check" == "0" ] ; then
		sysevent set ${SERVICE_NAME}-status started
		ulog ${SERVICE_NAME} status "now started"
	fi
}
service_stop ()
{
   wait_till_end_state ${SERVICE_NAME}
	check_err $? "Couldnt handle stop"
	killall -TERM lldpd
	sysevent set ${SERVICE_NAME}-status stopped
	ulog ${SERVICE_NAME} status "now stopped"
}
if [ "`syscfg get lldpd::enabled`" != "1" ] ; then
	echo "lldpd disabled in syscfg" >> /dev/console
	exit 0
fi
echo "lldpd event $1 $2 received. "
ulog ${SERVICE_NAME} status "lldpd event $1 $2 received. "
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
	setup::presetup)
		service_stop
		service_start
		;;
	lan_ipaddr)
		reload_lldp_config
		;;
	ipv4_wan_ipaddr)
		if [ "`syscfg get smart_mode::mode`" == "1" ] && [ "$(sysevent get ipv4_wan_ipaddr)" != "0.0.0.0" ]; then
			reload_lldp_config
		fi
		;;
	lldp::reload_config)
		reload_lldp_config
		;;
	lldp::root_accessible)
		if  [ "`syscfg get smart_mode::mode`" == "1" ] && [ "$2" != "" ] ; then
			if [ "$2" == "2" ] ; then
				COUNTER=`expr $RANDOM % 5`
				TIMER=`expr $COUNTER + 5`
				echo "lldp::root_accessible 2, sleeping $TIMER before reload the lldp config." >> /dev/console
				sleep $TIMER
			elif [ "$2" == "1" ] ; then
				echo "lldp::root_accessible 1, sleeping 1s before reload the lldp config." >> /dev/console
				sleep 1
			fi
			reload_lldp_config
		fi
		;;
	lldp::update)
		if [ "2" = "$(syscfg get smart_mode::mode)" ] ; then
		    lldp_update
		fi
		;;
	ETH::port_1_status|ETH::port_2_status|ETH::port_3_status|ETH::port_4_status|ETH::port_5_status)
		if [ "$2" == "up" ] ; then
			LASTCHANGE=`date +%s`
			sysevent set "$1"_change $LASTCHANGE
			if [ "`syscfg get smart_mode::mode`" == "1" ]; then 
				COUNTER=`expr $RANDOM % 5`
				TIMER=`expr $COUNTER + 2`
				echo "sleeping for $TIMER before restarting lldp because of cable attach on port 4" >> /dev/console
				sleep $TIMER
				service_stop
				service_start
			elif [ "`syscfg get smart_mode::mode`" == "2" ]; then
				lldp_update
			fi
		fi
		;;
	backhaul::status)
		if [ "`syscfg get smart_mode::mode`" == "1" ] && [ "$(sysevent get backhaul::media)" == "2" ]; then
			if [ "$2" == "up" ] ; then
				master_ip="$(sysevent get master::ip)"
				if [ "$master_ip" != "" ] ; then
					backhaul_intf="$(sysevent get backhaul::intf)"
					update_se_if_changed lldp::root_intf "${backhaul_intf}"
					current_RA="$(sysevent get lldp::root_accessible)"
					if [ "$current_RA" = "2" ] ; then
						current_root_address="$(sysevent get lldp::root_address)"
						if [ "$current_root_address" !=  "$master_ip" ] ; then
							sysevent set lldp::root_address "${master_ip}"
							reload_lldp_config
						fi
					else
						update_se_if_changed lldp::root_address "${master_ip}"
						update_se_if_changed lldp::root_accessible 2
					fi
				fi
			elif [ "$2" == "down" ] ; then
				update_se_if_changed lldp::root_accessible 0
			fi
		fi
		;;
	master::ip)
		if [ "$2" != "" ] && [ "`syscfg get smart_mode::mode`" == "1" ] ; then
			if [ "`sysevent get backhaul::status`" == "up" ] && [ "$(sysevent get backhaul::media)" == "2" ]; then
				backhaul_intf="$(sysevent get backhaul::intf)"
				update_se_if_changed lldp::root_intf "${backhaul_intf}"
				current_RA="$(sysevent get lldp::root_accessible)"
				if [ "$current_RA" = "2" ] ; then
					current_root_address="$(sysevent get lldp::root_address)"
					if [ "$current_root_address" !=  "$2" ] ; then
						sysevent set lldp::root_address "$2"
						reload_lldp_config
					fi
				else
					update_se_if_changed lldp::root_address "$2"
					update_se_if_changed lldp::root_accessible 2
				fi
			fi
		fi
		;;				
	*)
		echo "error : $1 unknown" > /dev/console 
		echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		exit 3
		;;
esac
