#!/bin/sh
source /etc/init.d/service_wan_intf_auto_detect/wan_intf_detect_util.sh
SRV_NAME="wan_intf_auto_detect"
SUB_COMP="manager"
if [ "$(syscfg get wan::intf_auto_detect_debug)" = "1" ]; then
    set -x
fi
locking()
{
    local LOCK_FILE=$1
    if (set -o noclobber; echo "$$" > "$LOCK_FILE") 2> /dev/null
    then  # Try to lock a file
        trap 'rm -f "$LOCK_FILE"; exit $?' INT TERM EXIT;
        return 0;
    fi
    return 1
}
lock()
{
    if [ -z "$1" ]; then
        return 1
    fi
    local IS_DONE="1"
    local CNT="0"
    local MAX_TRY="30"
    local LOCK_FILE=/tmp/wan_intf_detect_$1.lock
    while [ "$IS_DONE" != "0" -a "$CNT" -lt "$MAX_TRY" ]
    do
        locking $LOCK_FILE
        IS_DONE="$?"
        if [ "0" != "$IS_DONE" ]
        then
            CNT="`expr $CNT + 1`"
            sleep 1
            ulog $SRV_NAME $SUB_COMP "$PID aquiring the lock $CNT"
        fi
    done
    if [ "$CNT" = "$MAX_TRY" ]; then
        return 1
    fi
    return 0
}
unlock()
{
    if [ -z "$1" ]; then
        return 1
    fi
    local LOCK_FILE=/tmp/wan_intf_detect_$1.lock
    rm -f "$LOCK_FILE"    # Remove the lock file
    trap - INT TERM EXIT
    return 0
}
is_locked()
{
    local LOCK_FILE=/tmp/wan_intf_detect_$1.lock
    if [ -e $LOCK_FILE ]; then
        return 1
    else
        return 0
    fi
}
start_protocol_detection()
{
    if [ -z "$1" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID interface is not specified"
        return 3
    fi
    
    wan_detected_proto=`sysevent get wan::detected_proto`
    if [ -n "$wan_detected_proto" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID wan proto exist, no need to detect"
    else
        sysevent set wan::proto_detection_status DETECTING
        
        local dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
        local pppoe_detect_pid_file=/tmp/pppoe_detect_${1}.pid
        sysevent set dhcp_detect_on_${1}
        sysevent set pppoe_detect_on_${1}
        $DHCP_DETECT_SCRIPT "$1" "$dhcp_detect_pid_file" &
        $PPPOE_DETECT_SCRIPT "$1" "$pppoe_detect_pid_file" &
        local max_try=10
        local try=0
        while [ "$try" -lt "$max_try" ]; do
            local dhcp_detection_status=`sysevent get dhcp_detect_on_${1}`
            local pppoe_detection_status=`sysevent get pppoe_detect_on_${1}`
            
            if [ "$dhcp_detection_status" = "DETECTED" ]; then
                sysevent set wan::detected_intf $1
                sysevent set wan::detected_proto dhcp
                sysevent set wan::proto_detection_status DETECTED
                sysevent set wan::intf_detection_status DETECTED
                if [ "`syscfg get wan_proto`" != "dhcp" ]; then
                    syscfg set wan_proto dhcp
                    syscfg commit
                fi
                return 1
            fi
            if [ "$pppoe_detection_status" = "DETECTED" ]; then
                sysevent set wan::detected_intf $1
                sysevent set wan::detected_proto pppoe
                sysevent set wan::proto_detection_status DETECTED
                sysevent set wan::intf_detection_status DETECTED
                 
                if [ "`syscfg get wan_proto`" != "pppoe" ]; then
                    syscfg set wan_proto pppoe
                    syscfg commit
                fi
                return 1
            fi
            if [ "$dhcp_detection_status" = "FAILED" -a "$pppoe_detection_status" = "FAILED" ]; then
                return 0
            fi
            try=`expr $try + 1`
            sleep 2
        done
        
        return 0
    fi
}
start_intf_detection()
{
    if [ -z "$1" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID interface is not specified"
        return 2
    fi
    local wan_proto=`syscfg get wan_proto`
    local intf_detected="0"
    local dhcp_detect_pid_file
    local pppoe_detect_pid_file
    local static_detect_pid_file
    
    local test_proto   
    
    ulog $SRV_NAME $SUB_COMP "$PID start $wan_proto wan intf detection on $1"
 
    case "$wan_proto" in
        dhcp)
            dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
            sysevent set dhcp_detect_on_${1}
            $DHCP_DETECT_SCRIPT "$1" "$dhcp_detect_pid_file" &
            test_proto="dhcp"
            ;;
        pppoe)
            pppoe_detect_pid_file=/tmp/pppoe_detect_${1}.pid
            sysevent set pppoe_detect_on_${1}
            $PPPOE_DETECT_SCRIPT "$1" "$pppoe_detect_pid_file" &
            test_proto="pppoe"
            ;;
        static)
            static_detect_pid_file=/tmp/static_detect_${1}.pid
            sysevent set static_detect_on_${1}
            $STATIC_DETECT_SCRIPT "$1" "$static_detect_pid_file" &
            test_proto="static"
            ;;
        pptp)
            local pptp_address_static=`syscfg get pptp_address_static`
            if [ "$pptp_address_static" = "1" ]; then
                static_detect_pid_file=/tmp/static_detect_${1}.pid
                sysevent set static_detect_on_${1}
                $STATIC_DETECT_SCRIPT "$1" "$static_detect_pid_file" &
                test_proto="static"
            else
                dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
                sysevent set dhcp_detect_on_${1}
                $DHCP_DETECT_SCRIPT "$1" "$dhcp_detect_pid_file" &
                test_proto="dhcp"
            fi
            ;;
        l2tp)
            local l2tp_address_static=`syscfg get l2tp_address_static`
            if [ "$l2tp_address_static" = "1" ]; then
                static_detect_pid_file=/tmp/static_detect_${1}.pid
                sysevent set static_detect_on_${1}
                $STATIC_DETECT_SCRIPT "$1" "$static_detect_pid_file" &
                test_proto="static"
            else
                dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
                sysevent set dhcp_detect_on_${1}
                $DHCP_DETECT_SCRIPT "$1" "$dhcp_detect_pid_file" &
                test_proto="dhcp"
            fi
            ;;
        *)
            ulog $SRV_NAME $SUB_COMP "$PID invalid wan proto [$wan_proto]"
            test_proto=""
            return 2
            ;;
    esac
    local max_try=10
    local try=0
    
    local dhcp_detection_status
    local pppoe_detection_status
   
    sleep 4
    while [ "$try" -lt "$max_try" ]; do
        case "$test_proto" in
            dhcp)
                dhcp_detection_status=`sysevent get dhcp_detect_on_${1}`
                if [ "$dhcp_detection_status" = "DETECTED" ]; then
                    sysevent set wan::detected_intf $1
                    sysevent set wan::intf_detection_status DETECTED
                    return 1
                fi
            ;;
            
            pppoe)
                pppoe_detection_status=`sysevent get pppoe_detect_on_${1}`
                if [ "$pppoe_detection_status" = "DETECTED" ]; then
                    sysevent set wan::detected_intf $1
                    sysevent set wan::intf_detection_status DETECTED
                    return 1
                fi
            ;;
            
            static)
                static_detection_status=`sysevent get static_detect_on_${1}`
                if [ "$static_detection_status" = "DETECTED" ]; then
                    sysevent set wan::detected_intf $1
                    sysevent set wan::intf_detection_status DETECTED
                    return 1
                fi
            ;;   
            
            *)
            ;;
        esac
            
        try=`expr $try + 1`
        sleep 2
    done
    return 0
}
stop_protocol_detection ()
{
    if [ -z "$1" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID interface is not specified"
        return 2
    fi
    
    is_locked $1
    local ret=$?
    if [ "$ret" = "0" ]; then
        return 1
    else
        dhcp_detect_pid_file=/tmp/dhcp_detect_${1}.pid
        pppoe_detect_pid_file=/tmp/pppoe_detect_${1}.pid
        dhcp_pid=`cat $dhcp_detect_pid_file`
        pppoe_pid=`cat $pppoe_detect_pid_file`
        if [ -n "$dhcp_pid" ]; then
            kill $dhcp_pid
        fi
        if [ -n "$pppoe_pid" ]; then
            kill $pppoe_pid
        fi
        
        local LOCK_FILE=/tmp/wan_intf_detect_$1.lock
        local pid=`cat $LOCK_FILE`
        if [ -n "$pid" ]; then
            is_locked syscfg
            syscfg_lock="$?"
            local try="0"
            local max_try="5"
            while [ "$syscfg_lock" = "1" -a "$try" -lt "$max_try" ]; do
                sleep 2
                is_locked syscfg
                syscfg_lock="$?"
                try="`expr $try + 1`"
            done
            kill $pid
            rm -f $LOCK_FILE
            return 1
        else
            ulog $SRV_NAME $SUB_COMP "$PID lock pid is NULL"
            rm -f $LOCK_FILE
            return 2
        fi
    fi 
}
stop_intf_detection()
{
    if [ -z "$1" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID interface is not specified"
        return 2
    fi
    is_locked $1
    local ret=$?
    if [ "$ret" = "0" ]; then
        return 1
    else
     
        local wan_proto=`syscfg get wan_proto`
        local test_proto
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
                ulog $SRV_NAME $SUB_COMP "$PID invalid wan proto [$wan_proto]"
                test_proto=""
                return 2
            ;;
        esac
        
        
        case "$test_proto" in
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
            *)
                return 2
            ;;
        esac
        local LOCK_FILE=/tmp/wan_intf_detect_$1.lock
        local pid=`cat $LOCK_FILE`
        if [ -n "$pid" ]; then
            is_locked syscfg
            syscfg_lock="$?"
            local try="0"
            local max_try="5"
            while [ "$syscfg_lock" = "1" -a "$try" -lt "$max_try" ]; do
                sleep 2
                is_locked syscfg
                syscfg_lock="$?"
                try="`expr $try + 1`"
            done
            kill $pid
            rm -f $LOCK_FILE
            return 1
        else
            ulog $SRV_NAME $SUB_COMP "$PID lock pid is NULL"
            rm -f $LOCK_FILE
            return 2
        fi
    fi
}
parse_event ()
{
    if [ -z "$1" ]; then
        exit 2
    fi
    value="$2"
    case "$1" in
        ETH::port_${port0_number}_status)
            if [ -z "$value" ]; then
                exit 2
            fi
            EVENT="$1"   
            WD_INTF="$port0_intf"
            map_link_state $value           
            WD_INTF_LINK_STATE="$LINK"
            WD_INTF_PORT_NUM="$port0_number"
            WD_INTF_COM="$port1_intf"
            WD_INTF_COM_PORT_NUM="$port1_number"
            map_link_state `sysevent get "$port1_link_event"`
            WD_INTF_COM_LINK_STATE="$LINK"
            return 0
            ;;
        ETH::port_${port1_number}_status)
            if [ -z "$value" ]; then
                exit 2
            fi
            EVENT="$1"         
            WD_INTF="$port1_intf"
            map_link_state $value           
            WD_INTF_LINK_STATE="$LINK"
            WD_INTF_PORT_NUM="$port1_number"
            WD_INTF_COM="$port0_intf"
            WD_INTF_COM_PORT_NUM="$port0_number"
            map_link_state `sysevent get "$port0_link_event"`
            WD_INTF_COM_LINK_STATE="$LINK"
            return 0
            ;;
        force_wan_intf_detect)
        
            EVENT="force_wan_intf_detect"
            map_link_state `sysevent get $port0_link_event`
            PORT0_LINK="$LINK"
            PORT0_INTF="$port0_intf"
            map_link_state `sysevent get $port1_link_event`
            PORT1_LINK="$LINK"
            PORT1_INTF="$port1_intf"
            
            return 0
            ;;
        wan_port_changed)
            EVENT="wan_port_changed"
            map_link_state `sysevent get $port0_link_event`
            PORT0_LINK="$LINK"
            PORT0_INTF="$port0_intf"
            PORT0_NUM="$port0_number"
            map_link_state `sysevent get $port1_link_event`
            PORT1_LINK="$LINK"
            PORT1_INTF="$port1_intf"
            PORT1_NUM="$port1_number"
            return 0
            ;;
        *)
            return 2
            ;;
    esac
}
PID="$$"
ulog $SRV_NAME $SUB_COMP "$PID event $1 $2 received"
wan_intf_auto_detect_enabled=$(syscfg get wan::intf_auto_detect_enabled)
if [ "$wan_intf_auto_detect_enabled" != "1" ]; then
    ulog $SRV_NAME $SUB_COMP "$PID wan intf auto detect not enabled"
    exit 1
