#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/ipv6_functions.sh
SERVICE_NAME=ipv6_disc
if [ "1" = "`syscfg get ipv6_verbose_logging`" ] 
then
   LOG=/var/log/ipv6.log
else
   LOG=/dev/null
fi
case "$1" in
    ${SERVICE_NAME}-stop)
        ;;
    ${SERVICE_NAME}-start|${SERVICE_NAME}-restart|lan-started|system_state-normal|devicedb-ready|*::link_status_changed|lan_dhcp_client_change)
        ulog ${SERVICE_NAME} status "${SERVICE_NAME} service, triggered by $1"
        async_disc_ip6_to_ddb >> $LOG
        ;;
    lan_dhcp6_client_change) # TODO: generate such sysevent in dhcpv6 server
        ulog ${SERVICE_NAME} status "${SERVICE_NAME} service, triggered by $1"
        async_disc_ip6_to_ddb >> $LOG
        ;;
    *)
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart | lan-started | devicedb-ready | system_state-normal ]" >&2
        exit 3
        ;;
esac
