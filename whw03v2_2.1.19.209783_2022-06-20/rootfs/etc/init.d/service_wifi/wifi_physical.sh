#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_virtual.sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
wifi_physical_start()
{
	ulog wlan status "${SERVICE_NAME}, wifi_physical_start($1)"
	echo "${SERVICE_NAME}, wifi_physical_start($1)"
	PHY_IF=$1
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	wait_till_end_state ${WIFI_PHYSICAL}_${PHY_IF}
	STATUS=`sysevent get ${WIFI_PHYSICAL}_${PHY_IF}-status`
	if [ "started" = "$STATUS" ] || [ "starting" = "$STATUS" ] ; then
		ulog wlan status "${SERVICE_NAME}, ${WIFI_PHYSICAL} is starting/started, ignore the request"
		return 1
	fi
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	USER_STATE=`syscfg_get ${SYSCFG_INDEX}_state`
	if [ "$USER_STATE" = "down" ]; then
		VIR_IF=`syscfg_get "$SYSCFG_INDEX"_user_vap`
		echo "${SERVICE_NAME}, ${SYSCFG_INDEX}_state=$USER_STATE, do not start physical $PHY_IF"
		return 1
	fi
	STA_PHY_IF=`syscfg_get wifi_sta_phy_if`
	if [ "2" = "`syscfg_get wifi_bridge::mode`" ] && [ "$PHY_IF" = "$STA_PHY_IF" ]; then
		echo "${SERVICE_NAME}, $PHY_IF is in repeater mode, do not start physical again"
		return 1
	fi
	sysevent set ${WIFI_PHYSICAL}_${PHY_IF}-status starting
	physical_pre_setting $PHY_IF
	
	physical_setting $PHY_IF
	
	physical_post_setting $PHY_IF
	sysevent set ${WIFI_PHYSICAL}_${PHY_IF}-status started
	
	return 0
}
wifi_physical_stop()
{
	ulog wlan status "${SERVICE_NAME}, wifi_physical_stop($1)"
	echo "${SERVICE_NAME}, wifi_physical_stop($1)"
	PHY_IF=$1
	if [ -z "$PHY_IF" ]; then
		echo "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		ulog wlan status "${SERVICE_NAME}, ${WIFI_USER} ERROR: invalid interface name, ignore the request"
		return 1
	fi
	wait_till_end_state ${WIFI_PHYSICAL}_${PHY_IF}
	STATUS=`sysevent get ${WIFI_PHYSICAL}_${PHY_IF}-status`
	if [ "stopping" = "$STATUS" ] || [ "stopped" = "$STATUS" ] || [ -z "$STATUS" ]; then
		ulog wlan status "${SERVICE_NAME}, ${WIFI_PHYSICAL} is already stopping/stopped, ignore the request"
		return 1
	fi
	STA_PHY_IF=`syscfg_get wifi_sta_phy_if`
	if [ "2" = "`syscfg_get wifi_bridge::mode`" ] && [ "$PHY_IF" = "$STA_PHY_IF" ]; then
		echo "${SERVICE_NAME}, $PHY_IF is in repeater mode, do not stop this physical interface"
		return 1
	fi
        
	sysevent set ${WIFI_PHYSICAL}_${PHY_IF}-status stopping
	if [ "`sysevent get ldal_setup_vap-status`" = "started" ]; then
		sysevent set ldal_setup_vap-stop
		wait_till_end_state ldal_setup_vap
	fi
	
	if [ "`sysevent get ldal_infra_vap-status`" = "started" ]; then
		sysevent set ldal_infra_vap-stop
		wait_till_end_state ldal_infra_vap
	fi
	
	if [ "`sysevent get ldal_station_connect-status`" = "started" ]; then
		sysevent set ldal_station_connect-stop
		wait_till_end_state ldal_station_connect
	fi
	
	sysevent set ${WIFI_PHYSICAL}_${PHY_IF}-status stopped
	return 0
}
wifi_physical_restart()
{
	ulog wlan status "${SERVICE_NAME}, wifi_physical_restart()"
	echo "${SERVICE_NAME}, wifi_physical_restart()"
	for PHY_IF in $PHYSICAL_IF_LIST; do
		wifi_physical_stop $PHY_IF
		wifi_physical_start $PHY_IF
	done
	return 0
}
physical_pre_setting()
{
	ulog wlan status "${SERVICE_NAME}, physical_pre_setting($1)"
	PHY_IF=$1
	return 0
}
physical_post_setting()
{
	ulog wlan status "${SERVICE_NAME}, physical_post_setting($1)"
	PHY_IF=$1
	LDAL_ENABLED=`syscfg_get lego_enabled`
	LDAL_VSTA=`syscfg_get ldal_wl_vsta`
	if [ ! -z "$LDAL_ENABLED" ] && [ "$LDAL_ENABLED" = "1" ]; then
		if [ -z "$LDAL_VSTA" ]; then
			ulog wlan status "${SERVICE_NAME}, fire up the infra vap first" > /dev/console
			sysevent set ldal_infra_vap-stop
			sysevent set ldal_infra_vap-start
		else
			EDALSETTINGFILE="/var/config/ldal/edalsettingd.cfg"
			if [ ! -f $EDALSETTINGFILE ]; then
				ulog wlan status "${SERVICE_NAME}, force to edal setup on the first boot" > /dev/console
				syscfg_set ldal_wl_station_state unconfigured
			fi
			ulog wlan status "${SERVICE_NAME}, fire up the station connect first" > /dev/console
			sysevent set ldal_station_connect-stop
			sysevent set ldal_station_connect-start
		fi
	fi
	return 0
}
physical_setting()
{
	ulog wlan status "${SERVICE_NAME}, physical_setting($1)"
	PHY_IF=$1
	if [ "wifi0" = "`syscfg_get wifi_sta_phy_if`" ]; then
		STA_PHY_IF="ath0"
	elif [ "wifi1" = "`syscfg_get wifi_sta_phy_if`" ]; then
		STA_PHY_IF="ath1"
	fi
	
	if [ "Extender" = $DEVICE_TYPE ]; then
		set_driver_opmode $PHY_IF
		set_driver_wmm $PHY_IF
	else
		if [ "`cat /etc/product`" != "nodes" ] && [ "`cat /etc/product`" != "nodes-jr" ] && [ "`cat /etc/product`" != "rogue" ] && [ "`cat /etc/product`" != "lion" ] ; then
			set_driver_obss_rssi_threshold $PHY_IF
		fi
		set_driver_mcastenhance $PHY_IF		
		set_driver_regioncode $PHY_IF
		set_driver_gprotect $PHY_IF
		set_driver_htprotect $PHY_IF
		set_driver_bcninterval $PHY_IF
		set_driver_rts_threshold $PHY_IF
		set_driver_htgreenfiled_preamble $PHY_IF
		set_driver_htstbc $PHY_IF
		set_driver_transmission_rate $PHY_IF
		set_driver_short_gi $PHY_IF
		set_driver_wmm $PHY_IF
		set_driver_dfs $PHY_IF
		if [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
			if [ "up" != "`sysevent get backhaul::status`" ] || [ "$PHY_IF" != "`sysevent get backhaul::intf_AP`" ];then
				set_driver_opmode $PHY_IF
				set_driver_channel $PHY_IF
			else
				echo "${SERVICE_NAME}, physical_setting($PHY_IF): STA interface is on this same band, keep channel setting the same as root AP channel"
				STA_IF=`sysevent get backhaul::intf_AP`
				STA_CHANNEL="`get_interface_channel $STA_IF`"
				echo "	$PHY_IF set channel to STA channel $STA_CHANNEL"
				iwconfig $PHY_IF channel $STA_CHANNEL
			fi		
		else
			if [ "" = "`syscfg_get wifi_bridge::mode`" ] || [ "0" = "`syscfg_get wifi_bridge::mode`" ] || [ "$PHY_IF" != "$STA_PHY_IF" ]; then
				set_driver_opmode $PHY_IF
				set_driver_channel $PHY_IF
			else
				echo "${SERVICE_NAME}, physical_setting($PHY_IF): STA interface is on this same band, keep channel setting the same as root AP channel"
				STA_IF=`syscfg_get wifi_sta_vir_if`
				STA_CHANNEL="`get_interface_channel $STA_IF`"
				echo "	$PHY_IF set channel to STA channel $STA_CHANNEL"
				iwconfig $PHY_IF channel $STA_CHANNEL
			fi	
		fi				
		set_driver_regioncode $PHY_IF
	fi	
	return 0
}
get_wl_name() 
{
	if [ "Extender" = $DEVICE_TYPE ]; then
		if [ ! -z "$EXTENDER_RADIO_MODE" ] && [ $EXTENDER_RADIO_MODE = "1" ]; then
			wlname="wl1"
		else
			wlname="wl0"
		fi
	else
		wlname=$1;
	fi
	echo "$wlname"
}
get_sideband() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_CHANNEL=`syscfg_get "$SYSCFG_INDEX"_channel`
	SIDEBAND=`syscfg_get "$SYSCFG_INDEX"_sideband`
	if [ "$SIDEBAND" = "lower" ]; then
		SIDEBAND="MINUS"
	else
		SIDEBAND="PLUS"
	fi
	if [ "$SYSCFG_CHANNEL" = "1" -o "$SYSCFG_CHANNEL" = "2" -o "$SYSCFG_CHANNEL" = "3" -o "$SYSCFG_CHANNEL" = "4" -o "$SYSCFG_CHANNEL" = "36" -o "$SYSCFG_CHANNEL" = "44" -o "$SYSCFG_CHANNEL" = "52" -o "$SYSCFG_CHANNEL" = "100" -o "$SYSCFG_CHANNEL" = "116" -o "$SYSCFG_CHANNEL" = "132" -o "$SYSCFG_CHANNEL" = "149" -o "$SYSCFG_CHANNEL" = "157" ]; then
		SIDEBAND="PLUS"
	elif [ "$SYSCFG_CHANNEL" = "8" -o "$SYSCFG_CHANNEL" = "9" -o "$SYSCFG_CHANNEL" = "10" -o "$SYSCFG_CHANNEL" = "11" -o "$SYSCFG_CHANNEL" = "12" -o "$SYSCFG_CHANNEL" = "13" -o "$SYSCFG_CHANNEL" = "40" -o "$SYSCFG_CHANNEL" = "48" -o "$SYSCFG_CHANNEL" = "153" -o "$SYSCFG_CHANNEL" = "161" ]; then
		SIDEBAND="MINUS"
	elif [ "$SYSCFG_CHANNEL" = "0" ]; then
		SIDEBAND=""
	fi	
	echo $SIDEBAND
}
get_driver_bandwidth() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_BW=`syscfg_get "$SYSCFG_INDEX"_radio_band`
	if [ "standard" = "$SYSCFG_BW" ]; then
		HTBW="$HTBW_20MHZ"
	elif [ "wide" = "$SYSCFG_BW" ]; then
		HTBW="$HTBW_40MHZ"
	elif [ "wide80" = "$SYSCFG_BW" ]; then
		HTBW="$HTBW_80MHZ"
	else
		if [ "`is_11ac_supported $SYSCFG_INDEX`" = "1" ]; then
			HTBW="$HTBW_80MHZ"
		else
			HTBW="$HTBW_40MHZ"
		fi
	fi
	if [ "165" = "`syscfg get ${SYSCFG_INDEX}_channel`" ]; then
		HTBW="$HTBW_20MHZ"
	fi
	if [ "`cat /etc/product`" = "nodes-jr" ] && [ "$SYSCFG_INDEX" = "wl1" ] ; then
		if [ "1" = "`syscfg_get wifi::multiregion_support`" -a "1" = "`syscfg_get wifi::multiregion_enable`" -a "1" = "`get_multiregion_region_validation`" ] ; then
		    	REGION=`syscfg get wifi::multiregion_region`
		else
		    	REGION=`syscfg_get device::cert_region`
		fi
		if [ "ID" = "$REGION" ] ; then
		    	HTBW="$HTBW_20MHZ"
		fi
	fi
	
	echo $HTBW
}
get_driver_channel() 
{
	channel="$1"
	echo "$channel"
}
get_driver_trans_rate() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_TRANS_RATE=`syscfg_get "$SYSCFG_INDEX"_transmission_rate`
	if [ -n "$SYSCFG_TRANS_RATE" ] && [ "auto" = "$SYSCFG_TRANS_RATE" ]; then
		TRANS_RATE=0
	else
		case "$SYSCFG_TRANS_RATE" in
			"6000000")
				TRANS_RATE=12
				;;
			"9000000")
				TRANS_RATE=18
				;;
			"12000000")
				TRANS_RATE=24
				;;
			"18000000")
				TRANS_RATE=36
				;;
			"24000000")
				TRANS_RATE=48
				;;
			"36000000")
				TRANS_RATE=72
				;;
			"48000000")
				TRANS_RATE=96
				;;
			"54000000")
				TRANS_RATE=108
				;;
			*)
				TRANS_RATE=0
				ulog wlan status "invalid transmission_rate: $1"
				;;
		esac
	fi
			
	echo "$TRANS_RATE"
}
get_driver_n_trans_rate() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_NXRATE=`syscfg_get "$SYSCFG_INDEX"_n_transmission_rate`
	NXRATE=0 
	if [ -n "$SYSCFG_NXRATE" ]; then
		if [ "auto" = "$SYSCFG_NXRATE" ]; then
			NXRATE=0
		elif [ $SYSCFG_NXRATE -ge 0 ] && [ $SYSCFG_NXRATE -le 15 ]; then
			NXRATE=`expr $SYSCFG_NXRATE + 256`
		else
			ulog wlan status "invalid n_transmission_rate: $SYSCFG_NXRATE"
		fi
	fi
	echo "$NXRATE"
}
get_driver_beacon_interval() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_BCN_INTERVAL=`syscfg_get "$SYSCFG_INDEX"_beacon_interval`
	if [ -n "$SYSCFG_BCN_INTERVAL" ] && [ $SYSCFG_BCN_INTERVAL -ge 20 ] && [ $SYSCFG_BCN_INTERVAL -le 1000 ]; then
		BCN_INTERVAL=$SYSCFG_BCN_INTERVAL
	else
		BCN_INTERVAL=100
	fi
	echo "$BCN_INTERVAL"
}
get_driver_rts_threshold() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_RTS_THRESHOLD=`syscfg_get "$SYSCFG_INDEX"_rts_threshold`
	if [ -n "$SYSCFG_RTS_THRESHOLD" ] && [ $SYSCFG_RTS_THRESHOLD -ge 255 ] && [ $SYSCFG_RTS_THRESHOLD -le 2346 ]; then
		RTS_THRESHOLD=$SYSCFG_RTS_THRESHOLD
	else
		RTS_THRESHOLD=2347
	fi
	echo "$RTS_THRESHOLD"
}
get_driver_grn_field_pre() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_HTGREENFIELD_PREAMBLE=`syscfg_get "$SYSCFG_INDEX"_grn_field_pre`
	if [ "$SYSCFG_HTGREENFIELD_PREAMBLE" = "enabled" ]; then
		HTGREENFIELD_PREAMBLE=1
	else
		HTGREENFIELD_PREAMBLE=0
	fi
	echo "$HTGREENFIELD_PREAMBLE"
}
get_driver_stbc() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_STBC=`syscfg_get "$SYSCFG_INDEX"_stbc`
	if [ "$SYSCFG_STBC" = "enabled" ]; then
		STBC=1
	else
		STBC=0
	fi
	echo "$STBC"
}
get_driver_txpower()
{
    PHY_IF=$1
    echo -n "$(iwlist $PHY_IF txpower | fgrep dBm | fgrep 'Current' | cut -d':' -f2 | cut -d' ' -f1)"
}
get_driver_txpower_list()
{
    PHY_IF=$1
    SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
    SYSEVENT_TXPOWER_LIST=`sysevent get "$SYSCFG_INDEX"_txpower_list`
    if [ -z "$SYSEVENT_TXPOWER_LIST" ]; then
	TXPOWER_LIST="$(iwlist $PHY_IF txpower | fgrep dBm | fgrep -v 'Current' | awk '{print $1}' | tr '\n' ' ')"
	sysevent set ${SYSCFG_INDEX}_txpower_list "$TXPOWER_LIST"
    else
	TXPOWER_LIST="$SYSEVENT_TXPOWER_LIST"
    fi
    echo -n "$TXPOWER_LIST"
}
set_driver_opmode() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SIDEBAND=`get_sideband "$PHY_IF"`
	HTBW=`get_driver_bandwidth "$PHY_IF"`
	LEGALCY=`is_legalcy_mode $PHY_IF`
	iwpriv $PHY_IF pure11ac 0
	iwpriv $PHY_IF strictbw 0
	if [ "true" = "$LEGALCY" ]; then
		HTBW=$HTBW_20MHZ
	fi
	if [ "Extender" = "$DEVICE_TYPE" ]; then
		if [ ! -z "$EXTENDER_RADIO_MODE" ] && [ $EXTENDER_RADIO_MODE = "1" ]; then
			SYSCFG_NETWORK_MODE=`syscfg_get wl1_network_mode`
		else
			SYSCFG_NETWORK_MODE=`syscfg_get wl0_network_mode`
		fi
		SYSCFG_INDEX=wl"$EXTENDER_RADIO_MODE"
	else
		SYSCFG_NETWORK_MODE=`syscfg_get "$SYSCFG_INDEX"_network_mode`
	fi
	if [ "Mixed" = "$SYSCFG_NETWORK_MODE" -o "mixed" = "$SYSCFG_NETWORK_MODE" -o "MIXED" = "$SYSCFG_NETWORK_MODE" ] ; then
		if [ "$SYSCFG_INDEX" = "wl0" ]; then
			SYSCFG_NETWORK_MODE="11b 11g 11n"
		else
			if [ "`cat /etc/product`" = "wraith" ] || [ "`cat /etc/product`" = "macan" ] || [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "dallas" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
				SYSCFG_NETWORK_MODE="11a 11n 11ac"
			else
				SYSCFG_NETWORK_MODE="11a 11n"
			fi
		fi
	fi
	if [ "$HTBW" = "20" ]; then
		EXT="20"
	elif [ "$HTBW" = "80" ]; then
		if [ "11b 11g 11n 11ac" != "$SYSCFG_NETWORK_MODE" ] && [ "11a 11n 11ac" != "$SYSCFG_NETWORK_MODE" ] ; then
			EXT=40"$SIDEBAND"
		fi
	else
		EXT=40"$SIDEBAND"
	fi
	if [ "$SYSCFG_INDEX" = "wl0" ]; then
		iwpriv $PHY_IF pureg 0
		iwpriv $PHY_IF puren 0
	else
		iwpriv $PHY_IF puren 0
	fi
			
			
	case "$SYSCFG_NETWORK_MODE" in
		"11a")
			OPMODE="11A"
			;;
		"11b")
			OPMODE="11B"
			;;
		"11g")
			OPMODE="11G"
			iwpriv $PHY_IF pureg 1
			;;
		"11n")
			if [ "$SYSCFG_INDEX" = "wl0" ]; then
				OPMODE=11NGHT"$EXT"
			else
				OPMODE=11NAHT"$EXT"
			fi
			iwpriv $PHY_IF puren 1
			;;
		"11b 11g")
			OPMODE="11G"
			;;
		"11a 11n")
			OPMODE=11NAHT"$EXT"
			;;
		"11b 11g 11n")
			OPMODE=11NGHT"$EXT"
			;;
		"11a 11n 11ac")
			if [ "$HTBW" = "20" ]; then
				OPMODE=11ACVHT20
			elif [ "$HTBW" = "80" ]; then
				OPMODE=11ACVHT80
			else
				OPMODE=11ACVHT40"$SIDEBAND"
			fi
			;;
		"11ac")
			iwpriv $PHY_IF pure11ac 1
			if [ "$HTBW" = "20" ]; then
				OPMODE=11ACVHT20
			elif [ "$HTBW" = "80" ]; then
				OPMODE=11ACVHT80
				iwpriv $PHY_IF strictbw 1
			else
				OPMODE=11ACVHT40"$SIDEBAND"
			fi
			;;
		*)
			if [ "$SYSCFG_INDEX" = "wl0" ]; then
				OPMODE=11NGHT"$EXT"
			else
				OPMODE=11NAHT"$EXT"
			fi
			;;
	esac
	if [ "`syscfg get WiFi::5GHz_40MHZ`" = "1" ] && [ "$OPMODE" = "11ACVHT80" ] ; then
		OPMODE=11ACVHT40"$SIDEBAND"
	fi
	iwpriv $PHY_IF mode $OPMODE
	return 0
}
set_driver_wmm() 
{
	PHY_IF=$1
    if [ "`syscfg_get wl_wmm_support`" = "enabled" ]; then
        iwpriv $PHY_IF wmm 1
    else
        iwpriv $PHY_IF wmm 0
    fi
	return 0
}
set_driver_mcastenhance()
{
	PHY_IF=$1
    if [ "`syscfg_get wl_mcastenhance_support`" = "enabled" ]; then
        iwpriv $PHY_IF mcastenhance 2
    else
        iwpriv $PHY_IF mcastenhance 0
    fi
	return 0
}
set_driver_gprotect() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_CTSPROTECTION=`syscfg_get "$SYSCFG_INDEX"_cts_protection_mode`
	if [ "auto" != "$SYSCFG_CTSPROTECTION" ]; then
		iwpriv $PHY_IF protmode 0
		iwpriv $PHY_IF shpreamble 1 
		iwpriv $PHY_IF enablertscts 0
		iwpriv $PHY_IF chwidth 0
	else
		iwpriv $PHY_IF protmode 1		
	fi
	return 0
}
set_driver_htprotect() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_CTSPROTECTION=`syscfg_get "$SYSCFG_INDEX"_cts_protection_mode`
	HTPROTECT=0
	if [ "auto" = "$SYSCFG_CTSPROTECTION" ]; then
		HTPROTECT=1
	fi
	iwpriv $PHY_IF extprotmode $HTPROTECT
	return 0
}
set_driver_bcninterval() 
{
	PHY_IF=$1
	BCNINTERVAL=`get_driver_beacon_interval "$PHY_IF"`
	iwpriv $PHY_IF bintval $BCNINTERVAL
	return 0
}
set_driver_rts_threshold() 
{
	PHY_IF=$1
	RTS_THRESHOLD=`get_driver_rts_threshold "$PHY_IF"`
	iwconfig $PHY_IF rts $RTS_THRESHOLD
	return 0
}
set_driver_htgreenfiled_preamble() 
{
	PHY_IF=$1
	GRNFIELDPRE=`get_driver_grn_field_pre "$PHY_IF"`
	return 0
}
set_driver_htstbc() 
{
	PHY_IF=$1
	STBC=`get_driver_stbc "$PHY_IF"`
	if [ "`cat /etc/product`" = "wraith" ] || [ "`cat /etc/product`" = "macan" ] || [ "`cat /etc/product`" = "nodes" ] || [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "dallas" ] || [ "`cat /etc/product`" = "rogue" ] || [ "`cat /etc/product`" = "lion" ] ; then
		iwpriv $PHY_IF rx_stbc $STBC
		iwpriv $PHY_IF tx_stbc $STBC
	else
		INT=`get_phy_interface_name_from_vap "$PHY_IF"`
		iwpriv $INT rxstbc $STBC
		iwpriv $INT txstbc $STBC
		if [ "1" = "$STBC" ]; then
			iwpriv $INT TxBFCTL 0
		else
			iwpriv $INT TxBFCTL 246		
		fi
	fi
	return 0
}
set_driver_transmission_rate() 
{
	PHY_IF=$1
	LEGALCY=`is_legalcy_mode $PHY_IF`
	if [ "true" = "$LEGALCY" ]; then
		RATE=`get_driver_trans_rate "$PHY_IF"`
	else
		RATE=`get_driver_n_trans_rate "$PHY_IF"`
	fi
	if [ "0" = "$RATE" ]; then
		iwconfig $PHY_IF rate auto
	else
		iwconfig $PHY_IF rate "$RATE"M
	fi	
	
	return 0
}
set_driver_short_gi() 
{
	PHY_IF=$1
	iwpriv $PHY_IF shortgi 1	
	
	return 0
}
set_driver_channel() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	SYSCFG_CHANNEL=`syscfg_get "$SYSCFG_INDEX"_channel`
	if [ "auto" = $SYSCFG_CHANNEL -o "0" = $SYSCFG_CHANNEL ]; then
		echo "Auto channel"
		if [ "$SYSCFG_INDEX" = "wl0" ] ; then
			iwpriv wifi0 acs_2g_allch 1
		fi
		iwconfig $PHY_IF freq 0
	else
		iwconfig $PHY_IF channel `expr $SYSCFG_CHANNEL`
	fi
	return 0
}
set_driver_txpower() 
{
    PHY_IF=$1
    SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
    SYSCFG_TXPOWER=`syscfg_get "$SYSCFG_INDEX"_txpower`
    TXPOWER=$(get_driver_txpower $PHY_IF)
    TXPOWER_LIST="$(get_driver_txpower_list $PHY_IF)"
    if [ -n "$SYSCFG_TXPOWER" ] && $(contains "$TXPOWER_LIST" $SYSCFG_TXPOWER) && [ "$TXPOWER" != "$SYSCFG_TXPOWER" ]; then
	iwconfig $PHY_IF txpower $SYSCFG_TXPOWER
    fi
    return 0
}
