#!/bin/sh
REQUEST_ID=$$_$(date -u +%s)
OPTION="$1 $2"
CHKOPTION=""
case "$1" in
    -d)
        REQUEST="scanunconfigured"
        SYSEVENT_VAR="bt::${REQUEST}_status"
        ;;
    -c)
        REQUEST="connect"
        SYSEVENT_VAR="bt::${REQUEST}_status"
        ;;
    -t)
        REQUEST="disconnect"
        SYSEVENT_VAR="bt::${REQUEST}_status"
        ;;
    -D)
        REQUEST="scanbackhauldownslave"
        SYSEVENT_VAR="bt::${REQUEST}_status"
        ;;
    -p)
        REQUEST="getsmartconnectpin"
        SYSEVENT_VAR="btsmart_connect::${REQUEST}_status"
        ;;
    -s)
        REQUEST="getsmartconnectstatus"
        SYSEVENT_VAR="btsmart_connect::${REQUEST}_status"
        ;;
    -S)
        REQUEST="startsmartconnectclient"
        SYSEVENT_VAR="btsmart_connect::${REQUEST}_status"
        ;;
    -g)
        REQUEST="getslavesetupstatus"
        SYSEVENT_VAR="btsmart_connect::${REQUEST}_status"
        ;;
    -V)
        REQUEST="getversioninfo"
        SYSEVENT_VAR="btsmart_connect::${REQUEST}_status"
        ;;
    *)
        CHKOPTION="Invalid"
        ;;
esac
OUTFILE=/tmp/central.txt.${REQUEST}
if [ "Invalid" = "$CHKOPTION" ] ; then
    exit 1
else
    echo $REQUEST_ID
fi
sysevent set $SYSEVENT_VAR "Running"
/usr/bin/btsetup_central $OPTION > $OUTFILE 2>/dev/null
sysevent set $SYSEVENT_VAR ""
