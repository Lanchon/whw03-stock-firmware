#!/bin/sh
source /etc/init.d/ulog_functions.sh
SRV_NAME="wan_intf_auto_detect"
SUB_COMP="bridge_link_detect"
if [ "`syscfg get smart_mode::mode`" = "1" ]; then
    ulog $SRV_NAME $SUB_COMP "bridge wan detection would not run on slave nodes"
    exit
fi
if [ "$(syscfg get wan::intf_auto_detect_debug)" = "1" ]; then
    set -x
fi
port0_status=`sysevent get ETH::port_5_status`
port1_status=`sysevent get ETH::port_4_status`
current_wan_link=`sysevent get phylink_wan_state`
bridge_mode=`syscfg get bridge_mode`
if [ "$port0_status" = "down" -a "$port1_status" = "down" ]; then
    ulog $SRV_NAME $SUB_COMP "both ports disconnected, phylink_wan_state is down"
    if [ "$current_wan_link" != "down" ];  then
        sysevent set phylink_wan_state down
    fi
    exit
else
    if [ "$current_wan_link" = "up" ]; then
        if [ "$2" = "up" ]; then
            ulog $SRV_NAME $SUB_COMP "port connected, phylink_wan_state is already up"
            exit
        else
            ulog $SRV_NAME $SUB_COMP "port disconnected, check phylink_wan_state"
            case $bridge_mode in
                1)
                    default_gateway=`sysevent get default_router`
                    ;;
                2)
                    default_gateway=`syscfg get bridge_default_gateway`
                    ;;
                *)
                    ulog $SRV_NAME $SUB_COMP "invalid bridge mode=$bridge_mode"
                    exit
                    ;;
            esac
            if [ -z "$default_gateway" ]; then
                ulog $SRV_NAME $SUB_COMP "no default gateway in bridge mode"
                exit
            else
                ping -4 -q -c 2 -W 4 $default_gateway > /dev/null
                ret="$?"
                ulog $SRV_NAME $SUB_COMP "ping bridge gateway, result=$ret"
                wan_link_new=`sysevent get phylink_wan_state`
                if [ "$ret" != "0" ]; then
                    if [ "$wan_link_new" != "down" ]; then
                        sysevent set phylink_wan_state down
                    fi
                else
                    if [ "$wan_link_new" != "up" ]; then
                        sysevent set phylink_wan_state up
                    fi
                fi
            fi
        fi
    else
        if [ "$2" = "down" ]; then
            ulog $SRV_NAME $SUB_COMP "port disconnected, phylink_wan_state is already down"
            exit
        else
            case $bridge_mode in
                1)
                    BRIDGE_DHCP_DETECT_SCRIPT=/etc/init.d/service_wan_intf_auto_detect/dhcp_detect.sh
                    br_dhcp_detect_pid_file=/tmp/bridge_dhcp_detect_file.pid
                    br_intf=`syscfg get lan_ifname`
                    if [ -e "$br_dhcp_detect_pid_file" ]; then
                        ulog $SRV_NAME $SUB_COMP "bridge dhcp detect is running, no need to fire another"
                        exit
                    fi
                    $BRIDGE_DHCP_DETECT_SCRIPT "$br_intf" "$br_dhcp_detect_pid_file"
                    ret="$?"
                    ulog $SRV_NAME $SUB_COMP "bridge try to get ip addr, result=$ret"
                    wan_link_new=`sysevent get phylink_wan_state`
                    if [ "$ret" = "1" ]; then
                        if [ "$wan_link_new" != "up" ]; then
                            sysevent set phylink_wan_state up
                        fi
                    else
                        if [ "$wan_link_new" != "down" ]; then
                            sysevent set phylink_wan_state down
                        fi
                    fi
                    ;;
                2)
                    default_gateway=`syscfg get bridge_default_gateway`
                    if [ -z "$default_gateway" ]; then
                        ulog $SRV_NAME $SUB_COMP "no default gateway in bridge mode $bridge_mode"
                        exit
                    fi
                    sleep 3
                    ping -4 -q -c 2 -W 4 $default_gateway > /dev/null
                    ret="$?"
                    ulog $SRV_NAME $SUB_COMP "ping bridge gateway, result=$ret"
                    if [ "$ret" = "0" ]; then
                        if [ "$wan_link_new" != "up" ]; then
                            sysevent set phylink_wan_state up
                        fi
                    else
                        if [ "$wan_link_new" != "down" ]; then
                            sysevent set phylink_wan_state down
                        fi
                    fi
                    ;;
                *)
                    ulog $SRV_NAME $SUB_COMP "invalid bridge mode=$bridge_mode"
                    exit
                    ;;
            esac
        fi
    fi
fi
