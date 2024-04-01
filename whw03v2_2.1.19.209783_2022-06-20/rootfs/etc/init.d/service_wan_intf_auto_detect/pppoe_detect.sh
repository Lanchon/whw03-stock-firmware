#!/bin/sh
source /etc/init.d/ulog_functions.sh
SRV_NAME="wan_intf_auto_detect"
SUB_COMP="pppoe_detect"
if [ "$(syscfg get wan::intf_auto_detect_debug)" = "1" ]; then
    set -x
fi
if [ -z "$1" -o -z "$2" ]; then
    ulog $SRV_NAME $SUB_COMP "interface missing,pppoe detect abort"
    return 2
fi
pid_file="$2"
echo "$$" > $pid_file
trap 'rm -f "$pid_file"' INT TERM EXIT;
ulog $SRV_NAME $SUB_COMP "pppoe detect starts on $1"
date_start=$(date +%s)
RESULT="0"
for intf in $1
do
    pppoe -a -t 3 -b 5 -T 3 -I $intf > /dev/null 2>&1
    ret=$?
    if [ "$ret" = "0" ]; then
        RESULT="1"
        break
    fi
done
    
date_end=$(date +%s)
time_spend=$(expr $date_end - $date_start)
if [ "$RESULT" = "1" ]; then
    ulog $SRV_NAME $SUB_COMP "detect result: Yes, spent $time_spend seconds"
    sysevent set pppoe_detect_on_${1} "DETECTED"
else
    ulog $SRV_NAME $SUB_COMP "detect result: No, spent $time_spend seconds"
    sysevent set pppoe_detect_on_${1} "FAILED"
fi
if [ -n "$(pidof pppoe)" ]; then
    pkill -SIGTERM -f "pppoe -a -t 3 -b 5 -T 3"
fi
rm -f "$2"
return $RESULT
