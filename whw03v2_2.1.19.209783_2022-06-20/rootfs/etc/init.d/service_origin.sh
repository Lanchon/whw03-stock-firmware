#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_misc_functions.sh
export TZ=`sysevent get TZ`
SERVICE_NAME="origin"
NAMESPACE=$SERVICE_NAME
MOTION_NAMESPACE="motion"
SMART_MODE="`syscfg get smart_mode::mode`"
dfc_enabled=0
dfc_debug=0
dfc_supported=2     # The supported Aware FW phase NOTE: namespace is motion::
SOUNDER_CONF="/tmp/sounder.conf"
SOUNDER_ROUTING_LIST_FILE="/tmp/sounder_routing_list"
SOUNDER_BOT_ROUTING_LIST_FILE="/tmp/sounder_bot_routing_list"
SYSCFG_DEVICE_MAC="device::mac_addr"
SYSCFG_ORIGIN_SERVER="origin::serverip"
ORIGIN_UUID_PREFIX="0x0002"
ORIGIN_DEFAULT_SERVER="54.209.186.220"
ORIGIN_DEFAULT_PNP="no"
PERSISTENT_DIR="/var/config/motion"
PERSISTENT_BOT_LIST_FILE="$PERSISTENT_DIR/persistent_bot_list"
SLAVE_SCAN_BOT_LIST_FILE="/tmp/msg/MOTION/bot_scan_list"
SCANNED_BOT_LIST="/tmp/scanned_bot_list"
LOCAL_SCANNED_BOT_LIST="/tmp/local_scanned_bot_list"
DEBUG_LOG_DIR="/tmp/origin_info"
ORIGIN_INFO="/www/cgi-bin/origin_info.cgi"
MAX_LOG_FILES=5
create_debug_files()
{
    if [ "$(syscfg get origin::debug)" = "1" ]; then
        NUM_FILES=$(ls $DEBUG_LOG_DIR | wc -l)
        if [ $NUM_FILES -ge $MAX_LOG_FILES ]; then
            OLDEST_LOG=$(ls -tr $DEBUG_LOG_DIR | head -1)
            echo "Removing oldest log file: $DEBUG_LOG_DIR/$OLDEST_LOG" > /dev/console
            rm $DEBUG_LOG_DIR/$OLDEST_LOG
        fi
        
        LOG_DATE=$(date +%s)
        echo "Creating new log file: $DEBUG_LOG_DIR/origin_log_$LOG_DATE"
        sh $ORIGIN_INFO > $DEBUG_LOG_DIR/origin_log_$LOG_DATE
    fi
}
check_restart_authority()
{
    PROC_PID_LINE="`ps -w | grep "origin_restart_authority" | grep -v grep`"
    PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
    if [ -z "$PROC_PID" ]; then
        /etc/init.d/origin_restart_authority.sh $EVENT_NAME $EVENT_VALUE &
        echo "Running origin_restart_authority..."
    else
        echo "origin_restart_authority is already running..."
    fi
}
check_config_changed()
{
    delete_sounder_routing_list
    create_sounder_routing_list
    delete_bot_sounder_routing_list
    create_bot_sounder_routing_list
    ROUTING_NEW=""
    while read line
    do
        if [ -n "$ROUTING_NEW" ]; then
            ROUTING_NEW="$ROUTING_NEW,$line"
        else
            ROUTING_NEW="$line"
        fi
    done < "$SOUNDER_ROUTING_LIST_FILE"
    if [ -f "$SOUNDER_BOT_ROUTING_LIST_FILE" ]; then
        while read line
        do
            if [ -n "$ROUTING_NEW" ]; then
                ROUTING_NEW="$ROUTING_NEW,$line"
            else
                ROUTING_NEW="$line"
            fi
        done < "$SOUNDER_BOT_ROUTING_LIST_FILE"
    fi
    ROUTING_OLD=""
    if [ -f "$SOUNDER_CONF" ]; then
        ROUTING_OLD="$(cat $SOUNDER_CONF | grep routing= | sed 's/routing=//g')"
    fi
    
    if [ "$ROUTING_NEW" != "$ROUTING_OLD" ]; then
        return 1
    fi
    return 0
}
check_bot_scan()
{
    PROC_PID_LINE="`ps -w | grep "origin_bot_scanning_start" | grep -v grep`"
    PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
    if [ -n "$PROC_PID" ]; then
        if [ -z "$(sysevent get restart_after_bot_scan)" ]; then    
            sysevent set restart_after_bot_scan 1
            exit 0
        fi
    fi
    local SCAN_START_TIME=$( sysevent get origin::bot_scanning_starttime )
    local CURRENT_TIME=$( date +%s )
    local DEFAULT_SCAN_TIME=130
    if [ -n "$SCAN_START_TIME" ] && [ $( expr $CURRENT_TIME - $SCAN_START_TIME ) -lt $DEFAULT_SCAN_TIME ]; then
        sysevent set restart_after_bot_scan 1
        exit 0
    fi
}
create_configuration_files()
{
    create_sounder_routing_list
    create_bot_sounder_routing_list
    create_sounder_conf_file
}
create_bot_sounder_routing_list()
{
    if [ ! -f "$SOUNDER_BOT_ROUTING_LIST_FILE" ]; then
        touch "$SOUNDER_BOT_ROUTING_LIST_FILE"
    fi
    
    while read line
    do
        MAC_ADDR=$line
        UUID="$(topomgmt -m devicedb -c get_device_by_mac -p $MAC_ADDR | jsonparse deviceId)"
        AP_BSSID="$(topomgmt -m devicedb -c get_device_interface_table_by_mac -p $MAC_ADDR | jsonparse ap_bssid)"
        if [ "$AP_BSSID" = "" ]; then
            echo "Missing ap_bssid info for bot ( $MAC_ADDR )"
            continue
        fi
        PARENT_IP="$(topomgmt -m viewer -c generate_node_by_mac_address -p $AP_BSSID | jsonparse devinfo.data.ip)"
        INTF_NAME="$(topomgmt -m devinfo -c get_intf_name_by_mac -p $AP_BSSID | jsonparse intf_name)"
        STA_MAC="$(topomgmt -m wlan -c get_wlan_client_status_by_mac -p $MAC_ADDR | jsonparse data.sta_bssid)"
        STA_MAC_FORMATTED="`echo $STA_MAC | sed "s|[:,]||g" | upper`"
        UUID="`echo $UUID | cut -c25-37`"
        UUID="$ORIGIN_UUID_PREFIX$UUID"
        PARENT_UUID="$( topomgmt -m viewer -c generate_node_by_mac_address -p $AP_BSSID | jsonparse devinfo.uuid )"
        PARENT_UUID_FORMATTED=$( echo $PARENT_UUID | cut -c25-37 )
        PARENT_UUID_FORMATTED="$ORIGIN_UUID_PREFIX$PARENT_UUID_FORMATTED"
        MASTER_UUID=$( cat /tmp/msg/DEVINFO/master | jsonparse uuid )
        if [ "$PARENT_UUID" != "$MASTER_UUID" ]; then
            if [ ! -f "/tmp/msg/MOTION/$PARENT_UUID/status.supported" ]; then
                echo "Skipping $MAC_ADDR, parent is not motion capable!"
                continue
            fi
        fi
        
        if [ "$UUID" = "" ] || [ "$PARENT_IP" = "" ] || [ "$INTF_NAME" = "" ] || [ "$STA_MAC" = "" ]; then
            echo "Missing information from bot ( $MAC_ADDR )"
            continue
        fi
        if [ -f "$SOUNDER_BOT_ROUTING_LIST_FILE" ]; then
            REPLACE="`cat "$SOUNDER_BOT_ROUTING_LIST_FILE" | grep ^$UUID`"
            if [ -n "$REPLACE" ]; then
                sed -i "s/$REPLACE.*/$UUID:$PARENT_IP:$PARENT_UUID_FORMATTED:$INTF_NAME:$STA_MAC_FORMATTED/g" "$SOUNDER_BOT_ROUTING_LIST_FILE"
            else
                echo "$UUID:$PARENT_IP:$PARENT_UUID_FORMATTED:$INTF_NAME:$STA_MAC_FORMATTED" >> "$SOUNDER_BOT_ROUTING_LIST_FILE"
            fi
        else
            echo "$UUID:$PARENT_IP:$PARENT_UUID_FORMATTED:$INTF_NAME:$STA_MAC_FORMATTED" > "$SOUNDER_BOT_ROUTING_LIST_FILE"
        fi
    done < "$PERSISTENT_BOT_LIST_FILE"
}
create_sounder_routing_list()
{
    DEVICE_BH_DIR="/tmp/msg/BH"
    DEVINFO_DIR="/tmp/msg/DEVINFO"
    MOTION_DIR="/tmp/msg/MOTION"
    if [ ! -f "$SOUNDER_ROUTING_LIST_FILE" ]; then
        touch "$SOUNDER_ROUTING_LIST_FILE"
    fi
    
    if [ ! -d "$DEVICE_BH_DIR" ] || [ ! -d "$DEVINFO_DIR" ]; then
        ulog ${SERVICE_NAME} ERROR "Can't find directory '$DEVICE_BH_DIR' or '$DEVINFO_DIR'"
        DBG evconslog ${SERVICE_NAME} ERROR "Can't find directory '$DEVICE_BH_DIR' or '$DEVINFO_DIR'"
        return
    fi
    for device in $(ls $DEVICE_BH_DIR)
    do
        PAYLOAD_PATH_PARENT_IP="$DEVICE_BH_DIR/$device/status.parent_ip"
        PAYLOAD_PATH_BH_STATUS="$DEVICE_BH_DIR/$device/status"
        if [ -f "$PAYLOAD_PATH_BH_STATUS" ] && [ -f "$PAYLOAD_PATH_PARENT_IP" ]; then
            UUID="$(jsonparse uuid < $PAYLOAD_PATH_BH_STATUS)"
            STA_MAC="$(jsonparse data.sta_bssid < $PAYLOAD_PATH_BH_STATUS)"
            INTF_NAME="$(jsonparse data.intf < $PAYLOAD_PATH_BH_STATUS)"
            STA_MAC_FORMATTED="`echo $STA_MAC | sed "s|[:,]||g"`"
            UUID="`echo $UUID | cut -c25-37`"
            UUID="$ORIGIN_UUID_PREFIX$UUID"
            PARENT_IP="$(cat $PAYLOAD_PATH_PARENT_IP)"
            WIRED="$(echo "$INTF_NAME" | grep -i "eth")"
            if [ -n "$WIRED" ]; then
                continue
            fi
            PARENT_UUID=""
            AP_MAC="$(jsonparse data.ap_bssid < $PAYLOAD_PATH_BH_STATUS)"
            for device in $(ls $DEVINFO_DIR)
            do
                PAYLOAD_PATH_DEVINFO="$DEVINFO_DIR/$device"
                AP_5GL="$(jsonparse data.userAp5GL_bssid < $PAYLOAD_PATH_DEVINFO)"
                AP_5GH="$(jsonparse data.userAp5GH_bssid < $PAYLOAD_PATH_DEVINFO)"
                
                if [ "$AP_MAC" == "$AP_5GL" ] || [ "$AP_MAC" == "$AP_5GH" ]; then
                    PARENT_UUID="$device"
                    break
                fi
            done
            
            if [ ! -d "$MOTION_DIR/$PARENT_UUID" ]; then
                continue
            fi
            PRODUCT_NAME="`cat /etc/product`"
            if [ $PRODUCT_NAME == "nodes-jr" ]; then # VELOP JR 5G RADIO (ath1 INTERFACE) CAN USE 5GL & 5GH
                INTF_NAME="ath1"
            else
                if [ $INTF_NAME != "5GL" ]; then
                    INTF_NAME="ath10"
                else
                    INTF_NAME="ath1"
                fi
            fi
            AP_BSSID="$(jsonparse data.ap_bssid < $PAYLOAD_PATH_BH_STATUS)"
            PARENT_UUID="$( topomgmt -m viewer -c generate_node_by_mac_address -p $AP_BSSID | jsonparse devinfo.uuid )"
            PARENT_UUID_FORMATTED=$( echo $PARENT_UUID | cut -c25-37 )
            PARENT_UUID_FORMATTED="$ORIGIN_UUID_PREFIX$PARENT_UUID_FORMATTED"
            if [ -f "$SOUNDER_ROUTING_LIST_FILE" ]; then
                REPLACE="`cat "$SOUNDER_ROUTING_LIST_FILE" | grep ^$UUID`"
                if [ -n "$REPLACE" ]; then
                    sed -i "s/$REPLACE.*/$UUID:$PARENT_IP:$PARENT_UUID_FORMATTED:$INTF_NAME:$STA_MAC_FORMATTED/g" "$SOUNDER_ROUTING_LIST_FILE"
                else
                    echo "$UUID:$PARENT_IP:$PARENT_UUID_FORMATTED:$INTF_NAME:$STA_MAC_FORMATTED" >> "$SOUNDER_ROUTING_LIST_FILE"
                fi
            else
                echo "$UUID:$PARENT_IP:$PARENT_UUID_FORMATTED:$INTF_NAME:$STA_MAC_FORMATTED" > "$SOUNDER_ROUTING_LIST_FILE"
            fi
        else
            ulog ${SERVICE_NAME} ERROR "Can't find message file '$PAYLOAD_PATH_BH_STATUS' or '$PAYLOAD_PATH_PARENT_IP'"
            DBG evconslog ${SERVICE_NAME} ERROR "Can't find message file '$PAYLOAD_PATH_BH_STATUS' or '$PAYLOAD_PATH_PARENT_IP'"
        fi
    done
}
create_sounder_conf_file()
{
    if [ ! -f "$SOUNDER_CONF" ]; then
        MAC="`syscfg get $SYSCFG_DEVICE_MAC`"
        MAC="`echo $MAC | sed "s|[:,]||g"`" #remove : to match format of orign UUIDs
        ORIGIN_UUID="$ORIGIN_UUID_PREFIX$MAC"
        echo "server=$ORIGIN_DEFAULT_SERVER" > $SOUNDER_CONF
        echo "pnp=$ORIGIN_DEFAULT_PNP" >> $SOUNDER_CONF
        echo "origin_uuid=$ORIGIN_UUID" >> $SOUNDER_CONF
        echo "routing=" >> $SOUNDER_CONF
        ORIGIN_SERVER="`syscfg get $SYSCFG_ORIGIN_SERVER`"
        if [ -n "$ORIGIN_SERVER" ]; then
            sed -i "s/server=.*/server=$ORIGIN_SERVER/g" "$SOUNDER_CONF"
        fi
    fi
    ROUTING_NEW=""
    while read line
    do
        if [ -n "$ROUTING_NEW" ]; then
            ROUTING_NEW="$ROUTING_NEW,$line"
        else
            ROUTING_NEW="$line"
        fi
    done < "$SOUNDER_ROUTING_LIST_FILE"
    if [ -f "$SOUNDER_BOT_ROUTING_LIST_FILE" ]; then
        while read line
        do
            if [ -n "$ROUTING_NEW" ]; then
                ROUTING_NEW="$ROUTING_NEW,$line"
            else
                ROUTING_NEW="$line"
            fi
        done < "$SOUNDER_BOT_ROUTING_LIST_FILE"
    fi
    sed -i "s/routing=.*/routing=$ROUTING_NEW/g" "$SOUNDER_CONF"
}
add_bots_to_persistent_file()
{
    if ! [ -f $PERSISTENT_BOT_LIST_FILE ]; then
        touch $PERSISTENT_BOT_LIST_FILE
    fi
    
    MAC_LIST="$(sysevent get origin::add_bots)"
    
    OLD_IFS="$IFS"
    IFS=','
    for MAC_ADDR in $MAC_LIST; do
        if [ -f "$PERSISTENT_BOT_LIST_FILE" ]; then
            BOT_FOUND="$(cat "$PERSISTENT_BOT_LIST_FILE" | grep $MAC_ADDR)"
            if [ -n "$BOT_FOUND" ]; then
                continue
            else
                echo "$MAC_ADDR" >> "$PERSISTENT_BOT_LIST_FILE"
            fi
        else
            echo "$MAC_ADDR" > "$PERSISTENT_BOT_LIST_FILE"
        fi
    done
    IFS=$OLD_IFS
    
}
remove_bots_from_persistent_file()
{
    if ! [ -f $PERSISTENT_BOT_LIST_FILE ]; then
        touch $PERSISTENT_BOT_LIST_FILE
    fi
    
    MAC_LIST="$(sysevent get origin::remove_bots)"
    
    OLD_IFS="$IFS"
    IFS=','
    for MAC_ADDR in $MAC_LIST; do
        if [ -f "$PERSISTENT_BOT_LIST_FILE" ]; then
            BOT_FOUND="$(cat "$PERSISTENT_BOT_LIST_FILE" | grep $MAC_ADDR)"
            if [ -n "$BOT_FOUND" ]; then
                sed -i "/$MAC_ADDR/d" $PERSISTENT_BOT_LIST_FILE
            else
                continue
            fi
        fi
    done
    IFS=$OLD_IFS
    
}
delete_configuration_files()
{
    delete_bot_sounder_routing_list
    delete_sounder_routing_list
    delete_sounder_conf_file
}
delete_bot_sounder_routing_list()
{
    if [ -f "$SOUNDER_BOT_ROUTING_LIST_FILE" ]; then
        rm "$SOUNDER_BOT_ROUTING_LIST_FILE"
    fi
}
delete_sounder_routing_list()
{
    if [ -f "$SOUNDER_ROUTING_LIST_FILE" ]; then
        rm "$SOUNDER_ROUTING_LIST_FILE"
    fi
}
delete_sounder_conf_file()
{
    if [ -f "$SOUNDER_CONF" ]; then
        rm "$SOUNDER_CONF"
    fi
}
upper() {
    tr '[a-z]' '[A-Z]'
}
set_defaults()
{
    for i in enabled debug; do
        DEF_VAL="$(eval echo "\$dfc_${i}")"
        if [ -z "$(syscfg get ${NAMESPACE}::$i)" ] ; then
            echo "$0 $1 Setting default for $i"  > /dev/console
            syscfg set ${NAMESPACE}::$i $DEF_VAL
        fi
    done
    for i in supported; do
        DEF_VAL="$(eval echo "\$dfc_${i}")"
        CUR_VAL=$(syscfg get ${MOTION_NAMESPACE}::$i)
        if [ -z "$CUR_VAL" -o "$CUR_VAL" != "$DEF_VAL" ]; then
            echo "$0 $1 Setting default for $i"  > /dev/console
            syscfg set ${MOTION_NAMESPACE}::$i $DEF_VAL
        fi
    done
}
service_init ()
{
    if [ "$SMART_MODE" == "0" ] ; then
        echo "In unconfigured mode, please setup before enabling origin."
        exit 1
    fi
    if [ "$(sysevent get ${NAMESPACE}::inited)" != "1" ] ; then
        set_defaults
        sysevent set ${NAMESPACE}::inited 1
    fi
    
    if ! [ -d "$PERSISTENT_DIR" ]; then
        mkdir -p $PERSISTENT_DIR
    fi
    
    if ! [ -f "$PERSISTENT_BOT_LIST_FILE" ]; then
        touch $PERSISTENT_BOT_LIST_FILE
    fi
    
    if ! [ -d "$DEBUG_LOG_DIR" ]; then
        mkdir -p $DEBUG_LOG_DIR
    fi
}
service_start ()
{
    if [ "`syscfg get ${NAMESPACE}::enabled`" == "1" ] ; then
        echo "$SERVICE_NAME running $1"
    else
        echo "$SERVICE_NAME disabled in syscfg"
        exit 1
    fi
	  wait_till_end_state ${SERVICE_NAME}
    if [ $( pgrep origin | wc -l ) -gt 0 ]; then
        echo "${SERVICE_NAME} has binaries running, force kill and continue service_start." > /dev/console
        killall_if_running origin-fusion 15
        killall_if_running origind 15
    fi
    if [ "$SMART_MODE" == "2" ] ; then
        create_configuration_files
        /usr/sbin/origind -D
        /usr/bin/origin-fusion /tmp/sounder.conf -D
    else
        /usr/sbin/origind -D
    fi
	check_err $? "Couldnt handle start"
	sysevent set ${SERVICE_NAME}-status started
	ulog ${SERVICE_NAME} status "now started"
}
service_stop ()
{
    check_bot_scan
    create_debug_files
   wait_till_end_state ${SERVICE_NAME}
   if [ "$SMART_MODE" == "2" ] ; then
        delete_configuration_files
        killall_if_running origin-fusion 15
        killall_if_running origind 15
    else
        killall_if_running origind 15
    fi
	check_err $? "Couldnt handle stop"
	sysevent set ${SERVICE_NAME}-status stopped
	ulog ${SERVICE_NAME} status "now stopped"
}
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
    wifi-status)
        WIFI_STATUS="$(sysevent get wifi-status)"
        if [ "$WIFI_STATUS" == "started" ] && ! [ "$( sysevent get origin_wifi_start_once )" = "1" ]; then
            sysevent set origin_wifi_start_once 1
            check_restart_authority
        fi
        ;;
    motion::master_restart)
        if [ "$SMART_MODE" == "2" ]; then
            service_stop
            service_start
        fi
        ;;
    motion::slave_restart)
        if [ "$SMART_MODE" == "1" ]; then
            service_stop
            service_start
        fi
        ;;
    backhaul::status_data)
        if [ "$SMART_MODE" == "2" ]; then
            check_config_changed
            if [ "$?" == "1" ] && [ "$(syscfg get ${NAMESPACE}::enabled)" == "1" ]; then
                check_restart_authority
            fi
        fi
        ;;
    backhaul::parent_ip)
        if [ "$SMART_MODE" == "2" ]; then
            check_config_changed
            if [ "$?" == "1" ] && [ "$(syscfg get ${NAMESPACE}::enabled)" == "1" ]; then
                check_restart_authority
            fi
        fi
        ;;
    origin::config_changed)
        if [ "$SMART_MODE" == "2" ] && [ "$(syscfg get ${NAMESPACE}::enabled)" == "1" ]; then
            check_restart_authority
        elif [ "$SMART_MODE" == "2" ] && [ "$(syscfg get ${NAMESPACE}::enabled)" == "0" ]; then
            if [ "$SMART_MODE" == "2" ] ; then
                 delete_configuration_files
                 killall_if_running origin-fusion 15
                 killall_if_running origind 15
                 PROC_PID_LINE="`ps -w | grep "origin_bot_scanning_start" | grep -v grep`"
                 PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
                 if [ -z "$PROC_PID" ]; then
                     echo "origin_bot_scanning_start is not running, no need to kill"
                 else
                     kill -15 $PROC_PID
                 fi
                 sysevent set origin::bot_scanning_status Error
                 sysevent set origin_control-stop
             else
                 killall_if_running origind 15
                 PROC_PID_LINE="`ps -w | grep "origin_bot_scanning_start" | grep -v grep`"
                 PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
                 if [ -z "$PROC_PID" ]; then
                     echo "origin_bot_scanning_start is not running, no need to kill"
                 else
                     kill -15 $PROC_PID
                 fi
                 sysevent set origin::bot_scanning_status Error
                 sysevent set origin_control-stop
             fi
        fi
        ;;
    TZ)
        if [ "$SMART_MODE" == "2" ] && [ "$(syscfg get ${NAMESPACE}::enabled)" == "1" ]; then
            check_restart_authority
        fi
        ;;
    slave_offline)
        if [ "$SMART_MODE" == "2" ]; then
            check_config_changed
            if [ "$?" == "1" ] && [ "$(syscfg get ${NAMESPACE}::enabled)" == "1" ]; then
                check_restart_authority
            fi
        fi
        ;;
    mqttsub::wlansubdev)
        if [ "$SMART_MODE" == "2" ] && [ "$(syscfg get ${NAMESPACE}::enabled)" == "1" ]; then
            CLIENT_PATH="$(sysevent get mqttsub::wlansubdev)"
            CLIENT_MAC="$(cat $CLIENT_PATH | jsonparse data.sta_bssid)"
            CLIENT_FOUND="$(cat $PERSISTENT_BOT_LIST_FILE | grep -i "$CLIENT_MAC")"
            
            if [ -n $CLIENT_FOUND ]; then
                check_config_changed
                if [ "$?" == "1" ]; then
                    check_restart_authority
                fi
            fi 
        fi
        ;;
    origin::start_bot_scanning)
        PROC_PID_LINE="`ps -w | grep "origin_bot_scanning_start" | grep -v grep`"
        PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
        MAC_LIST="$( sysevent get origin::start_bot_scanning )"
        
        if [ -z "$MAC_LIST" ]; then
            exit 0
        fi
        
        if [ -z "$PROC_PID" ]; then
            FORMATTED_MAC_LIST=""
            OLD_IFS="$IFS"
            IFS=','
            for MAC_ADDR in $MAC_LIST; do
                INTF="$(topomgmt -m wlan -c get_wlan_client_status_by_mac -p $MAC_ADDR | jsonparse data.interface)"
                MAC_ADDR_NO_COMMA=$(echo $MAC_ADDR | sed 's/://g')
                
                if [ -z "$INTF" ]; then
                    continue
                fi
                
                if [ -n "$FORMATTED_MAC_LIST" ]; then
                    FORMATTED_MAC_LIST="$FORMATTED_MAC_LIST,$INTF:$MAC_ADDR_NO_COMMA"
                else
                    FORMATTED_MAC_LIST="$INTF:$MAC_ADDR_NO_COMMA"
                fi
            done
            IFS=$OLD_IFS
            
            pub_slave_start_bot_scan $FORMATTED_MAC_LIST
            /etc/init.d/origin_bot_scanning_start.sh $FORMATTED_MAC_LIST &
            echo "origin_bot_scanning_start started"
        else
            echo "origin_bot_scanning_start is already running"
        fi
        sysevent set origin::start_bot_scanning
        ;;
    motion::slave_start_bot_scan)
        PROC_PID_LINE="`ps -w | grep "origin_bot_scanning_start" | grep -v grep`"
        PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
        if [ -z "$PROC_PID" ]; then
            if [ -f "$SLAVE_SCAN_BOT_LIST_FILE" ]; then
                FORMATTED_MAC_LIST="$( cat $SLAVE_SCAN_BOT_LIST_FILE )"
                /etc/init.d/origin_bot_scanning_start.sh $FORMATTED_MAC_LIST &
                echo "origin_bot_scanning_start started"
            else
                echo "origin_bot_scanning_start missing $SLAVE_SCAN_BOT_LIST_FILE!"
            fi
        else
            echo "origin_bot_scanning_start is already running"
        fi
        ;;
    origin::add_bots)
        if [ -z "$( sysevent get origin::add_bots )" ]; then
            exit 0
        fi
        
        add_bots_to_persistent_file
        check_restart_authority
        sysevent set origin::add_bots
        ;;
    origin::remove_bots)
        if [ -z "$( sysevent get origin::remove_bots )" ]; then
            exit 0
        fi
        
        remove_bots_from_persistent_file
        check_restart_authority
        sysevent set origin::remove_bots
        ;;
    origin::last_restart_time)
        pub_slave_motion_restart
        sleep 1
        pub_master_motion_restart
        ;;
    subscriber::connected)
        if [ "$EVENT_VALUE" == "1" ]; then
            sleep 2
            pub_motion_supported
        fi
        ;;
	*)
		echo "error : $1 unknown" > /dev/console
		echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		exit 3
		;;
esac
