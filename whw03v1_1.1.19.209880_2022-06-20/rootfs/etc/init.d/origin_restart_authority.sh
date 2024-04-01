#!/bin/sh
DEFAULT_WAIT_TIME=30
LAST_RESTART_TIME=$( sysevent get origin::last_restart_time )
CURRENT_TIME=$( date +%s )
DEBUG=$( syscfg get origin::debug )
datime () {
    echo -n "$(date -u +'%F %T')"
}
conslog () {
    echo "$(datime) - $0: $*" > /dev/console
}
evconslog () {
    local MSG
    if [ $# -gt 0 ]; then
        MSG="$*"
    fi
    conslog "$PROG_NAME $EVENT_NAME $EVENT_VALUE: ${MSG}" > /dev/console
}
DBG () {
    if [ "$DEBUG" = "1" ]; then
        $*
    fi
}
if [ "$LAST_RESTART_TIME" = "" ]; then
    sysevent set origin::last_restart_time $CURRENT_TIME
    DBG conslog "$0: Setting restart time ( $CURRENT_TIME ) - TRIGGER( $1, $2 )"
else
    while [ $( expr $CURRENT_TIME - $LAST_RESTART_TIME ) -lt $DEFAULT_WAIT_TIME ]
    do
        COUNTER=$( expr $CURRENT_TIME - $LAST_RESTART_TIME )
        REMAINDER=$( expr $DEFAULT_WAIT_TIME - $COUNTER )
        DBG conslog "$0: Restart condition not met, remainder time ( $REMAINDER )"
        sleep 1
        CURRENT_TIME=$( date +%s )
    done
    
    PROC_PID="`ps -w | grep "origin_bot_scanning_start" | grep -v grep | awk '{print $1}'`"
    while [ -n "$PROC_PID" ]
    do
        DBG conslog "$0: Bot scanning is running, wait to restart.... $PROC_PID"
        sleep 1
        PROC_PID="`ps -w | grep "origin_bot_scanning_start" | grep -v grep | awk '{print $1}'`"
    done
    
    sysevent set origin::last_restart_time $CURRENT_TIME
    DBG conslog "$0: Setting restart time ( $CURRENT_TIME ) - TRIGGER( $1, $2 )"
fi