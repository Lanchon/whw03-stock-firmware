#!/bin/sh
source /etc/init.d/ulog_functions.sh
SRV_NAME="wan_intf_auto_detect"
SUB_COMP="static_detect"
verify_gateway_reachability()
{
    local intf="$1"
    local default_gateway="$2"
    local TRY="0"
    local MAX_TRY="2"
    while [ "$TRY" -lt "$MAX_TRY" ]; do
        arping -f -q -w 3 -I $intf $default_gateway
        ret="$?"
        if [ "$ret" = "0" ]; then
            RESULT="1"
            break
        fi
        sleep 1
        ping -4 -c 3 -W 3 -I $intf $default_gateway > /dev/null 2>&1
        ret=$?
        if [ "$ret" = "0" ]; then
            RESULT="1"
            break
        fi
        TRY=`expr $TRY + 1`
        sleep 1
    done
}
if [ "$(syscfg get wan::intf_auto_detect_debug)" = "1" ]; then
    set -x
fi
if [ -z "$1" -o -z "$2" ]; then
    ulog $SRV_NAME $SUB_COMP "interface not specified, static detect abort"
    return 2
fi
v_wan_ipaddr=$(syscfg get wan_ipaddr)
v_wan_netmask=$(syscfg get wan_netmask)
v_wan_default_gateway=$(syscfg get wan_default_gateway)
v_nameserver1=$(syscfg get nameserver1)
v_nameserver2=$(syscfg get nameserver2)
v_nameserver3=$(syscfg get nameserver3)
if [ -z "$v_wan_ipaddr" -o -z "$v_wan_netmask" -o -z "$v_wan_default_gateway" ]; then
    ulog $SRV_NAME $SUB_COMP "ip address($v_wan_ipaddr), netmask($v_wan_netmask), gateway($v_wan_default_gateway) not specified in static mode"
    return 2
fi
pid_file="$2"
echo "$$" > $pid_file
trap 'rm -f "$pid_file"' INT TERM EXIT;
RESULT="0"
ulog $SRV_NAME $SUB_COMP "static detect starts on $1"
date_start=$(date +%s)
ip -4 addr add $v_wan_ipaddr/$v_wan_netmask dev $1
iptables -t filter -A INPUT -p icmp -j ACCEPT
verify_gateway_reachability "$1" "$v_wan_default_gateway"
date_end=$(date +%s)
time_spend=$(expr $date_end - $date_start)
if [ "$RESULT" = "1" ]; then
    ulog $SRV_NAME $SUB_COMP "detect result: Yes, spent $time_spend seconds"
    sysevent set static_detect_on_${1} "DETECTED"
else
    ulog $SRV_NAME $SUB_COMP "detect result: No, spent $time_spend seconds"
    sysevent set static_detect_on_${1} "FAILED"
fi
if [ -n "$(pidof arping)" ]; then
    pkill -SIGTERM -f "arping -f -q -w 3 -I $1"
fi
if [ -n "$(pidof ping)" ]; then
    pkill -SIGTERM -f "ping -4 -c 3 -W 3 -I $1"
fi
ip -4 addr del $v_wan_ipaddr/$v_wan_netmask dev $1
rm -f "$2"
return $RESULT
