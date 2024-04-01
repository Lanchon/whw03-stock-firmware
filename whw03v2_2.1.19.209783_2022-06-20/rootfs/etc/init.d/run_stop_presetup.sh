#!/bin/sh
LAST_DEVICE_ID=`sysevent get presetup::last_device_id`
if [ "" != "$LAST_DEVICE_ID" ] ; then
    /usr/sbin/pub_presetup -u $LAST_DEVICE_ID -s false
    sysevent set presetup::last_device_id ""
fi
