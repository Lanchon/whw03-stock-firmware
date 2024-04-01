#!/bin/sh

# This is sysevent handler for:
# lrhk::update_violation <mac>|<time stamp>
#
# This differs from lrhk::accessviolation. lrhk::update_violation will
# write the access violation date into database. Then after that's done,
# the LRHK library will trigger lrhk::accessviolation to notify the ADK
# via PAL. We have two sysevents because if ADK is triggered first
# then the data won't be available yet.

# check if we're on slave, this does not run on slave
mode=`syscfg get smart_mode::mode`
if [ "$mode" == "1" ]; then
    exit 0
fi

# $1 - sysevent name
# $2 - sysevent value
mac=`echo "$2" | awk -F '|' '{print $1}'`
timestamp=`echo "$2" | awk -F '|' '{print $2}'`

result=`/usr/sbin/lrhk_util -u updateViolation "$mac" "$timestamp"`

# if the update changed the database then we trigger backup
if [ "$result" == "updated" ]; then
    /usr/sbin/lrhk_util --backup
fi


