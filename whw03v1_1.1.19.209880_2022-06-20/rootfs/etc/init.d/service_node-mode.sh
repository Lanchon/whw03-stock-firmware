#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_misc_functions.sh
source /etc/init.d/node-mode_common.sh
source /etc/init.d/service_wifi/wifi_steer_util.sh
source /etc/init.d/mosquitto_common.sh
dfc_debug="0"
dfc_enabled="1"
let "dfc_${PERIODIC_BH_SPEED_CHECK}=1"
dfc_port="$MOSQUITTO_DEFAULT_PORT"
MODE=$(syscfg get smart_mode::mode)
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1
set_defaults()
{
    local OLD_NAMESPACE=$NAMESPACE
    local NAMESPACE="omsg"
    set |                                     \
        grep '^dfc_' |                        \
        grep -v -e dfc_debug -e dfc_enabled | \
        cut -f1 -d= |                         \
        cut -f2- -d_ |                        \
        while read i;do
        local DEF_VAL="$(eval echo "\$dfc_${i}")"
        if [ -z "$(syscfg get ${NAMESPACE}::$i)" ] ; then
            evconslog "Setting default for $i = '$DEF_VAL'"
            syscfg set ${NAMESPACE}::$i $DEF_VAL
        fi
    done
    NAMESPACE=$OLD_NAMESPACE
    for i in debug enabled $PERIODIC_BH_SPEED_CHECK; do
        DEF_VAL="$(eval echo "\$dfc_${i}")"
        if [ -z "$(syscfg get ${NAMESPACE}::$i)" ] ; then
            evconslog "Setting default for $i = '$DEF_VAL'"
            syscfg set ${NAMESPACE}::$i $DEF_VAL
        fi
    done
}
kill_mdns_lookup() {
    killall_if_running mdns_lookup
    ulog ${SERVICE_NAME} STATUS "kill_mdns_lookup"
}
kill_mdns_register() {
    killall_if_running mdns_register
    ulog ${SERVICE_NAME} STATUS "kill_mdns_register"
}
start_mdns_lookup() {
    if [ -x "/usr/sbin/mdns_lookup" ] ; then
       /usr/sbin/mdns_lookup &
       ulog ${SERVICE_NAME} STATUS "start_mdns_lookup"
    fi
}
start_mdns_register() {
    LOCAL_IP="$(sysevent get $MASTERIP_EV_NAME)"
    OMSG_PORT="$(syscfg get omsg::port)"
    DBG conslog "$SERVICE_NAME start_mdns_register LOCAL_IP: $LOCAL_IP, OMSG_PORT: $OMSG_PORT"
    ulog ${SERVICE_NAME} STATUS "start_mdns_register LOCAL_IP: $LOCAL_IP, OMSG_PORT: $OMSG_PORT"
    if [ -x "/usr/sbin/mdns_register" ] ; then
        if [ -n "$LOCAL_IP" ] ; then
            /usr/sbin/mdns_register -i "$LOCAL_IP" -p "$OMSG_PORT" &
            ulog ${SERVICE_NAME} STATUS "start_mdns_register"
        else
            ulog ${SERVICE_NAME} STATUS "start_mdns_register failed. $MASTERIP_EV_NAME is empty."
        fi
    fi
}
init_local_omsg_server() {
    if [ "`syscfg get bridge_mode`" = "0" ] ; then
        LOCAL_IP="$(syscfg get lan_ipaddr)"
    else
        LOCAL_IP="$(sysevent get ipv4_wan_ipaddr)"
    fi
    sysevent set $MASTERIP_EV_NAME $LOCAL_IP
    syscfg set omsg::port 1883
}
CRON_JOB_BIN="/usr/sbin"
CRON_JOB_SRC_FILE="refresh_bh_perf"
CRON_JOB_FILE="${CRON_JOB_SRC_FILE}.cron"
CRON_JOB_DEST="/tmp/cron/cron.everyminute"
install_cronjob() {
    if [ "$(syscfg get $PERIODIC_BH_SPEED_CHECK_SYSCFG_VAR)" == "1" ]; then
        if [ "$MODE" = "$MASTER_MODE" ]; then
            if [ ! -f "${CRON_JOB_DEST}/${CRON_JOB_FILE}" ]; then
                DBG conslog "$SERVICE_NAME installing ${CRON_JOB_FILE} to ${CRON_JOB_DEST}/"
                ln -s ${CRON_JOB_BIN}/${CRON_JOB_SRC_FILE} ${CRON_JOB_DEST}/${CRON_JOB_FILE}
            fi
        fi
    else
        remove_cronjob
    fi
}
remove_cronjob() {
    if [ "$MODE" = "$MASTER_MODE" ]; then
        if [ -f "${CRON_JOB_DEST}/${CRON_JOB_FILE}" ]; then
            DBG conslog "$SERVICE_NAME removing ${CRON_JOB_FILE} from ${CRON_JOB_DEST}/"
            rm ${CRON_JOB_DEST}/${CRON_JOB_FILE}
        fi
    fi
}
service_init()
{
    [ "$(syscfg get "${NAMESPACE}::debug")" == "1" ] && DEBUG=1
    if [ $MODE -eq $MASTER_MODE ]; then
        local OMSG_NS="omsg"
        for i in secport psk_id psk;do
            if [ -z "$(syscfg get ${OMSG_NS}::$i)" ]; then
                local MOSQ_VAL="$(syscfg get mosquitto::$i)"
                [ $MOSQ_VAL ] && syscfg set ${OMSG_NS}::$i "$MOSQ_VAL"
            fi
        done
    fi
    if [ "$(sysevent get ${NAMESPACE}::inited)" != "1" ] ; then
        set_defaults
        sysevent set ${NAMESPACE}::inited 1
        if [ "$(syscfg get ${NAMESPACE}::enabled)" = "1" ] ; then
            conslog "$SERVICE_NAME running $1"
        else
            conslog "$SERVICE_NAME disabled in syscfg"
            exit 1
        fi
    fi
}
post_configure_me() {
    ulog ${SERVICE_NAME} STATUS "Posting set-me-up"
    pub_configure_me
}
service_start ()
{
    DBG evconslog "Starting in mode $MODE"
    if [ "$(sysevent get ${SERVICE_NAME}-status)" != started ]; then
        sysevent set ${SERVICE_NAME}-status starting
        case $MODE in
            $UNCONFIGURED_MODE)
                ulog ${SERVICE_NAME} STATUS "Starting in Unconfigured mode"
		sysevent set $OMSG_LOC_EV_NAME ""
                start_mdns_lookup
                ;;
            $MASTER_MODE)
                ulog ${SERVICE_NAME} STATUS "Starting in Master mode"
                syscfg set infra_services cnc,config,rtt,wifi_scheduler
                init_local_omsg_server
                start_mdns_register
                install_cronjob
                ;;
            $SLAVE_MODE)
                ulog ${SERVICE_NAME} STATUS "Starting in Slave mode"
                syscfg set infra_services thrulay
                sysevent set $OMSG_LOC_EV_NAME ""
                start_mdns_lookup
                ;;
            *)
                ulog ${SERVICE_NAME} ERROR "Illegal mode '$MODE'"
                ;;
        esac
        check_err $? "Couldn't handle start"
        sysevent set ${SERVICE_NAME}-status started
        ulog ${SERVICE_NAME} status "now started"
    fi
}
service_stop ()
{
    ulog ${SERVICE_NAME} STATUS "STOP requested"
    sysevent set ${SERVICE_NAME}-status stopping
    remove_cronjob
    kill_mdns_lookup
    kill_mdns_register
    sysevent set ${SERVICE_NAME}-status stopped
}
service_restart() {
    service_stop
    sleep 1
    service_start
}
omsg_master_located() {
    local OMSG_LOCATION="$1"
    if [ -n "$OMSG_LOCATION" -a "$OMSG_LOCATION" != "NULL" ]; then
        MASTER_IP="$(echo $OMSG_LOCATION | cut -f1 -d:)"
        OMSG_PORT="$(echo $OMSG_LOCATION | cut -f2 -d:)"
        if [ -n "$MASTER_IP" -a -n "$OMSG_PORT" ]; then
            DBG conslog "Setting event '$MASTERIP_EV_NAME' = '$MASTER_IP'"
            sysevent set $MASTERIP_EV_NAME $MASTER_IP
            syscfg set omsg::port $OMSG_PORT
            sysevent set subscriber-restart
            DBG conslog "$SERVICE_NAME restarting secure_config"
            sysevent set secure_config-restart
        else
            ulog ${SERVICE_NAME} ERROR "Bad omsg location '$OMSG_LOCATION'"
        fi
    else
        DBG conslog "Clearing $MASTERIP_EV_NAME on $OMSG_LOC_EV_NAME ($OMSG_LOCATION)"
        ulog ${SERVICE_NAME} ERROR "$1 Clearing $MASTERIP_EV_NAME due to empty location"
    fi
}
presetup_xtrol() {
    if [ "$MODE" = "$MASTER_MODE" ]; then
        if [ "$1" = "true" -o "$1" = "false" ]; then
            if [ -n "$2" -a "$2" != "NULL" ]; then
                pub_presetup -s "$1" -u "$2"
            else
                ulog ${SERVICE_NAME} ERROR "Bad or missing UUID: '$2'"
            fi
        else
            ulog ${SERVICE_NAME} ERROR "Bad or missing presetup state: '$1'"
        fi
    fi
}
pub_eth_subdev_info() {
    if [ -n "$1" ]; then
        local EVENT_VALUE="$1"
        local STATUS="$(echo "$EVENT_VALUE" | cut -f1 -d,)"
        if [ "$STATUS" = "up" ]; then
            STATUS="connected"
        else
            STATUS="disconnected"
        fi
        local INTF_MAC="$(echo "$EVENT_VALUE" | cut -f2 -d,)"
        local INTF_NM="$(echo "$EVENT_VALUE" | cut -f3 -d,)"
        local CLIENT_MAC="$(echo "$EVENT_VALUE" | cut -f4 -d,)"
        local PORT="$(echo "$EVENT_VALUE" | cut -f5 -d,)"
        local SPEED="$(echo "$EVENT_VALUE" | cut -f6 -d,)"
        ulog ${SERVICE_NAME} "$PROG_NAME pub_eth_subdev $CLIENT_MAC $INTF_NM $STATUS $INTF_MAC $PORT $SPEED"
        pub_eth_subdev $CLIENT_MAC $INTF_NM $STATUS $INTF_MAC $PORT $SPEED
    else
        conslog "$PROG_NAME: pub_eth_subdev_info called with no argument"
    fi
}
service_init
pub_sysevent() {
    conslog "$PROG_NAME: Setting sysevent $1 = $2 on slaves"
    local EVENT="$1"
    local SUBSCRIPTION_NAME="$(echo "$EVENT" | tr -s ':-' '_' | tr '[a-z]' '[A-Z]')"
    local TOPIC="$(omsg-conf -s "$SUBSCRIPTION_NAME")"
    local VALUE="$2"
    DBG evconslog "Publishing msg '$VALUE' to topic '$TOPIC'"
    echo "$VALUE" | pub_generic "$TOPIC"
}
pub_sysevent_value() {
    if [ -n "$2" -a "$2" != "NULL" ]; then
        pub_sysevent $1 $2
    else
        conslog "$PROG_NAME: Skipping sharing valueless $1"
    fi
}
pub_parent_ip() {
    if [ "$MODE" = "$SLAVE_MODE" ]; then
        BH_INTF="$1"
        case "$BH_INTF" in
            eth[0-9]|eth[0-9].[0-9]|ethX)
                (
                    sleep 5;
                    lldp_to_parent_ip $BH_INTF
                ) > /dev/console &
                ;;
            "") DBG evconslog "Ignoring empty interface '$BH_INTF'"  ;;
            *) DBG evconslog "Ignoring non-ethernet interface '$BH_INTF'"  ;;
        esac
    else
        DBG evconslog "Ignoring for non-Slave"
    fi
}
node_mode_check()
{
    CHECK_CTR="$(sysevent get node-mode::check_counter)"
    [ -z "$CHECK_CTR" ] && CHECK_CTR="0"
    sysevent set node-mode::check_counter `expr $CHECK_CTR + 1`
    echo "${SERVICE_NAME} node-mode::check ctr=$CHECK_CTR" > /dev/console
    if [ "$(sysevent get backhaul::status)" != "up" ] || [ "$CHECK_CTR" -ge "5" ]; then
        rm ${CRON_JOB_DEST}/node_mode_check.sh
	echo "${SERVICE_NAME} node-mode::check end" > /dev/console
        sysevent set node-mode::check_counter ""
	sysevent set node-mode::last_check ""
	sysevent set node-mode::secure_config_checked ""
	sysevent set node-mode::mqtt_secure_checked ""
	return
    fi
    NOW="$(date +%s)"
    LAST_CHECK="$(sysevent get node-mode::last_check)"
    INTERVAL="`expr $NOW - $LAST_CHECK`"
    [ "$INTERVAL" -lt 40 ] && return
    if [ "$INTERVAL" -gt 300 ]; then
        sysevent set node-mode::last_check "$NOW"
        return
    fi 
    sysevent set node-mode::last_check "$NOW"
    OMSG_SECPORT="`syscfg get omsg::secport`"
    if [ "$OMSG_SECPORT" != "8883" -a "`sysevent get node-mode::secure_config_checked`" != "1" ] ; then
        echo "${SERVICE_NAME} secure_config check" > /dev/console
        sysevent set secure_config-start
	sysevent set node-mode::secure_config_checked 1
	return
    fi
    if [ -z "$(sysevent get $OMSG_LOC_EV_NAME)" ] ; then
        echo "${SERVICE_NAME} mdns_lookup check" > /dev/console
        service_restart
	return
    fi
    [ "`sysevent get subscriber::connected`" != "1" ] && return
    ps -w | grep omsgd | grep -q "$OMSG_SECPORT"
    if [ "$?" != "0" -a "`sysevent get node-mode::mqtt_secure_checked`" != "1" ] ; then
        echo "${SERVICE_NAME} mqtt secure check" > /dev/console
        sysevent set subscriber-restart
        sysevent set node-mode::mqtt_secure_checked 1
        return
    fi
    BH_PERF="$(sysevent get backhaul::l3_perf)"
    [ -z "$BH_PERF" ] && BH_PERF="0"
    if [ "$BH_PERF" -lt "`syscfg get backhaul::l3_perf_threshold`" ] ; then
        echo "${SERVICE_NAME} backhaul::l3_perf check" > /dev/console
        pub_bh_status
	return
    fi
    rm ${CRON_JOB_DEST}/node_mode_check.sh
    echo "${SERVICE_NAME} node-mode::check end" > /dev/console
    sysevent set node-mode::check_counter ""
    sysevent set node-mode::last_check ""
    sysevent set node-mode::secure_config_checked ""
    sysevent set node-mode::mqtt_secure_checked ""
}
DBG evconslog
case "$ACTION" in
    ${SERVICE_NAME}-start)
        service_start
        ;;
    ${SERVICE_NAME}-stop)
        service_stop
        ;;
    ${SERVICE_NAME}-restart)
        service_restart
        ;;
    backhaul::l3_perf)
        ;;
    backhaul::status)
        if [ "$MODE" = "$MASTER_MODE" ] && [ "$EVENT_VALUE" = "up" ]; then
            LOCAL_IP="$(sysevent get lan_ipaddr)"
            DBG evconslog "LOCAL_IP (from lan_ipaddr): '$LOCAL_IP'"
            if [ -n "$LOCAL_IP" ]; then
                service_restart
            else
                evconslog "ERROR cannot determine LAN ip address"
            fi
        fi
        if [ "$MODE" = "$SLAVE_MODE" ]; then
            if [ "$EVENT_VALUE" = "up" ]; then
                [ -n "$(sysevent get $MASTERIP_EV_NAME)" ] && service_restart
                if [ ! -f "${CRON_JOB_DEST}/node_mode_check.sh" ]; then
                    echo "#! /bin/sh" > ${CRON_JOB_DEST}/node_mode_check.sh
                    echo "sysevent set node-mode::check" >> ${CRON_JOB_DEST}/node_mode_check.sh
                    chmod 700 ${CRON_JOB_DEST}/node_mode_check.sh
                    sysevent set node-mode::last_check "$(date +%s)"
                fi
            else
                service_stop
                sysevent set subscriber-stop
            fi
        fi
        ;;
    backhaul::parent_ip)
        if [ "$MODE" = "$MASTER_MODE" ]; then
            BASE_STATUS_NAME="$(dirname $PAYLOAD_PATH)/$(basename $PAYLOAD_PATH .parent_ip)"
            DBG evconslog "Cleaning performance file for $PAYLOAD_PATH"
            clean_file_variants ${BASE_STATUS_NAME} .performance
        else
            if [ -f "$PAYLOAD_PATH" ]; then
                PARENT_IP="$(cat $PAYLOAD_PATH)"
                if [ -n "$PARENT_IP" ]; then
                    sysevent set $PARENT_IP_EV_NAME $PARENT_IP
                    install_cronjob
                    THRULAY_PORT="$(syscfg get thrulay::port)"
                    if [ $THRULAY_PORT ]; then
                        RESENDING_DATA=$(sysevent get backhaul::resending_data)
                        ([ ! $RESENDING_DATA ] && sleep 10; sysevent set thrulay::location "$PARENT_IP:$THRULAY_PORT")&
                    else
                        conslog "Couldn't determine Thrulay port"
                    fi
                else
                    ulog ${SERVICE_NAME} ERROR "Determining parent IP from $2"
                    DBG conslog ${SERVICE_NAME} ERROR "Determining parent IP from $PAYLOAD_PATH"
                fi
            else
                ulog ${SERVICE_NAME} ERROR "Missing backhaul parent IP file $2"
                DBG conslog ${SERVICE_NAME} ERROR "Missing backhaul parent IP file $PAYLOAD_PATH"
            fi
            sysevent set backhaul::resending_data NULL
            update_slave $EVENT_NAME
        fi
        ;;
    backhaul::status_resend)
        sysevent set backhaul::resending_data 1
        pub_bh_status
        if [ $? -ne 0 ]; then
            sysevent set backhaul::resending_data NULL
        fi
        ;;
    backhaul::status_resend_all)
        pub_devinfo_status;
        sleep 1;
        pub_wlan_status;
        sleep 1;
        pub_bh_status
        ;;
    node-mode::check)
	node_mode_check
        ;;
    thrulay::last_thrulay)
        if [ "$MODE" = "$SLAVE_MODE" ]; then
            BH_MEDIA="$(sysevent get $BH_MEDIA_EV_NAME)"
            case "$BH_MEDIA" in
                $BH_MEDIA_WIRELESS) OUR_PARENT="$(sysevent get $PARENT_IP_EV_NAME)"             ;;
                $BH_MEDIA_WIRED)    OUR_PARENT="$(sysevent get master::ip)"                     ;;
                *)                  conslog "Unknown backhaul media type ($BH_MEDIA)" ; exit 1  ;;
            esac
            req_mod /etc/init.d/thrulay_support.sh
            TEST_PARENT_IP="$(parse_thrulay_test "$EVENT_VALUE" parent_ip )"
            if [ "$TEST_PARENT_IP" = "$OUR_PARENT" ]; then
                RATE="$(      parse_thrulay_test "$EVENT_VALUE" rate )"
                JITTER="$(    parse_thrulay_test "$EVENT_VALUE" jitter )"
                DELAY="$(     parse_thrulay_test "$EVENT_VALUE" delay )"
                pub_bh_perf -p "$TEST_PARENT_IP" -r "$RATE" -j "$JITTER" -D "$DELAY"
            else
                DBG conslog "Ignoring thrulay test to non-parent '$TEST_PARENT_IP' (our parent: '$OUR_PARENT')"
            fi
        fi
        ;;
    wifi_config_changed)
        install_cronjob
        ;;
    backhaul::status_data)
        ulog ${SERVICE_NAME} STATUS "$1 $2 trying to send parent IP to slave"
        DBG evconslog "Trying to send parent_ip to slave"
        pub_slave_parent_ip $PAYLOAD_PATH
        update_nodes $EVENT_NAME
        ddb_omsg_import --action=bh $PAYLOAD_PATH
        UUID="$(jsonparse uuid < $PAYLOAD_PATH)"
        STATE="$(jsonparse data.state < $PAYLOAD_PATH)"
        LOGMSG="Node $UUID"
        CON_TYPE="offline"
        if [ "$STATE" != "up" ]; then
            LOGMSG="$LOGMSG is down"
        else
            IP="$(jsonparse data.ip < $PAYLOAD_PATH)"
            LOGMSG="$LOGMSG @$IP is $STATE"
            CON_TYPE="$(jsonparse data.type < $PAYLOAD_PATH)"
            if [ "$CON_TYPE" == "WIRELESS" ]; then
                LOGMSG="$LOGMSG (RSSI:$(jsonparse data.rssi < $PAYLOAD_PATH)"
                LOGMSG="$LOGMSG ap_bssid:$(jsonparse data.ap_bssid < $PAYLOAD_PATH))"
            fi
        fi
        ulog ${SERVICE_NAME} BH-STATUS "$CON_TYPE $LOGMSG"
        SECONDARY_EVENT="$(omsg-conf --slave --attribute=event BH)"
        SECONDARY_EVENT_VALUE="$(omsg-conf --slave --attribute=value BH)"
        if [ -n "$SECONDARY_EVENT" ]; then
            DBG evconslog "Set 2ndary event $SECONDARY_EVENT='$SECONDARY_EVENT_VALUE'"
            sysevent set "$SECONDARY_EVENT" "$SECONDARY_EVENT_VALUE"
        fi
        sysevent set backhaul::refresh_error_$UUID NULL
        ;;
    backhaul::intf)
        pub_parent_ip "$2"
        ;;
    ipv4_wan_ipaddr)
        if [ -n "$EVENT_VALUE" ] &&
           [ "$EVENT_VALUE" != "0.0.0.0" ] &&
           [ "$MODE" = "$SLAVE_MODE" ] &&
           [ -n "$(sysevent get $MASTERIP_EV_NAME)" ] &&
           [ "$(sysevent get backhaul::status)" = "up" ]; then
            service_restart
        fi
        ;;
    $OMSG_LOC_EV_NAME)
        DBG evconslog "omsg location event detected"
        omsg_master_located $EVENT_VALUE
        ;;
    mdnsd-status)
        DBG evconslog "MODE: $MODE"
        if [ "$EVENT_VALUE" = "started" ]; then
            if [ "$MODE" = "$UNCONFIGURED_MODE" ] || [ "$MODE" = "$SLAVE_MODE" ]; then
                kill_mdns_lookup
                sleep 1
                start_mdns_lookup
            elif [ "$MODE" = "$MASTER_MODE" ]; then
                kill_mdns_register
                start_mdns_register
            fi
        fi
        ;;
    lan-status)
        [ "$EVENT_VALUE" = "stopping" ] && sysevent set node-off-stop
        if [ "$MODE" = "$MASTER_MODE" ]; then
            if [ "$EVENT_VALUE" == "started" ] ; then
                if [ "$(sysevent get backhaul::status)" != "up" ]; then
                    ulog ${SERVICE_NAME} STATUS "$PROG_NAME $1 setting backhaul::status up"
                    sysevent set backhaul::status up
                fi
                DBG evconslog "Resetting omsg IP & mdns register"
                init_local_omsg_server
                kill_mdns_register
                start_mdns_register
                sysevent set subscriber-restart
            else
                sysevent set subscriber-stop
            fi
        fi
        ;;
    wan-status)
        if [ "$MODE" = "$UNCONFIGURED_MODE" ] ; then
            if [ "$EVENT_VALUE" == "started" ] ; then
                DBG evconslog "wan_conflict_resolved and lan restarted; doing service_restart"
                service_restart
            else
                sysevent set subscriber-stop
            fi
        fi
        ;;
    smart_connect::setup_status)
        if [ "$EVENT_VALUE" = "START" -o "$EVENT_VALUE" = "STOP" ]; then
            STATUS="$(echo $EVENT_VALUE | tr \"[a-z]\" \"[A-Z]\")"
            nohup pub_smart_connect_status $STATUS &
        fi
        ;;
    smart_connect_status)
        EVENT_NAME="smart_connect::setup_status"
        if [ -f "$PAYLOAD_PATH" ]; then
            STATUS="$(grep '"status":' $PAYLOAD_PATH | sed -r 's/^ *"status": "(.*)".*$/\1/')"
            if [ "$STATUS" = "START" -o "$STATUS" = "STOP" ]; then
                if [ "$(sysevent get $EVENT_NAME)" != "$STATUS" ]; then
                    sysevent set $EVENT_NAME $STATUS
                else
                    DBG evconslog "Ignoring status '$STATUS'; already in that state"
                fi
            else
                DBG evconslog "Ignoring status '$STATUS' (only act on START & STOP)"
            fi
        else
            ulog ${SERVICE_NAME} ERROR "Can't find message file '$PAYLOAD_PATH'"
            DBG evconslog ${SERVICE_NAME} ERROR "Can't find message file '$PAYLOAD_PATH'"
        fi
        ;;
    mqttsub::bhconfig)
        if [ -f "$PAYLOAD_PATH" ]; then
            UUID="$(jsonparse uuid < $PAYLOAD_PATH)"
            BAND="$(jsonparse data.band < $PAYLOAD_PATH)"
            CHANNEL="$(jsonparse data.channel < $PAYLOAD_PATH)"
            BSSID="$(jsonparse data.bssid < $PAYLOAD_PATH)"
            evconslog "backhaul config: $BAND $CHANNEL $BSSID"
            echo "$CHANNEL" | egrep "^[0-9]{1,3}$" > /dev/null 2>&1
            if [ $? -eq 0 ];then
                sysevent set mqttsub::bh_channel $CHANNEL
            else
                sysevent set mqttsub::bh_channel ""
            fi
            echo "$BSSID" | egrep "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$" > /dev/null 2>&1
            if [ $? -eq 0 ];then
                sysevent set mqttsub::bh_bssid $BSSID
            else
                sysevent set mqttsub::bh_bssid ""
            fi
            if [ $BAND = '5GL' ] || [ $BAND = '5GH' ] || [ $BAND = 'AUTO' ];then
                sysevent set backhaul::set_intf $BAND
            fi
        else
            evconslog "File '$PAYLOAD_PATH' does not exist"
            ulog ${SERVICE_NAME} ERROR "Message payload '$PAYLOAD_PATH' does not exist"
        fi
        ;;
    wifi_smart_connect_setup-run)
        if [ "$MODE" = "$MASTER_MODE" ]; then
            evconslog "Invoking pub_smart_connect_start_stop start"
            pub_smart_connect_start_stop start
        else
            evconslog "Non-Master skipping pub_smart_connect_start_stop start"
        fi
        ;;
    wifi_smart_connect_setup-stop)
        if [ "$MODE" = "$MASTER_MODE" ]; then
            evconslog "Invoking pub_smart_connect_start_stop stop"
            pub_smart_connect_start_stop stop
        else
            evconslog "Non-Master skipping pub_smart_connect_start_stop stop"
        fi
        ;;
    cloud::alert_user_unconfigured_node)
        if [ "$(syscfg get auto_onboarding::wired_enabled)" = "1" ]; then
            PIN="$(jsonparse data.pin < $PAYLOAD_PATH)"
            UUID="$(jsonparse uuid < $PAYLOAD_PATH)"
            if [ -n "$PIN" ]; then
                ulog ${SERVICE_NAME} STATUS "Automatically onboarding unconfigured node $UUID"
                DBG evconslog "$SERVICE_NAME $EVENT_NAME: Automatically onboarding unconfigured node $UUID"
                DBG conslog "$PROG_NAME: Invoking 'porter -d -a -P $PIN -W'..."
                porter -d -a -P "$PIN" -W
                sysevent set smart_connect::setup_device $UUID
                DBG conslog "$PROG_NAME: Porter invoked, doubling down on CONFIG-SELF message..."
                sleep 4
                pub_configure_self $UUID
                DBG conslog "$PROG_NAME: CONFIG-SELF re-sent."
            else
                DBG evconslog "$SERVICE_NAME ERROR: Could not determine PIN for wired node auto-onboard $UUID"
                ulog ${SERVICE_NAME} ERROR "Could not determine PIN for wired node auto-onboard"
            fi
        else
            if [ -f "$PAYLOAD_PATH" ]; then
                UUID="$(jsonparse uuid <$PAYLOAD_PATH)"
                PIN="$(jsonparse data.pin <$PAYLOAD_PATH)"
                evconslog "configure-me: $UUID $PIN"
                if [ -n "$UUID" -a -n "$PIN" ]; then
                    sysevent set CONFIG-ME_${PIN} $UUID
                fi
            else
                evconslog "$PROG_NAME error: $PAYLOAD_PATH does not exist"
            fi
            cat <<EOF
