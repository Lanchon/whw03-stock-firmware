#!/bin/sh
[ -z "$PROGNAME" ] && PROGNAME="$(basename $0)"
errout () {
    echo "$*" 1>&2
}
debout () {
    [ "$DEBUG" ] && errout "$*"
}
die() {
    errout "$PROGNAME: " "$*"
    exit 1
}
if_to_ip() {
    ifconfig $1    | \
        grep 'inet addr' | \
        cut -f2 -d:      | \
        cut -f1 -d' '
}
export HOST_ADDR="$(sysevent get master::ip)"
export HOST_PORT="$(syscfg get omsg::port)"
export MODE="$(syscfg get smart_mode::mode)"
export MODE_MASTER=2
export MODE_SLAVE=1
export MODE_UNCONFIG=0
UUID="$(syscfg get device::uuid)"
export UUID
if [ "$MODE" = "$MODE_MASTER" ]; then
    TOPIC_UUID="master"
else
    TOPIC_UUID="$UUID"
fi
export TOPIC_UUID
soft_validate() {
    local RESULT=0
    local VAL="$(eval echo "\$${1}")"
    if [ -z "$VAL" ]; then
        RESULT=1
    fi
    return $RESULT
}
validate() {
    if ! soft_validate $1; then
        die "Error: could not determine $1"
    fi
}
multi_validate () {
    for i in $*; do
        validate $i
    done
}
multi_soft_validate () {
    local RESULT=0
    for i in $*; do
        if ! soft_validate $i; then
            RESULT=1
            break
        fi
    done
    return $RESULT
}
multi_validate HOST_PORT HOST_ADDR TOPIC_UUID UUID
OMSG_USER="$(syscfg get smart_connect::auth_login)"
OMSG_PW="$(syscfg get smart_connect::auth_pass)"
publish() {
    local MSG="$(cat)"
    nohup echo "$MSG" | omsg-publish $1 >& /dev/null &
    sleep 0.25
}
