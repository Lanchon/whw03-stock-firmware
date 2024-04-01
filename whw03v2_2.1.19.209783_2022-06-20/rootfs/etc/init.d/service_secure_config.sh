#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/service_misc_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_wifi/wifi_utils.sh
SERVICE_NAME="secure_config"
NAMESPACE=$SERVICE_NAME
BACKUP_FILE_PATH="/var/config/smart_backup.conf"
BACKUP_TEMPLATE="/etc/smart_backup_template.conf"
BACKUP_MASTER="/etc/smart_backup_master.conf"
SYSCFG_FILES_DIR="/tmp"
SYSCFG_FILES_PREFIX="syscfg_change_"
SCF_EVENT_FILE="/tmp/secure_config_sysevents_list"
dfc_config_file="/etc/secure_config.conf"
dfc_username="user"
dfc_password="password"
dfc_port="6060"
dfc_enabled="1"
dfc_smart_backup_enable_purge="1"
dfc_backup_preseed_config="0"
dfc_backup_use_master="0"
dfc_debug="0"
DFC_NAMES="config_file debug enabled username password port smart_backup_enable_purge"
DFC_NAMES="$DFC_NAMES backup_preseed_config backup_use_master"
MODE=$(syscfg get smart_mode::mode)
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1
set_defaults()
{
    for i in $DFC_NAMES;do
        DEF_VAL="$(eval echo "\$dfc_${i}")"
        if [ -z "$(syscfg get ${NAMESPACE}::$i)" ] ; then
            [ "$DEBUG" = "1" ] && echo "$0 $1 Setting default for $i to $DEF_VAL"
            syscfg set ${NAMESPACE}::$i $DEF_VAL
        fi
    done
}
assure_backup_file () {
    if [ "$BACKUP_PRESEED_CONFIG" = "1" ]; then
        if [ ! -f "$BACKUP_FILE_PATH" ]; then
            cp "$BACKUP_TEMPLATE" "$BACKUP_FILE_PATH"
        fi
    fi
}
inject_syscfgs_from_file () {
    local SYSCFGS_FILE="$1"
    local DEB_OPTS=""
    if [ "$DEBUG" = '1' ]; then
        echo "$0: Injecting syscfgs from '$SYSCFGS_FILE' ($(cat $SYSCFGS_FILE))"
        DEB_OPTS="--debug"
    fi
    if [ "$USE_MASTER" = "1" ]; then
        syscfg_inject $DEB_OPTS                  \
                      --verbose                  \
                      --master="$BACKUP_MASTER"  \
                      --syscfgs="$SYSCFGS_FILE"  \
                      "$BACKUP_FILE_PATH"
    else
        syscfg_inject $DEB_OPTS                  \
                      --verbose                  \
                      --syscfgs="$SYSCFGS_FILE"  \
                      "$BACKUP_FILE_PATH"
    fi
    if [ "$SB_PURGE_ENABLED" = '1' ]; then
        [ "$DEBUG" = '1' ] && echo "$0: Purging '$SYSCFGS_FILE'"
            rm $SYSCFGS_FILE
    fi
}
delay_required()
{
	local DELAY_MAX=15
	local CNT=0
	if [ "$MSG_TYPE" = "sync" ]; then
		STATUS="`sysevent get wifi_cache_updating`"
		while  [ "$STATUS" = "1" ] && [ "$CNT" -lt "$DELAY_MAX" ]
		do
			sleep 1
			STATUS="`sysevent get wifi_cache_updating`"
			CNT=`expr $CNT + 1`
		done
	fi
}
create_sysevent_list_file()
{
cat <<EOF > ${SCF_EVENT_FILE}
config_sync::admin_password_synchronized
EOF
}
service_init()
{
    if [ ! "$(sysevent get ${SERVICE_NAME}::inited)" ] ; then
        set_defaults
        sysevent set ${NAMESPACE}::inited 1
        create_sysevent_list_file
        if [ "`syscfg get ${NAMESPACE}::enabled`" == "1" ] ; then
            [ "$DEBUG" = "1" ] && echo "$SERVICE_NAME running $1"
        else
            echo "$SERVICE_NAME disabled in syscfg"
            exit 1
        fi
    fi
}
stop_config_server() {
    killall_if_running $SCT_SERVER
}
service_start ()
{
    [ "$DEBUG" = "1" ] && echo "$0 $1 Starting in mode $MODE"
    case $MODE in
        $UNCONFIGURED_MODE)
            ulog ${SERVICE_NAME} STATUS "Nothing to do in Unconfigured mode"
            ;;
        $MASTER_MODE)
            ulog ${SERVICE_NAME} STATUS "Starting in Master mode"
            stop_config_server
            if [ -n "$CONFIG_FILE" -a -n "$PORT" ]; then
                if [ -f "$CONFIG_FILE" ]; then
                    [ "$DEBUG" = "1" ] && echo "$0 $1 executing: $SCT_SERVER --config_file $CONFIG_FILE --port $PORT --daemon"
                    $SCT_SERVER --config_file $CONFIG_FILE --port $PORT --daemon
                else
                    printf "$0 $1 Error: configuration file \"%s\" not found.\n" "$CONFIG_FILE"
                    ulog ${SERVICE_NAME} ERROR "$1 Error: configuration file \"$CONFIG_FILE\" not found."
                fi
            else
                ulog ${SERVICE_NAME} ERROR $1 Missing required value
            fi
            ;;
        $SLAVE_MODE)
            ulog ${SERVICE_NAME} STATUS "Starting in Slave mode"
            if [ -n "$SERVER_IP" -a -n "$USER" -a "$PASSWORD" -a -n "$PORT" -a "$MSG_TYPE" ]; then
                delay_required
                $SCT_CLIENT --ip       "$SERVER_IP" \
                            --deviceid "$UUID"      \
                            --login    "$USER"      \
                            --password "$PASSWORD"  \
                            --msgtype  "$MSG_TYPE"  \
                            --port     "$PORT"
            else
                [ "$DEBUG" = "1" ] && echo ${SERVICE_NAME} ERROR $1 Missing required value
                ulog ${SERVICE_NAME} ERROR $1 Missing required value
            fi
            ;;
        *)
            ulog ${SERVICE_NAME} ERROR "Illegal mode '$MODE'"
            ;;
    esac
    assure_backup_file
    check_err $? "Couldn't handle start"
    sysevent set ${SERVICE_NAME}-status started
    ulog ${SERVICE_NAME} status "now started"
}
service_stop ()
{
    ulog ${SERVICE_NAME} STATUS "STOP requested"
    if [ "$MODE" = $MASTER_MODE ]; then
        stop_config_server
    fi
}
service_init
CONFIG_FILE="$(      syscfg   get ${SERVICE_NAME}::config_file               )"
PASSWORD="$(         syscfg   get smart_connect::auth_pass                   )"
PORT="$(             syscfg   get ${SERVICE_NAME}::port                      )"
SERVER_IP="$(        sysevent get master::ip                                 )"
USER="$(             syscfg   get smart_connect::auth_login                  )"
UUID="$(             syscfg   get device::uuid                               )"
DEBUG="$(            syscfg   get ${SERVICE_NAME}::debug                     )"
BACKUP_PRESEED_CONFIG="$(syscfg get ${SERVICE_NAME}::backup_preseed_config   )"
USE_MASTER="$(       syscfg   get ${SERVICE_NAME}::backup_use_master         )"
SB_PURGE_ENABLED="$( syscfg   get ${SERVICE_NAME}::smart_backup_enable_purge )"
MSG_TYPE="sync"
if [ "$DEBUG" = "1" ]; then
    echo "$0 variable dump:"
    printf "%22s : \"%s\"\n" "CONFIG_FILE" "$CONFIG_FILE"
    printf "%22s : \"%s\"\n" "DEBUG"       "$DEBUG"
    printf "%22s : \"%s\"\n" "PASSWORD"    "$PASSWORD"
    printf "%22s : \"%s\"\n" "PORT"        "$PORT"
    printf "%22s : \"%s\"\n" "SERVER_IP"   "$SERVER_IP"
    printf "%22s : \"%s\"\n" "USER"        "$USER"
    printf "%22s : \"%s\"\n" "UUID"        "$UUID"
    printf "%22s : \"%s\"\n" "BACKUP_PRESEED_CONFIG" "$BACKUP_PRESEED_CONFIG"
    printf "%22s : \"%s\"\n" "USE_MASTER"  "$USE_MASTER"