EOF
            > /dev/console
        fi
        ;;
    smart_connect::configure_wired_setup-start)
        ulog ${SERVICE_NAME} STATUS "smart_connect::configure_wired_setup-start"
        porter -d -c -W
        ;;
    fwup_master_request)
        update_slave $EVENT_NAME &
        ;;
    fwup_slave_status)
        update_nodes $EVENT_NAME &
        ;;
    setup::send-presetup-start) presetup_xtrol "true"  $EVENT_VALUE ;;
    setup::send-presetup-stop)  presetup_xtrol "false" $EVENT_VALUE ;;
    subscriber::connected)
        if [ "$EVENT_VALUE" == "1" ]; then
            if  [ "$MODE" = "$SLAVE_MODE" ];then
                if [ "$(sysevent get $SUBS_REP_STATE)" = "$SUBS_REP_STATE_RUNNING" ]; then
                    PID="`sysevent get subscriber::sub_process`"
		    echo "${SERVICE_NAME} subscriber::connected another process running, kill ${PID}" > /dev/console
		    [ -n "$PID" ] && kill $PID
                fi
                sysevent set $SUBS_REP_STATE $SUBS_REP_STATE_RUNNING
                DBG evconslog "Publishing DEVINFO, WLAN and BH status to Master"
                SC_SETUP_STATUS="$(sysevent get smart_connect::setup_status)"
                SC_SETUP_MODE="$(sysevent get smart_connect::setup_mode)"
                (
                    sleep 2;
                    sysevent set node-off-restart;
                    sleep 1;
                    pub_devinfo_status;
                    sleep 1;
                    pub_wlan_status;
                    sleep 1;
                    pub_bh_status;
                    sleep 1;
                    pub_parent_ip "`sysevent get backhaul::intf`"
                    sleep 1;
                    pub_mesh_usb_partitions;
                    sleep 1;
                    sysevent set $SUBS_REP_STATE $SUBS_REP_STATE_DONE
                    sysevent set subscriber::sub_process
                    if [ "$SC_SETUP_STATUS" = "DONE" -a "$SC_SETUP_MODE" = "wired" ]; then
                        pub_configure_me_done
                    fi
                    sleep 1
                    pub_eth_subdev_info "$(sysevent get ETH::link_status_changed)"
                ) > /dev/console &
                sysevent set subscriber::sub_process "$!"
                PHY_INTF="`sysevent get backhaul::intf`"
                if [ "$PHY_INTF" = "ath9" ] || [ "$PHY_INTF" = "ath11" ];then
                    AP_BSSID=`sysevent get backhaul::preferred_bssid`
                    RSSI=`iwlist "$PHY_INTF" ap 2>/dev/null | grep "$AP_BSSID" -i | sed 's/Signal level=/&\n/' |  awk 'NR==2 {print $1}' `
                    ABSOLUTE_RSSI=`echo $RSSI | sed 's/-//'`
                    echo "$ABSOLUTE_RSSI" | egrep "[0-9]+" > /dev/null
                    if [ $? -eq 0 ];then
                        DBG evconslog "detected rssi: $RSSI"
                        sysevent set backhaul::rssi "$ABSOLUTE_RSSI"
                    else
                        DBG evconslog "failed to detect rssi: $RSSI"
                        sysevent set backhaul::rssi
                    fi
                fi
            elif  [ "$MODE" = "$MASTER_MODE" ];then
                DBG evconslog "Publishing DEVINO & WLAN status to Master"
                sysevent set node-off-start
                sleep 1
                pub_wlan_status
                sleep 1
                pub_devinfo_status
                sleep 1
                pub_slaves_resend_bh_status
            fi
        else
            DBG evconslog "Ignoring"
        fi
        ;;
    wifi-status)
        if [ "`sysevent get wifi-status`" = "started" ]; then
            pub_devinfo_status;
            sleep 1;
            pub_wlan_status;
        fi
        ;;
    $AC_STATUS_EV_NAME)
        if [ "$MODE" = "$SLAVE_MODE" ];then
            if [ "$EVENT_VALUE" = "running" ];then
                DBG evconslog "Setting $AC_QUIET_EV_NAME=1"
                sysevent set $AC_QUIET_EV_NAME 1
            else
                DBG evconslog "(ignoring)"
            fi
        fi
        ;;
    $AC_DONE_EV_NAME)
        if [ "$MODE" = "$SLAVE_MODE" ];then
            DBG evconslog "Setting $AC_QUIET_EV_NAME=0"
            sysevent set $AC_QUIET_EV_NAME 0
            DBG evconslog "${AC_SRV} done: publishing WLAN status to Master"
            (
                pub_wlan_status;
                sleep 1;
                pub_bh_status
            ) > /dev/console &
        fi
        ;;
    link_status_changed)
        if [ "$MODE" = "$SLAVE_MODE" ];then
            INTF_TYPE="$(echo "$EVENT_VALUE" | cut -f4 -d,)"
            DBG evconslog "$PROG_NAME INTF_TYPE: $INTF_TYPE"
            if [ "$INTF_TYPE" = "Ethernet" ]; then
                DBG conslog "Publishing to Master"
                pub_link_status_changed $EVENT_VALUE
            fi
        fi
        ;;
    lldp::root_address)
        if [ "$MODE" = "$UNCONFIGURED_MODE" -o "$MODE" = "$SLAVE_MODE" ] &&
           [ -n "$EVENT_VALUE" -a "$EVENT_VALUE" != "NULL" ]; then
            if [ "$EVENT_VALUE" != "`sysevent get $MASTERIP_EV_NAME`" ]; then
                sysevent set $MASTERIP_EV_NAME $EVENT_VALUE
            else
                evconslog "Ignoring unchanged omsg serverip ($EVENT_VALUE)"
            fi
        fi
        ;;
    lldp::device-delete)
        rm $PAYLOAD_PATH
        STAT_FILE="$(echo $PAYLOAD_PATH | sed "s/.delete$//")"
        [ -f "$STAT_FILE" ] && rm "$STAT_FILE"
        ;;
    plc::link_status_changed)
        SYS_GET_ST="`sysevent get plc::link_status_changed`"
        DBG evconslog "plc::link_status_changed: $SYS_GET_ST"
        if [ "$SYS_GET_ST" ] ; then
            pub_plc_link_status_changed "$SYS_GET_ST"
        fi
        ;;
    ETH::link_status_changed)
        ulog ${SERVICE_NAME} "$0 $1 $2"
        pub_eth_link_status_changed $EVENT_VALUE
        pub_eth_subdev_info "$EVENT_VALUE"
        ;;
    WIFI::link_status_changed)
        if [ "$MODE" = "$SLAVE_MODE" ];then
            DBG evconslog
            pub_wifi_link_status_changed $EVENT_VALUE
        fi
        ;;
    slave_link_status_changed|slave_eth_link_status_changed|slave_wifi_link_status_changed)
        if [ "$MODE" = "$MASTER_MODE" ];then
            evconslog "Detected Slave link change"
            ulog ${SERVICE_NAME} STATUS "$0 $1 $2 Detected Slave link change"
        fi
        ;;
    slave_offline)
        DBG evconslog "Marking slave offline"
        ddb_omsg_import -d -v --action=offline $PAYLOAD_PATH
        update_nodes $EVENT_NAME
        NODE_UUID="$(jsonparse uuid <$PAYLOAD_PATH)"
        BH_PATH=`omsg-conf -m -a path BH | sed "s/%2/$NODE_UUID/"`
        BH_PATH="$MSG_CACHE_DIR/$BH_PATH"
        rm $BH_PATH  $BH_PATH.* >& /dev/null
        MESH_USB_PATH=`omsg-conf -m -a path MESH_USB_PARTITIONS | sed "s/%2/$NODE_UUID/"`
        MESH_USB_PATH="$MSG_CACHE_DIR/$MESH_USB_PATH"
        rm $MESH_USB_PATH  $MESH_USB_PATH.* >& /dev/null
        ;;
    devinfo)
        if  [ "$MODE" = "$MASTER_MODE" ];then
            if [ -f "$PAYLOAD_PATH" ]; then
                update_device_db "$PAYLOAD_PATH"
            fi
            sleep 5
            ICC_STATE="$(sysevent get icc_internet_state)"
            if [ -n "$ICC_STATE" ]; then
                (
                    pub_sysevent_value icc_internet_state "$ICC_STATE"
                ) > /dev/console &
            else
                (
                    pub_sysevent_value icc_internet_state "down"
                ) > /dev/console &
            fi
        fi
        ;;
    wlan::refresh-subdev)
        pub_wlan_subdev
        ;;
    wlan::user-req-refresh-subdev)
        TOPIC="$(omsg-conf WLAN_subdev_refresh | sed "s/+/all/")"
        date | pub_generic $TOPIC
        ;;
    WPS::pin-start|WPS::pin-cancel|icc_internet_state)
        if  [ "$MODE" = "$MASTER_MODE" ];then
            pub_sysevent "$EVENT_NAME" "$EVENT_VALUE"
        fi
        ;;
    wps_process)
        if [ "$EVENT_VALUE" = "completed" ]; then
            FROM_REMOTE="$(sysevent get wps_process_from_remote)"
            if [ -z "$FROM_REMOTE" ]; then
                pub_sysevent "$EVENT_NAME" "$EVENT_VALUE"
            else
                sysevent set wps_process_from_remote
            fi
        fi
        ;;
    wps_process_remote)
        if [ "$(sysevent get wps_process)" != "$EVENT_VALUE" ]; then
            sysevent set wps_process_from_remote 1
            evconslog "Triggering local wps_process = $EVENT_VALUE"
            sysevent set wps_process "$EVENT_VALUE"
        fi
        ;;
    WPS::success)
        cat <<EOF
