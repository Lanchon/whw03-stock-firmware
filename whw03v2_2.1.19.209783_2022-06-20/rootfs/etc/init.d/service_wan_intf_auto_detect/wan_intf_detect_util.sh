#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/resolver_functions.sh
DHCP_DETECT_SCRIPT=/etc/init.d/service_wan_intf_auto_detect/dhcp_detect.sh
PPPOE_DETECT_SCRIPT=/etc/init.d/service_wan_intf_auto_detect/pppoe_detect.sh
STATIC_DETECT_SCRIPT=/etc/init.d/service_wan_intf_auto_detect/static_detect.sh
isolate_lan_eth_intf_from_bridge ()
{
    local bridge=`syscfg get lan_ifname`
    local lan_eth_intf=`syscfg get lan_ethernet_physical_ifnames`
    if [ -n "$bridge" -a -n "$lan_eth_intf" ]; then
        brctl delif "$bridge" "$lan_eth_intf"
    else
        ulog $SRV_NAME $SUB_COMP "$PID bridge name or ethernet lan interface missing, please check"
    fi
}
enslave_lan_eth_intf_to_bridge ()
{
    local bridge=`syscfg get lan_ifname`
    local lan_eth_intf=`syscfg get lan_ethernet_physical_ifnames`
    if [ -n "$bridge" -a -n "$lan_eth_intf" ]; then
        brctl addif "$bridge" "$lan_eth_intf"
    else
        ulog $SRV_NAME $SUB_COMP "$PID bridge name or ethernet lan interface missing, please check"
    fi
}
save_wan_intf_setting ()
{
    if [ -z "$1" -o -z "$2" -o "$1" = "$2" ]; then
        return 1
    fi
    local wan_intf="$1"
    local lan_intf="$2"
    syscfg set wan_physical_ifname $wan_intf
    syscfg set wan_1::ifname $wan_intf
    syscfg set wan_1::wan_physical_ifname $wan_intf
    syscfg set wan_2::wan_physical_ifname $wan_intf
    syscfg set lan_ethernet_physical_ifnames $lan_intf
    syscfg commit
    local vlan_script="/usr/sbin/vlan_setup.sh"
    [ -x "$vlan_script" ] && eval "$vlan_script"
    return 0
}
update_vlan_backhaul ()
{
    if [ "`syscfg get smart_mode::mode`" = "2" ] ; then
        wan_physical_ifname=$(syscfg get wan_physical_ifname)
        lan_physical_ifname=$(syscfg get lan_ethernet_physical_ifnames)
        svap_vlan_id=$(syscfg get svap_vlan_id)
        svap_lan_ifname=$(syscfg get svap_lan_ifname)
        delete_vlan_from_backhaul "$wan_physical_ifname" "$svap_vlan_id" "$svap_lan_ifname"
        add_vlan_to_backhaul "$lan_physical_ifname" "$svap_vlan_id" "$svap_lan_ifname"
        hk_vlan_id=$(syscfg get lrhk::vlan_id)
        hk_ifname=$(syscfg get lrhk::ifname)
        delete_vlan_from_backhaul "$wan_physical_ifname" "$hk_vlan_id" "$hk_ifname"
        add_vlan_to_backhaul "$lan_physical_ifname" "$hk_vlan_id" "$hk_ifname"
 
        guest_enabled=$(syscfg get guest_enabled)
        if [ "$guest_enabled" == "1" ] ; then
        	guest_vlan_id=$(syscfg get guest_vlan_id)
        	guest_lan_ifname=$(syscfg get guest_lan_ifname)
        	delete_vlan_from_backhaul "$wan_physical_ifname" "$guest_vlan_id" "$guest_lan_ifname"
        	add_vlan_to_backhaul "$lan_physical_ifname" "$guest_vlan_id" "$guest_lan_ifname"
        fi
    fi    
}
map_link_state ()
{
    LINK="$1"
}
lldp_neighbor_check()
{
    if [ -z "$1" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID lldp check: intf is not specified"
        return 10
    fi
    local NB_DIR="/tmp/nb/${1}"
    if [ ! -e "$NB_DIR" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID lldp check:lldp log dir not exist"
        return 0
    fi
    LLDP_ITEMS=`ls -1 $NB_DIR`
    if [ -z "$LLDP_ITEMS" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID lldp check: no item in log dir"
        return 0
    fi
    
    item_num=`ls -1 $NB_DIR | wc -l`
    if [ $item_num -gt 1 ]; then
        return 10
    fi
    item=$LLDP_ITEMS
    peer_dsp=`cat ${NB_DIR}/${item} | grep -E ^'chassis\.descr' | cut -d'=' -f2`
    if [ "$peer_dsp" = "Velop" ]; then
        peer_mode="`cat ${NB_DIR}/${item} | grep -E ^mode | cut -d'=' -f2`"
        case ${peer_mode} in 
            "00")
                ulog $SRV_NAME $SUB_COMP "$PID lldp check: unconfigured nodes"
                return 2
                ;;
            "01")
                peer_ra="`cat ${NB_DIR}/${item} | grep -E ^ra | cut -d'=' -f2`"
                if [ "$peer_ra" = "01" ]; then
                    ulog $SRV_NAME $SUB_COMP "$PID lldp check: slave nodes with RA=1 "
                    return 5
                else
                    ulog $SRV_NAME $SUB_COMP "$PID lldp check: slave nodes with RA=0"
                    return 4
                fi
                ;;
            "02")
                ulog $SRV_NAME $SUB_COMP "$PID lldp check: master nodes"
                return 3
                ;;
            *)
                ulog $SRV_NAME $SUB_COMP "$PID lldp check: unrecongnized mode $peer_mode"
                return 10
                ;;
        esac
    else
        ulog $SRV_NAME $SUB_COMP "$PID lldp check: not velop devices"
        return 1
    fi
    ulog $SRV_NAME $SUB_COMP "$PID lldp check: end, return error"
    return 10
}