fi
bridge_mode=$(syscfg get bridge_mode)
if [ "$bridge_mode" != "0" ]; then
    ulog $SRV_NAME $SUB_COMP "$PID wan intf auto detect will not run in bridge mode"
    exit 1
fi
port0_intf="`syscfg get switch::router_2::ifname`"
port1_intf="`syscfg get switch::router_1::ifname`"
port0_number="`syscfg get switch::router_2::port_numbers`"
port1_number="`syscfg get switch::router_1::port_numbers`"
if [ -z "$port0_intf" -o -z "$port1_intf" -o -z "$port0_number" -o -z "$port1_number" ]; then
    ulog $SRV_NAME $SUB_COMP "$PID port info not avaliable, please verify"
    echo "port info not avaliable, please verify" >> /dev/console
    exit 1
fi
port0_link_event="ETH::port_${port0_number}_status"
port1_link_event="ETH::port_${port1_number}_status"
parse_event $1 $2
if [ -z "$EVENT" ]; then
    exit 1
fi
ulog $SRV_NAME $SUB_COMP "$PID EVENT is $EVENT"
port_toggle_flag=`sysevent get ETH::port${WD_INTF_PORT_NUM}_toggle`
if [ "$WD_INTF_LINK_STATE" = "down" ]; then
    if [ "$port_toggle_flag" = "1" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID port toggle, link down"
        sysevent set ETH::port${WD_INTF_PORT_NUM}_toggle_down_received "1"
        exit 1
    fi
elif [ "$WD_INTF_LINK_STATE" = "up" ]; then
    toggle_down_recved=`sysevent get ETH::port${WD_INTF_PORT_NUM}_toggle_down_received`
    if [ "$port_toggle_flag" = "1" -a "$toggle_down_recved" = "1" ]; then
        ulog $SRV_NAME $SUB_COMP "$PID port toggle, link up"
        sysevent set ETH::port${WD_INTF_PORT_NUM}_toggle 0
        sysevent set ETH::port${WD_INTF_PORT_NUM}_toggle_down_received "0"
        exit 1
    fi
else
    ulog $SRV_NAME $SUB_COMP "$PID non port toggle event, good event"
fi
wan_detected_intf=$(sysevent get wan::detected_intf)
wan_detected_type=$(syscfg get wan::detected_type)
case "$EVENT" in 
    ETH::port_${port0_number}_status|ETH::port_${port1_number}_status)
           if [ -z "$wan_detected_type" -o "$wan_detected_type" = "false" ]; then
               if [ -n "$wan_detected_intf" ]; then
                   if [ "$WD_INTF" = "$wan_detected_intf" ]; then
                       sysevent set phylink_wan_state "$WD_INTF_LINK_STATE"
                   fi
               fi
           
               if [ "$WD_INTF_LINK_STATE" = "down" ]; then
                   ulog $SRV_NAME $SUB_COMP "$PID $WD_INTF link down, stop detection"
                   stop_protocol_detection $WD_INTF              
                   if [ "$WD_INTF_LINK_STATE" = "down" -a "$WD_INTF_COM_LINK_STATE" = "down" ]; then
                       isolate_lan_eth_intf_from_bridge
                       sysevent set wan-stop
                       sysevent set ipv6-stop
                       sysevent set wan::detected_proto
                       sysevent set wan::detected_intf
                       sysevent set wan::intf_detection_status IDLE
                       sysevent set wan::proto_detection_status IDLE                              
                   fi
               else
                   ulog $SRV_NAME $SUB_COMP "$PID $WD_INTF link up"
                   wan_detected_proto=`sysevent get wan::detected_proto`
                   if [ -n "$wan_detected_proto" ]; then
                       ulog $SRV_NAME $SUB_COMP "$PID wan_detected_proto exist, no need to detect"
                       exit 0
                   fi
                   lock $WD_INTF
                   lock="$?"
                   if [ "$lock" = "1" ]; then
                       unlock $WD_INTF
                       exit 2
                   fi
                   isolate_lan_eth_intf_from_bridge
                   start_protocol_detection $WD_INTF
                   ret="$?"
                   if [ "$ret" = "1" ]; then
                       ulog $SRV_NAME $SUB_COMP "$PID wan protocol detected"
                       is_locked "$WD_INTF_COM"
                       intf_com_lock="$?"
                       if [ "$intf_com_lock" = "1" ]; then
                           stop_protocol_detection $WD_INTF_COM
                       fi                      
                       sysevent set wan::detected_intf $WD_INTF
                       wan_link=`sysevent get phylink_wan_state`
                       if [ "$wan_link" != "$WD_INTF_LINK_STATE" ]; then                   
                           sysevent set phylink_wan_state "$WD_INTF_LINK_STATE"
                       fi
                       c_wan_intf=`syscfg get wan_physical_ifname`
                       if [ "$WD_INTF" != "$c_wan_intf" ]; then
                           is_locked syscfg
                           syscfg_lock="$?"
                           try="0"
                           max="5"
                           while [ "$syscfg_lock" = "1" -a "$try" -lt "$max" ]; do
                               sleep 2
                               is_locked syscfg
                               syscfg_lock="$?"
                               try="`expr $try + 1`"
                           done
                           if [ "$try" = "$max" ]; then
                               ulog $SRV_NAME $SUB_COMP "$PID could not get syscfg lock in 10s, quit"
                               unlock syscfg
                               unlock $WD_INTF
                               exit 2
                           fi
                           lock syscfg
                           save_wan_intf_setting $WD_INTF $WD_INTF_COM
                           unlock syscfg
                           sysevent set wan-restart
                           sysevent set ipv6-restart
                       else
                           sysevent set wan-start
                           sysevent set ipv6-start
                       fi
                       enslave_lan_eth_intf_to_bridge
                       update_vlan_backhaul
                       unlock $WD_INTF
                       exit 0
                       
                   elif [ "$ret" = "0" ]; then
                       ulog $SRV_NAME $SUB_COMP "$PID wan protocol not detected on $WD_INTF"                  
                       is_locked "$WD_INTF_COM"
                       intf_com_lock="$?"
                       if [ "$intf_com_lock" = "1" ]; then
                           ulog $SRV_NAME $SUB_COMP "$PID the other port is still detecting, let it determine"
                           unlock $WD_INTF
                           exit 1
                       fi             
                       sysevent set wan::detected_proto
                       sysevent set wan::proto_detection_status "FAILED"
                       sysevent set wan::detected_intf $WD_INTF_COM
                       sysevent set wan::intf_detection_status "FAILED"                                   
                       
                       c_wan_link=`sysevent get phylink_wan_state`
                       if [ "$WD_INTF_PORT_NUM" = "5" ]; then
                           map_link_state `sysevent get $port1_link_event`
                           wan_link="$LINK"
                       else
                           map_link_state `sysevent get $port0_link_event`
                           wan_link="$LINK"
                       fi
                       if [ "$c_wan_link" != "$wan_link" ]; then                   
                           sysevent set phylink_wan_state "$wan_link"
                       fi                   
                       
                       c_wan_intf=`syscfg get wan_physical_ifname`
                       if [ "$WD_INTF_COM" != "$c_wan_intf" ]; then
                           is_locked syscfg
                           syscfg_lock="$?"
                           try="0"
                           max="5"
                           while [ "$syscfg_lock" = "1" -a "$try" -lt "$max" ]; do
                               sleep 2
                               is_locked syscfg
                               syscfg_lock="$?"
                               try="`expr $try + 1`"
                           done
                           if [ "$try" = "$max" ]; then
                               ulog $SRV_NAME $SUB_COMP "$PID could not get syscfg lock in 10s, quit"
                               unlock syscfg
                               unlock $WD_INTF
                               exit 2
                           fi
                           lock syscfg
                           save_wan_intf_setting $WD_INTF_COM $WD_INTF
                           unlock syscfg
                       fi
                       enslave_lan_eth_intf_to_bridge
                       update_vlan_backhaul
                       sleep 2
                       sysevent set wan-restart
                       sysevent set ipv6-restart
                       unlock $WD_INTF
                       exit 1
                   else
                       unlock $WD_INTF
                       exit 2
                   fi
               fi
                       
           else
               if [ -n "$wan_detected_intf" ]; then
                   if [ "$WD_INTF" = "$wan_detected_intf" ]; then
                       sysevent set phylink_wan_state "$WD_INTF_LINK_STATE"
                   fi
               fi
               
               
               if [ "$WD_INTF_LINK_STATE" = "down" ]; then           
                   ulog $SRV_NAME $SUB_COMP "$PID $WD_INTF link down, stop detection"
                   stop_intf_detection $WD_INTF           
                   if [ "$WD_INTF_LINK_STATE" = "down" -a "$WD_INTF_COM_LINK_STATE" = "down" ]; then
                       isolate_lan_eth_intf_from_bridge
                       sysevent set wan-stop
                       sysevent set ipv6-stop
                       sysevent set wan::detected_intf
                       sysevent set wan::intf_detection_status IDLE                           
                   fi             
               else
                   ulog $SRV_NAME $SUB_COMP "$PID $WD_INTF link up"
                   wan_detected_intf=`sysevent get wan::detected_intf`
                   if [ -n "$wan_detected_intf" ]; then
                       ulog $SRV_NAME $SUB_COMP "$PID wan_detected_intf exist, no need to detect"
                       exit 1
                   fi
                   lock $WD_INTF
                   lock="$?"
                   if [ "$lock" = "1" ]; then
                       ulog $SRV_NAME $SUB_COMP "$PID it takes too long to get the intf lock, quit"
                       unlock $WD_INTF
                       exit 2
                   fi
                   start_intf_detection $WD_INTF
                   ret="$?"
                   if [ "$ret" = "1" ]; then
                       ulog $SRV_NAME $SUB_COMP "$PID wan intf detected"
                       is_locked "$WD_INTF_COM"
                       intf_com_lock="$?"
                       if [ "$intf_com_lock" = "1" ]; then
                           stop_intf_detection $WD_INTF_COM
                       fi
                       
                       sysevent set wan::detected_intf $WD_INTF                   
                       wan_link=`sysevent get phylink_wan_state`
                       if [ "$wan_link" != "$WD_INTF_LINK_STATE" ]; then                   
                           sysevent set phylink_wan_state "$WD_INTF_LINK_STATE"
                       fi
                       c_wan_intf=`syscfg get wan_physical_ifname`
                       if [ "$WD_INTF" != "$c_wan_intf" ]; then
                           is_locked syscfg
                           syscfg_lock="$?"
                           try="0"
                           max="5"
                           while [ "$syscfg_lock" = "1" -a "$try" -lt "$max" ]; do
                               sleep 2
                               is_locked syscfg
                               syscfg_lock="$?"
                               try="`expr $try + 1`"
                           done
                           if [ "$try" = "$max" ]; then
                               ulog $SRV_NAME $SUB_COMP "$PID could not get syscfg lock in 10s, quit"
                               unlock syscfg
                               unlock $WD_INTF
                               exit 2
                           fi
                           lock syscfg
                           save_wan_intf_setting $WD_INTF $WD_INTF_COM
                           unlock syscfg
                           sysevent set wan-restart
                           sysevent set ipv6-restart
                       else
                           sysevent set wan-start
                           sysevent set ipv6-start
                       fi
                       enslave_lan_eth_intf_to_bridge
                       update_vlan_backhaul
                       
                       unlock $WD_INTF
                       exit 0
                   elif [ "$ret" = "0" ]; then
                       ulog $SRV_NAME $SUB_COMP "$PID wan server not detected"                  
                       is_locked "$WD_INTF_COM"
                       intf_com_lock="$?"
                       if [ "$intf_com_lock" = "1" ]; then
                           ulog $SRV_NAME $SUB_COMP "$PID the other port is still detecting, let it determine"
                           unlock $WD_INTF
                           exit 1
                       fi             
                       
                       sysevent set wan::detected_intf $WD_INTF_COM
                       sysevent set wan::intf_detection_status "FAILED"     
                       
                       c_wan_link=`sysevent get phylink_wan_state`
                       if [ "$WD_INTF_PORT_NUM" = "5" ]; then
                           map_link_state `sysevent get $port1_link_event`
                           wan_link="$LINK"
                       else
                           map_link_state `sysevent get $port0_link_event`
                           wan_link="$LINK"
                       fi
                       if [ "$c_wan_link" != "$wan_link" ]; then                   
                           sysevent set phylink_wan_state "$wan_link"
                       fi                   
                       
                       c_wan_intf=`syscfg get wan_physical_ifname`
                       if [ "$WD_INTF_COM" != "$c_wan_intf" ]; then
                           is_locked syscfg
                           syscfg_lock="$?"
                           try="0"
                           max="5"
                           while [ "$syscfg_lock" = "1" -a "$try" -lt "$max" ]; do
                               sleep 2
                               is_locked syscfg
                               syscfg_lock="$?"
                               try="`expr $try + 1`"
                           done
                           if [ "$try" = "$max" ]; then
                               ulog $SRV_NAME $SUB_COMP "$PID could not get syscfg lock in 10s, quit"
                               unlock syscfg
                               unlock $WD_INTF
                               exit 2
                           fi
                           lock syscfg
                           save_wan_intf_setting $WD_INTF_COM $WD_INTF
                           unlock syscfg
                       fi
                       enslave_lan_eth_intf_to_bridge
                       update_vlan_backhaul
                       sysevent set wan-restart
                       sysevent set ipv6-restart
                       
                       unlock $WD_INTF
                       exit 1
                   else
                       unlock $WD_INTF
                       exit 2
                   fi
               fi
           fi
       ;;
    force_wan_intf_detect)
        
        ;;
    wan_port_changed)
        wan_port="`syscfg get wan::port`"
        wan_intf_detection_status="`sysevent get wan::intf_detection_status`"
        if [ -n "$wan_detected_intf" -a "$wan_intf_detection_status" = "DETECTED" ]; then
            ulog $SRV_NAME $SUB_COMP "$PID wan intf has been detected, no need to set wan port manually, quit"
            exit 0
        else
            if [ -n "$wan_port" ]; then
                ulog $SRV_NAME $SUB_COMP "$PID applying the wan port setting"
                is_locked "$PORT0_INTF"
                port0_lock="$?"
                if [ "$port0_lock" = "1" ]; then
                    stop_intf_detection $PORT0_INTF
                fi
                is_locked "$PORT1_INTF"
                port1_lock="$?"
                if [ "$port1_lock" = "1" ]; then
                    stop_intf_detection $PORT1_INTF
                fi
                sysevent set wan::intf_detection_status DETECTED
                sysevent set wan::detected_intf "$wan_port"
                isolate_lan_eth_intf_from_bridge
                c_wan_port="`syscfg get wan_physical_ifname`"
                if [ "$c_wan_port" != "$wan_port" ]; then
                    is_locked syscfg
                    syscfg_lock="$?"
                    try="0"
                    max="5"
                    while [ "$syscfg_lock" = "1" -a "$try" -lt "$max" ]; do
                        sleep 2
                        is_locked syscfg
                        syscfg_lock="$?"
                        try="`expr $try + 1`"
                    done
                    if [ "$try" = "$max" ]; then
                        ulog $SRV_NAME $SUB_COMP "$PID could not get syscfg lock in 10s, quit"
                        unlock syscfg
                        exit 2
                    fi
                    if [ "$wan_port" = "$PORT0_INTF" ]; then
                        wan_link="$PORT0_LINK"
                        lan_port="$PORT1_INTF"
                        lan_link="$PORT1_LINK"
                        lan_port_num="$PORT1_NUM"
                    else
                        wan_link="$PORT1_LINK"
                        lan_port="$PORT0_INTF"
                        lan_link="$PORT0_LINK"
                        lan_port_num="$PORT0_NUM"
                    fi
                    lock syscfg
                    save_wan_intf_setting $wan_port $lan_port
                    unlock syscfg
                else
                    if [ "$wan_port" = "$PORT0_INTF" ]; then
                        wan_link="$PORT0_LINK"
                        lan_port="$PORT1_INTF"
                        lan_link="$PORT1_LINK"
                        lan_port_num="$PORT1_NUM"
                    else
                        wan_link="$PORT1_LINK"
                        lan_port="$PORT0_INTF"
                        lan_link="$PORT0_LINK"
                        lan_port_num="$PORT0_NUM"
                    fi
                fi
                c_wan_link="`sysevent get phylink_wan_state`"
                if [ "$c_wan_link" != "$wan_link" ]; then
                    sysevent set phylink_wan_state "$wan_link"
                fi
                enslave_lan_eth_intf_to_bridge
                update_vlan_backhaul
                if [ "$lan_link" = "up" ]; then
                    sysevent set ETH::port${lan_port_num}_toggle 1
                    reset_ethernet_ports
                fi
                
            fi
        fi
        exit 0
        ;;
    *)
        ulog $SRV_NAME $SUB_COMP "$PID no handler for event $1"
        exit 1
        ;;
esac
exit 1