EOF
        > /dev/console
        ;;
    soft_sku_changing)
        if [ -n "$EVENT_VALUE" ]; then
            MODEL_NUM="$(syscfg get device::modelNumber)"
            ulog ${SERVICE_NAME} STATUS "Event $EVENT_NAME='$EVENT_VALUE', modelNumber='$MODEL_NUM'"
            DBG evconslog "device::modelNumber currently '$MODEL_NUM'"
            if [ "$MODE" = "$MASTER_MODE" ]; then
                DBG conslog "Distributing event $EVENT_NAME to other Nodes"
                TOPIC="$(omsg-conf -s SOFT_SKU_CHANGING)"
                if [ $TOPIC ]; then
                    echo "$EVENT_VALUE" | pub_generic $TOPIC
                else
                    ulog ${SERVICE_NAME} ERROR "Could not determine message topic for event '$EVENT_NAME'"
                    conslog "Error: Could not determine message topic for event '$EVENT_NAME'"
                fi
            fi
        else
            ulog ${SERVICE_NAME} STATUS "Ignoring event '$EVENT_NAME'; there is no value"
            conslog "Ignoring '$EVENT_NAME' without value"
        fi
        ;;
    soft_sku_changed)
        MODEL_NUM="$(syscfg get device::modelNumber)"
        ulog ${SERVICE_NAME} STATUS "Event $EVENT_NAME='$EVENT_VALUE', modelNumber='$MODEL_NUM'"
        DBG evconslog "device::modelNumber now '$MODEL_NUM'"
        ;;
    system-status)
        if [ "$MODE" = "$SLAVE_MODE" -a "$EVENT_VALUE" = "stopping" ]; then
            evconslog "Informing Master we are shutting down"
            pub_shutting_down
        fi
        ;;
    slave_shutdown)
        if [ "$MODE" = "$MASTER_MODE" ];then
            evconslog "A slave has shut down gracefully"
            ddb_omsg_import -d -v --action=offline $PAYLOAD_PATH
        fi
        ;;
    router_status)
        if [ "$MODE" = "$MASTER_MODE" ]; then
            if [ "$EVENT_VALUE" = "REBOOT" ]; then
                reset_slave_nodes -A 
            fi
        fi
        ;;
    smart_connect::setup_ip_changed)    
        if [ "$MODE" = "$MASTER_MODE" ]; then
            DBG conslog "Distributing event $EVENT_NAME to other Nodes"
            TOPIC="$(omsg-conf -s SETUP_IP_CHANGED)"
            if [ $TOPIC ]; then
                echo "$EVENT_VALUE" | pub_generic $TOPIC
            else
                ulog ${SERVICE_NAME} ERROR "Could not determine message topic for event '$EVENT_NAME'"
                conslog "Error: Could not determine message topic for event '$EVENT_NAME'"
            fi        
        elif [ "$MODE" = "$SLAVE_MODE" ]; then
            sysevent set setup_dhcp_client-restart
        fi
        ;;
    wlan::status)
        if [ "$MODE" = "$MASTER_MODE" ]; then
            pub_refresh_serving_channels
        fi
        ;;
    wlan::refresh_serving_channels)
        pub_serving_channels
        ;;
    *)
        conslog "error : $ACTION unknown"
        conslog "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]"
        exit 3
        ;;
esac
