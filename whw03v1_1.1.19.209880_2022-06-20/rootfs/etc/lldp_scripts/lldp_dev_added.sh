#!/bin/sh
#
# This script will be called when an LLDP ADD event is recieved
#
# $1 = recv interface name
# $2 = mac address of device that sent update packet

#echo "lldp device added Interface:$1, MAC:$2"
source /etc/init.d/lldp_funcs.sh
INTF="$1"
RAW_MAC_ADDR=$2

LOCK_FILE=/tmp/added_handler_$1_$2.lock
lock $LOCK_FILE
if [ $? == 0 ]; then
    /etc/lldp_scripts/added_handler.sh $INTF $RAW_MAC_ADDR &
fi
