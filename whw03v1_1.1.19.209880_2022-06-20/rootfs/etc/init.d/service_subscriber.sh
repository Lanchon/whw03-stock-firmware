#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/service_misc_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_misc_functions.sh
source /etc/init.d/node-mode_common.sh
MASTERIP_EV_NAME="master::ip"
SERVICE_NAME="subscriber"
NAMESPACE=$SERVICE_NAME
DAEMON_CMD=${SERVICE_NAME}
PMON=/etc/init.d/pmon.sh
PID_FILE=/var/run/${DAEMON_CMD}.pid
LOCK_FILE=/var/lock/${SERVICE_NAME}
CONNECT_TIMEOUT_VARNAME=connect_timeout
CONNECT_TIMEOUT_DEFAULT_VAL=10
dfc_subs="/var/config/subscriber.subs"
dfc_enabled="1"
dfc_file_prefix="/tmp/msg"
dfc_keepalive="60"
let "dfc_${CONNECT_TIMEOUT_VARNAME}=${CONNECT_TIMEOUT_DEFAULT_VAL}"
MODE=$(syscfg get smart_mode::mode)
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1
SEC_MODE_SECURE="secure"
SEC_MODE_UNSECURE="unsecure"
set_defaults()
{
    for i in $(set|grep '^dfc_'|cut -f1 -d=|cut -f2- -d_);do
        local DEF_VAL="$(eval echo "\$dfc_${i}")"
        if [ -z "$(syscfg get ${NAMESPACE}::$i)" ] ; then
            echo "$0 $1 Setting default for $i to '$DEF_VAL'"  > /dev/console
            syscfg set ${NAMESPACE}::$i $DEF_VAL
        fi
    done
}
start_omsg_agent() {
    kill_omsg_agent
    local CONNECT_TIMEOUT="$(syscfg get ${NAMESPACE}::${CONNECT_TIMEOUT_VARNAME})"
    CONNECT_TIMEOUT=${CONNECT_TIMEOUT:-${CONNECT_TIMEOUT_DEFAULT_VAL}}
    local REQ_SEC_MODE=$1
    local OMSG_PSK_ID
    local OMSG_PSK
    local OMSG_SEC_OPTS
    local OMSG_SEC_PORT
    local OMSG_USER
    local OMSG_PASS
    local OMSG_SERVERIP
    local OMSG_PORT="$(syscfg get omsg::port)"
    DBG evconslog "start_omsg_agtent REQ_SEC_MODE: '$REQ_SEC_MODE'"
    if [ $MODE -eq $MASTER_MODE ]; then
        OMSG_SERVERIP=localhost
    else
        OMSG_SERVERIP="$(sysevent get $MASTERIP_EV_NAME)"
        if [ -z "$OMSG_SERVERIP" ]; then
            evconslog "Cannot determine Master IP; cannot start omsgd nor subscriber"
            exit 1
        fi
        OMSG_SEC_PORT="$(syscfg get omsg::secport)"
        if [ -n "$OMSG_SEC_PORT" -a "$REQ_SEC_MODE" != "$SEC_MODE_UNSECURE" ]; then
            OMSG_PORT=$OMSG_SEC_PORT
            OMSG_PSK_ID="$(syscfg get omsg::psk_id)"
            OMSG_PSK="$(syscfg get omsg::psk)"
            OMSG_USER="$(syscfg get smart_connect::auth_login)"
            OMSG_PASS="$(syscfg get smart_connect::auth_pass)"
            OMSG_SEC_OPTS='-I "$OMSG_PSK_ID" -K "$OMSG_PSK" -u "$OMSG_USER" -P "$OMSG_PASS"'
        fi
    fi
    if [ "$(syscfg get omsg::debug)" == "1" ]; then
        OMSG_DEBUG="-d"
    fi
    ulog ${SERVICE_NAME} STATUS "MODE is $MODE"
    if [ "$MODE" = "$MASTER_MODE" ]; then
        ulog ${SERVICE_NAME} STATUS "Starting messaging agent in master mode"
        OMSG_XTRA_PARAM="-m"
    else
        ulog ${SERVICE_NAME} STATUS "Starting messaging agent in non-master mode"
    fi
    DBG eval conslog ${SERVICE_NAME} executing: omsgd $OMSG_DEBUG "${OMSG_XTRA_PARAM}" -H "$OMSG_SERVERIP" -p "$OMSG_PORT" -D  "${OMSG_SEC_OPTS}"
    eval omsgd $OMSG_DEBUG "${OMSG_XTRA_PARAM}" -H "$OMSG_SERVERIP" -p "$OMSG_PORT" -D  "${OMSG_SEC_OPTS}"
    sysevent set omsg::daemon::started 1
    DBG evconslog "Running omsg-info:"
    ( omsg-gen-service-info ; \
      printf "uuid=%s\n" "$(syscfg get device::uuid)" \
    ) | omsg-info -H "$OMSG_SERVERIP" -p "$OMSG_PORT"
    DBG evconslog "Done running omsg-info:"
    if [ "$MODE" = "$UNCONFIGURED_MODE" ]; then
        /etc/init.d/configure_me_monitor.sh &
    fi
}
kill_omsg_agent() {
    killall_if_running omsgd
    sysevent set omsg::daemon::started 0
    if [ "$MODE" = "$UNCONFIGURED_MODE" ]; then
        killall configure_me_monitor.sh
        rm /var/run/configure_me_monitor.sh.pid
    fi
}
service_init()
{
    [ "$(syscfg get "${NAMESPACE}::debug")" == "1" ] && DEBUG=1
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
install_subs_file() {
    local SUBS_FILE="$(syscfg get ${NAMESPACE}::subs)"
    local SUBS_SRC_DIR="/etc/${SERVICE_NAME}.d"
    case $1 in
        $MASTER_MODE)       SUBS_SRC_FNAME=$SUBS_SRC_DIR/master.subs ;;
        $SLAVE_MODE)        SUBS_SRC_FNAME=$SUBS_SRC_DIR/slave.subs  ;;
        $UNCONFIGURED_MODE) SUBS_SRC_FNAME=$SUBS_SRC_DIR/unconfigured.subs ;;
        *)
            echo "$0 $1: Not installing subs file for mode '$MODE'" > /dev/console
            return
            ;;
    esac
    echo "$0 $1 $2: Generating $SUBS_FILE from $SUBS_SRC_FNAME"  > /dev/console
    UUID="$(syscfg get device::uuid)"
    sed \
        -e "s,%uuid,${UUID},g" \
        < $SUBS_SRC_FNAME \
        > $SUBS_FILE
}
start_subscriber() {
    kill_subscriber
    local CONNECT_TIMEOUT="$(syscfg get ${NAMESPACE}::${CONNECT_TIMEOUT_VARNAME})"
    CONNECT_TIMEOUT=${CONNECT_TIMEOUT:-${CONNECT_TIMEOUT_DEFAULT_VAL}}
    local REQ_SEC_MODE=$1
    local SERVERIP
    local PORT
    local PSK_ID
    local PSK
    local SEC_OPTS
    local SEC_PORT
    local USER
    local PASS
    DBG evconslog "start_subscriber REQ_SEC_MODE: '$REQ_SEC_MODE'"
    if [ $MODE -eq $MASTER_MODE ]; then
        SERVERIP=localhost
        PORT=1883
    else
        SERVERIP="$(sysevent get $MASTERIP_EV_NAME)"
        SEC_PORT="$(syscfg get omsg::secport)"
        if [ -n "$SEC_PORT" -a "$REQ_SEC_MODE" != "$SEC_MODE_UNSECURE" ]; then
            DBG evconslog "Starting subscriber daemon securely"
            PORT=$SEC_PORT
            USER="$(syscfg get smart_connect::auth_login)"
            PASS="$(syscfg get smart_connect::auth_pass)"
            PSK_ID="$(syscfg get omsg::psk_id)"
            PSK="$(syscfg get omsg::psk)"
            SEC_OPTS='-I "$PSK_ID" -K "$PSK" -u "$USER" -P "$PASS"'
        else
            DBG evconslog "Starting subscriber daemon unsecurely"
            PORT="$(syscfg get omsg::port)"
        fi
    fi
    if [ -n "${SERVERIP}" -a -n "$PORT" ]; then
        install_subs_file $MODE
        local SUBS_KEEPALIVE="$(syscfg get ${SERVICE_NAME}::keepalive)"
        SUBS_KEEPALIVE=${SUBS_KEEPALIVE:-60}
        eval /usr/sbin/${DAEMON_CMD} -d -D -H "${SERVERIP}" -t "${CONNECT_TIMEOUT}" -k "${SUBS_KEEPALIVE}" -p "$PORT" "${SEC_OPTS}"
        pidof ${DAEMON_CMD} > $PID_FILE
        $PMON setproc ${SERVICE_NAME} ${DAEMON_CMD} $PID_FILE \
              "/etc/init.d/service_${SERVICE_NAME}.sh ${SERVICE_NAME}-restart"
    else
        ulog ${SERVICE_NAME} ERROR "Insufficient connection information to contact MQTT broker"
        [ -z "${SERVERIP}" ] && ulog ${SERVICE_NAME} ERROR "Need $MASTERIP_EV_NAME"
        [ -z "$PORT"       ] && ulog ${SERVICE_NAME} ERROR "Need omsg::port"
    fi
}
kill_subscriber() {
    killall ${SERVICE_NAME} >& /dev/null
    rm -f $PID_FILE
    $PMON unsetproc ${SERVICE_NAME}
}
service_start ()
{
    start_omsg_agent $SEC_MODE_SECURE
    start_subscriber $SEC_MODE_SECURE
    check_err $? "Couldn't handle start"
    sysevent set ${SERVICE_NAME}-status started
    ulog ${SERVICE_NAME} status "now started"
}
service_stop ()
{
    ulog ${SERVICE_NAME} STATUS "STOP requested"
    sysevent set ${SERVICE_NAME}-status stopping
    kill_subscriber
    kill_omsg_agent
    sysevent set ${SERVICE_NAME}-status stopped
}
service_restart() {
    service_stop
    service_start
}
start_lock_fail () {
    conslog "${PROG_NAME}: startup already in-progress"
    exit 1
}
service_init
echo "$0 $1 $2 MODE: $MODE"  > /dev/console
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
    subscriber::need-reconnect)
        if [ "$(sysevent get ${SERVICE_NAME}-status)" = "started" ]; then
            LAST_SECMODE="$(sysevent get omsg::security_mode)"
            DBG evconslog "security mode: '$LAST_SECMODE', EVENT_VALUE: '$EVENT_VALUE'"
            if [ "$EVENT_VALUE" = "1" ]; then
                DBG evconslog "Restarting subscriber due to disconnect ($EVENT_VALUE)"
                (   # Use flock to prevent multiple simultaneous execution
                    flock -n 9 || start_lock_fail
                    CONNECT_UNSECURE_FALLBACK_DISAB="$(syscfg get omsg::${CONNECT_UNSECURE_FALLBACK_DISABLED_VARNAME})"
                    if [ "$CONNECT_UNSECURE_FALLBACK_DISAB" != "1" ]; then
                        if [ "$(sysevent get omsg::security_mode)" = "$SEC_MODE_UNSECURE" ]; then
                            NEW_SEC_MODE="$SEC_MODE_SECURE"
                            sleep 5
                        else
                            NEW_SEC_MODE="$SEC_MODE_UNSECURE"
                        fi
                    else
                        DBG evconslog "Not falling back to unsecure mode;" \
                            "omsg::${CONNECT_UNSECURE_FALLBACK_DISABLED_VARNAME} is " \
                            "'$CONNECT_UNSECURE_FALLBACK_DISAB'"
                    fi
                    DBG evconslog "Subscriber daemon restarting with security ($NEW_SEC_MODE)"
                    start_subscriber $NEW_SEC_MODE
                    start_omsg_agent $NEW_SEC_MODE
                ) 9>${LOCK_FILE} &
            else
                DBG evconslog "Skipping: EVENT_VALUE ($EVENT_VALUE) is not 1"
            fi
        else
            DBG evconslog "Ignoring event; service not started"
        fi
        ;;
    *)
        echo "error : $1 unknown" > /dev/console
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart ]" > /dev/console
        exit 3
        ;;
esac