fi
SCT_SERVER="sct_server"
SCT_CLIENT="sct_client"
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
    backhaul::status)
        ulog ${SERVICE_NAME} STATUS "Processing backhaul::status = $2"
        [ "$DEBUG" = "1" ] && echo "$0 $1 $2"
        if [ "$2" = "up" ]; then
            service_start
        else
            service_stop
        fi
        ;;
    config_sync::change)
        ulog ${SERVICE_NAME} STATUS "Processing config_sync::change"
        [ "$DEBUG" = "1" ] && echo "$0 $1 $2"
        if [ "$MODE" = "$SLAVE_MODE" ]; then
            service_start
        fi
        ;;
    config_sync::send_update)
        ulog ${SERVICE_NAME} STATUS "Processing config_sync::send_update"
        [ "$DEBUG" = "1" ] && echo "$0 $1 $2"
        MSG_TYPE="update"
        if [ "$MODE" = "$SLAVE_MODE" ]; then
            service_start
        fi
        ;;
    
    wifi-status)
        if [ "`sysevent get wifi-status`" = "started" ] && [ "`sysevent get backhaul::status`" = "up" ]; then
            if [ "$MODE" = "$SLAVE_MODE" ] && [ -f "$SCF_EVENT_FILE" ]; then
                while read line
                do
                    sysevent set "${line}"
                done < "$SCF_EVENT_FILE"
                
                rm ${SCF_EVENT_FILE}
            fi
        fi
        ;;
    wifi_config_changed|jnap_side_effects-setpassword|fwup_autoupdate_flags|user_consented_data_upload|mac_filter_changed|powertable_config_changed|omsg_changed|mesh_usb::config_changed|origin::config_changed|tesseract-status|lrhk::config_changed|lrhk::mn_enabled_changed|lrhk::paired)
        if [ "$MODE" = "$MASTER_MODE" ]; then
            
            if [ "$1" = "tesseract-status" ]; then
                if [ "$2" != "started" ]; then
                    exit 0
                fi  
            fi
            SEQ_NUM_VAR="${NAMESPACE}::seq_num"
            seq_num="$(sysevent get ${SEQ_NUM_VAR})"
            seq_num=$((++seq_num))
            sysevent set "${SEQ_NUM_VAR}" $seq_num
            jsongen -r msg_type:64 \
                    -r "payload:$(jsongen -s seq_num:$seq_num \
                                          -s "sender-address:localhost")" | \
                omsg-publish com.linksys.olympus/service/message
        fi
        ;;
    config_sync::admin_password_synchronized)
        if [ "$MODE" = "$SLAVE_MODE" ]; then
            ADMIN_PW="$(syscfg get device::admin_password)"
            if [ -n "$ADMIN_PW" ]; then
                ADMIN_PW="$(wrappy "$ADMIN_PW")"
                syscfg set device::admin_password "$ADMIN_PW"
                sysevent set jnap_side_effects-setpassword "$ADMIN_PW"
            else
                ulog ${SERVICE_NAME} ERROR "Empty admin password"
            fi
        fi
        ;;
    config_sync::user_consent_synchronized)
        ulog ${SERVICE_NAME} STATUS "Processing config_sync::user_consent_synchronized"
        if [ "$MODE" = "$SLAVE_MODE" ]; then
            sysevent set data_uploader-restart
        fi
        ;;
    config_sync::powertable_synchronized)
        ulog ${SERVICE_NAME} STATUS "Processing config_sync::powertable_synchronized"
        if [ "$MODE" = "$SLAVE_MODE" ]; then
            if [ "1" = "`syscfg_get wifi::multiregion_support`" -a \
                "1" = "`syscfg_get wifi::multiregion_enable`" -a \
                "1" = "`get_multiregion_selectedcountry_validation`" ] ; then
            reboot
            fi
        fi
        ;;
    lan-started)
        [ "$MODE" = "$MASTER_MODE" ] && service_start
        ;;
    syscfg-change)
        [ "$DEBUG" = '1' ] && echo "$0 $1 $2 ($(cat $2))"
        assure_backup_file
        ( inject_syscfgs_from_file $2 ) > /dev/console &
        ;;
    *)
        echo "error : $1 unknown" > /dev/console
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
        exit 3
        ;;
esac
