#!/bin/sh
#
# This script will be called when an LLDP UPDATE event is recieved
#
# $1 = recv interface name
# $2 = mac address of device that sent update packet
source /etc/init.d/lldp_funcs.sh
INTF="$1"
RAW_MAC_ADDR=$2

LOCK_FILE=/tmp/update_handler_$1_$2.lock
lock $LOCK_FILE
if [ $? == 0 ]; then
    /etc/lldp_scripts/update_handler.sh $INTF $RAW_MAC_ADDR &
fi
