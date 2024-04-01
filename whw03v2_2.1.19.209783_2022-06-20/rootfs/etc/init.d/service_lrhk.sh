#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_misc_functions.sh
source /etc/init.d/interface_functions.sh
SERVICE_NAME="lrhk"
NAMESPACE="lrhk"
VARLOCK_DIR="/var/lock"
RUNTIME_DIR="/tmp/lrhk"
STORAGE_DIR="/var/config/lrhk"
MODULE_DIR="/etc/lrhk"
UTIL="/usr/sbin/lrhk_util"
MAX_LOG_SIZE="200000"
CLIENTDB_SCHEMA="${MODULE_DIR}/clientdb.sql"
LRHK_CLIENTDB_PURGE_CHECK="${RUNTIME_DIR}/purge_db"
MODE="$(syscfg get smart_mode::mode)"
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1
PMON=/etc/init.d/pmon.sh
WFR_BIN=WiFiRouter
WFR=/usr/bin/${WFR_BIN}
WFR_PID_FILE=/var/run/${WFR_BIN}.pid
PSKUPD_BIN=psk_updater
PSKUPD=/usr/bin/${PSKUPD_BIN}
PSKUPD_PID_FILE=/var/run/${PSKUPD_BIN}.pid
dfc_debug="0"
dfc_hk_store_path="/var/config/lrhk/hk/.HomeKitStore"
dfc_admin_password="${NAMESPACE}123"
dfc_lrhk_device_name="Linksys`/usr/sbin/skuapi -g serial_number | cut -d' ' -f 3 | cut -b10-14`"
dfc_shm_db_lock="/lrhk_db_lock"
dfc_clientdb="${RUNTIME_DIR}/clientdb.db"
dfc_clientdb_backup="${STORAGE_DIR}/clientdb.db"
dfc_mpsk_config_file="/tmp/hostapd.mpsk"
dfc_mpsk_temp_file="/tmp/hostapd.mpsk.tmp"
dfc_psk_updater_enabled="1"
dfc_psk_updater_debug="0"
dfc_psk_updater_mqname="/mpsk_update"
dfc_sectrans_data_cedardb="cedardb"
init_fixed_service_syscfg ()
{
    local val=`syscfg get ${NAMESPACE}::$1`
    if [ "$val" != "$2" ] ; then
        syscfg set ${NAMESPACE}::$1 $2
    fi
}
enable_wifi_isolation ()
{
    if [ "`sysevent get wifi-status`" == "started" ] ; then
        echo "turning on WiFi mac based isolation" >> /dev/console
        /usr/sbin/wlanconfig ath0 isolation enable
        /usr/sbin/wlanconfig ath1 isolation enable
        /usr/sbin/wlanconfig ath10 isolation enable
    else
        echo "skipping wifi isolation until wifi is ready"
    fi
}
disable_wifi_isolation ()
{
    if [ "`sysevent get wifi-status`" == "started" ] ; then
        echo "turning off WiFi mac based isolation" >> /dev/console
        /usr/sbin/wlanconfig ath0 isolation disable
        /usr/sbin/wlanconfig ath1 isolation disable
        /usr/sbin/wlanconfig ath10 isolation disable
    else 
        echo "skipping wifi isolation until wifi is ready"
    fi
}
read_service_syscfg ()
{
    local val=`syscfg get ${NAMESPACE}::$1`
    if [ -z "$val" ]; then
        syscfg set ${NAMESPACE}::$1 $2
        val=$2
    fi
    if [ ! -z "$3" ]; then
        eval $3=$val
    fi
}
check_db ()
{
    if [ -e "$LRHK_clientdb" ]; then
        return
    fi
    if [ ! -e "$LRHK_clientdb_backup" ]; then
        sqlite3 $LRHK_clientdb < $CLIENTDB_SCHEMA
        cp $LRHK_clientdb $LRHK_clientdb_backup
        return
    fi
    cp $LRHK_clientdb_backup $LRHK_clientdb
    $UTIL --initdb
}
set_defaults ()
{
    init_fixed_service_syscfg runtime_dir $RUNTIME_DIR
    init_fixed_service_syscfg storage_dir $STORAGE_DIR
    read_service_syscfg "hk_store_path" $dfc_hk_store_path
    read_service_syscfg "device_name" $dfc_lrhk_device_name
    if [ ! -d "`syscfg get lrhk::hk_store_path`" ] ; then
        mkdir -p "`syscfg get lrhk::hk_store_path`"
    fi
    if [ -z "`syscfg get ${NAMESPACE}::admin_password`" ] ; then
        syscfg set ${NAMESPACE}::admin_password $dfc_admin_password
        syscfg set ${NAMESPACE}::http_admin_password "$(/etc/init.d/service_httpd/httpd_util.sh generate_passwd "$NAMESPACE" "$dfc_admin_password")"
    fi
    process_lrhk_enabled
    read_service_syscfg "mn_enabled" "0" "LRHK_mn_enabled"
    read_service_syscfg "shm_db_lock" $dfc_shm_db_lock
    read_service_syscfg "clientdb" $dfc_clientdb "LRHK_clientdb"
    read_service_syscfg "clientdb_backup" $dfc_clientdb_backup "LRHK_clientdb_backup"
    read_service_syscfg "mpsk_config_file" $dfc_mpsk_config_file
    read_service_syscfg "mpsk_temp_file" $dfc_mpsk_temp_file
    read_service_syscfg "psk_updater_enabled" $dfc_psk_updater_enabled "PSKUP_enabled"
    read_service_syscfg "psk_updater_debug"   $dfc_psk_updater_debug   "PSKUP_debug"
    read_service_syscfg "psk_updater_mqname"  $dfc_psk_updater_mqname  "PSKUP_mqname"
    read_service_syscfg "sectrans_data_cedardb"  $dfc_sectrans_data_cedardb "LRHK_sectrans_data_cedardb"
    if [ "`syscfg get lrhk::productdata`" == "" ] ; then
        echo "looking for product data information in devinfo with skuapi" >> /dev/console
        LRHK_PD="`/usr/sbin/skuapi -g lrhk_pd | cut -d'=' -f2`"
        if [ "$LRHK_PD" != "" ] ; then
            echo "lrhk_pd found in devinfo" >> /dev/console
            syscfg set lrhk::productdata $LRHK_PD
        else
            echo "lrhk_pd NOT found in devinfo" >> /dev/console
        fi
    fi
    if [ "`syscfg get lrhk::productdata`" == "" ] ; then
        if [ "`/usr/sbin/skuapi -g hw_revision | cut -d'=' -f2 | grep 2`" ] ; then
            echo "using V2 product data for Cedar" >> /dev/console
            syscfg set lrhk::productdata "1e903f6d754d7876"
        else
            echo "using V1 product data for Cedar" >> /dev/console
            syscfg set lrhk::productdata "1e903f6d0fe6e2f7"
        fi
    fi
}
run_wfr()
{
    if [ "$MODE" = "$SLAVE_MODE" ]; then
        return 1
    fi
    
    ps|grep $WFR_BIN|grep -vq grep
    if [ $? -eq 0 ] ; then
        [ ! -f $WFR_PID_FILE ] && pidof $WFR_BIN > $WFR_PID_FILE
        return 1
    fi
    
    if [ ! -d "/tmp/www" ] ; then
        mkdir -p /tmp/www/
    fi
    
    grep -q production /etc/product.type
    if [ "$?" != "0" ] ; then
        ln -s /tmp/lrhk.log /tmp/www/lrhk.txt
    fi
    
    rm -f $WFR_PID_FILE
    if [ "`syscfg get lrhk::max_log_size`" != "" ] ; then
        MAX_LOG_SIZE="`syscfg get lrhk::max_log_size`"
    fi
    cd $STORAGE_DIR/hk && $WFR 2>&1 | tee -a /tmp/lrhk.log &
    ps|grep $WFR_BIN|grep -vq grep
    if [ $? -eq 1 ] ; then
        ulog ${SERVICE_NAME} "$WFR_BIN process isn't running, wait for 100ms"
        sleep 0.1
    fi
    pidof $WFR_BIN > $WFR_PID_FILE
    $PMON setproc ${WFR_BIN} $WFR_BIN $WFR_PID_FILE "/etc/init.d/service_lrhk.sh ${SERVICE_NAME}-restart"
}
run_pskupd()
{
    local DBGOPT
    local MQOPT
    local DAEMON_OPT="-D"
    [ "$PSKUP_debug" = "1" ] && DBGOPT="-d "
    [ -n "$PSKUP_mqname" ] && MQOPT="-n $PSKUP_mqname"
    rm -f $PSKUPD_PID_FILE
    $PSKUPD $DAEMON_OPT $DBGOPT $MQOPT &
    ps|grep $PSKUPD_BIN|grep -vq grep
    if [ $? -eq 1 ] ; then
        ulog ${SERVICE_NAME} "$PSKUPD_BIN process isn't rnnung, wait for 100ms"
        sleep 0.1
    fi
    pidof $PSKUPD_BIN > $PSKUPD_PID_FILE
    $PMON setproc ${PSKUPD_BIN} $PSKUPD_BIN $PSKUPD_PID_FILE "/etc/init.d/service_lrhk.sh ${SERVICE_NAME}-restart"
}
stop_service_monitoring()
{
    if [ -f $WFR_PID_FILE ];then
        rm $WFR_PID_FILE
        $PMON unsetproc ${WFR_BIN}
    fi
    if [ -f $PSKUPD_PID_FILE ];then
        rm $PSKUPD_PID_FILE
        $PMON unsetproc ${PSKUPD_BIN}
    fi
}
service_start ()
{
    LAN_INTF=`syscfg get lan_ifname`
    SSDP_PROCESS="$(pidof ssdp_listener)"
    MDNS_PROCESS="$(pidof mdns_listener)"
    if [ "$LRHK_enabled" = "1" -a "`syscfg get bridge_mode`" = "0" ] ; then
        wait_till_end_state ${SERVICE_NAME}
        check_err $? "Couldnt handle start"
        if [ "$PSKUP_enabled" = "1" ]; then
            run_pskupd
        fi
        ulogd -d -c /etc/init.d/ulogd.conf
        if [ "$MN_VALUE" = "1" ] ; then
            if [ -z "$SSDP_PROCESS" ]; then
                ssdp_listener -i ${LAN_INTF} &
            fi
            if [ -z "$MDNS_PROCESS" ]; then
                mdns_listener -i ${LAN_INTF} &
            fi
        fi
        if [ "`sysevent get mdnsd-status`" = "started" ] ; then
            if [ ! -d  ] ; then
                mkdir -p $STORAGE_DIR/hk/.HomeKitStore
            fi
            run_wfr
        fi
    fi
    if [ "$MN_VALUE" = "1" -a  "$MODE" = "$SLAVE_MODE" ]; then
        if [ -z "$SSDP_PROCESS" ]; then
            ssdp_listener -i ${LAN_INTF} -c &
        fi
    fi
    cp /etc/lrhk/cron_log_rotate.sh /tmp/cron/cron.everyminute/
    chmod +x /tmp/cron/cron.everyminute/cron_log_rotate.sh
    sysevent set ${SERVICE_NAME}-status started
}
service_stop ()
{
    echo "stopping $SERVICE_NAME" >> /dev/console
    wait_till_end_state ${SERVICE_NAME}
    if [ "$LRHK_enabled" = "0" ] ; then
        killall -15 WiFiRouter
    fi
    killall -9 psk_updater
    check_err $? "Couldnt handle stop"
    killall mdns_listener
    killall ssdp_listener
    rm -rf /tmp/cron/cron.everyminute/cron_log_rotate.sh
    sysevent set ${SERVICE_NAME}-status stopped
    ulog ${SERVICE_NAME} status "now stopped"
    stop_service_monitoring
}
set_if_bridge_mode ()
{
    if [ "$1" == "1" ]; then
        echo "set_if_bridge_mode 1" >> /dev/console
        PHYSICAL_IF_LIST=`syscfg get lan_wl_physical_ifnames`
        for VIR_IF in $PHYSICAL_IF_LIST; do 
                SYSCFG_INDEX="`syscfg get ${PHY_IF}_syscfg_index`"
                USER_STATE="`syscfg get ${SYSCFG_INDEX}_state`"
                if [ "$USER_STATE" != "down" ]; then
                    echo "=====> Setting hairpin on for br0 $VIR_IF!" > /dev/console
                    brctl hairpin br0 $VIR_IF on
                    echo "=====> Setting ap bridge to 0 for $VIR_IF!" > /dev/console
                    iwpriv $VIR_IF ap_bridge 0
                else
                    echo "interface $VIR_IF is down - skipping"
                fi
        done
        echo "=====> Turn on bridge-nf-call-iptables" > /dev/console
        echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
    else
        echo "set_if_bridge_mode 0" >> /dev/console
        PHYSICAL_IF_LIST=`syscfg get lan_wl_physical_ifnames`
        for VIR_IF in $PHYSICAL_IF_LIST; do 
            SYSCFG_INDEX="`syscfg get ${PHY_IF}_syscfg_index`"
            USER_STATE="`syscfg get ${SYSCFG_INDEX}_state`"
            if [ "$USER_STATE" != "down" ]; then
                echo "=====> Setting hairpin off for br0 $VIR_IF!" > /dev/console
                brctl hairpin br0 $VIR_IF off
                echo "=====> Setting ap bridge to 1 for $VIR_IF!" > /dev/console
                iwpriv $VIR_IF ap_bridge 1
            else
                echo "interface $VIR_IF is down - skipping"
            fi
        done
        echo "=====> Restore bridge-nf-call-iptables" > /dev/console
        sysevent set fastpath-restart
    fi
}
service_init()
{
    [ "$(syscfg get "${NAMESPACE}::debug")" == "1" ] && DEBUG=1
    DBG evconslog "Debugging on"
    LAN_IFNAME="$(syscfg get lan_ifname)"
    set_defaults
    if [ "$LRHK_enabled" = "1" ] ; then
        DBG evconslog "$SERVICE_NAME running $EVENT_NAME"
        MN_VALUE="$(syscfg get lrhk::mn_enabled)"
        IP_VALUE="$(syscfg get lrhk::ispaired)"
        if [ "$IP_VALUE" = "1" ] && [ "$MN_VALUE" == "1" ] ; then
            set_if_bridge_mode 1
        else
            set_if_bridge_mode 0
        fi
    else
        if [ "$EVENT_NAME" != "${SERVICE_NAME}-stop" ] && 
           [ "$EVENT_NAME" != "lrhk::generate_setup_payload" ] &&
           [ "$EVENT_NAME" != "node-mode-restart" ]; then
            evconslog "$SERVICE_NAME disabled in syscfg"
            service_stop
            exit 1
        else
            DBG evconslog "Allowing $EVENT_NAME event though disabled"
        fi
    fi
    mkdir -p $RUNTIME_DIR
    mkdir -p $STORAGE_DIR
    check_db
}
service_purge_db ()
{
    echo "Purging LRHK database ..."
    touch $LRHK_CLIENTDB_PURGE_CHECK
    rm -rf $LRHK_clientdb_backup
}
service_backup_db ()
{
    if [ ! -f "$LRHK_CLIENTDB_PURGE_CHECK" ]; then
        echo "Backing up LRHK database ..."
        $UTIL --backup
    fi
}
refresh_db_from_master ()
{
    if [ "$MODE" = "$SLAVE_MODE" ]; then
        local sc_ip=`sysevent get master::ip`
        local sc_login=`syscfg get sectrans::login`
        local sc_secret=`syscfg get smart_connect::configured_vap_passphrase`
        local sc_port=`syscfg get sectrans::port`
        sectrans_client -l $sc_login -s $sc_secret -i $sc_ip -p $sc_port -d $LRHK_sectrans_data_cedardb
        sysevent set firewall-restart
    fi
}
service_sys_stop ()
{
    local factory_reset=`sysevent get system_stop_no_syscfg_commit`;
    if [ "$factory_reset" = "1" ]; then
        if [ "`syscfg get lrhk::ispaired`" == "1" ] ; then
            echo "factory reset triggers pairing removal if unit is paired"
            killall -12 WiFiRouter
        fi
        service_purge_db
    else
        if [ ! -f "$LRHK_CLIENTDB_PURGE_CHECK" ]; then
            echo "Backing up LRHK database ..."
            $UTIL --forcebackup
        fi
    fi
}
process_lrhk_enabled ()
{
    local val=`syscfg get ${NAMESPACE}::enabled`
    if [ -z "$val" ]; then
        if [ "$MODE" = "$MASTER_MODE" ]; then
            val=1
        else
            val=0
        fi
        syscfg set ${NAMESPACE}::enabled $val
    fi
    LRHK_enabled=$val
}
node_mode_changed ()
{
    if [ "$MODE" = "$MASTER_MODE" ] && [ "$LRHK_enabled" = "0" ] ; then
        syscfg set ${NAMESPACE}::enabled 1
        LRHK_enabled=1
        service_stop
        service_start
    fi
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
    mdnsd-status)
        if [ "$LRHK_enabled" = "1" -a "`syscfg get bridge_mode`" = "0" -a "`sysevent get mdnsd-status`" = "started" ] ; then
            if [ "`sysevent get wifi-status`" == "started" ] ; then
                run_wfr
            else 
                echo "delaying start of WiFiRouter until wifi has been started"
            fi
        fi
        ;;
    lrhk::generate_ownership_token)
        echo "generating lrhk ownership token"
        killall -10 WiFiRouter
        echo "Token: `syscfg get lrhk::ownership_token`" >> /dev/console
        ;;
    devinfo|slave_eth_link_status_changed|slave_link_status_changed|slave_offline|slave_wifi_link_status_changed|devicedb-backup)
        [ "$EVENT_NAME" == "devinfo" ] && (check_hk_support $PAYLOAD_PATH &)
        sleep 5
        if [ "`syscfg get lrhk::slave_device_count`" != "`/usr/sbin/devicedb_client -c getSlaves | wc -l`" ] ; then
            echo "slave device count changed `syscfg get lrhk::slave_device_count` => `/usr/sbin/devicedb_client -c getSlaves | wc -l` - refreshing sattelite devices for cedar" >> /dev/console
            slave_count="`/usr/sbin/devicedb_client -c getSlaves | wc -l`"
            echo "setting child count to $slave_count" >> /dev/console
            syscfg set lrhk::slave_device_count "$slave_count"
            killall -29 WiFiRouter
        else
            echo "slave device count did not change `syscfg get lrhk::slave_device_count` - skipping cedar refresh " >> /dev/console
        fi
        if [ "$EVENT_NAME" == "slave_link_status_changed" ] || [ "$EVENT_NAME" == "slave_wifi_link_status_changed" ] || [ "$EVENT_NAME" == "slave_eth_link_status_changed" ] || [ "$EVENT_NAME" == "devinfo" ]; then
            echo "refreshing satelitte device information" >> /dev/console
            killall -29 WiFiRouter
        else
            echo "!!! $EVENT_NAME triggered sattelite refresh, but refresh was not done" >> /dev/console
        fi
        ;;
    backup_db)
        service_backup_db
        ;;
    purge_db)
        service_purge_db
        ;;
    lrhk::kickmac)
        /etc/lrhk/kickmac.sh $EVENT_NAME $EVENT_VALUE &
        
        if [ "$MODE" = "$MASTER_MODE" ]; then
            pub_lrhk_kickmac $EVENT_NAME $EVENT_VALUE
        fi
        ;;
    lrhk::remove_all_pairings)
        killall -12 WiFiRouter
        echo "doing some trickery to ensure pairing data is really gone" >> /dev/console
        mkdir -p /tmp/ahdk.lrhk/
        cp /var/config/lrhk/hk/.HomeKitStore/40.* /tmp/ahdk.lrhk/
        rm -rf /var/config/lrhk/hk/.HomeKitStore/*
        cp /tmp/ahdk.lrhk/* /var/config/lrhk/hk/.HomeKitStore/
        rm -rf /tmp/ahdk.lrhk/
        sleep 2
        service_stop
        service_start
        ;;
    lrhk::config_changed)        
        if [ "$MODE" = "$MASTER_MODE" ]; then
            service_stop
            service_start
        fi
        ;;
    system-status)
        STATUS=`sysevent get system-status`
        if [ "$STATUS" == "stopping" ]; then
            service_sys_stop
        fi
        ;;
    lrhk::generate_setup_payload)
        SETUP_CODE="`syscfg get lrhk::setup_code`"
        LRHK_UUID="`syscfg get lrhk::software_token_uuid`"
        LRHK_TOKEN="`syscfg get lrhk::software_token`"
        if [ "$SETUP_CODE" ] ; then
            if [ "$LRHK_UUID" ] ; then
                if [ "$LRHK_TOKEN" != "0" ] ; then
                    if [ ! -f "$STORAGE_DIR/hk/.HomeKitStore/40.20" ] ; then
                        cd $STORAGE_DIR/hk/.HomeKitStore && /usr/bin/lrhkprvsn -v -s $SETUP_CODE -u $LRHK_UUID -t "$LRHK_TOKEN" > /tmp/lrhk.out.log
                        mv $STORAGE_DIR/hk/.HomeKitStore/lrhkprvsn.log /tmp/
                        syscfg set lrhk::setup_payload "`cat /tmp/lrhk.out.log | grep "Setup Payload" | cut -d '-' -f2-3 | tr -d ' '`"
                        echo "re-starting WiFiRouter Process to get software apiring tokens" >> /dev/console
                        killall -9 WiFiRouter
                        sleep 1
                        run_wfr
                    else
                        echo "LRHK PAIRING IFORMATION ALREADY EXISTS - not recreating" >> /dev/console
                    fi
                fi
            fi
        fi
        ;;
    lrhk::database_update)
        if [ "$MODE" = "$MASTER_MODE" ]; then
            echo "Notify slave to update their db: $( jsongen -s "cmds:${EVENT_VALUE}" )"
            jsongen -s "cmds:${EVENT_VALUE}" | omsg-publish "lrhk/database_update"
            ./etc/init.d/handler_database_update.sh ${EVENT_VALUE}
        else
            ./etc/init.d/handler_database_update.sh $( echo ${EVENT_VALUE} | jsonparse cmds)
        fi
        ;;
    master::ip)
        if [ "`sysevent get master::ip`" != "" ]; then
            refresh_db_from_master
        fi
        ;;
    wifi-status)
        if [ "`sysevent get wifi-status`" == "started" ] ; then
            if [ "$LRHK_enabled" = "1" -a "`syscfg get bridge_mode`" = "0" -a "`sysevent get mdnsd-status`" = "started" ] ; then
                run_wfr
            fi
        fi
        ;;
    lrhk::mn_enabled_changed)
        MN_VALUE="$(syscfg get lrhk::mn_enabled)"
        if [ "$MN_VALUE" = "1" ] ; then
            LAN_INTF=`syscfg get lan_ifname`
            SSDP_PROCESS="$(pidof ssdp_listener)"
            MDNS_PROCESS="$(pidof mdns_listener)"
            if [ -z "$SSDP_PROCESS" ]; then
                if [ "$MODE" = "$SLAVE_MODE" ]; then
                    ssdp_listener -i ${LAN_INTF} -c &
                else
                    ssdp_listener -i ${LAN_INTF} &
                fi
            fi
            if [ -z "$MDNS_PROCESS" -a "$MODE" = "$MASTER_MODE" ]; then
                mdns_listener -i ${LAN_INTF} &
            fi
            ipv4_firewall hk_firewall-enable
            ipv6_firewall hk_firewall-enable
            bridge_firewall hk_firewall-enable
						enable_wifi_isolation
            set_if_bridge_mode 1
        else
            killall mdns_listener
            killall ssdp_listener
            ipv4_firewall hk_firewall-disable
            ipv6_firewall hk_firewall-disable
            bridge_firewall hk_firewall-disable
						disable_wifi_isolation
            set_if_bridge_mode 0
        fi
        ;;
    lrhk::paired)
        MN_VALUE="$(syscfg get lrhk::mn_enabled)"
        IP_VALUE="$(syscfg get lrhk::ispaired)"
        if [ "$IP_VALUE" = "1" ] ; then
            if [ "$MN_VALUE" != "1" ] ; then
                set_if_bridge_mode 1
            fi
        else
            set_if_bridge_mode 0
            if [ "$MN_VALUE" != "0" ] ; then
                syscfg set lrhk::mn_enabled 0
                sysevent set lrhk::mn_enabled_changed 0
            fi
        fi
        ;;
    config_sync::lrhk_synchronized)
        ulog ${SERVICE_NAME} STATUS "Processing config_sync::lrhk_synchronized"
        if [ "$MODE" = "$SLAVE_MODE" ]; then
            service_stop
            service_start
            sysevent set wifi_config_changed
        fi
        ;;
    node-mode-restart)
        node_mode_changed
        ;;
    *)
        conslog "error : $1 unknown"
        conslog "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart | mdnsd-status | backup_db | purge_db | system-status | refresh_db ]"
        exit 3
        ;;
esac
