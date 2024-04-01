#!/bin/sh
#
# This script will be called when an LLDP UPDATE event is recieved
#
# $1 = recv interface name
# $2 = mac address of device that sent update packet


source /etc/init.d/lldp_funcs.sh

INTF="$1"
RAW_MAC_ADDR=$2
MAC_ADDR=`echo $RAW_MAC_ADDR | tr -d ":"`
FILE_DIR="/tmp"
STAT_FILE="$(compose_stat_path $FILE_DIR $INTF $MAC_ADDR)"

LOCK_FILE=/tmp/update_handler_$1_$2.lock

SM_MODE="`syscfg get smart_mode::mode`"

if [ "$SM_MODE" == "1" ] ; then
	RADDR="`sysevent get lldp::root_address`"
	#echo "slave detected lldp update packet on $INTF,$MAC_ADDR" >> /dev/console
	#echo "slave lldp::root_accessible=`sysevent get lldp::root_accessible`" >> /dev/console
	sleep 2
	if [ ! -f "$STAT_FILE" ] ; then
		sleep 2
	fi	
	if [ -f "$STAT_FILE" ] ; then
	
		RA="`cat $STAT_FILE | grep "ra=" -m 1 | cut -d'=' -f2`"
		RA_MODE="$(cat $STAT_FILE | grep "mode=" -m 1 | cut -d'=' -f2)"
		HEX_RA=`cat $STAT_FILE | grep "rip=" -m 1 | cut -d'=' -f2 | sed "s/,/ 0x/g"`
		WAN_IP=$(sysevent get ipv4_wan_ipaddr)
		PEER_MAC="$(cat $STAT_FILE | grep "port.mac" -m 1 | cut -d'=' -f2)"
		MY_MAC="$(syscfg get device::mac_addr)"
		ROOT_ACCESS=$(sysevent get lldp::root_accessible)
		BACKHAUL_MEDIA="$(sysevent get backhaul::media)"
		
		if [ "`syscfg get lldpd::debug`" == "1" ] ; then
		
		###########################################
		echo "===============   LLDP  UPDATE ==============" >> /dev/console
		echo " got update packet where RA=$RA HEX_RA=$HEX_RA on int=$INTF PEER_MAC=$PEER_MAC" >> /dev/console
		echo " current sysevent lldp::root_accessible=`sysevent get lldp::root_accessible`" >> /dev/console
		echo " current sysevent backhaul::media=`sysevent get backhaul::media`" >> /dev/console
		echo " current sysevent lldp::root_address=`sysevent get lldp::root_address`" >> /dev/console
		echo "=============================================" >> /dev/console
		###########################################
		fi

		#if rip is null, return
		if [ "$HEX_RA" != "" ] ; then
			RA_RIP="$(printf "%d.%d.%d.%d" 0x${HEX_RA})"
			MY_RIP="`sysevent get lldp::root_address`"
		else
			unlock $LOCK_FILE
			return 1
		fi
		
		#if ra is null, return
		if [ "$RA" == "" ] ; then
			unlock $LOCK_FILE
			return 1
		fi
		if [ "$RA"  == "00" ]; then
			RA="0"
		else
			RA="`echo $RA | tr -d '0'`"
		fi

		#if [ "${ROOT_ACCESS}" != "${RA}" ] ; then # if RA != lldp::root_accessible
			# Here we have detected a RA device on a wired port, set the RA the same as the upstream device
			if [ "`echo $INTF | grep eth`" ] ; then			
				backhaul_intf="$(sysevent get backhaul::intf)"
				#check the RA
				#if get LLDP RA=1, definite set as wired backhaul, backhaul::media=1. 
				#but as the root_intf, we need to check if the other port is backhaul and backhaul::media=1
				if [ "$RA" == "1" ] ; then
					update_se_if_changed lldp::root_intf $INTF
					if [ "$RA_RIP" != "" ]; then
						update_se_if_changed lldp::root_address $RA_RIP
					fi	
					update_RA "$RA"
					update_BM "1"					
				#Get LLDP RA=2
				elif [ "$RA" == "2" ] ; then					
					#my mac < peer's mac, and try backhaul switch less than 3 times for this MAC then set backhaul media 1, else keep the status.
					PEER_MAC=$(echo $PEER_MAC | tr '[a-z]' '[A-Z]') 
					MY_MAC=$(echo $MY_MAC | tr '[a-z]' '[A-Z]') 
					RETRY="`sysevent get backhaul::${PEER_MAC}`"
					RETRY_TIMES=0
					LAST_RETRY=0
					if [ -n "${RETRY}" ] ; then
						RETRY_TIMES=$(echo $RETRY | awk -F '/' '{print $1}')
						LAST_RETRY=$(echo $RETRY | awk -F '/' '{print $2}')
					fi
					NOW=$(date +%s)
					if [ "$MY_MAC" \> "$PEER_MAC" ] && [ "$RETRY_TIMES" -lt 3 ] && [ "`expr $NOW - $LAST_RETRY`" -gt 60 ] ; then
						update_se_if_changed lldp::root_intf $INTF
						if [ "${BACKHAUL_MEDIA}" == "2" ]; then
						    RETRY_TIMES=`expr ${RETRY_TIMES} + 1`
						    sysevent set backhaul::${PEER_MAC} "${RETRY_TIMES}/${NOW}"
						fi
						if [ "$RA_RIP" != "" ]; then
							update_se_if_changed lldp::root_address $RA_RIP
						fi							
						update_RA "$RA"
						update_BM "1"
						echo "[BH] Warning: Set BM 1, get RA=2 from $PEER_MAC " >> /dev/console						
					else
						[ "$RETRY_TIMES" -ge 3 ] && echo "[BH] 3 times limitation of wired backhaul switching in the current topology" >> /dev/console
						#else just update RA for wired backhaul
						if [ "${BACKHAUL_MEDIA}" == "1" ]; then
							update_se_if_changed lldp::root_intf $INTF
							if [ "$RA_RIP" != "" ]; then
								update_se_if_changed lldp::root_address $RA_RIP
							fi								
							update_RA "$RA"
						fi
					fi
				#Get RA=0 on backhaul interface, set the lldp::root_accessible=0
				elif [ "$RA" == "0" ] ; then
					if [ "${backhaul_intf:0:3}" == "eth" ] && [ "${BACKHAUL_MEDIA}" == "1" ]; then
						ip_connection_down
						if [ "$?" == "0" ] ; then
							sysevent set backhaul::intf
							sysevent set backhaul::status down
							sysevent set lldp::root_intf
							update_RA "0"
							update_BM "2"						
						fi
					fi
				fi
			# Here we have detected a RA device on a wireless port,
			else
				#check the RA and current backhaul::media
				if [ "$RA" != "0" ] && [ "${BACKHAUL_MEDIA}" != "1" ] ; then
					# Here we have detected a RA device on a wireless port
					update_se_if_changed lldp::root_intf ${INTF}
					update_RA "2"
					update_BM "2"				
				fi
			fi
		#fi # if RA != ROOT_ACCESS
		#if the root address changed(master ip changed.)
		if [ "$RA_RIP" != "" ] && [ "${MY_RIP}" != "${RA_RIP}" ] ; then
			echo "reload lldp config because root address was changed from $MY_RIP to $RA_RIP" >> /dev/console
			if [ "$RA_RIP" != "" ] && [ "${BACKHAUL_MEDIA}" == "1" ]; then
				update_se_if_changed lldp::root_address $RA_RIP
			fi				
			#echo "lldp restarting dhcp" >> /dev/console
			sysevent set dhcp_client-release
			sleep 2
			sysevent set dhcp_client-renew
			#Reload the lldp config file, it will trigger lldp update to the neighbors			
			sysevent set lldp::reload_config
		fi
	fi #if [ -f "$STAT_FILE" ]
