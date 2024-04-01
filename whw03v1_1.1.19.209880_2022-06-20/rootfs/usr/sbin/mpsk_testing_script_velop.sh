#!/bin/sh
PASS_DEFAULT="linksys"
MAC_MULTI="00:00:00:00:00:00"
IF_DEFAULT="ath0"

MPSK_CONFIG_FILE="/tmp/hostapd.mpsk"
DELAY=30
COUNT=1

while [ $COUNT -lt 101 ]
do
    LOG_TIME=`date +%T`
    echo "$LOG_TIME: >>>>>>>>>>>>>>>>>>>>>> Add new passwork for interface $IF_DEFAULT: $MAC_MULTI $PASS_DEFAULT$COUNT"
    /usr/sbin/update_mpsk_file.sh -a -i $IF_DEFAULT -m $MAC_MULTI -p "$PASS_DEFAULT$COUNT"
    COUNT=$(($COUNT + 1))
    sleep $DELAY
done
