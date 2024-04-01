#!/bin/sh
sName=`basename $0`
pidFile="/var/run/$sName.pid"
DEBUG="$(sysevent get configure_me_debug)"
run_check () {
    pid=""
    [ -f "$pidFile" ] && pid=`cat $pidFile`
    if [ -n "$pid" ] && [ "$$" != "$pid" ]; then
        ps -w | grep  "^.*$pid " | grep -v grep
	if [ "$?" = "0" ]; then
            [ $DEBUG ] && echo "[M] another monitor instance is running"
            exit 1
        fi
	echo "[M] another monitor stopped unexpectedly"
	rm $pidFile
	sleep 2
    fi
    if [ ! -f "$pidFile" ]; then
        echo "[M] created pid file"
        echo $$ > $pidFile
    fi
    SETUP_STATUS="`sysevent get smart_connect::setup_status`"
    if [ "$SETUP_STATUS" = "DONE" ] || [ "`syscfg get smart_mode::mode`" != "0" ]; then
        [ $DEBUG ] && echo "[M] monitor exit"
	rm $pidFile
        exit 1
    fi
}
run_check
[ $DEBUG ] && echo "[M] monitor start!"
while [ 1 ]; do
    while [ 1 ]; do
        [ $DEBUG ] && echo "[M] arp test"
        OMSG_STARTED="$(sysevent get omsg::daemon::started)"
        SUBSCRIBER_CONNECTED="$(sysevent get subscriber::connected)"
        WAN_IFNAME="$(sysevent get wan::detected_intf)"
        [ -z "$WAN_IFNAME" ] && WAN_IFNAME="$(syscfg get uplink_ifname)"
        [ -z "$WAN_IFNAME" ] && WAN_IFNAME="$(syscfg get wan_physical_ifname)"
        OMSG_IP="$(sysevent get master::ip)"
        if [ "$OMSG_STARTED" = "1" -a "$SUBSCRIBER_CONNECTED" = "1" -a -n "${OMSG_IP}" -a -n "$WAN_IFNAME" ] ; then
            arping -I ${WAN_IFNAME} -f -w 1 ${OMSG_IP}
            [ "$?" = "0" ] && break
        fi
        sleep 5
	run_check
    done
    [ $DEBUG ] && echo "[M] pub configure me!"
    pub_configure_me
    sleep_cnt=0
    while [ "$sleep_cnt" -lt "4" ];
    do
        [ $DEBUG ] && echo "[M] wait for START"
        sleep 5
        SETUP_STATUS="`sysevent get smart_connect::setup_status`" 
        [ -n "$SETUP_STATUS" -a "$SETUP_STATUS" != "READY" ] && break
        sleep_cnt=`expr $sleep_cnt + 1`
    done
    [ -z "$SETUP_STATUS" -o "$SETUP_STATUS" = "READY" ] && continue
    sleep_cnt=0
    while [ "$sleep_cnt" -lt "12" ];
    do
        [ $DEBUG ] && echo "[M] wait for DONE"
        sleep 10
        SETUP_STATUS="`sysevent get smart_connect::setup_status`" 
        [ "$SETUP_STATUS" = "DONE" -o "$SETUP_STATUS" = "ERROR" -o "$SETUP_STATUS" = "READY" ] && break
        sleep_cnt=`expr $sleep_cnt + 1`
    done
    
    if [ "$SETUP_STATUS" = "DONE" ]; then
        [ $DEBUG ] && echo "[M] DONE!"
	rm $pidFile
        exit 0
    fi
    [ "$SETUP_STATUS" != "READY" ] && sysevent set smart_connect::setup_status READY
done
