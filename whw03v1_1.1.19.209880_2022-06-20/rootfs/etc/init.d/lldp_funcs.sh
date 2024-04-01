#!/bin/sh
compose_stat_path () {
    local FILE_DIR="$1"
    local INTF="$2"
    local MAC_ADDR="$3"
    echo "${FILE_DIR}/nb/${INTF}/${MAC_ADDR}.txt"
}
pub_lldp_status () {
    local STAT_FILE="$1"
    if [ -f "$STAT_FILE" ] ; then
        source /etc/init.d/sub_pub_funcs.sh
        local MAC_HYPHENATED="$(echo $2 | sed 's/:/-/g')"
        local INTF="$3"
        multi_validate MAC_HYPHENATED INTF UUID
        PUB_TOPIC="$(omsg-conf --master LLDP_status | \
                 sed "s/+/$UUID/"                   | \
                 sed "s/+/$INTF/"                   | \
                 sed "s/+/$MAC_HYPHENATED/" )"
        lldp_to_json --mac=$MAC_ADDR  \
                     --interface=$INTF \
                     "$STAT_FILE" | publish "$PUB_TOPIC"
    fi
}
update_se_if_changed (  ) {
	curval="`sysevent get $1`"
	if [ "$2" != "$curval" ] ; then
		if [ "`syscfg get lldpd::debug`" == "1" ] ; then
			echo "`date` update $1 => $2" >> /tmp/lldp.dbg.log
		fi
		sysevent set $1 $2
	fi
}
update_RA () {
	update_se_if_changed lldp::root_accessible "$1"
}
update_BM () {
	update_se_if_changed backhaul::media "$1"
}
ip_connection_down ()
{
    lan_ifname="$(syscfg get lan_ifname)"
    master_ip="$(sysevent get master::ip)"
    if [ "${master_ip}" == "" ] ; then
        master_ip="$(sysevent get lldp::root_address)"
    fi
    arping -I ${lan_ifname} -f -w 1 ${master_ip}
    if [ "$?" = "0" ]; then
        return 1
    fi
    return 0
}
lock()
{
    local LOCK_FILE=$1
    if (set -o noclobber; echo "$$" > "$LOCK_FILE") 2> /dev/null; then    # Try to lock a file
        trap 'rm -f "$LOCK_FILE"; exit $?' INT TERM;                     # Remove a lock file in abnormal termination.
        return 0;                                    # Locked
    fi
    return 1                                                   # Failure
}
 
unlock()
{
    local LOCK_FILE=$1
 
    rm -f "$LOCK_FILE"                                  # Remove a lock file
    trap - INT TERM EXIT
 
    return 0
}
