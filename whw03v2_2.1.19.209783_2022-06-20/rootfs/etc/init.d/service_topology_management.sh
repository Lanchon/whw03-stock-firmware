#!/bin/sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_steer_util.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/topology_management_misc.sh
source /etc/init.d/topology_management_common.sh # Note: service-name & namespace acquired from topology_management_common.sh
CRON_JOB_DEST="/tmp/cron/cron.everyminute"
CRON_JOB_BIN="/usr/bin"
CRON_JOB_FSM="topomgmt-fsm"
let "dfc_${ENABLED}=0"
set_defaults()
{
    conslog "Setting defaults"
    for i in $ENABLED ; do
        DEF_VAL="$( eval echo "\$dfc_${i}" )"
        if [ -z "$( syscfg get ${NAMESPACE}::$i )" ] ; then
            evconslog "$0 $1 Setting default for $i"
            syscfg set ${NAMESPACE}::$i $DEF_VAL
        fi
    done
}
service_init()
{
    [ "$( syscfg get "${NAMESPACE}::debug" )" == "1" ] && DEBUG=1
    
    if [ "$( sysevent get ${NAMESPACE}::inited )" != "1" ] ; then
        set_defaults
        init_dirs
        install_cronjobs
        sysevent set ${NAMESPACE}::inited 1
    fi
    
    if ! service_enabled ; then
        DBG conslog "$SERVICE_NAME disabled in syscfg."
        exit 1
    fi
    
    
}
service_start ()
{
    if [ "$(sysevent get ${SERVICE_NAME}-status)" != started ]; then
        sysevent set ${SERVICE_NAME}-status starting
        check_err $? "Couldn't handle start"
        sysevent set ${SERVICE_NAME}-status started
        ulog ${SERVICE_NAME} status "now started"
    else
        evconslog "Ignoring, status already started."
    fi
}
service_stop ()
{
    ulog ${SERVICE_NAME} STATUS "STOP requested"
    sysevent set ${SERVICE_NAME}-status stopping
    sysevent set ${SERVICE_NAME}-status stopped
}
service_restart() {
    service_stop
    service_start
}
service_enabled()
{
    [ "$( syscfg get $ENABLED_SYSCFG_NAME )" = "1" ]; return $?
}
init_dirs()
{
    for DIR in $TOPOLOGY_MANAGEMENT_BLACKLIST_DIR; do
        if [ ! -d "${DIR}" ]; then
            DBG conslog "Creating directory ${DIR}"
            mkdir -p ${DIR}
        fi
    done
}
manage_cronjob()
{
    local OPERATION="$1"
    local CRON_JOB_FILE="$2"
    case "$OPERATION" in
        install)
            if [ ! -f "${CRON_JOB_DEST}/${CRON_JOB_FILE}" ]; then
                DBG conslog "$SERVICE_NAME installing ${CRON_JOB_FILE} to ${CRON_JOB_DEST}/${CRON_JOB_FILE}"
                ln -s ${CRON_JOB_BIN}/${CRON_JOB_FILE} ${CRON_JOB_DEST}/${CRON_JOB_FILE}
            fi
        ;;
        
        remove)
            if [ -f "${CRON_JOB_DEST}/${CRON_JOB_FILE}" ]; then
                DBG conslog "$SERVICE_NAME removing ${CRON_JOB_FILE} from ${CRON_JOB_DEST}/"
                rm -f ${CRON_JOB_DEST}/${CRON_JOB_FILE}
            fi
        ;;
        
        *)
            ulog ${SERVICE_NAME} error "Unknown operation '$OPERATION' to manage_cronjob"
            conslog "Error: Unknown operation '$OPERATION' to mg_cronjob"
        ;;
    esac
}
install_cronjobs()
{
    manage_cronjob install $CRON_JOB_FSM
}
temporary_blacklist_handler()
{
    local PAYLOAD_PATH="$1"
    local client="$( jsonparse -f $PAYLOAD_PATH data.client )"
    local duration="$( jsonparse -f $PAYLOAD_PATH data.duration )"
    local action="$( jsonparse -f $PAYLOAD_PATH data.action )"
    local excluded_units="$( jsonparse -f $PAYLOAD_PATH data.exclude )"
    
    DBG conslog "blacklist event recieved!"
    DBG conslog "client($client), duration($duration), action($action), exclude_units($excluded_units)"
    
    if [ -z "$client" -o -z "$duration" -o -z "$action" ]; then
        DBG conslog "invalid parameters: client($client), duration($duration), action($action), exit ( 1 )"
        exit 1
    fi
    
    unit_uuid="$(syscfg get device::uuid)"
    excluded_unit=$(echo "$excluded_units" | grep $unit_uuid > /dev/null; [ "$?" = "0" ] && echo "1" || echo "0")
    [ "$excluded_unit" = "1" ] && flag="" || flag=" not"
    [ "$action" = "start" ] && DBG conslog "this is$flag a excluded unit"
    serving_ap=""
    is_client_associated_unit "$client"
    [ "$?" = "1" ] && flag="" || flag=" not"
    DBG conslog "client $client has$flag been associated to this unit $serving_ap"
    
    if [ "$excluded_unit" = "1" ]; then
        case "$action" in
            "start")
                if [ -n "$serving_ap" ]; then
                    DBG conslog "client $client has already been associated to a excluded unit, no need to blacklist it"
                    topomgmt -m steerer -c publish_temporary_blacklist -p "{\"client\":\"$client\", \"duration\":\"$duration\", \"action\":\"cancel\"}" -d
                fi
                ;;
                
            "cancel")
                ;;
            *)
                DBG conslog "invalid blacklist action:$action, exit ( 1 )"
                exit 1
                ;;
        esac
        
        exit 0
    else
        case "$action" in
            "start")
                add_client_into_blacklist_unit $client
                cp "$PAYLOAD_PATH" "${TOPOLOGY_MANAGEMENT_BLACKLIST_DIR}/${client}"
                if [ -n "$serving_ap" ]; then
                    force_disassociate_client "$serving_ap" "$client"
                fi
                ;;
                
            "cancel")
                remove_client_from_blacklist_unit $client
                ;;
                
            *)
                dbg_log "invalid blacklist action:$action, exit ( 1 )"
                exit 1
                ;;
        esac
        
        exit 0
    fi
}
steer_11v_handler()
{
    local PAYLOAD_PATH="$1"
    local client="$( jsonparse -f $PAYLOAD_PATH data.client_bssid )"
    local target_bssid="$( jsonparse -f $PAYLOAD_PATH data.ap_bssid )"
    local target_channel="$( jsonparse -f $PAYLOAD_PATH data.ap_channel )"
    
    if [ -z "$client" -o -z "$target_bssid" -o -z "$target_channel" ]; then
        DBG conslog "invalid parameters client($client), target_bssid($target_bssid), target_channel($target_channel), exit ( 1 )"
        exit 1
    fi
    
    DBG conslog "steer_11v_handler start"
    DBG conslog "client=$client, target_bssid=$target_bssid, target_channel=$target_channel"
    
    local serving_ap=""
    is_client_associated_unit "$client"
    [ "$?" = "1" ] && flag="" || flag=" not"
    DBG conslog "client $client has$flag been associated to this unit $serving_ap"
    if [ -n "$serving_ap" ]; then
        if [ "$(ap_to_bssid $serving_ap)" = "$target_bssid" ]; then
            DBG conslog "$client has already been associated to $target_bssid, no need to steer, exit ( 1 )"
            exit 1
        fi
        steer_11v "$serving_ap" "$client" "$target_bssid" "$target_channel"
        st_ret="$?"
        if [ "$st_ret" = "0" ]; then
            DBG conslog "11v cmd fired successfully"
        else
            DBG conslog "11v cmd fired with error $st_ret, exit ( 1 )"
            exit 1
        fi
    fi
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
    topology_management::temporary_blacklist)
        if [ -f $PAYLOAD_PATH ]; then
            temporary_blacklist_handler $PAYLOAD_PATH
        fi
        ;;
    topology_management::steer_11v)
        if [ -f $PAYLOAD_PATH ]; then
            steer_11v_handler $PAYLOAD_PATH
        fi
        ;;
    *)
        conslog "Error: $ACTION UNKNOWN!"
        exit 3
        ;;
esac
