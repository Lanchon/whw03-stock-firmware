#!/bin/sh
MODE="$(syscfg get smart_mode::mode)"
SLAVE_MODE=1
DEBUG="$( syscfg get lrhk::debug )"
DBG () {
    if [ $DEBUG ]; then
        $*
    fi
}
if [ "$MODE" = "$SLAVE_MODE" ]; then
    MASTER_IP="$( sysevent get master::ip )"
    SECTRANS_LOGIN="$( syscfg get sectrans::login )"
    SECTRANS_SECRET="$( syscfg get smart_connect::configured_vap_passphrase )"
    SECTRANS_PORT="$( syscfg get sectrans::port )"
    DATABASE="$( syscfg get lrhk::sectrans_data_cedardb )"
    DBG echo "Slave, start sectrans_client -l ${SECTRANS_LOGIN} -s ${SECTRANS_SECRET} -i ${MASTER_IP} -p ${SECTRANS_PORT} -d ${DATABASE}"
    sectrans_client -l ${SECTRANS_LOGIN} -s ${SECTRANS_SECRET} -i ${MASTER_IP} -p ${SECTRANS_PORT} -d ${DATABASE}
fi
DBG echo "Trigger generate firewall rules"
/usr/sbin/ipv4_firewall hk_firewall-add 1 profile
/usr/sbin/ipv6_firewall hk_firewall-add 1 profile
/usr/sbin/bridge_firewall hk_firewall-add 1 profilelan
