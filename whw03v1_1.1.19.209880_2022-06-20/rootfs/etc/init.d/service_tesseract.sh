#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_steer_util.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_misc_functions.sh
source /etc/init.d/tesseract_common.sh
MASTERIP_EV_NAME="master::ip"
ENAB_SYSCFG_NAME="${SERVICE_NAME}::enabled"
AVOID_DFS_SYSCFG_NAME="${SERVICE_NAME}::avoid_dfs"
CLIENT_STEER_REPORT_EVNAME="$(omsg-conf -s --attribute=event TESSERACT_CLIENT_STEER_FSM_REPORT)"
implied_dfs_enabled () {
    local RC=1
    local REGION
    if [ "$(syscfg_get wifi::multiregion_support)" = "1" -a \
         "$(syscfg_get wifi::multiregion_enable)"  = "1" -a \
         "$(get_multiregion_region_validation)"    = "1" ]; then
        REGION="$(syscfg get wifi::multiregion_region)"
    else
        REGION="$(syscfg_get device::cert_region)"
    fi
    case "$REGION" in
        EU | JP | ME)  RC=0 ;;
        *)             RC=1 ;;
    esac
    return $RC
}
dfs_enabled () {
    local WL_LIST=$(syscfg get configurable_wl_ifs)
    for WL_INTF in $WL_LIST;do
        if [ "$(syscfg get ${WL_INTF}_dfs_enabled)" = "1" ]; then
            return 0
        fi
    done
    implied_dfs_enabled
}
service_enabled () {
    [ "$(syscfg get $ENAB_SYSCFG_NAME)" = "1" ]; return $?
}
balance_enabled () {
    [ "$(syscfg get $BALANCE_ENABLED_SYSCFG_VAR)" = "1" ]; return $?
}
node_steering_enabled () {
    return 1
}
client_steering_enabled () {
    return 1
}
conditions_favorable () {
    [ "$(syscfg get $AVOID_DFS_SYSCFG_NAME)" != "1" ] || ! dfs_enabled; return $?
}
operations_permitted () {
    service_enabled && conditions_favorable; return $?
}
dfc_enabled="1"
dfc_avoid_dfs="1"
let "dfc_${TESSERACT_BAL_DELAY}=4"
let "dfc_${CLIENT_STEER_RCPI_MIN_DELTA}=20"
let "dfc_${CLIENT_STEER_CONNECT_TIMEOUT}=60"
let "dfc_${CLIENT_STEER_TEMP_BLACKLIST_TIMEOUT}=60"
let "dfc_${CLIENT_STEER_ENABLED}=0"
let "dfc_${NODE_STEER_ENABLED}=0"
eval "dfc_${STEERING_DECISION_ENG}=tess_steer_local_decision_eng"
let "dfc_${CLIENT_STEER_SAVE_OLD_SURVEYS}=1"
let "dfc_${BALANCE_ENABLED}=1"
let "dfc_${CLIENT_STEER_SURVEY_DELAY}=120"
let "dfc_${CLIENT_STEER_SURVEY_INTERVAL}=600"
let "dfc_${CLIENT_TEMP_BLACKLIST_TIMEOUT}=60"
let "dfc_${CLIENT_STEER_NODE_CONNECT_DELAY}=300"
let "dfc_${CLIENT_STEER_RCPI_MIN_THRESHOLD}=100"
let "dfc_${NODE_STEER_RCPI_MASTER_THRESHOLD}=100"
let "dfc_${NODE_STEER_MIN_COOLDOWN}=11"
MODE=$(syscfg get smart_mode::mode)
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1
init_dirs () {
    for DIR in $TESS_CS_WAIT_TO_SURVEY $TESS_CS_SURVEYS  \
               $TESS_CS_PENDING_STEERS $TESS_CS_PENDING_BLACKLISTS \
               $TESS_CS_PENDING_NODE_CONNECTS \
               $TESS_CS_LOCAL_INSTALLED_BLACKLISTS \
               $TESS_CS_RECENTLY_STEERED_NODES \
               $TESS_BAL_RECENTLY_BALANCED_NODES; do
        if [ ! -d "${DIR}" ]; then
            DBG conslog "Creating directory ${DIR}"
            mkdir -p ${DIR}
        fi
    done
}
get_radio_cnt()
{
    return $(syscfg get lan_wl_physical_ifnames | wc -w)
}
set_defaults()
{
    conslog "Setting defaults"
    init_dirs
    for i in avoid_dfs enabled ${TESSERACT_BAL_DELAY} ${CLIENT_STEER_RCPI_MIN_DELTA} \
             ${CLIENT_STEER_CONNECT_TIMEOUT} ${CLIENT_STEER_TEMP_BLACKLIST_TIMEOUT}  \
             ${STEERING_DECISION_ENG}    ${CLIENT_STEER_RCPI_MIN_THRESHOLD}      \
             ${CLIENT_STEER_ENABLED} ${CLIENT_STEER_SURVEY_DELAY} \
             ${NODE_STEER_ENABLED} ${NODE_STEER_MIN_COOLDOWN} \
             ${CLIENT_STEER_SURVEY_INTERVAL} ${CLIENT_STEER_SAVE_OLD_SURVEYS} \
             ${CLIENT_STEER_NODE_CONNECT_DELAY} ${NODE_STEER_RCPI_MASTER_THRESHOLD}; do
        local DEF_VAL="$(eval echo "\$dfc_${i}")"
        if [ $DEF_VAL ] && [ -z "$(syscfg get ${NAMESPACE}::$i)" ] ; then
            DBG conslog "$0 $1 Setting default for $i to $DEF_VAL"
            syscfg set ${NAMESPACE}::$i $DEF_VAL
        else
            DBG conslog "${NAMESPACE}::$i already set to $(syscfg get ${NAMESPACE}::$i)"
        fi
    done
    if [ -z "$(syscfg get ${NAMESPACE}::${BALANCE_ENABLED})" ]; then
        get_radio_cnt
        radio_cnt="$?"
        case "$radio_cnt" in
            "3")
                DBG console "${NAMESPACE}::${BALANCE_ENABLED} is set to default"
                syscfg set ${NAMESPACE}::${BALANCE_ENABLED} "$(eval echo "\$dfc_${BALANCE_ENABLED}")"
                ;;
            "2")
                DBG console "${NAMESPACE}::${BALANCE_ENABLED} is disabled for dual-band products"
                ;;
            *)
                DBG console "radio count:$radio_cnt, ${NAMESPACE}::${BALANCE_ENABLED} is set to default"
                syscfg set ${NAMESPACE}::${BALANCE_ENABLED} "$(eval echo "\$dfc_${BALANCE_ENABLED}")"
                ;;
        esac
    else
        DBG conslog "${NAMESPACE}::${BALANCE_ENABLED} already set to $(syscfg get ${NAMESPACE}::${BALANCE_ENABLED})"
    fi
}
service_init()
{
    [ "$(syscfg get "${NAMESPACE}::debug")" == "1" ] && DEBUG=1
    if [ "$(sysevent get ${NAMESPACE}::inited)" != "1" ] ; then
        set_defaults
        sysevent set ${NAMESPACE}::inited 1
    fi
    if service_enabled ; then
        DBG conslog "$SERVICE_NAME running $1"
    else
        DBG conslog "$SERVICE_NAME disabled in syscfg"
        exit 1
    fi
}
TESS_STEER_CMD=tess_steer
CRON_JOB_BIN="/usr/sbin"
CHECK_TOPO_CRON_JOB_FILE="check-topology.cron"
TESS_STEER_CRON_JOB_FILE="device-steer-fsm.cron"
TESS_STEER_CRON_JOB_FILE_SRC=${TESS_STEER_CMD}
CRON_JOB_DEST="/tmp/cron/cron.everyminute"
mg_cronjob () {
    local OP="$1"
    local CRON_JOB_FILE="$2"
    local DEST_FILE=${3:-$CRON_JOB_FILE}
    case "$OP" in
        install)
            if [ ! -f "${CRON_JOB_DEST}/${DEST_FILE}" ]; then
                DBG conslog "$SERVICE_NAME installing ${CRON_JOB_FILE} to ${CRON_JOB_DEST}/${DEST_FILE}"
                ln -s ${CRON_JOB_BIN}/${CRON_JOB_FILE} ${CRON_JOB_DEST}/${DEST_FILE}
            fi
        ;;
        remove)
            if [ -f "${CRON_JOB_DEST}/${DEST_FILE}" ]; then
                DBG conslog "$SERVICE_NAME removing ${DEST_FILE} from ${CRON_JOB_DEST}/"
                rm -f ${CRON_JOB_DEST}/${DEST_FILE}
            fi
        ;;
        *)
            ulog ${SERVICE_NAME} error "Unknown operation '$OP' to mg_cronjob"
            conslog "Error: Unknown operation '$OP' to mg_cronjob"
            ;;
    esac
}
maybe_mg_cronjob () {
    local OP="$1"
    local CRON_JOB_FILE="$2"
    local SYSCFG_VARNAME="${NAMESPACE}::$3"
    local ENABLED="$(syscfg get ${SYSCFG_VARNAME})"
    local DEST="$4"
    if [ "$OP" = "remove" ] || [ "$ENABLED" = "1" ]; then
        mg_cronjob $OP "$CRON_JOB_FILE" "$DEST"
    else
        DBG conslog "Not performing '$OP' on '$CRON_JOB_FILE': $SYSCFG_VARNAME ='$ENABLED'"
    fi
}
install_cronjobs() {
    maybe_mg_cronjob install $TESS_STEER_CRON_JOB_FILE_SRC $CLIENT_STEER_ENABLED $TESS_STEER_CRON_JOB_FILE
    maybe_mg_cronjob install $TESS_STEER_CRON_JOB_FILE_SRC $NODE_STEER_ENABLED $TESS_STEER_CRON_JOB_FILE
    if [ "$MODE" = "$MASTER_MODE" ] && conditions_favorable; then
        maybe_mg_cronjob install $CHECK_TOPO_CRON_JOB_FILE $BALANCE_ENABLED
    fi
    if [ "$(syscfg get $CLIENT_STEER_ENABLED_SYSCFG_VAR)" = "1" -o "$(syscfg get $NODE_STEER_ENABLED_SYSCFG_VAR)" = "1" ]; then
        make_scan_table_update_cron_job
    fi
}
remove_cronjobs() {
    maybe_mg_cronjob remove $TESS_STEER_CRON_JOB_FILE_SRC $CLIENT_STEER_ENABLED $TESS_STEER_CRON_JOB_FILE
    maybe_mg_cronjob remove $CHECK_TOPO_CRON_JOB_FILE $BALANCE_ENABLED
    remove_scan_table_update_cron_job
}
SCAN_TABLE_UPDATE_CRON_FILE="/tmp/cron/cron.hourly/scan_table_update.sh"
make_scan_table_update_cron_job()
{
    if [ -e "$SCAN_TABLE_UPDATE_CRON_FILE" ]; then
        return 1
    fi
    echo -n > $SCAN_TABLE_UPDATE_CRON_FILE
    cat << EOF >> $SCAN_TABLE_UPDATE_CRON_FILE
#!/bin/sh
sysevent set scan_table_update
EOF
    chmod u+x $SCAN_TABLE_UPDATE_CRON_FILE
    return 0
}
remove_scan_table_update_cron_job()
{
    if [ ! -e "$SCAN_TABLE_UPDATE_CRON_FILE" ]; then
        return 1
    fi
    rm -rf $SCAN_TABLE_UPDATE_CRON_FILE
    return 0
}
nodes_steering_start_handler() {
    local PAYLOAD_PATH="$1"
    local client="$(jsonparse -f $PAYLOAD_PATH data.client_bssid)"
    local target_bssid="$(jsonparse -f $PAYLOAD_PATH data.ap_bssid)"
    local target_channel="$(jsonparse -f $PAYLOAD_PATH data.ap_channel)"
    if [ -z "$client" -o -z "$target_bssid" -o -z "$target_channel" ]; then
        DBG conslog "invalid param client($client), target_bssid($target_bssid), target_channel($target_channel), exit"
        exit 1
    fi
    DBG conslog "client steering starts"
    DBG conslog "client=$client, target_bssid=$target_bssid, target_channel=$target_channel"
    local serving_ap=""
    is_client_associated_unit "$client"
    [ "$?" = "1" ] && flag="" || flag=" not"
    DBG conslog "client $client has$flag been associated to this unit $serving_ap"
    if [ -n "$serving_ap" ]; then
        if [ "$(ap_to_bssid $serving_ap)" = "$target_bssid" ]; then
            DBG conslog "$client has already been associated to $target_bssid, no need to steer, exit"
            exit 1
        fi
        steer_11v "$serving_ap" "$client" "$target_bssid" "$target_channel"
        st_ret="$?"
        if [ "$st_ret" = "0" ]; then
            DBG conslog "11v cmd fired successfully"
        else
            DBG conslog "11v cmd fired with error $st_ret"
            exit 1
        fi
    else
        ap_intf_name=$(bssid_to_ap "$target_bssid")
        local flag
        if [ -n "$ap_intf_name" ];then
            flag=""
            cp "$PAYLOAD_PATH" "${TESS_CS_PENDING_STEERS}/${client}"
        else
            flag=" not"
        fi
        DBG conslog "this is$flag the target unit"
    fi
}
nodes_temporary_blacklist_handler()
{
    local PAYLOAD_PATH="$1"
    local client="$(jsonparse -f $PAYLOAD_PATH data.client)"
    local duration="$(jsonparse -f $PAYLOAD_PATH data.duration)"
    local action="$(jsonparse -f $PAYLOAD_PATH data.action)"
    local excluded_units="$(jsonparse -f $PAYLOAD_PATH data.exclude)"
    dbg_log "client steering temporary blacklist event received"
    dbg_log "client($client), duration($duration), action($action), exclude_units($excluded_units)"
    if [ -z "$client" -o -z "$duration" -o -z "$action" ]; then
        dbg_log "invalid param, client($client), duration($duration), action($action), exit"
        exit 1
    fi
    unit_uuid="$(syscfg get device::uuid)"
    excluded_unit=$(echo "$excluded_units" | grep $unit_uuid > /dev/null; [ "$?" = "0" ] && echo "1" || echo "0")
    [ "$excluded_unit" = "1" ] && flag="" || flag=" not"
    [ "$action" = "start" ] && dbg_log "this is$flag a excluded unit"
    serving_ap=""
    is_client_associated_unit "$client"
    [ "$?" = "1" ] && flag="" || flag=" not"
    dbg_log "client $client has$flag been associated to this unit $serving_ap"
    if [ "$excluded_unit" = "1" ]; then
        case "$action" in
            "start")
                if [ -n "$serving_ap" ]; then
                    dbg_log "client $client has already been associated to a excluded unit, no need to blacklist it"
                    dbg_log "broadcast msg to cancel the blacklist of $client"
                    pub_nodes_temporary_blacklist $client $duration "cancel"
                else
                    DBG conslog "Mark temporary blacklist ($PAYLOAD_PATH --> ${TESS_CS_PENDING_BLACKLISTS}/${client}"
                    cp "$PAYLOAD_PATH" "${TESS_CS_PENDING_BLACKLISTS}/${client}"
                fi
                ;;
            "cancel")
                ;;
            *)
                dbg_log "invalid blacklist action:$action, exit"
                exit 1
                ;;
        esac
        exit 0
    else
        case "$action" in
            "start")
                add_client_into_blacklist_unit $client
                cp "$PAYLOAD_PATH" "${TESS_CS_LOCAL_INSTALLED_BLACKLISTS}/${client}"
                if [ -n "$serving_ap" ]; then
                    force_disassociate_client "$serving_ap" "$client"
                fi
                ;;
            "cancel")
                remove_client_from_blacklist_unit $client
                ;;
            *)
                dbg_log "invalid blacklist action:$action, exit"
                exit 1
                ;;
        esac
        exit 0
    fi
}
service_start ()
{
    if [ "$(sysevent get ${SERVICE_NAME}-status)" != started ]; then
        sysevent set ${SERVICE_NAME}-status starting
        install_cronjobs
        check_err $? "Couldn't handle start"
        sysevent set ${SERVICE_NAME}-status started
        ulog ${SERVICE_NAME} status "now started"
    else
        evconslog "Ignoring, status already = 'started'"
    fi
}
service_stop ()
{
    ulog ${SERVICE_NAME} STATUS "STOP requested"
    sysevent set ${SERVICE_NAME}-status stopping
    remove_cronjobs
    sysevent set ${SERVICE_NAME}-status stopped
}
service_restart() {
    service_stop
    service_start
}
service_init
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
    wifi-status)
        if [ "$MODE" = "1" -o "$MODE" = "2" ]; then
            (
            sleep 1
            node_steering_enabled && pub_nb_rssi
            ) > /dev/console &
        fi
        ;;
    report_nb_rssi)
        if [ "$MODE" = "1" ]; then
            node_steering_enabled && pub_nb_rssi &
        fi
        ;;
    subscriber::connected)
        if [ "$EVENT_VALUE" = "1" ]; then
            conslog "Starting service ${SERVICE_NAME}: $EVENT_NAME $EVENT_VALUE"
            service_start
        else
            conslog "Stopping service ${SERVICE_NAME}: $EVENT_NAME $EVENT_VALUE"
            service_stop
        fi
        ;;
    devinfo|slave_offline)
        if balance_enabled && operations_permitted && [ "$MODE" = "$MASTER_MODE" ]; then
            DBG conslog "Touching $TESSERACT_BAL_CHECK_FLAG"
            touch $TESSERACT_BAL_CHECK_FLAG
        fi
        if client_steering_enabled; then
            DBG conslog "Installing '$PAYLOAD_PATH' to '$TESS_CS_PENDING_NODE_CONNECTS'"
            mkdir -p $TESS_CS_PENDING_NODE_CONNECTS
            DBG conslog "cp -p \"$PAYLOAD_PATH\" \"$TESS_CS_PENDING_NODE_CONNECTS/\""
            cp -p "$PAYLOAD_PATH" "$TESS_CS_PENDING_NODE_CONNECTS/"
            if node_steering_enabled; then
                TOPIC="$(omsg-conf -s REPORT-NEIGHBORS)"
                if [ -n "$TOPIC" ]; then
                    DBG conslog "Publishing to '$TOPIC'"
                    date | pub_generic "$TOPIC"
                else
                    DBG conslog "Couldn't determine omsg topic for REPORT-NEIGHBORS"
                fi
            else
                DBG conslog "Skip requesting neighbor reports; node-steering disabled"
            fi
        else
            DBG conslog "Skip flagging node-connect; client-steering disabled"
        fi
        ;;
    wifi_client_site_survey)
        DBG evconslog "Importing client survey $EVENT_VALUE"
        import_client_survey -f $EVENT_VALUE -r -d
        ;;
    wlan::send-client-survey)
        CLIENT="$(echo $EVENT_VALUE | jsonparse data.client_bssid)"
        if [ -n "$CLIENT" ]; then
            if is_client_associated_unit "$CLIENT"; then
                DBG conslog "Ignoring event: client not associated to this AP"
            else
                conslog "Requesting neighbor report for client '$CLIENT':"
                ( pub_client_survey -c "$CLIENT" &&
                  conslog "Client '$CLIENT' neighbor report sent" ) &
            fi
        else
            conslog "Error: survey data lacked client_bssid field"
        fi
        ;;
    wlan::client-survey)
        if [ "$MODE" = "$MASTER_MODE" ]; then
            BSSID="$(jsonparse data.client_bssid < $PAYLOAD_PATH)"
            if [ -n "$BSSID" ];then
                FSM_DESTPATH=${TESS_CS_SURVEYS}/${BSSID}
                DBG evconslog "Client '$BSSID'"
                mkdir -p ${TESS_CS_SURVEYS}
                cp -p "$PAYLOAD_PATH" "${FSM_DESTPATH}"
            else
                conslog "Error: Missing client_bssid from survey data"
            fi
        fi
        ;;
    wlan::node-survey)
        if [ "$MODE" = "$MASTER_MODE" ]; then
            if node_steering_enabled; then
                UUID="$(jsonparse uuid < $PAYLOAD_PATH)"
                if [ -n "$UUID" ];then
                    FSM_DESTPATH=${TESS_CS_SURVEYS}/${UUID}.node
                    DBG evconslog "Node '$UUID' reports neighbors ==> '${FSM_DESTPATH}"
                    mkdir -p ${TESS_CS_SURVEYS}
                    if [ "$UUID" != "$(syscfg get device::uuid)" ]; then
                        nb2client_survey -p < "$PAYLOAD_PATH" > "${FSM_DESTPATH}"
                    else
                        DBG evconslog "Not submitting survey for steering; '$UUID' is Master"
                    fi
                else
                    conslog "Error: Missing UUID from Node neighbor report"
                fi
            else
                DBG conslog "Skip requesting neighbor reports; node-steering disabled"
            fi
        fi
        ;;
    mqttsub::wlansubdev)
        if client_steering_enabled; then
            BSSID="$(jsonparse data.sta_bssid < $PAYLOAD_PATH)"
            if [ -n "$BSSID" ];then
                STATUS="$(jsonparse data.status < $PAYLOAD_PATH)"
                if [ -n "$STATUS" ]; then
                    mkdir -p ${TESS_CS_WAIT_TO_SURVEY}
                    FSM_DESTPATH=${TESS_CS_WAIT_TO_SURVEY}/${BSSID}
                    SURVEY_PATH=${TESS_CS_SURVEYS}/${BSSID}
                    if [ "$STATUS" = "connected" ]; then
                        DBG evconslog "Client '$BSSID' is UP, resetting some pending FSM states"
                        TODIE="$(find ${TESS_CS_SURVEYS} ${TESS_CS_PENDING_STEERS} -iname ${BSSID} | grep -v '.OLD')"
                        if [ -n "$TODIE" ]; then
                            DBG conslog "Purging obsolete client-steering state files $TODIE"
                            rm $TODIE
                        fi
                        if [ "$MODE" = "$MASTER_MODE" ]; then
                            DBG evconslog "Client '$BSSID' is UP, storing to ${FSM_DESTPATH}"
                            if ! cp -p "$PAYLOAD_PATH" "${FSM_DESTPATH}"; then
                                DBG evconslog "ERROR: FAILED to copy payload to ${FSM_DESTPATH}"
                            fi
                        fi
                    else
                        DBG evconslog "Client '$BSSID' is down, removing '${FSM_DESTPATH}'"
                        rm -f "${FSM_DESTPATH}"
                    fi
                else
                    conslog "Error: Missing 'status' field from WLAN sub-device status"
                fi
            else
                conslog "Error: Missing sta_bssid from WLAN subdevice data"
            fi
        fi
        ;;
    wlan::nodes_steering_start)
        nodes_steering_start_handler "$PAYLOAD_PATH"
        ;;
    wlan::nodes_temporary_blacklist)
        nodes_temporary_blacklist_handler "$PAYLOAD_PATH"
        ;;
    $CLIENT_STEER_REPORT_EVNAME)
        if [ "$MODE" = "$SLAVE_MODE" ]; then
            DBG conslog "Sending client-steering FSM report to Master"
            TOPIC="$(omsg-conf -s TESSERACT_CLIENT_STEER_FSM_REPORT)"
            ( source /etc/init.d/sub_pub_funcs.sh
              ${TESS_STEER_CMD} -q | publish $TOPIC.response
            )
        fi
        ;;
    wlan::reconsider-backhaul)
        DBG conslog "Firing event backhaul::set_intf"
        ;;
    wlan::report-neighbors)
        DBG conslog "Forcing scan-table update + neighbor report"
        rm -f /tmp/last_scan_table_update
        sysevent set scan_table_update
        ( sleep 20 && pub_nb_rssi & )
        ;;
    *)
        conslog "error : $ACTION unknown"
        conslog "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | " \
                "${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart ]"
        exit 3
        ;;
esac
