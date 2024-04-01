#!/bin/sh
# © 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.

# -----------------------------------------------------------------------------
# DeviceDB and DevidentD has a memory leak, possibly from the same source
# As soon as the root cause is identified and fixed, this workaround
# should be removed.
# -----------------------------------------------------------------------------

source /etc/init.d/ulog_functions.sh

# Search strings to find the process
DEVICEDB="sbin/[d]evicedb"
DEVIDENTD="[d]evidentd"

# -----------------------------------------------------------------------------
# Checks if a process is larger than a certain size
# INPUT
# $1 - Search pattern of the process, should use the bracket trick
#      for grep, otherwise we could get the grep pid instead
# OUTPUT
# RESTART=1 if process should be restarted
# -----------------------------------------------------------------------------
check_process ()
{
    RESTART=0

    # get process info
    # -------------------------------
    local pinfo=`ps | grep -e "$1"`
    if [ "$?" != "0" ]; then
        # process not found, do nothing
        return
    fi

    # check VSZ
    # -------------------------------
    local vsz=`echo "$pinfo" | awk '{print $3}'`

    # check if there's an "m"
    echo "$vsz" | grep -q "m"
    if [ "$?" != "0" ]; then
        # process did not exceed size
        return
    fi

    # check if it's larger than 50m
    local num=`echo "$vsz" | grep -o -e "[0-9]\+"`
    if [ "$num" -lt "50" ]; then
        # process did not exceed size
        return
    fi

    RESTART=1
}

# -----------------------------------------------------------------------------
# Start
# -----------------------------------------------------------------------------
check_process "$DEVICEDB"
if [ "$RESTART" == "1" ]; then
    /etc/init.d/service_devicedb.sh devicedb-restart
    ulog service devidentd "deviceDB restarted due to memory issue"
fi

check_process "$DEVIDENTD"
if [ "$RESTART" == "1" ]; then
    sysevent set devidentd-restart
    ulog service devidentd "devidentd restarted due to memory issue"
fi

