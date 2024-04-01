#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_misc_functions.sh
SERVICE_NAME="node-off"
NAMESPACE=$SERVICE_NAME
SUBS_REP_STATE="subscriber::connected_state"
SUBS_REP_STATE_RUNNING="reporting"
SUBS_REP_STATE_DONE="ready"
MSG_CACHE_DIR="/tmp/msg"
dfc_debug="0"
dfc_enabled="1"
dfc_min_offline_time="3"
dfc_enable_cloud="1"
dfc_cache_dir="/tmp/msg"
MODE=$(syscfg get smart_mode::mode)
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1
set_defaults()
{
    for i in cache_dir debug enabled enable_cloud min_offline_time; do
        DEF_VAL="$(eval echo "\$dfc_${i}")"
        if [ -z "$(syscfg get ${NAMESPACE}::$i)" ] ; then
            echo "$0 $1 Setting default for $i = '$DEF_VAL'"  > /dev/console
            syscfg set ${NAMESPACE}::$i $DEF_VAL
        fi
    done
    local NOTIFICATION_ENABLER="notification::enabled"
    local NOTIFICATION_ENABLER_DEFAULT="1"
    if [ -z "$(syscfg get ${NOTIFICATION_ENABLER})" ] ; then
        echo "$0 $1 Setting default for ${NOTIFICATION_ENABLER} ="\
             "'$NOTIFICATION_ENABLER_DEFAULT'"  > /dev/console
        syscfg set ${NOTIFICATION_ENABLER} $NOTIFICATION_ENABLER_DEFAULT
    fi
}
service_init()
{
    if [ "$(sysevent get ${NAMESPACE}::inited)" != "1" ] ; then
        set_defaults
        sysevent set ${NAMESPACE}::inited 1
        if [ "$(syscfg get ${NAMESPACE}::enabled)" = "1" ] ; then
            echo "$SERVICE_NAME running $1"  > /dev/console
        else
            echo "$SERVICE_NAME disabled in syscfg"  > /dev/console
            exit 1
        fi
    fi
}
CRON_JOB_BIN="/usr/sbin"
CRON_JOB_FILE="offline-notifier.cron"
CRON_JOB_DEST="/tmp/cron/cron.everyminute"
install_cronjob() {
    if [ ! -f "${CRON_JOB_DEST}/${CRON_JOB_FILE}" ]; then
        [ $DEBUG ] && echo "$SERVICE_NAME installing ${CRON_JOB_FILE} to ${CRON_JOB_DEST}/"  > /dev/console
        cp ${CRON_JOB_BIN}/${CRON_JOB_FILE} ${CRON_JOB_DEST}/
    fi
}
remove_cronjob() {
    if [ -f "${CRON_JOB_DEST}/${CRON_JOB_FILE}" ]; then
        [ $DEBUG ] && echo "$SERVICE_NAME removing ${CRON_JOB_FILE} to ${CRON_JOB_DEST}/"  > /dev/console
        rm ${CRON_JOB_DEST}/${CRON_JOB_FILE}
    fi
}
service_start ()
{
    [ $DEBUG ] && echo "$0 $1 $2 Starting in mode $MODE"  > /dev/console
    if [ "$(sysevent get ${SERVICE_NAME}-status)" != started ]; then
        sysevent set ${SERVICE_NAME}-status starting
        case $MODE in
            $MASTER_MODE)
                install_cronjob
                ;;
            $SLAVE_MODE)
                pub_offline_will
                ;;
            *)
                ulog ${SERVICE_NAME} ERROR "Illegal mode '$MODE'"
                ;;
        esac
        check_err $? "Couldn't handle start"
        sysevent set ${SERVICE_NAME}-status started
        ulog ${SERVICE_NAME} status "now started"
    else
        echo "$0 $1 $2: Ignoring, status already = 'started'" > /dev/console
    fi
}
kill_offline_subscription () {
    DBG conslog "Canceling offline notification subscription"
    local PID="$(ps ww | grep mosquitto_sub | grep OFFLINE/$(syscfg get device::uuid) | awk '{print $1}')"
    if [ -n "$PID" ]; then
        DBG conslog "Killing process $PID"
        ulog ${SERVICE_NAME} STATUS "Offline subscription process ($PID) not responding to CANCEL; now killing"
        kill $PID
    fi
}
service_stop ()
{
    ulog ${SERVICE_NAME} STATUS "STOP requested"
    sysevent set ${SERVICE_NAME}-status stopping
    case $MODE in
        $MASTER_MODE)  remove_cronjob      ;;
        $SLAVE_MODE)   kill_offline_subscription ;;
    esac
    sysevent set ${SERVICE_NAME}-status stopped
}
service_restart() {
    service_stop
    sleep 2
    service_start
}
service_init
[ $DEBUG ] && echo "$0 $1 $2 MODE: $MODE"  > /dev/console
case "$1" in
    ${SERVICE_NAME}-start)
        service_start
        ;;
    ${SERVICE_NAME}-stop)
        service_stop
        ;;
    ${SERVICE_NAME}-restart)
        service_restart
        ;;
    slave_offline)
        if  [ "$MODE" = "$MASTER_MODE" ];then
            [ $DEBUG ] && echo "$0 $1 $2 Got node offline message" > /dev/console
            SLAVE_UUID="$(jsonparse uuid < $2)"
            pub_are_you_up -u $SLAVE_UUID
        fi
        ;;
    devinfo)
        if  [ "$MODE" = "$MASTER_MODE" ];then
            [ $DEBUG ] && echo "$0 $1 $2 Got DEVINFO message" > /dev/console
            NODE_UUID="$(jsonparse uuid < $2)"
            [ $DEBUG ] && echo "$0 $1: NODE_UUID: $NODE_UUID" > /dev/console
            OFFLINE_REPORT="${MSG_CACHE_DIR}/$(omsg-conf -m -a path LAST-WILL|sed "s/%2/$NODE_UUID/")"
            [ -f "$OFFLINE_REPORT" ] && rm $OFFLINE_REPORT
        fi
        ;;
    cmd::are-you-up)
        if  [ "$MODE" = "$SLAVE_MODE" ];then
            [ $DEBUG ] && echo "$0 $1 $2 Resending devinfo" > /dev/console
            pub_devinfo_status
            sleep 1
            pub_bh_status
        fi
        ;;
    *)
        echo "error : $1 unknown" > /dev/console
        echo -n "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | " > /dev/console
        echo "${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
        exit 3
        ;;
esac
