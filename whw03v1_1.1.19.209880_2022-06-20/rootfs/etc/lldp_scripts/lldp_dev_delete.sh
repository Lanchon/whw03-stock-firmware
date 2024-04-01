#!/bin/sh
#
# This script will be called when an LLDP DELETE event is recieved
#
# $1 = recv interface name
# $2 = mac address of device that sent update packet

# omsg publication deprecated Thu Aug 10 10:00:50 PDT 2017 by dash.
# It appears that no one uses the LLDP data sent to the Master.  I'm
# commenting this out for now and will revisit for complete removal at
# a later date.  If you have a need for this and would like this
# functionality restored, contact dash (darrell.shively@belkin.com).

# source /etc/init.d/sub_pub_funcs.sh
#
# INTF="$1"
# MAC_HYPHENATED="$(echo $2 | sed 's/:/-/g')"
#
# PUB_TOPIC="$(omsg-conf --master LLDP_delete | \
#              sed "s/+/$UUID/"               | \
#              sed "s/+/$INTF/"               | \
#              sed "s/+/$MAC_HYPHENATED/" )"
#
# mk_infra_payload       \
#     --type=cmd         \
#     --UUID=$UUID       \
#     --set="intf:$INTF" \
#     --set="mac:$MAC" | publish $PUB_TOPIC
