#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="senq"
NAMESPACE=$SERVICE_NAME
SUBS_REP_STATE="subscriber::connected_state"
SUBS_REP_STATE_RUNNING="reporting"
SUBS_REP_STATE_DONE="ready"
dfc_debug="0"
dfc_enabled="1"
dfc_event_pause="0"
MODE=$(syscfg get smart_mode::mode)
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1
set_defaults()
{
    for i in debug enabled event_pause; do
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
CRON_JOB_FILE="sysevent_queue_process.cron"
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
    echo "$0 $1 $2 Starting in mode $MODE"  > /dev/console
    if [ "$(sysevent get ${SERVICE_NAME}-status)" != started ]; then
        sysevent set ${SERVICE_NAME}-status starting
        install_cronjob
        check_err_exit $? "Couldn't handle start"
        sysevent set ${SERVICE_NAME}-status started
        ulog ${SERVICE_NAME} status "now started"
    else
        echo "$0 $1 $2: Ignoring, status already = 'started'" > /dev/console
    fi
}
service_stop ()
{
    ulog ${SERVICE_NAME} STATUS "STOP requested"
    sysevent set ${SERVICE_NAME}-status stopping
    remove_cronjob
    sysevent set ${SERVICE_NAME}-status stopped
}
service_restart() {
    service_stop
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
    senq::test)
        echo "${SERVICE_NAME}: Test event $1 $2" > /dev/console
        ;;
    *)
        echo "error : $1 unknown" > /dev/console
        echo -n "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | " > /dev/console
        echo "${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
        exit 3
        ;;
esac
