#!/bin/sh
PROG_NAME="$(basename $0)"
ACTION="$1"
EVENT_NAME="$1"
EVENT_VALUE="$2"
PAYLOAD_PATH="$2"
datime () {
    echo -n "$(date -u +'%F %T')"
}
conslog () {
    echo "$(datime): $*" > /dev/console
}
evconslog () {
    local MSG
    if [ $# -gt 0 ]; then
        MSG=": $*"
    fi
    conslog "$PROG_NAME $EVENT_NAME $EVENT_VALUE${MSG}" > /dev/console
}
DBG () {
    if [ $DEBUG ]; then
        $*
    fi
}
req_mod () {
    local MPATH="$1"
    local MNAME="$(basename $MPATH .sh)"
    local LOADED_FLAG="$(eval echo "\$${MNAME}_LOADED")"
    if [ $LOADED_FLAG ]; then
        echo "Module '$MNAME' already loaded"
    else
        source $MPATH
        let "${MNAME}_LOADED=1"
    fi
    return 0
}
clean_file_variants () {
    local STATUS=0
    local FBASE=$1
    shift
    for VARIANT in $@;do
        local VICTIM="${FBASE}${VARIANT}"
        [ $DEBUG ] && echo "clean_file_variants: Would remove '${VICTIM}'"
        [ -f "${VICTIM}" ] && rm "${VICTIM}"
    done
    return $STATUS
}
killall_if_running() {
    local PROCESS_NAME=$1
    local SIG_VAL=$2
    
    pgrep ${PROCESS_NAME} > /dev/null
    if [ "$?" = "0" ]; then
        if [ -z ${SIG_VAL} ]; then
            killall ${PROCESS_NAME}
        else
            killall -${SIG_VAL} ${PROCESS_NAME}
        fi
    fi
}
