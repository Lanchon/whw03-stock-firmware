#!/bin/sh
sName=`basename $0`
count=`ps |grep $sName |grep -v grep |grep -v $$ |wc -l`
if [ $count -gt 1 ]; then
    echo "Another backhaul check instance is running."
    exit 1
fi
if [ "1" != "$(syscfg get smart_mode::mode)" ] ; then
   exit 1
fi
if [ "$(sysevent get backhaul::media)" == "1" ]; then
    exit 1
fi
ip_connect_check ()
{
    complete_check=$1
    master_ip="$(sysevent get master::ip)"
    if [ "${master_ip}" == "" ] ; then
        master_ip="$(sysevent get default_router)"
    fi
    if [ "${master_ip}" == "" ]; then
        return 0
    fi
    arping -I br0 -q -f -w 1 ${master_ip}
    [ "$?" != "0" ] && return 0
    if [ "$complete_check" != "1" ]; then
        echo "=== Set BM 1, ip_connect_check is ok ===" >> /dev/console
        sysevent set backhaul::media 1
        return 1
    fi
    
    MACADDR="`arp -a | grep \(${master_ip}\) | grep br0 | awk -F ' ' '{print $4}'`"
    [ -n "$MACADDR" ] && PORTID="`brctl showmacs br0 | grep -i ${MACADDR} | awk -F ' ' '{print $1}'`"
    [ -n "$DEBUG" ] && echo "complete check! mac=$MACADDR port=$PORTID" > /dev/console
    if [ -n "$PORTID" ]; then
        PORTID=`expr 8000 + ${PORTID}`
        brctl showstp br0 | egrep -C 1 "port id.+${PORTID}" | grep -q "eth"
        if [ "$?" = "0" ]; then
            echo "=== Set BM 1, ip_connect_check is ok ===" >> /dev/console
            sysevent set backhaul::media 1
            return 1
        fi
    fi
    return 0
}
brctl showstp br0 |grep ath1 -w -A 1 |grep blocking > /dev/null
if [ "$?" == "0" ] ; then
    sysevent set blocking::ath1 1
    ifconfig ath1 down
    echo "Warning: ath1 is blocked by STP, down ath1 about 2 minutes. Will turn up by monitor later..." >> /dev/console
elif [ "`sysevent get blocking::ath1`" = "1" ] ; then
    sysevent set blocking::ath1 2
else
    sysevent set blocking::ath1
fi
brctl showstp br0 |grep ath10 -w -A 1 |grep blocking > /dev/null
if [ "$?" == "0" ] ; then
    sysevent set blocking::ath10 1
    ifconfig ath10 down
    echo "Warning: ath10 is blocked by STP, down ath10 about 2 minutes. Will turn up by monitor later..." >> /dev/console
elif [ "`sysevent get blocking::ath10`" = "1" ] ; then
    sysevent set blocking::ath10 2
else
    sysevent set blocking::ath10
fi
backhaul_status="$(sysevent get backhaul::status)"
if [ "$backhaul_status" == "up" ]; then
    backhaul_intf="$(sysevent get backhaul::intf)"
    if [ "${backhaul_intf:0:3}" = "ath" ] ; then
        brctl showstp br0 |grep $backhaul_intf -w -A 1 |grep blocking > /dev/null
        if [ "$?" == "0" ] ;then
            echo "Wired backhaul is availiable and wireless interface $backhaul_intf is blocking, will check the ip connection, if it is ok will switch backhaul to wired."
            ip_connect_check
            exit 1
        fi
	    for i in 1 2 3
	    do
            ip_connect_check 1
            [ "$?" = "1" ] && break
			sleep 5
	    done
    fi
else
    if [ "$(sysevent get wifi-status)" == "started" ] ; then
        ATH9_STATUS="`iwconfig ath9 | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
        ATH11_STATUS="`iwconfig ath11 | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
        if [ "Not-Associated" == "$ATH9_STATUS" ] && [ "Not-Associated" == "$ATH11_STATUS" ]; then
            echo "=== STA is not associated do backhaul ip check ===" >> /dev/console
            ip_connect_check
            exit 1
        fi
    else
        echo "=== wifi is not started do backhaul ip check ===" >> /dev/console
        RESULT=`ip_connect_check`
        if [ "$RESULT" == "0" ]; then
	    for i in 1 2 3; 
	    do
                echo "=== wifi is not started do backhaul ip check ===" >> /dev/console
                RESULT=`ip_connect_check`
                if [ "$RESULT" == "0" ] && [ "$(sysevent get wifi-status)" != "started" ]; then
                    sleep 1
                else
                    exit 1
                fi
	    done
        fi  
    fi
fi
exit 1
