#!/bin/sh
source /etc/init.d/addr_functions.sh
LOCKFILE=/tmp/fpbypass_build_bypass.lock
lock()
{
    lockfile=$1
    lockwait=${2:-5}
    for i in `seq 1 "$lockwait"`; do
        if (set -o noclobber; echo "$$" > "$lockfile") 2> /dev/null; then
            trap 'rm -f "$lockfile"; exit $?' INT TERM EXIT;
            return 0;
        fi
        sleep 1
    done
    return 1
}
unlock()
{
    lockfile=$1
    rm -f "$lockfile"
    trap - INT TERM EXIT
}
build_bypass_for_parental_control()
{
    pmax=`syscfg get parental_control_policy_count`
    for pidx in `seq 1 "$pmax"`; do
        policy=`syscfg get parental_control_policy_$pidx`
        dmax=`syscfg get $policy::blocked_device_count`
        for didx in `seq 1 "$dmax"`; do
            mac=`syscfg get $policy::blocked_device_$didx`
	    echo "smac=$mac" > /proc/sys/net/ecm/fpbypass_ipv4_add
	    echo "smac=$mac" > /proc/sys/net/ecm/fpbypass_decelerate_onemac
        done
    done
}
rebuild_bypass_list()
{
    lock $LOCKFILE
    if [ "$?" -eq 0 ]; then
        eval `utctx_cmd get fastpath_enable parental_control_enabled`
        if [ "$SYSCFG_fastpath_enable" -eq 1 ]; then
            echo 1 > /proc/sys/net/ecm/fpbypass_ipv4_clear
            if [ "$SYSCFG_parental_control_enabled" -eq "1" ]; then
                build_bypass_for_parental_control
            fi
        fi
        unlock $LOCKFILE
    fi
}
set_lan_net()
{
    if [ -f /proc/sys/net/ecm/fpbypass_ipv4_set_lan ]; then
        lan_ipaddr=`syscfg get lan_ipaddr`
	if [ "$lan_ipaddr" != "" ]; then
        	echo "s=$lan_ipaddr lan=1" > /proc/sys/net/ecm/fpbypass_ipv4_set_lan 
	fi
    fi
}
unset_lan_net()
{
    if [ -f /proc/sys/net/ecm/fpbypass_ipv4_set_lan ]; then
	echo "lan=0" > /proc/sys/net/ecm/fpbypass_ipv4_set_lan
    fi
}
set_wan_ip()
{
    if [ -f /proc/sys/net/ecm/fpbypass_ipv4_set_wan ]; then
        wan_ip=`sysevent get ipv4_wan_ipaddr`
	if [ "$wan_ip" != "" ]; then
		echo "s=$wan_ip wan=1" > /proc/sys/net/ecm/fpbypass_ipv4_set_wan
	fi
    fi
}
unset_wan_ip()
{
    if [ -f /proc/sys/net/ecm/fpbypass_ipv4_set_wan ]; then
	echo "wan=0" > /proc/sys/net/ecm/fpbypass_ipv4_set_wan
    fi
}
echo "nss_build_bypass is called with $1" > /dev/console
if [ ! -f /proc/sys/net/ecm/fpbypass_all ]; then
    exit 0
fi
fastpath_status=`sysevent get fastpath-status`
if [  "$fastpath_status" != "started" -a "$fastpath_status" != "starting" ]; then
    exit 0
fi
case "$1" in
    lan_dhcp_client_change)
        rebuild_bypass_list
        ;;
    lan_device_detected)
        rebuild_bypass_list
        ;;
    lan_arpdevice_detected)
        rebuild_bypass_list
        ;;
    lan_nbtdevice_detected)
        rebuild_bypass_list
        ;;
    ddd_device_online)
	rebuild_bypass_list
	;;
    lan-started)
        set_lan_net
        ;;
    lan-stopped)
        unset_lan_net
        ;;
    ipv4_wan_ipaddr)
        set_wan_ip
        ;;
    wan-stopped)
        unset_wan_ip
        ;;
    guardian-configured)
        rebuild_bypass_list
        ;;  
    build_bypass)
        rebuild_bypass_list
	set_lan_net
	set_wan_ip
        ;;
esac
