#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/smart_connect_server_utils.sh
source /etc/init.d/service_wifi/wifi_platform_specific_setting.sh
PROG_NAME="$(basename $0)"
WIFI_DEBUG_SETTING=`syscfg_get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
DEBUG echo "${SERVICE_NAME}, sysevent received: $1 (`date`)"
SERVICE_NAME="wifi_ext"
service_init()
{
	ulog wlan status "${SERVICE_NAME}, service_init()"
	return 0
}
wifi_renew_clients_handler()
{
	ulog wlan status "${SERVICE_NAME}, wifi_renew_clients_handler()"
	echo "${SERVICE_NAME}, wifi_renew_clients_handler()"
	sysevent set wifi_renew_clients-status starting
	wifi_refresh_interfaces
	sysevent set wifi_renew_clients-status started
}
wifi_smart_connect_setup_start()
{
	ulog wlan status "${SERVICE_NAME}, smart_connect_setup-start"
	echo "${SERVICE_NAME}, smart_connect_setup-start"
	for PHY_IF in $PHYSICAL_IF_LIST; do
		wifi_smart_setup_start $PHY_IF
	done
}
wifi_smart_connect_setup_stop()
{
	ulog wlan status "${SERVICE_NAME}, smart_connect_setup-stop"
	echo "${SERVICE_NAME}, smart_connect_setup-stop"
	if [ "`syscfg get smart_mode::mode`" = "2" ]; then
		sysevent set smart_connect::setup_status READY
	fi
	for PHY_IF in $PHYSICAL_IF_LIST; do
		wifi_smart_setup_stop $PHY_IF
	done
}
check_legacy_client()
{
	INTERFACE=$1
	MAC=$2
	MODE=`wlanconfig ${INTERFACE} list sta | grep ${MAC} | sed 's/IEEE80211/\n&/' | awk NR==2'{print $1}'`
	if [ -z $MODE  ]; then
	    return 0
	fi
	if [ "${MODE}" != "IEEE80211_MODE_11A" ] && [ "${MODE}" != "IEEE80211_MODE_11B" ] && [ "${MODE}" != "IEEE80211_MODE_11G" ]; then
	    return 0
	fi
	return 1
}
triggerEventForWifiClient()
{
	MAC=$1
	STATUS=$2
	INT=$3
	RSSI=$4
	GUEST=$5
	BAND='2.4G'
	BSSID=`ifconfig $INT 2>/dev/null | awk -F'HWaddr' '/HWaddr/ {print $2}' | sed 's/ //g'`
	MESSAGE="$STATUS,$BSSID,$INT,$MAC"
	[ "$INT" = "`syscfg get wl1_user_vap`" -o "$INT" = "`syscfg get wl1_guest_vap`" -o "$INT" = "`syscfg get wl2_user_vap`" ] && BAND='5G'
	[ "$INT" = "`syscfg get wl1_owe_vap`" -o "$INT" = "`syscfg get wl2_owe_vap`" ] && BAND='5G'
	if [ "$STATUS" = "up" ]; then
		if [ "Broadcom" != "`syscfg get hardware_vendor_name`" ]; then
			MODE=`wlanconfig ${INT} list sta | grep "$MAC" | sed 's/IEEE80211_MODE_/&\n/' | awk NR==2'{print $1}'`
			RATE=`wlanconfig ${INT} list sta | grep "$MAC" | awk {'print $5'}`
		else
			MODE="`wl -i ${INT} band`"
			RATE="`wl -i ${INT} sta_info ${MAC} | awk '/rate of last tx pkt: / {print $6}'` Kbps"
		fi
		MESSAGE="$MESSAGE,$BAND,$MODE,$RATE,$RSSI,$GUEST"
	fi
	echo "--$MESSAGE--"
	sysevent set WIFI::link_status_changed "$MESSAGE"
}
wifi_client_associated()
{
	ulog wlan status "${SERVICE_NAME}, wifi_client_associated"
	MAC=`echo $1 | cut -c1-17`
	INT=`echo $1 | cut -c18-`
	CLIENT_MCS="0"
	WAIT_TIMES="0"
	GUESTCLIENT="false"
	[ "$INT" = "`syscfg get wl0_guest_vap`" -o "$INT" = "`syscfg get wl1_guest_vap`" ] && GUESTCLIENT="true"
	if [ "Broadcom" != "`syscfg get hardware_vendor_name`" ]; then
		check_legacy_client ${INT} $MAC
		if [ "$?" = "1" ]; then
			echo "$MAC is a legacy client"
		fi
		CLIENT_RSSI="`wlanconfig $INT list sta 2>/dev/null | grep "$MAC" | awk '{print $6}' `"
		echo $CLIENT_RSSI | egrep "^[0-9]+$" > /dev/null
		if [ $? -eq 0 ];then
			let CLIENT_RSSI=-95+CLIENT_RSSI
		fi
                while [ "${CLIENT_MCS}" = "0" ]                                                       
                do                                                                                    
                	CLIENT_MCS="`wlanconfig $INT list sta 2>/dev/null | grep -A 2 "$MAC" | awk NR==3'{print $6}' ; sleep .5`"
			if [ $WAIT_TIMES -gt 10 ];then
				break
			fi
			WAIT_TIMES=`expr $WAIT_TIMES + 1`                                                                 
                done    	
	else
		CLIENT_RSSI="`wl -i ${INT} rssi ${MAC}`"
		echo $CLIENT_RSSI | egrep "^[0-9]+$" > /dev/null
		if [ $? -eq 0 ];then
			let CLIENT_RSSI=-95+CLIENT_RSSI
		fi
		CLIENT_MCS="`wl -i ${INT} sta_info ${MAC} | awk '/mcs/ {print $3}' | awk NR==2`"
	fi
	echo "$MAC,client_associated to $INT (`date`)"
	triggerEventForWifiClient $MAC "up" $INT $CLIENT_RSSI $GUESTCLIENT
	MODE="`syscfg get smart_mode::mode`"
	if [ "$MODE" = "2" ] || [ "$MODE" = "1" ] ;then
		BSSID=`ifconfig $INT 2>/dev/null | awk -F'HWaddr' '/HWaddr/ {print $2}' | sed 's/ //g'`
		echo "$BSSID,$MAC" | egrep "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2},([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			echo "publish message: $MAC associated"
			pub_wlan_subdev  "$MAC" "$BSSID" "$INT" "connected" "$BAND" "$CLIENT_RSSI" "$GUESTCLIENT" "$CLIENT_MCS"
		fi
	fi
        if [ "`syscfg get wifi_tb::enabled`" = "1" ]; then
            if [ "$INT" = "$(syscfg get ${WIFI_PRIV_NAMESPACE}::wl0_vap)" -o \
                "$INT" = "$(syscfg get ${WIFI_PRIV_NAMESPACE}::wl1_vap)" -o \
                "$INT" = "$(syscfg get ${WIFI_PRIV_NAMESPACE}::wl2_vap)"  ]; then
                check_client_signal "$MAC" "$INT" "$CLIENT_RSSI"
            fi
        fi
	return
}
wifi_client_disassociated()
{
	ulog wlan status "${SERVICE_NAME}, wifi_client_disassociated"
	MAC=`echo $1 | cut -c1-17`
	INT=`echo $1 | cut -c18-`
	CLIENT_RSSI=""
	CLIENT_MCS=""
	GUESTCLIENT="false"
	[ "$INT" = "`syscfg get wl0_guest_vap`" -o "$INT" = "`syscfg get wl1_guest_vap`" ] && GUESTCLIENT="true"
	echo "$MAC,client_disassociated from $INT (`date`)"
	triggerEventForWifiClient $MAC "down" $INT $CLIENT_RSSI $GUESTCLIENT
	MODE="`syscfg get smart_mode::mode`" 
	[ "$MODE" != "2" -a "$MODE" != "1" ] && return
	BSSID=`ifconfig $INT 2>/dev/null | awk -F'HWaddr' '/HWaddr/ {print $2}' | sed 's/ //g'`
	echo "$BSSID,$MAC" | egrep "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2},([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$" > /dev/null 2>&1
	[ "$?" != "0" ] && return
    
	CHECK_IF_LIST="`syscfg get wl0_user_vap` `syscfg get wl0_guest_vap` `syscfg get wl1_user_vap` `syscfg get wl1_guest_vap` `syscfg get wl2_user_vap`"
	for WL_SYSCFG in wl0 wl1 wl2 ; do
		[ "`syscfg get ${WL_SYSCFG}_security_mode`" != "wpa3-open" ] && continue
		CHECK_IF_LIST="${CHECK_IF_LIST} `syscfg get ${WL_SYSCFG}_owe_vap`"
	done
	HARDWARE_VENDOR="`syscfg get hardware_vendor_name`"
	for CHECK_IF in $CHECK_IF_LIST; do
		if [ "Broadcom" != "$HARDWARE_VENDOR" ]; then
			EXIST="`wlanconfig ${CHECK_IF} list sta 2>/dev/null | grep "$MAC" | awk '{print $1}'`"
		else
			EXIST="`wl -i ${CHECK_IF} assoclist 2>/dev/null | grep -i "$MAC"`"
		fi
		[ ! -z $EXIST ] && break;
	done
	if [ ! -z $EXIST ] ; then
		echo "Got disconnected event $EXIST from $INT, but associated to other VAP ${CHECK_IF}, do NOT publish"
		return
	fi
	echo "publish message: $MAC disconnected"
	pub_wlan_subdev  "$MAC" "$BSSID" "$INT" "disconnected" "$BAND" "$CLIENT_RSSI" "$GUESTCLIENT" "$CLIENT_MCS"
	return
}
backhaul_intf_choose()
{
	BH="`sysevent get backhaul::intf`"
	WL="`sysevent get backhaul::set_intf`"
	BACKHAUL_CHANGE=0
	if [ ! -z "$BH" -a "${BH:0:3}" != "eth" ]; then
		CURRENT_CHAN=$(get_interface_channel $BH)
		if [ "$CURRENT_CHAN" -le "13" ];then	
			if [ "`syscfg_get backhaul::24G_enabled`" != "1" ]; then
				return 1
			fi
			if [ "$WL" != "2.4G" ]; then
				echo "smart connect client: choose ${WL:-default} as backhaul" > /dev/console
				BACKHAUL_CHANGE=1
			fi
		elif [ "$CURRENT_CHAN" -ge "36" -a "$CURRENT_CHAN" -lt "65" ]; then
			if [ "$WL" != "5GL" ]; then
				echo "smart connect client: choose ${WL:-default} as backhaul" > /dev/console
				BACKHAUL_CHANGE=1
			fi
		else
			if [ "$WL" != "5GH" ]; then
				echo "smart connect client: choose ${WL:-default} as backhaul" > /dev/console
				BACKHAUL_CHANGE=1
			fi
		fi
		if [ $BACKHAUL_CHANGE -ne 1 ]; then
			MQTT_BSSID="`sysevent get mqttsub::bh_bssid | tr [:upper:] [:lower:]`"
			BACKHAUL_BSSID="`sysevent get backhaul::preferred_bssid`"
			if [ -n "$MQTT_BSSID" ]; then
				if [ "$MQTT_BSSID" != "$BACKHAUL_BSSID" ]; then
					echo "smart connect client: choose $MQTT_BSSID on $WL as backhaul" > /dev/console
					BACKHAUL_CHANGE=1
				fi
			fi
		fi
		if [ $BACKHAUL_CHANGE -eq 1 ]; then
			ifconfig $BH down
			sysevent set backhaul::status down
			sysevent set backhaul::preferred_bssid ""
		else
			echo "smart connect client: using ${WL:-default} as backhaul right now, do nothing" > /dev/console
		fi
	fi
}
reconsider_backhaul_busy () {
    echo "Skipping reconsider_backhaul; it is already running" 1>&2
    exit 1
}
get_backhaul_ssid()
{
    local bh_intf=$1
    local vendor_name=$(syscfg get hardware_vendor_name)
    [ -z "${bh_intf}" -o -z "${vendor_name}" ] && echo "" && ulog wlan status "bh_intf=$bh_intf, vendor_name=$vendor_name"
    case "${vendor_name}" in
        "QCA")
            essid="$(iwconfig ${bh_intf} | grep "ESSID:" | cut -d : -f2)"
            ret="$(echo $essid | sed -n -e 's/^"//' -e 's/"$//p')"
            echo "$ret"
            ;;
        "BRCM")
            echo ""
            ;;
        "MTK")
            echo ""
            ;;
        *)
            echo ""
            ;;
    esac
}
reconsider_backhaul()
{
	local CONTEXT_ID="$1"
	echo "$0: reconsider_backhaul, CONTEXT_ID: '$CONTEXT_ID' (`date`) " > /dev/console
	rm -f /tmp/last_scan_table_update && sysevent set scan_table_update
    OFFLINE_SCAN_RESULT='/tmp/offline_scan_result'
	BSSID_RESULT='/tmp/offline_scan_bssid'
	RSSI_RESULT='/tmp/offline_scan_rssi'
	CHAN_RESULT='/tmp/offline_scan_chan'
    BAND_RESULT='/tmp/offline_scan_band'
	BACKHAUL_INTF=`sysevent get backhaul::intf`
    SCAN_SSID="$(get_backhaul_ssid $BACKHAUL_INTF)"
    [ -z "${SCAN_SSID}" ] && echo "reconsider_backhaul: SCAN_SSID is empty" > /dev/console && return
	sleep 20
	if [ ! -z $OFFLINE_SCAN_RESULT ] ; then
		rm -f $OFFLINE_SCAN_RESULT 	
	fi
	if [ ! -z $RSSI_RESULT ] ; then
		rm -f $RSSI_RESULT 	
	fi
	if [ ! -z $BSSID_RESULT ] ; then
		rm -f $BSSID_RESULT	
	fi
	if [ ! -z $CHAN_RESULT ] ; then
		rm -f $CHAN_RESULT	
	fi
	if [ ! -z $BAND_RESULT ] ; then
		rm -f $BAND_RESULT	
	fi
	local BAND_24G=0
	local BAND_5GL=1
	local BAND_5GH=2
	local BAND_6G=3
	local band
	local frequency
    if [ "$(sysevent get reconsider-backhaul::debug)" = "1" ]; then
        OFFLINE_SCAN_RESULT="$(sysevent get reconsider-backhaul::scan_result_file)"
        grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Signal level" | awk -F '=' '{print $3}' | awk -F ' ' '{print $1}' >> $RSSI_RESULT
        grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Address: " | awk -F ' ' '{print $5}' >> $BSSID_RESULT
        if [ "3" = "$band" ]; then
            freq_list="$(grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Frequency:" | awk -F: '{print $2}' | awk '{print $1}' | xargs)"
            for freq in $freq_list; do
                freq=$(echo "$freq 1000" | awk '{printf $1 * $2}')
                change_freq_to_chan $freq
                echo "$?" >> $CHAN_RESULT
            done
                
        else
            grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Channel" | awk '{print $(NF)}' | sed 's/)//' >> $CHAN_RESULT
        fi
        freq_list="$(grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Frequency:" | awk -F: '{print $2}' | awk '{print $1}' | xargs)"
        for freq in $freq_list; do
            freq=$(echo "$freq 1000" | awk '{printf $1 * $2}')
            echo "$(freq_to_band_name $freq)" >> $BAND_RESULT
        done
    else
        for INTF in $(syscfg get lan_wl_physical_ifnames); do
            if [ -n "$INTF" ]; then
                frequency=$(iwconfig $INTF | grep Frequency: | cut -d: -f3 | awk '{print $1}')
                frequency=$(echo "$frequency 1000" | awk '{printf $1 * $2}')
			    band="$(freq_to_band $frequency)"
                if [ "$band" = "0" ]; then
                    continue
                fi
                echo -n > $OFFLINE_SCAN_RESULT
                iwlist $INTF scanning last > $OFFLINE_SCAN_RESULT 2>/dev/null
                grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Signal level" | awk -F '=' '{print $3}' | awk -F ' ' '{print $1}' >> $RSSI_RESULT
                grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Address: " | awk -F ' ' '{print $5}' >> $BSSID_RESULT
                if [ "3" = "$band" ]; then
                    freq_list="$(grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Frequency:" | awk -F: '{print $2}' | awk '{print $1}' | xargs)"
                    for freq in $freq_list; do
                        freq=$(echo "$freq 1000" | awk '{printf $1 * $2}')
                        change_freq_to_chan $freq
                        echo "$?" >> $CHAN_RESULT
                    done
                
                else
                    grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Channel" | awk '{print $(NF)}' | sed 's/)//' >> $CHAN_RESULT
                fi
                freq_list="$(grep -F "$SCAN_SSID" -A 5 -B 1 $OFFLINE_SCAN_RESULT | grep "Frequency:" | awk -F: '{print $2}' | awk '{print $1}' | xargs)"
                for freq in $freq_list; do
                    freq=$(echo "$freq 1000" | awk '{printf $1 * $2}')
                    echo "$(freq_to_band_name $freq)" >> $BAND_RESULT
                done
            fi
        done
    fi
	if [ "Not-Associated" = "`iwconfig $BACKHAUL_INTF | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`" ] ; then
		return
	fi
	CURRENT_BSSID=`iwconfig ${BACKHAUL_INTF} | grep "Access Point:" | awk -F ' ' '{print $6}'`
	CURRENT_RSSI=`iwconfig ${BACKHAUL_INTF} | grep "Signal level" | awk -F '=' '{print $3}' | awk -F ' ' '{print $1}'`
    
    CURRENT_FRQ=`iwconfig ${BACKHAUL_INTF} | grep "Frequency:" | awk -F: '{print $3}' | awk '{print $1}'`
    CURRENT_FRQ=$(echo "$CURRENT_FRQ 1000" | awk '{printf $1 * $2}')
    CURRENT_BAND=`freq_to_band_name $CURRENT_FRQ`
	NUMBER=`wc -l $RSSI_RESULT  | awk '{print $1}'`
	MIN_RSSI=""
	INDEX=1
    grep -F $CURRENT_BSSID $BSSID_RESULT
    if [ "0" = "$?" ]; then
        while [ $INDEX -le $NUMBER ]; do
            BSSID="` sed -n ''$INDEX'p' $BSSID_RESULT 2>/dev/null`"
		    RSSI="` sed -n ''$INDEX'p' $RSSI_RESULT 2>/dev/null`"
            if [ "$CURRENT_BSSID" = "$BSSID" ]; then
                CURRENT_RSSI=$RSSI
                break
            fi
            INDEX=`expr $INDEX + 1`
        done
    fi
	echo "We are connected to ${CURRENT_BSSID}/${CURRENT_RSSI}/${CURRENT_BAND}"
    
    INDEX=1
    AP_CNT_6G="$(grep -F "6G" $BAND_RESULT | wc -l)"
    if [ ${AP_CNT_6G} -gt 0 ]; then
        while [ $INDEX -le $NUMBER ]; do
	        BSSID="` sed -n ''$INDEX'p' $BSSID_RESULT 2>/dev/null`"
		    RSSI="` sed -n ''$INDEX'p' $RSSI_RESULT 2>/dev/null`"
		    CHAN="` sed -n ''$INDEX'p' $CHAN_RESULT 2>/dev/null`"
            BAND="` sed -n ''$INDEX'p' $BAND_RESULT 2>/dev/null`"
            if [ "$BAND" = "6G" ]; then
		        echo "AP Number #${INDEX}, ${BSSID}/${RSSI}/${CHAN}/${BAND}"
		        INDEX=`expr $INDEX + 1`
		        if [ "$CURRENT_BAND" = "6G" ] ; then
                    if [ "$CURRENT_BSSID" = "$BSSID" ]; then
                        CURRENT_RSSI=$RSSI
                        continue
                    else
                        if [ $CURRENT_RSSI -lt $RSSI ]; then
                            MIN_BSSID=$BSSID
                            MIN_RSSI=$RSSI
                            MIN_CHAN=$CHAN
                            MIN_BAND=$BAND
                        fi
                    fi
                else
                    if [ -z "$MIN_RSSI" ] || [ -n "$MIN_RSSI" -a $MIN_RSSI -lt $RSSI ]; then
                        MIN_BSSID=$BSSID
                        MIN_RSSI=$RSSI
                        MIN_CHAN=$CHAN
                        MIN_BAND=$BAND
                    fi
		        fi
            else
		        echo "AP Number #${INDEX}, ${BSSID}/${RSSI}/${CHAN}/${BAND}, ignored"
                INDEX=`expr $INDEX + 1`
            fi
        done
        if [ -n "$MIN_RSSI" -a "$MIN_BSSID" != "$CURRENT_BSSID" ]; then
			pub_reconsider_bh_reply $CONTEXT_ID "yes"
			sysevent set backhaul::preferred_bssid $MIN_BSSID
			sysevent set backhaul::preferred_chan $MIN_CHAN
            sysevent set backhaul::preferred_band $MIN_BAND
			echo "Now we decide to connect to ${MIN_BSSID}/${MIN_RSSI}/${MIN_CHAN}/${MIN_BAND} (`date`)"
			sysevent set backhaul::status down
            return
        else
            echo "No better choice found, no action $(date)"
            pub_reconsider_bh_reply $CONTEXT_ID "no"
            return
        fi
    else
        if [ "$CURRENT_BAND" = "6G" ]; then
            echo "Current BH is 6G already and no 6G candidate AP found, no action $(date)"
            pub_reconsider_bh_reply $CONTEXT_ID "no"
            return
        else
			while [ $INDEX -le $NUMBER ];do
				BSSID="` sed -n ''$INDEX'p' $BSSID_RESULT 2>/dev/null`"
				RSSI="` sed -n ''$INDEX'p' $RSSI_RESULT 2>/dev/null`"
				CHAN="` sed -n ''$INDEX'p' $CHAN_RESULT 2>/dev/null`"
				BAND="` sed -n ''$INDEX'p' $BAND_RESULT 2>/dev/null`"
				echo "AP Number #${INDEX}, ${BSSID}/${RSSI}/${CHAN}/${BAND}"
				INDEX=`expr $INDEX + 1`
				if [ "$CURRENT_BSSID" = "$BSSID" ] ; then
					CURRENT_RSSI=$RSSI
					continue
				fi
				if [ "" = "$MIN_RSSI" ] || [ $RSSI -gt $MIN_RSSI ] ; then
					MIN_RSSI=$RSSI
					MIN_BSSID=$BSSID
					MIN_CHAN=$CHAN
				fi
			done
			PREVIOUS_BSSID=`apply_mac_inc -m $CURRENT_BSSID -i -1 | tr [:lower:] [:upper:]`
			LATER_BSSID=`apply_mac_inc -m $CURRENT_BSSID -i 1 | tr [:lower:] [:upper:]`
			if [ "" = "$MIN_RSSI" -o "$PREVIOUS_BSSID" = "$MIN_BSSID" -o "$LATER_BSSID" = "$MIN_BSSID" ] ; then
				pub_reconsider_bh_reply $CONTEXT_ID "no"
				return
			elif [ $MIN_RSSI -gt $CURRENT_RSSI ] ; then
				pub_reconsider_bh_reply $CONTEXT_ID "yes"
				sysevent set backhaul::preferred_bssid $MIN_BSSID
				sysevent set backhaul::preferred_chan $MIN_CHAN
			    sysevent set backhaul::preferred_band $MIN_BAND
				echo "Now we decide to connect to ${MIN_BSSID}/${MIN_RSSI}/${MIN_CHAN}/${MIN_BAND} (`date`)"
				sysevent set backhaul::status down
			else
				pub_reconsider_bh_reply $CONTEXT_ID "no"
				return
			fi
	    fi
    fi
}
ulog wlan status "${SERVICE_NAME}, sysevent received: $1"
service_init 
case "$1" in
	wifi_renew_clients)
		if [ "$(sysevent get wifi-status)" = "started" ]; then
		    wifi_renew_clients_handler
		fi
		;;
	wifi_smart_connect_setup-run)
		PROC_PID_LINE=`ps -w | grep "smart_connect_setup.sh" | grep -v grep`
		PROC_PID=`echo $PROC_PID_LINE |  awk '{print $1}'`
		if [ -n "$PROC_PID" ]; then
			echo "${SERVICE_NAME}, reset setup_duration"
			sysevent set smart_connect::setup_duration_reset "1"
		else
			/etc/init.d/service_wifi/smart_connect_setup.sh &
		fi
		;;
	wifi_smart_connect_setup-start)
		wifi_smart_connect_setup_start
		;;
	wifi_smart_connect_setup-stop)
		wifi_smart_connect_setup_stop
		;;
	client_associated)
		wifi_client_associated $2
		;;
	client_disassociated)
		wifi_client_disassociated $2
		;;
	backhaul::set_intf)
		if [ "nodes-jr" = "`cat /etc/product`" ] || [ "nodes" = "`cat /etc/product`" ] || [ "rogue" = "`cat /etc/product`" ] || [ "lion" = "`cat /etc/product`" ] ; then
			backhaul_intf_choose
		fi
        	;;
	wifi_channel_changed)
		if [ "$(sysevent get wifi-status)" = "started" ]; then
		    ulog wlan status "wifi channel change to $2"
		    pub_wlan_status
		fi
		;;
	powertable_config_changed)
		sleep 5
		reboot
		;;
	wlan::reconsider-backhaul)
		RECONSIDER_CONTEXT_ID="$(jsonparse data.context_id -f $2)"
		if [ -n "$RECONSIDER_CONTEXT_ID" ]; then
			DEBUG echo "Invoking reconsider_backhaul $RECONSIDER_CONTEXT_ID" > /dev/console
			(
			    flock -n 9 || reconsider_backhaul_busy
			    echo "Running reconsider_backhaul $RECONSIDER_CONTEXT_ID"
			    reconsider_backhaul $RECONSIDER_CONTEXT_ID
			) 9<$0
		else
			echo "$0 $1: Error extracting context_id from JSON payload at '$2'" > /dev/console
		fi
		;;
	wifi_interrupt_led)
		if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "$2" != "1" ]; then
			return
		fi
        if [ "`syscfg get smart_mode::mode`" = "2" ] || [ "`syscfg get smart_mode::mode`" = "1" -a -n "$(sysevent get config_sync::change)" ]; then
		    ulog wlan status "wifi ssid changed and led begin blue pulse"
		    /etc/led/nodes_led_pulse.sh blue 3
		    killall -q ssid_monitor.sh
		    SSID_MONITOR="/etc/init.d/service_wifi/ssid_monitor.sh"
		    $SSID_MONITOR &
        else
            sysevent set wifi_interrupt_led
		fi
		;;
	*)
	echo "Usage: service-${SERVICE_NAME} [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		;;
esac