#For unconfigured Nodes, we need to set the lldp::root_address, as node-mode depends on that.
elif [ "$SM_MODE" == "0" ] ; then 
	if [ ! -f "$STAT_FILE" ] ; then
		sleep 2
	fi
	if [ -f "$STAT_FILE" ] ; then
		RA="$(cat $STAT_FILE | grep "ra=" -m 1 | cut -d'=' -f2)"
		HEX_RA="$(cat $STAT_FILE | grep "rip=" -m 1 | cut -d'=' -f2 | sed "s/,/ 0x/g")"
		if [ "$HEX_RA" != "" ] && [ "$RA" == "01" -o "$RA" == "02" ]; then
			RA_RIP="$(printf "%d.%d.%d.%d" 0x${HEX_RA})"
			ROOT_ADDRESS="$(sysevent get lldp::root_address)"
			if [ "${RA_RIP}" != "${ROOT_ADDRESS}" ] ; then
				update_se_if_changed lldp::root_address $RA_RIP
			fi
		fi
	fi
fi
unlock $LOCK_FILE
# omsg publication deprecated Thu Aug 10 10:00:50 PDT 2017 by dash.
# It appears that no one uses the LLDP data sent to the Master.  I'm
# commenting this out for now and will revisit for complete removal at
# a later date.  If you have a need for this and would like this
# functionality restored, contact dash (darrell.shively@belkin.com).

# Also post to omsg if we have all the required information
# pub_lldp_status "$STAT_FILE" "$RAW_MAC_ADDR" "$INTF"
