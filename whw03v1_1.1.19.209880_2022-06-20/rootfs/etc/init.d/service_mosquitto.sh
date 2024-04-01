#!/bin/sh
source /etc/init.d/mosquitto_common.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_misc_functions.sh
SERVICE_NAME="mosquitto"
NAMESPACE=$SERVICE_NAME
CONF_SRC_DIR="/etc/${SERVICE_NAME}"
CONF_DIR="/tmp/etc/${SERVICE_NAME}"
CONF_FILE="${CONF_DIR}/mosquitto.conf"
PSK_VNAME="${NAMESPACE}::psk"
MODE=$(syscfg get smart_mode::mode)
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1
dfc_enabled="1"
dfc_debug="0"
dfc_port=$MOSQUITTO_DEFAULT_PORT
dfc_secport=$MOSQUITTO_DEFAULT_SECPORT
dfc_psk_id=$MOSQUITTO_DEFAULT_PSK_ID
create_conf_file () {
    local RC=0
    [ -d "$CONF_DIR" ] && rm -rf $CONF_DIR
    DBG conslog cp -a $CONF_SRC_DIR $CONF_DIR
    cp -a $CONF_SRC_DIR $CONF_DIR
    DBG conslog "Configuration files copied from '${CONF_SRC_DIR}' to '$CONF_DIR'"
    local IP="$(ip addr show br0|grep 'inet '|awk '{print $2}'|cut -f1 -d/)"
    local PSK="$(syscfg get ${PSK_VNAME})"
    if [ -n "$PSK" ]; then
        local TEMPLATES="mosquitto.conf conf.d/*.conf psk/server.keys"
        for i in $TEMPLATES; do
            local TARGET=$CONF_DIR/$i
            DBG conslog "Template processing '$TARGET':"
            sed -i $TARGET                                  \
                -e "s/%PORT%/$PORT/g"                       \
                -e "s/%SECPORT%/$SECPORT/g"                 \
                -e "s/%PSK_ID%/$MOSQUITTO_DEFAULT_PSK_ID/g" \
                -e "s/%PSK%/$PSK/g"                         \
                -e "s,%CONF_DIR%,$CONF_DIR,g"               \
                -e "s,%IP%,$IP,g"
        done
        set_socket_domain
        DBG conslog create_conf_file returning status $RC
    else
        conslog "Could not determine PSK (${PSK_VNAME}) - can not start Mosquitto"
        ulog ${SERVICE_NAME} error "Could not determine PSK (${PSK_VNAME}='$PSK')"
        RC=1
    fi
    return $RC
}
set_socket_domain() {
    IPV4_DISABLE_FILE="/proc/sys/net/ipv4/conf/all/disable_policy"
    IPV6_DISABLE_FILE="/proc/sys/net/ipv6/conf/all/disable_ipv6"
    
    local TEMPLATES="conf.d/*.conf"
    for i in $TEMPLATES; do
        local TARGET=$CONF_DIR/$i
        DBG conslog "Template processing '$TARGET':"
        
        if [ -f "$IPV6_DISABLE_FILE" ] && [ "$( cat $IPV6_DISABLE_FILE )" = "1" ]; then
            sed -i $TARGET -e "s/##socket_domain##/socket_domain ipv4/g"
        elif [ -f "$IPV4_DISABLE_FILE" ] && [ "$( cat $IPV4_DISABLE_FILE )" = "1" ]; then
            sed -i $TARGET -e "s/##socket_domain##/socket_domain ipv6/g"
        else
            DBG conslog "No socket domain change."
        fi
    done
}
set_defaults ()
{
    for i in $(set|grep '^dfc_'|cut -f1 -d=|cut -f2- -d_);do
        local DEF_VAL="$(eval echo "\$dfc_${i}")"
        if [ -z "$(syscfg get ${NAMESPACE}::$i)" ] ; then
            echo "$0 $1 Setting default for $i to '$DEF_VAL'"  > /dev/console
            syscfg set ${NAMESPACE}::$i $DEF_VAL
        fi
    done
    if [ -z "$(syscfg get ${PSK_VNAME})" ]; then
        local CONFIG_VAP_PASS="$(syscfg get smart_connect::configured_vap_passphrase)"
        if [ -n "$CONFIG_VAP_PASS" ]; then
            syscfg set ${PSK_VNAME} "$(echo "$CONFIG_VAP_PASS" | hexen -p)"
        fi
    fi
}
load_defaults () {
    PORT=$(syscfg get ${NAMESPACE}::port)
    SECPORT=$(syscfg get ${NAMESPACE}::secport)
}
service_init ()
{
    if [ "$MODE" != $MASTER_MODE ]; then
        echo "$SERVICE_NAME aborting: not Master" > /dev/console
        exit 0
    fi
    [ "$(syscfg get "${NAMESPACE}::debug")" == "1" ] && DEBUG=1
    if [ ! "`sysevent get ${NAMESPACE}::inited`" ] ; then
        set_defaults
        sysevent set ${NAMESPACE}::inited 1
    fi
    if [ "`syscfg get ${NAMESPACE}::enabled`" != "1" ] ; then
        echo "$SERVICE_NAME disabled in syscfg"
        exit 0
    fi
    load_defaults
}
service_start ()
{
    if [ "$MODE" -eq $MASTER_MODE ]; then
        wait_till_end_state ${SERVICE_NAME}
        create_conf_file
        check_err_exit $? "Error creating Mosquitto config"
        mosquitto -d -c $CONF_FILE
        check_err_exit $? "Couldn't handle start"
        sysevent set ${SERVICE_NAME}-status started
        ulog ${SERVICE_NAME} status "now started (Node is Master)"
    else
        ulog ${SERVICE_NAME} status "not Node master, not starting"
    fi
}
service_stop ()
{
    wait_till_end_state ${SERVICE_NAME}
    local M_PIDFILE=/var/run/mosquitto.pid
    if [ -f "$M_PIDFILE" ]; then
        DBG conslog "Killing mosquitto process using PID file"
        kill "$(cat $M_PIDFILE)"
        sleep 2
        kill -9 "$(cat $M_PIDFILE)"
        rm -f $M_PIDFILE
    else
        DBG conslog "Killing mosquitto process without PID file"
        killall_if_running mosquitto
    fi
    check_err $? "Couldnt handle stop"
    sysevent set ${SERVICE_NAME}-status stopped
    ulog ${SERVICE_NAME} status "now stopped"
}
service_restart () {
    service_stop
    sleep 0.5
    service_start
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
        service_restart
        ;;
    lan-status)
        if [ "`sysevent get lan-status`" == "started" ] ; then
            service_restart
        fi
        ;;
    *)
        echo "error : $1 unknown" > /dev/console
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | " \
             "${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart ]" > /dev/console
        exit 3
        ;;
esac
