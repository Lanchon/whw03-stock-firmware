#!/bin/sh
source /etc/init.d/event_flags
source /etc/init.d/service_wan_intf_auto_detect/wan_intf_detect_util.sh
SRV_NAME="wan_intf_auto_detect"
PID="$$"
EVENT=$1
if [ "$(syscfg get wan::intf_auto_detect_debug)" = "1" ]; then
    set -x
fi
register_phylink_event_handler ()
{
    if [ "$WAN_INTF_AUTO_DETECT_ENABLED" = "1" ]; then
        if [ "$bridge_mode" != "0" ]; then
	        cb_id=`sysevent async $port0_link_event /etc/init.d/service_wan_intf_auto_detect/bridge_wan_link_detect.sh`
	        sysevent set port0-status_cb_id "$cb_id"
	        cb_id=`sysevent async $port1_link_event /etc/init.d/service_wan_intf_auto_detect/bridge_wan_link_detect.sh`
	        sysevent set port1-status_cb_id "$cb_id"
	    else
	        cb_id=`sysevent async $port0_link_event /etc/init.d/service_wan_intf_auto_detect/wan_intf_detect_mgr.sh`
	        sysevent set port0-status_cb_id "$cb_id"
	        cb_id=`sysevent async $port1_link_event /etc/init.d/service_wan_intf_auto_detect/wan_intf_detect_mgr.sh`
	        sysevent set port1-status_cb_id "$cb_id"
		    cb_id=`sysevent async force_wan_intf_detect /etc/init.d/service_wan_intf_auto_detect/wan_intf_detect_mgr.sh`
	        sysevent set force_wan_intf_detect_cb_id "$cb_id"
	        sysevent setoptions force_wan_intf_detect $TUPLE_FLAG_EVENT
	
	        cb_id=`sysevent async wan_port_changed /etc/init.d/service_wan_intf_auto_detect/wan_intf_detect_mgr.sh`
	        sysevent set wan_port_changed_cb_id "$cb_id"
	        sysevent setoptions wan_port_changed $TUPLE_FLAG_EVENT
        fi
	else
        cb_id=`sysevent async $wan_port_link_event /etc/init.d/service_wan_intf_auto_detect/phylink_wan_state_handler.sh`
        sysevent set wan_port_link_event_cb_id "$cb_id"
    fi
}
unregister_phylink_event_handler ()
{
        cb_id=`sysevent get port0-status_cb_id`
        if [ -n "$cb_id" ]; then
            sysevent rm_async $cb_id
            sysevent set port0-status_cb_id
        fi
    
        cb_id=`sysevent get port1-status_cb_id`
        if [ -n "$cb_id" ]; then
            sysevent rm_async $cb_id
            sysevent set port1-status_cb_id
        fi
	
	    cb_id=`sysevent get force_wan_intf_detect_cb_id`
        if [ -n "$cb_id" ]; then
            sysevent rm_async $cb_id
            sysevent set force_wan_intf_detect_cb_id
        fi
	    cb_id=`sysevent get wan_port_changed_cb_id`
        if [ -n "$cb_id" ]; then
            sysevent rm_async $cb_id
            sysevent set wan_port_changed_cb_id
        fi
        cb_id=`sysevent get wan_port_link_event_cb_id`
        if [ -n "$cb_id" ]; then
            sysevent rm_async $cb_id
            sysevent set wan_port_link_event_cb_id
        fi
}
start_protocol_detection_on_intf ()
{
    if [ -z "$1" ]; then
        return 2
    fi
    local dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
    local pppoe_detect_pid_file=/tmp/pppoe_detect_${1}.pid
    
    sysevent set dhcp_detect_on_"${1}"
    sysevent set pppoe_detect_on_"${1}"
    
    $DHCP_DETECT_SCRIPT "$1" "$dhcp_detect_pid_file" &
    $PPPOE_DETECT_SCRIPT "$1" "$pppoe_detect_pid_file" &
    
    return 0
}
stop_protocol_detection_on_intf ()
{
    if [ -z "$1"]; then
        return 2
    fi
    local dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
    local pppoe_detect_pid_file=/tmp/pppoe_detect_${1}.pid
    
    local dhcp_detect_pid=`cat $dhcp_detect_pid_file`
    local pppoe_detect_pid=`cat $pppoe_detect_pid_file`
    if [ -n "$dhcp_detect_pid" ]; then
        kill $dhcp_detect_pid
    fi
    if [ -n "$pppoe_detect_pid" ]; then
        kill $pppoe_detect_pid
    fi
    sleep 1    
    return 0
}
check_protocol_detection_result ()
{
    PROTO=""
    WAN_INTF=""
    if [ "$is_port0_running" = "1" ]; then
        dhcp_detect_port0_status=`sysevent get dhcp_detect_on_${port0_intf}`
        pppoe_detect_port0_status=`sysevent get pppoe_detect_on_${port0_intf}`
        
        if [ "$dhcp_detect_port0_status" = "DETECTED" ]; then
            is_port0_running="0"
            PROTO="dhcp"
            WAN_INTF="$port0_intf"
            return 1
        fi
        if [ "$pppoe_detect_port0_status" = "DETECTED" ]; then
            is_port0_running="0"
            PROTO="pppoe"
            WAN_INTF="$port0_intf"
            return 1
        fi
        
        if [ "$dhcp_detect_port0_status" = "FAILED" -a "$pppoe_detect_port0_status" = "FAILED" ] ; then
            is_port0_running="0"
        fi
    fi
    if [ "$is_port1_running" = "1" ]; then
        dhcp_detect_port1_status=`sysevent get dhcp_detect_on_${port1_intf}`
        pppoe_detect_port1_status=`sysevent get pppoe_detect_on_${port1_intf}`
        
        if [ "$dhcp_detect_port1_status" = "DETECTED" ]; then
            is_port1_running="0"
            PROTO="dhcp"
            WAN_INTF="$port1_intf"
            return 1
        fi
        if [ "$pppoe_detect_port1_status" = "DETECTED" ]; then
            is_port1_running="0"
            PROTO="pppoe"
            WAN_INTF="$port1_intf"
            return 1
        fi
        
        if [ "$dhcp_detect_port1_status" = "FAILED" -a "$pppoe_detect_port1_status" = "FAILED" ] ; then
            is_port1_running="0"
        fi
    fi
    
    PROTO=""
    WAN_INTF=""
    return 0
}
start_intf_detection_on_intf ()
{
    if [ -z "$1" ]; then
        return 2
    fi
    
    local wan_proto="`syscfg get wan_proto`"
    local dhcp_detect_pid_file
    local pppoe_detect_pid_file
    local static_detect_pid_file
    
    case "$wan_proto" in
        "dhcp")
            sysevent set dhcp_detect_on_${1}
            dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
            $DHCP_DETECT_SCRIPT "$1" "$dhcp_detect_pid_file" &
        ;;
        
        "pppoe")
            sysevent set pppoe_detect_on_${1}
            pppoe_detect_pid_file=/tmp/pppoe_detect_${1}.pid
            $PPPOE_DETECT_SCRIPT "$1" "$pppoe_detect_pid_file" &
        ;;
        
        "static")
            sysevent set static_detect_on_${1}
            static_detect_pid_file=/tmp/static_detect_${1}.pid
            $STATIC_DETECT_SCRIPT "$1" "$static_detect_pid_file" &
        ;;
        
        "pptp")
            local pptp_address_static=`syscfg get pptp_address_static`
            if [ "$pptp_address_static" = "1" ]; then
                sysevent set static_detect_on_${1}
                static_detect_pid_file=/tmp/static_detect_${1}.pid
                $STATIC_DETECT_SCRIPT "$1" "$static_detect_pid_file" &
            else
                sysevent set dhcp_detect_on_${1}
                dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
                $DHCP_DETECT_SCRIPT "$1" "$dhcp_detect_pid_file" &
            fi
        ;;
        "l2tp")
            local pptp_address_static=`syscfg get l2tp_address_static`
            if [ "$l2tp_address_static" = "1" ]; then
                sysevent set static_detect_on_${1}
                static_detect_pid_file=/tmp/static_detect_${1}.pid
                $STATIC_DETECT_SCRIPT "$1" "$static_detect_pid_file" &
            else
                sysevent set dhcp_detect_on_${1}
                dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
                $DHCP_DETECT_SCRIPT "$1" "$dhcp_detect_pid_file" &
            fi
        ;;
        *)
            return 2
        ;;
    esac
    
    return 0
    
}
stop_intf_detection_on_intf ()
{
    if [ -z "$1"]; then
        return 2
    fi
    
    local wan_proto="`syscfg get wan_proto`"
    local dhcp_detect_pid_file
    local dhcp_pid
    local pppoe_detect_pid_file
    local pppoe_pid
    local static_detect_pid_file
    local static_pid
    
    case "$wan_proto" in
        "dhcp")
            dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
            dhcp_pid=`cat $dhcp_detect_pid_file`
            if [ -n "$dhcp_pid" ]; then
                kill $dhcp_pid
            fi
            ;;
        "pppoe")
            pppoe_detect_pid_file=/tmp/pppoe_detect_${1}.pid
            pppoe_pid=`cat $pppoe_detect_pid_file`
            if [ -n "$pppoe_pid" ]; then
                kill $pppoe_pid
            fi       
            ;;
        "static")
            static_detect_pid_file=/tmp/static_detect_${1}.pid
            static_pid=`cat $static_detect_pid_file`
            if [ -n "$static_pid" ]; then
                kill $static_pid
            fi          
            ;;
        "pptp")
            local pptp_address_static=`syscfg get pptp_address_static`
            if [ "$pptp_address_static" = "1" ]; then
                static_detect_pid_file=/tmp/static_detect_${1}.pid
                static_pid=`cat $static_detect_pid_file`
                if [ -n "$static_pid" ]; then
                    kill $static_pid
                fi  
            else
                dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
                dhcp_pid=`cat $dhcp_detect_pid_file`
                if [ -n "$dhcp_pid" ]; then
                    kill $dhcp_pid
                fi
            fi
            ;;
        
        "l2tp")
            local pptp_address_static=`syscfg get l2tp_address_static`
            if [ "$l2tp_address_static" = "1" ]; then
                static_detect_pid_file=/tmp/static_detect_${1}.pid
                static_pid=`cat $static_detect_pid_file`
                if [ -n "$static_pid" ]; then
                    kill $static_pid
                fi  
            else
                dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
                dhcp_pid=`cat $dhcp_detect_pid_file`
                if [ -n "$dhcp_pid" ]; then
                    kill $dhcp_pid
                fi
            fi
            ;;
            
            *)
            return 2
            ;;
    esac
    sleep 1
    return 0
}
check_intf_detection_result ()
{
    local wan_proto=`syscfg get wan_proto`
    
    case "$wan_proto" in
        dhcp)
            test_proto="dhcp"
            ;;
        pppoe)
            test_proto="pppoe"
            ;;
        static)
            test_proto="static"
            ;;
        pptp)
            local pptp_address_static=`syscfg get pptp_address_static`
            if [ "$pptp_address_static" = "1" ]; then
                test_proto="static"
            else
                test_proto="dhcp"
            fi
            ;;
        l2tp)
            local l2tp_address_static=`syscfg get l2tp_address_static`
            if [ "$l2tp_address_static" = "1" ]; then
                test_proto="static"
            else
                test_proto="dhcp"
            fi       
            ;;
            *)
            
            ;;
    esac
    
    case "$test_proto" in
        "dhcp")
        
            if [ "$is_port0_running" = "1" ]; then
                dhcp_detect_port0_status=`sysevent get dhcp_detect_on_${port0_intf}`
                
                if [ "$dhcp_detect_port0_status" = "DETECTED" ]; then
                    is_port0_running="0"
                    WAN_INTF="$port0_intf"
                    return 1
                elif [ "$dhcp_detect_port0_status" = "FAILED" ]; then
                    is_port0_running="0"
                fi
                       
            fi       
            
            
            if [ "$is_port1_running" = "1" ]; then
                dhcp_detect_port1_status=`sysevent get dhcp_detect_on_${port1_intf}`
                if [ "$dhcp_detect_port1_status" = "DETECTED" ]; then
                    is_port1_running="0"
                    WAN_INTF="$port1_intf"
                    return 1
                elif [ "$dhcp_detect_port1_status" = "FAILED" ]; then
                    is_port1_running="0"
                fi
                
            fi       
            
                        
            ;;
            
        "pppoe")
            if [ "$is_port0_running" = "1" ]; then
                pppoe_detect_port0_status=`sysevent get pppoe_detect_on_${port0_intf}`
                if [ "$pppoe_detect_port0_status" = "DETECTED" ]; then
                    is_port0_running="0"
                    WAN_INTF="$port0_intf"
                    return 1
                elif [ "$pppoe_detect_port0_status" = "FAILED" ]; then
                    is_port0_running="0"
    
                fi       
            fi
            if [ "$is_port1_running" = "1" ]; then
                pppoe_detect_port1_status=`sysevent get pppoe_detect_on_${port1_intf}`
                
                if [ "$pppoe_detect_port1_status" = "DETECTED" ]; then
                    is_port1_running="0"
                    WAN_INTF="$port1_intf"
                    return 1
                elif [ "$pppoe_detect_port1_status" = "FAILED" ]; then
                    is_port1_running="0"
                fi
                       
            fi
            ;;
            
        "static")
            if [ "$is_port0_running" = "1" ]; then
                static_detect_port0_status=`sysevent get static_detect_on_${port0_intf}`
                
                if [ "$static_detect_port0_status" = "DETECTED" ]; then
                    is_port0_running="0"
                    WAN_INTF="$port0_intf"
                    return 1
                elif [ "$static_detect_port0_status" = "FAILED" ]; then
                    is_port0_running="0"
                fi       
            fi
            if [ "$is_port1_running" = "1" ]; then
                static_detect_port1_status=`sysevent get static_detect_on_${port1_intf}`
                
                if [ "$static_detect_port1_status" = "DETECTED" ]; then
                    is_port1_running="0"
                    WAN_INTF="$port1_intf"
                    return 1
                elif [ "$static_detect_port1_status" = "FAILED" ]; then
                    is_port1_running="0"
                fi       
            fi
            ;;
        *)
            return 2
        ;;
            
    esac
            
    WAN_INTF=""
    return 0
}
bridge_mode_wan_link_detect ()
{
    local ret
    local try_cnt=0
    local max_try_cnt=4
    local br_intf="`syscfg get lan_ifname`"
    local br_detection_pid_file=/tmp/br_dt.pid
    local bridge_ip
    local bridge_nm
    local bridge_gateway
    local port0_link
    local port1_link
    while [ "$try_cnt" -lt "$max_try_cnt" ]; do
        port0_link="`sysevent get $port0_link_event`"
        port1_link="`sysevent get $port1_link_event`"
        ulog $SRV_NAME status "bridge mode wan link detection $try_cnt"
        if [ "$port0_link" = "up" -o "$port1_link" = "up" ]; then
            case "$bridge_mode" in
                1)
                    if [ -n "`pidof udhcpc`" ]; then
                        br_ip="`ip -4 addr show dev $br_intf | grep inet | awk '{print $2}'`"
                        if [ -n "$br_ip" ]; then
                            ulog $SRV_NAME status "br has an ip address, wan link is up"
                            return 1
                        fi
                    else
                        $DHCP_DETECT_SCRIPT $br_intf $br_detection_pid_file
                        ret="$?"
                        if [ "$ret" = "1" ]; then
                            ulog $SRV_NAME status "br could get an ip address, wan link is up"
                            return 1
                        fi
                        ulog $SRV_NAME status "br could not get an ip address, wan link is not up"
                    fi
                    ;;
                2)
                    bridge_ip="`syscfg get bridge_ipaddr`"
                    bridge_nm="`syscfg get bridge_netmask`"
                    bridge_gateway="`syscfg get bridge_default_gateway`"
                    
                    if [ -z "$bridge_ip" -o -z "$bridge_nm" -o -z "$bridge_gateway" ]; then
                        ulog $SRV_NAME status "bridge mode parameter error"
                        return 0
                    fi
                    if [ -n "$(pidof ping)" ]; then
                        pkill -SIGTERM -f "ping -4 -c 3 -W 3 -I $br_intf $bridge_gateway"
                    fi
                    sleep 2
                    ping -4 -c 3 -W 3 -I $br_intf $bridge_gateway > /dev/null
                    ret="$?"
                    if [ "$ret" = "0" ]; then
                        ulog $SRV_NAME status "br gateway is reachable, wan link is up"
                        return 1
                    fi
                    ulog $SRV_NAME status "br gateway is unreachable, wan link is not up"
                    ;;
                *)
                    ulog $SRV_NAME status "invalid bridge mode, <$bridge_mode>"
                    return 0
                    ;;
            esac
        fi
        try_cnt="`expr $try_cnt + 1`"
        sleep 20
    done
    return 0
}
run_bootup_detection ()
{
    wan_detected_type=`syscfg get wan::detected_type`
    wan_detected_proto=`sysevent get wan::detected_proto`
    wan_detected_intf=`sysevent get wan::detected_intf`
    
    local TRY=0
    local MAX_TRY=18
    
    local last_try="0"
    local last_try_max="4"
    
    
    is_port0_running="0"
    is_port1_running="0"
    if [ -z "$wan_detected_type" -o "$wan_detected_type" = "false" ]; then
        if [ -n "$wan_detected_proto" ]; then
            ulog $SRV_NAME protocol_detection "protocol exist, no need to detect"
            return 1
        fi
        while [ "$TRY" -lt "$MAX_TRY" ]; do
            map_link_state `sysevent get $port0_link_event`
            port0_status="$LINK"
            map_link_state `sysevent get $port1_link_event`
            port1_status="$LINK"
            if [ "$port0_status" = "up" -a "$is_port0_running" = "0" ]; then
                start_protocol_detection_on_intf "$port0_intf"
                is_port0_running="1"
            fi
            if [ "$port0_status" = "down" -a "$is_port0_running" = "1" ]; then
                stop_protocol_detection_on_intf "$port0_intf"
                is_port0_running="0"
                
            fi
            if [ "$port1_status" = "up" -a "$is_port1_running" = "0" ]; then
                start_protocol_detection_on_intf "$port1_intf"
                is_port1_running="1"
            fi
            if [ "$port1_status" = "down" -a "$is_port1_running" = "1" ]; then
                stop_protocol_detection_on_intf "$port1_intf"
                is_port1_running="0"
            fi
            sleep 4
            check_protocol_detection_result
            ret="$?"
            ulog $SRV_NAME protocol_detection "check_protocol_detection_result $TRY RESULT $ret"
            if [ "$TRY" -eq "`expr $MAX_TRY - 1`" ] && [ "$ret" = "0" ] && [ "$is_port0_running" = "1" -o "$is_port1_running" = "1" ]; then
                while [ "$last_try" -lt "$last_try_max" ]; do
                    sleep 6
                    last_try="`expr $last_try + 1`"
                    check_protocol_detection_result
                    ret="$?"
                    if [ "$ret" = "1" ]; then
                        break
                    fi
                    if [ "$is_port0_running" = "0" -a "$is_port1_running" = "0" ]; then
                        break
                    fi
                done
            fi
            dirty="0"
            if [ "$ret" = "1" -a -n "$PROTO" -a -n "$WAN_INTF" ]; then
                ulog $SRV_NAME protocol_detection "protocol $PROTO detected, wan intf $WAN_INTF"
                sysevent set wan::proto_detection_status "DETECTED"
                sysevent set wan::detected_proto "$PROTO"
                if [ "$PROTO" = "pppoe" ]; then
                    syscfg set wan_proto pppoe
                    dirty="1"
                fi
                
                sysevent set wan::intf_detection_status "DETECTED"
                sysevent set wan::detected_intf "$WAN_INTF"             
                
                if [ "$port0_intf" != "$WAN_INTF" ]; then
                    c_wan_intf=`syscfg get wan_physical_ifname`
                    if [ "$c_wan_intf" != "$port1_intf" ]; then
                        save_wan_intf_setting $port1_intf $port0_intf
                        dirty="0"
                    fi
                    wan_link=`sysevent get $port1_link_event`
                    map_link_state $wan_link
                    sysevent set phylink_wan_state "$LINK"
                    
                    enslave_lan_eth_intf_to_bridge
                    update_vlan_backhaul
                    sysevent set wan-start
                else
                    c_wan_intf=`syscfg get wan_physical_ifname`
                    if [ "$c_wan_intf" != "$port0_intf" ]; then
                        save_wan_intf_setting $port0_intf $port1_intf
                        dirty="0"
                    fi
                    wan_link=`sysevent get $port0_link_event`
                    map_link_state $wan_link
                    sysevent set phylink_wan_state "$LINK"
                    
                    enslave_lan_eth_intf_to_bridge
                    update_vlan_backhaul
                    sysevent set wan-start
                fi
                if [ "$dirty" = "1" ]; then
                    syscfg commit
                fi
                return 0              
            fi
            
            TRY=`expr $TRY + 1`
        done
        
        ulog $SRV_NAME protocol_detection "protocol detection failed"
        sysevent set wan::proto_detection_status "FAILED"
        sysevent set wan::detected_proto
        wan_port=`syscfg get wan::port`
        if [ -n "$wan_port" ]; then
            if [ "$port0_intf" = "$wan_port" ]; then
                lan_port="$port1_intf"
                wan_link=`sysevent get ETH::port_${port0_number}_status`
                lan_link=`sysevent get ETH::port_${port1_number}_status`
            else
                lan_port="$port0_intf"
                wan_link=`sysevent get ETH::port_${port1_number}_status`
                lan_link=`sysevent get ETH::port_${port0_number}_status`
            fi
            ulog $SRV_NAME protocol_detection "user specified wan port $wan_port"
            if [ "$wan_link" = "down" -a "$lan_link" = "down" ]; then
                ulog $SRV_NAME protocol_detection "both ports are disconnected"
                sysevent set wan::intf_detection_status "IDLE"
                sysevent set wan::detected_intf
                sysevent set phylink_wan_state "down"
                return 1
            fi
            c_wan_intf=`syscfg get wan_physical_ifname`
            if [ "$c_wan_intf" != "$wan_port" ]; then
                save_wan_intf_setting $wan_port $lan_port
            fi
            sysevent set wan::intf_detection_status "DETECTED"
            sysevent set wan::detected_intf $wan_port
            sysevent set phylink_wan_state "$wan_link"
            enslave_lan_eth_intf_to_bridge
            update_vlan_backhaul  
            sysevent set wan-start
            return 1
        fi
        port0_status=`sysevent get $port0_link_event`
        port1_status=`sysevent get $port1_link_event`
        if [ -z "$port0_status" -a -z "$port1_status" ] || [ "$port0_status" = "down" -a "$port1_status" = "down" ]; then
            ulog $SRV_NAME protocol_detection "both ports not connected"
            sysevent set wan::intf_detection_status "IDLE"
            sysevent set wan::detected_intf
            sysevent set phylink_wan_state "down"
        elif [ "$port0_status" = "up" -a "$port1_status" = "down" ]; then
            ulog $SRV_NAME protocol_detection "port0 connected, treat it as lan"            
            sysevent set wan::intf_detection_status "FAILED"
            sysevent set wan::detected_intf "$port1_intf"
            sysevent set phylink_wan_state "down"
            
            c_wan_intf=`syscfg get wan_physical_ifname`
            if [ "$c_wan_intf" != "$port1_intf" ]; then
                save_wan_intf_setting $port1_intf $port0_intf
            fi
            enslave_lan_eth_intf_to_bridge
            update_vlan_backhaul
            sysevent set wan-start
        elif [ "$port0_status" = "down" -a "$port1_status" = "up" ]; then
            ulog $SRV_NAME protocol_detection "port1 connected, treat it as lan"  
            sysevent set wan::intf_detection_status "FAILED"
            sysevent set wan::detected_intf "$port0_intf"
            sysevent set phylink_wan_state "down"
            
            c_wan_intf=`syscfg get wan_physical_ifname`
            if [ "$c_wan_intf" != "$port0_intf" ]; then
                save_wan_intf_setting $port0_intf $port1_intf
            fi
            enslave_lan_eth_intf_to_bridge
            update_vlan_backhaul
            sysevent set wan-start
        else
            ulog $SRV_NAME protocol_detection "both ports connected, treat port1 as lan"
            sysevent set wan::intf_detection_status "FAILED"
            sysevent set wan::detected_intf "$port0_intf"
            sysevent set phylink_wan_state "up"
            
            c_wan_intf=`syscfg get wan_physical_ifname`
            if [ "$c_wan_intf" != "$port0_intf" ]; then
                save_wan_intf_setting $port0_intf $port1_intf
            fi
            enslave_lan_eth_intf_to_bridge
            update_vlan_backhaul
            sysevent set wan-start
        fi
        
        return 1
    else
        
        if [ "$bridge_mode" != "0" ]; then
            
            bridge_mode_wan_link_detect
            ret="$?"
            if [ "$ret" = "0" ]; then
                sysevent set phylink_wan_state down
            else
                sysevent set phylink_wan_state up
            fi
            return 0
        fi
        if [ -n "$wan_detected_intf" ]; then
            ulog $SRV_NAME intf_detection "wan intf exists, no need to detect"
            return 1
        fi
        
        while [ "$TRY" -lt "$MAX_TRY" ]; do
            map_link_state `sysevent get $port0_link_event`
            port0_status="$LINK"
            map_link_state `sysevent get $port1_link_event`
            port1_status="$LINK"
            if [ "$port0_status" = "up" -a "$is_port0_running" = "0" ]; then
                start_intf_detection_on_intf "$port0_intf"
                is_port0_running="1"
            fi
            if [ "$port0_status" = "down" -a "$is_port0_running" = "1" ]; then
                stop_intf_detection_on_intf "$port0_intf"
                is_port0_running="0"
                    
            fi
            if [ "$port1_status" = "up" -a "$is_port1_running" = "0" ]; then
                start_intf_detection_on_intf "$port1_intf"
                is_port1_running="1"
            fi
            if [ "$port1_status" = "down" -a "$is_port1_running" = "1" ]; then
                stop_intf_detection_on_intf "$port1_intf"
                is_port1_running="0"
            fi
            
            sleep 4
            
            check_intf_detection_result
            ret="$?"
            ulog $SRV_NAME intf_detection "check_intf_detection_result $TRY: $ret"
            if [ "$TRY" -eq "`expr $MAX_TRY - 1`" ] && [ "$ret" = "0" ] && [ "$is_port0_running" = "1" -o "$is_port1_running" = "1" ]; then
                while [ "$last_try" -lt "$last_try_max" ]; do
                    sleep 6
                    last_try="`expr $last_try + 1`"
                    check_intf_detection_result
                    ret="$?"
                    if [ "$ret" = "1" ]; then
                        break
                    fi
                    if [ "$is_port0_running" = "0" -a "$is_port1_running" = "0" ]; then
                        break
                    fi
                done
            fi
            if [ "$ret" = "1" -a -n "$WAN_INTF" ] ; then
                ulog $SRV_NAME intf_detection "wan intf $WAN_INTF"
                sysevent set wan::intf_detection_status "DETECTED"
                sysevent set wan::detected_intf "$WAN_INTF"
                if [ "$port0_intf" != "$WAN_INTF" ]; then
                    
                    c_wan_intf=`syscfg get wan_physical_ifname`
                    if [ "$c_wan_intf" != "$port1_intf" ]; then
                        save_wan_intf_setting $port1_intf $port0_intf
                    fi
                    wan_link=`sysevent get $port1_link_event`
                    map_link_state $wan_link
                    sysevent set phylink_wan_state "$LINK"
                    
                    enslave_lan_eth_intf_to_bridge
                    update_vlan_backhaul  
                    sysevent set wan-start
                    
                else
                    c_wan_intf=`syscfg get wan_physical_ifname`
                    if [ "$c_wan_intf" != "$port0_intf" ]; then
                        save_wan_intf_setting $port0_intf $port1_intf
                    fi
                    wan_link=`sysevent get $port0_link_event`
                    map_link_state $wan_link
                    sysevent set phylink_wan_state "$LINK"
                    
                    enslave_lan_eth_intf_to_bridge
                    update_vlan_backhaul  
                    sysevent set wan-start                   
                fi
                
                return 0 
            fi
            
            TRY=`expr $TRY + 1`
        done
        
        ulog $SRV_NAME intf_detection "intf detection failed, no wan port"
        
        wan_port=`syscfg get wan::port`
        if [ -n "$wan_port" ]; then
            if [ "$port0_intf" = "$wan_port" ]; then
                lan_port="$port1_intf"
                wan_link=`sysevent get ETH::port_${port0_number}_status`
                lan_link=`sysevent get ETH::port_${port1_number}_status`
            else
                lan_port="$port0_intf"
                wan_link=`sysevent get ETH::port_${port1_number}_status`
                lan_link=`sysevent get ETH::port_${port0_number}_status`
            fi
            ulog $SRV_NAME intf_detection "user specified wan port $wan_port"
            if [ "$wan_link" = "down" -a "$lan_link" = "down" ]; then
                ulog $SRV_NAME intf_detection "both ports are disconnected"
                sysevent set wan::intf_detection_status "IDLE"
                sysevent set wan::detected_intf
                sysevent set phylink_wan_state "down"
                return 1
            fi
            c_wan_intf=`syscfg get wan_physical_ifname`
            if [ "$c_wan_intf" != "$wan_port" ]; then
                save_wan_intf_setting $wan_port $lan_port
            fi
            sysevent set wan::intf_detection_status "DETECTED"
            sysevent set wan::detected_intf $wan_port
            sysevent set phylink_wan_state "$wan_link"
            enslave_lan_eth_intf_to_bridge
            update_vlan_backhaul  
            sysevent set wan-start
            return 1
        fi
        port0_status=`sysevent get $port0_link_event`
        port1_status=`sysevent get $port1_link_event`
        if [ -z "$port0_status" -a -z "$port1_status" ] || [ "$port0_status" = "down" -a "$port1_status" = "down" ]; then
            ulog $SRV_NAME intf_detection "both ports not connected"
            sysevent set wan::intf_detection_status "IDLE"
            sysevent set wan::detected_intf
            sysevent set phylink_wan_state "down"
        elif [ "$port0_status" = "up" -a "$port1_status" = "down" ]; then
            ulog $SRV_NAME intf_detection "port0 connected, treat it as lan"            
            c_wan_intf=`syscfg get wan_physical_ifname`
            if [ "$c_wan_intf" != "$port1_intf" ]; then
                save_wan_intf_setting $port1_intf $port0_intf
            fi
            sysevent set wan::intf_detection_status "FAILED"
            sysevent set wan::detected_intf "$port1_intf"
            sysevent set phylink_wan_state "down"
            enslave_lan_eth_intf_to_bridge
            update_vlan_backhaul  
            sysevent set wan-start
        elif [ "$port0_status" = "down" -a "$port1_status" = "up" ]; then
            ulog $SRV_NAME protocol_detection "port1 connected, treat it as lan"  
            c_wan_intf=`syscfg get wan_physical_ifname`
            if [ "$c_wan_intf" != "$port0_intf" ]; then
                save_wan_intf_setting $port0_intf $port1_intf
            fi
            sysevent set wan::intf_detection_status "FAILED"
            sysevent set wan::detected_intf "$port0_intf"
            sysevent set phylink_wan_state "down"
            enslave_lan_eth_intf_to_bridge
            update_vlan_backhaul  
            sysevent set wan-start
        else
            ulog $SRV_NAME protocol_detection "both ports connected, treat port0 as wan"
            c_wan_intf=`syscfg get wan_physical_ifname`
            if [ "$c_wan_intf" != "$port0_intf" ]; then
                save_wan_intf_setting $port0_intf $port1_intf
            fi
            sysevent set wan::intf_detection_status "FAILED"
            sysevent set wan::detected_intf "$port0_intf"
            sysevent set phylink_wan_state "up"
            enslave_lan_eth_intf_to_bridge
            update_vlan_backhaul
            sysevent set wan-start
        fi
        return 1
    fi
}
service_init ()
{
    bridge_mode="`syscfg get bridge_mode`"
    WAN_INTF_AUTO_DETECT_ENABLED=$(syscfg get wan::intf_auto_detect_enabled)
    WAN_INTF_AUTO_DETECT_SUPPORTED=$(syscfg get wan::intf_auto_detect_supported)
    
    local wan_port_num=""
    
    if [ "$WAN_INTF_AUTO_DETECT_SUPPORTED" = "1" ]; then
        if [ "$WAN_INTF_AUTO_DETECT_ENABLED" = "1" ]; then
            if [ "$bridge_mode" != "0" ]; then
                bridge_max="`syscfg get switch::bridge_max`"
                if [ "$bridge_max" = "1" ]; then
                    port0_intf="`syscfg get switch::bridge_1::ifname`"
                    port1_intf="`syscfg get switch::bridge_1::ifname`"
                    port0_number="`syscfg get switch::bridge_1::port_numbers | cut -d' ' -f 2`"
                    port1_number="`syscfg get switch::bridge_1::port_numbers | cut -d' ' -f 1`"
                else
                    port0_intf="`syscfg get switch::bridge_2::ifname`"
                    port1_intf="`syscfg get switch::bridge_1::ifname`"
                    port0_number="`syscfg get switch::bridge_2::port_numbers`"
                    port1_number="`syscfg get switch::bridge_1::port_numbers`"
                fi
            else
                port0_intf="`syscfg get switch::router_2::ifname`"
                port1_intf="`syscfg get switch::router_1::ifname`"
                port0_number="`syscfg get switch::router_2::port_numbers`"
                port1_number="`syscfg get switch::router_1::port_numbers`"
            fi
            if [ -z "$port0_intf" -o -z "$port1_intf" -o -z "$port0_number" -o -z "$port1_number" ]; then
                ulog "$SRV_NAME" status "port info not avaliable, please verify"
                echo "port info not avaliable, please verify" >> /dev/console
                exit 1
            fi
            port0_link_event="ETH::port_${port0_number}_status"
            port1_link_event="ETH::port_${port1_number}_status"
        else
            current_wan_ifname="$(syscfg get wan_physical_ifname)"
            
            router_max=$(syscfg get switch::router_max)
            router_index=1
            
            while [ "$router_index" -le "$router_max" ]; do
                port_ifname=$(syscfg get switch::router_${router_index}::ifname)
                if [ -n "$port_ifname" -a "$current_wan_ifname" = "$port_ifname" ]; then
                    wan_port_num="$(syscfg get switch::router_${router_index}::port_numbers)"
                    fixed_wan_intf_name=$port_ifname
                    break
                fi
                router_index=$(expr $router_index + 1)
            done
            if [ -n "$wan_port_num" ]; then
                wan_port_link_event="ETH::port_${wan_port_num}_status"
                ulog "$SRV_NAME" status "wan auto detect support but disabled, wan port num is $wan_port_num"
            else
                ulog "$SRV_NAME" status "wan auto detect support but disabled, wan port not specified, abort"
                exit 1
            fi
        fi
    else
        if [ "$bridge_mode" = "0" ]; then
            router_max=$(syscfg get switch::router_max)
            router_index=1
            
            while [ "$router_index" -le "$router_max" ]; do
                port_name=$(syscfg get switch::router_${router_index}::port_names)
                wan_monitor_port=$(syscfg get switch::router_${router_index}::wan_monitor_port)
                if [ -n "$wan_monitor_port" ]; then
                    wan_port_num="$wan_monitor_port"
                    fixed_wan_intf_name=$(syscfg get switch::router_${router_index}::ifname)
                    break
                fi
                router_index=$(expr $router_index + 1)
            done
            if [ -n "$wan_port_num" ]; then
                wan_port_link_event="ETH::port_${wan_port_num}_status"
                ulog "$SRV_NAME" status "legacy mode: wan port num is $wan_port_num"
            else
                ulog "$SRV_NAME" status "legacy mode: wan port not specified, abort"
                exit 1
            fi
        else
            bridge_max=$(syscfg get switch::bridge_max)
            bridge_index=1
            while [ "$bridge_index" -le "$bridge_max" ]; do
                port_name=$(syscfg get switch::bridge_${bridge_index}::port_names)
                wan_monitor_port=$(syscfg get switch::bridge_${bridge_index}::wan_monitor_port)
                if [ -n "$wan_monitor_port" ]; then
                    wan_port_num="$wan_monitor_port"
                    break
                fi
                bridge_index=$(expr $bridge_index + 1)
            done
            if [ -n "$wan_port_num" ]; then
                wan_port_link_event="ETH::port_${wan_port_num}_status"
                ulog "$SRV_NAME" status "legacy mode: wan port num is $wan_port_num"
            else
                ulog "$SRV_NAME" status "legacy mode: wan port not specified, abort"
                exit 1
            fi
        fi
    fi
    
}
service_start ()
{
if [ "$WAN_INTF_AUTO_DETECT_ENABLED" = "1" ]; then
    if [ "$(syscfg get smart_mode::mode)" = "1" ]; then
        ulog $SRV_NAME status "the service failed to start on slave node"
        exit 1
    fi
    local wan_link=`sysevent get phylink_wan_state`
    if [ "$wan_link" != "down" -a "$bridge_mode" = "0" ]; then
        sysevent set phylink_wan_state down
    fi
    sleep 1
    run_bootup_detection
    
else
    if [ "$(syscfg get smart_mode::mode)" = "1" ]; then
        ulog $SRV_NAME status "the service failed to start on slave node"
        exit 1
    fi
    wan_port_link=$(sysevent get ${wan_port_link_event})
    if [ -n "$wan_port_link" ]; then
        sysevent set phylink_wan_state $wan_port_link
    fi
    if [ -n "$fixed_wan_intf_name" ]; then
        sysevent set wan::intf_detection_status "DETECTED"
        sysevent set wan::detected_intf "$fixed_wan_intf_name"
    fi
fi
register_phylink_event_handler
ulog "$SRV_NAME" status "service start"
sysevent set wan_intf_auto_detect-status started
    
}
service_stop ()
{
    ulog "$SRV_NAME" status "service stop"
    unregister_phylink_event_handler
    sysevent set ${SRV_NAME}-status stopped
}
ulog $SRV_NAME status "event $EVENT received"
service_init
STATUS=`sysevent get ${SRV_NAME}-status`
case $EVENT in
    ${SRV_NAME}-start)
        if [ "$STATUS" = "stopped" ]; then
            service_start
        elif [ "$STATUS" = "started" ]; then
            echo "service ${SRV_NAME} has been already started"
        fi
        ;;
    ${SRV_NAME}-stop)
        if [ "$STATUS" = "started" ]; then
            service_stop
        elif [ "$STATUS" = "stopped" ]; then
            echo "service ${SRV_NAME} has been already stopped"
        fi
        ;;
    ${SRV_NAME}-restart)
        if [ "$STATUS" = "started" ]; then
            service_stop
        fi
        service_start
        ;;
    *)
        echo "Event $EVENT received, no handler for this" > /dev/console
        exit 1
        ;;
esac
