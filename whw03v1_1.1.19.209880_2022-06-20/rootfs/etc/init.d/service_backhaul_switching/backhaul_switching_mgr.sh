#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/service_backhaul_switching/backhaul_utils.sh
BACKHAUL_SWITCHING_MGR_HANDLER="/etc/init.d/service_backhaul_switching/backhaul_mgr.sh"
SRV_NAME="backhaul_switching"
SUB_COMP="backhaul_switching_mgr"
PID="$$"
EVENT=$1
if [ "$(syscfg get ${SRV_NAME}_debug)" = "1" ]; then
    set -x
fi
linkstate_changed () 
{
    intf=$1
    value=$2
    if [ "${value}" == "down" ] && [ "$(sysevent get backhaul::intf)" == "${intf}" ] ; then
        if [ "$(sysevent get ETH::port_1_status)" == "up" ] ||  [ "$(sysevent get ETH::port_2_status)" == "up" ] || [ "$(sysevent get ETH::port_3_status)" == "up" ] ||  [ "$(sysevent get ETH::port_4_status)" == "up" ] || [ "$(sysevent get ETH::port_5_status)" == "up" ]  ; then
            ip_connection_down
            if [ "$?" == "1" ] ; then
                exit 1
            fi
        fi
        sysevent set dhcp_client-restart
	sysevent set setup_dhcp_client-restart
        sysevent set lldp::root_intf
        sysevent set backhaul::status down
        sysevent set backhaul::media 2        
        sysevent set lldp::root_accessible 0 
        echo "${SRV_NAME}, wired backhaul is down,will trigger lldpd-reconfig.."
    elif [ "${value}" == "up" ] ; then
        if [ "$guest_enabled" = "1" ] ; then
            add_vlan_to_backhaul "$1" "$guest_vlan_id" "$guest_lan_ifname"
        fi         
        add_vlan_to_backhaul "$1" "$svap_vlan_id" "$svap_lan_ifname"
        if [ -n "$(syscfg get lrhk::ifname)" ] ; then
            hk_vlan_id="`syscfg get lrhk::vlan_id`"
            hk_ifname="`syscfg get lrhk::ifname`"
            add_vlan_to_backhaul "$1" "$hk_vlan_id" "$hk_ifname"
        fi
    else
    	echo "${SRV_NAME}, linkstate down is not the backhaul interface.."
    fi
}
ulog $SRV_NAME status "event $EVENT $2 received on $SUB_COMP"
echo $SRV_NAME status "event $EVENT $2 received on $SUB_COMP"
case $EVENT in
    ETH::port_1_status|ETH::port_2_status|ETH::port_3_status|ETH::port_4_status|ETH::port_5_status)
        linkstate_changed $bridge_intf $2
        ;;
    backhaul::media)
        if [ "`sysevent get wifi-status`" == "started" ] ; then
            do_backhaul_check
        else
            echo "Backhaul media $2 received, but wifi status is not started. Will do backhaul check later" > /dev/console
        fi
        ;;
    default_router)
        if [ "$2" != "" ] && [ "$2" != "NULL" ] ; then
            if [ "$(syscfg get smart_mode::mode)" == "1" ] && [ "$(sysevent get backhaul::media)" != "1" ] ; then
                /etc/init.d/service_backhaul_switching/backhaul_check.sh &
            fi
        fi
        ;;        
    wifi-status)
        if [ "$2" == "started" ] ; then
            do_backhaul_check
        fi
        ;;               
    *)
        echo "Event $EVENT received, no handler for this" > /dev/console
        exit 1
        ;;
esac
