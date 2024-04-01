#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME=stunnel
BIN=stunnel
CONF_FILE=/tmp/stunnel.conf
PID_FILE=/var/run/${SERVICE_NAME}.pid
PMON=/etc/init.d/pmon.sh
generate_conf ()
{
    eval `utctx_cmd get ui::remote_host ui::remote_port ui::remote_stunnel ui::remote_stunnel_port ui::remote_stunnel_verify cloud::host cloud::port cloud::stunnel cloud::stunnel_port cloud::stunnel_verify`
    cat <<EOF
; stunnel configuration file (generated by service_stunnel.sh)
; Protocol version (all, SSLv2, SSLv3, TLSv1)
sslVersion = all
options = NO_SSLv2
options = NO_SSLv3
; Run as a "foreground" process since the alternative fails after handling one request on Broadcom platforms.
foreground = yes
; Note: PID is created inside the chroot jail
pid = ${PID_FILE}
; Some performance tunings
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
; Uncomment for more verbose logging
;debug = debug
;output = /var/log/stunnel.log
debug = warning
syslog = yes
fips = no
; Use it for client mode
client = yes
sni = ${SYSCFG_cloud_host}
; Service-level configuration
EOF
    if [ "${SYSCFG_ui_remote_stunnel}" != "0" ]; then
        if [ "${SYSCFG_ui_remote_stunnel_verify}" != "0" ]; then
            SYSCFG_ui_remote_stunnel_verify=2
        fi
        cat <<EOF
[ui-remote]
delay = yes
accept = 127.0.0.1:${SYSCFG_ui_remote_stunnel_port}
connect = ${SYSCFG_ui_remote_host}:${SYSCFG_ui_remote_port}
; The idle timeout will also be applicable when waiting for HTTP responses,
; since stunnel is not aware a response is expected. The server can always
; close the connection sooner if needed.
TIMEOUTidle = 30
CApath = /etc/certs/root
verify = ${SYSCFG_ui_remote_stunnel_verify}
EOF
    fi
    if [ "${SYSCFG_cloud_stunnel}" != "0" ]; then
        if [ "${SYSCFG_cloud_stunnel_verify}" != "0" ]; then
            SYSCFG_cloud_stunnel_verify=2
        fi
        cat <<EOF
[cloud]
delay = yes
accept = 127.0.0.1:${SYSCFG_cloud_stunnel_port}
connect = ${SYSCFG_cloud_host}:${SYSCFG_cloud_port}
; The idle timeout will also be applicable when waiting for HTTP responses,
; since stunnel is not aware a response is expected. The server can always
; close the connection sooner if needed.
TIMEOUTidle = 30
CApath = /etc/certs/root
verify = ${SYSCFG_cloud_stunnel_verify}
EOF
    fi
}
service_start ()
{
    wait_till_end_state ${SERVICE_NAME}
    STATUS=`sysevent get ${SERVICE_NAME}-status`
    if [ "started" != "$STATUS" ] ; then
        sysevent set ${SERVICE_NAME}-errinfo
        sysevent set ${SERVICE_NAME}-status starting
        ulog ${SERVICE_NAME} status "starting ${SERVICE_NAME} service"
        generate_conf > ${CONF_FILE}
        ${BIN} ${CONF_FILE} 2&> /dev/null &
        check_err $? "Couldnt handle start"
        sysevent set ${SERVICE_NAME}-status started
    fi
    $PMON setproc ${SERVICE_NAME} $BIN $PID_FILE "/etc/init.d/service_${SERVICE_NAME}.sh ${SERVICE_NAME}-restart"
}
service_stop ()
{
    wait_till_end_state ${SERVICE_NAME}
    STATUS=`sysevent get ${SERVICE_NAME}-status`
    if [ "stopped" != "$STATUS" ] ; then
        sysevent set ${SERVICE_NAME}-errinfo
        sysevent set ${SERVICE_NAME}-status stopping
        ulog ${SERVICE_NAME} status "stopping ${SERVICE_NAME} service"
        kill -TERM $(cat $PID_FILE)
        check_err $? "Couldnt handle stop"
        sysevent set ${SERVICE_NAME}-status stopped
    fi
    rm -f $PID_FILE
    $PMON unsetproc ${SERVICE_NAME}
}
service_restart ()
{
    service_stop
    service_start
}
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
    lan-started)
        ulog ${SERVICE_NAME} status "${SERVICE_NAME} service, triggered by $1"
        service_restart
        ;;
    lan-stopping)
        ulog ${SERVICE_NAME} status "${SERVICE_NAME} service, triggered by $1"
        service_stop
        ;;
    *)
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart | lan-started | lan-stopping ]" >&2
        exit 3
        ;;
esac