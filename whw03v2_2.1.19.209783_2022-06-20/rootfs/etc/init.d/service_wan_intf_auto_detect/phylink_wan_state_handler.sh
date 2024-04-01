#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/resolver_functions.sh
SRV_NAME="wan_intf_auto_detect"
SUB_COMP="phylink_wan_state_handler"
ulog $SRV_NAME $SUB_COMP "Received event $1: $2"
if [ -n "$2" ]; then
    sysevent set phylink_wan_state "$2"
fi
