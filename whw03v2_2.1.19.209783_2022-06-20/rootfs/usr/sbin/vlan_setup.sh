#!/bin/sh

#------------------------------------------------------------------
# © 2016 Belkin International, Inc. and/or its affiliates. All rights reserved.
#------------------------------------------------------------------

calculate_source_port ()
{
    val1=1
    val2=1
    i=1
    while [ $i -le $1 ]; do
        val1=`expr $val1 \* 2`
        i=$(($i+1))
    done
    i=1
    while [ $i -le $2 ]; do
        val2=`expr $val2 \* 2`
        i=$(($i+1))
    done
    val=`expr $val1 + $val2`
    val=`printf '%02x\n' $val`
    return $val
}
get_lan_port_numbers()
{
    local intf
    local port
    local lan_ports=""
    local wan_intf=$(syscfg get wan_physical_ifname)
    local max_intf_count=$(syscfg get switch::router_max)
    for index in $(seq $max_intf_count -1 1); do
        if [ ! -n "$index" ]; then
            continue
        fi
        intf="$(syscfg get switch::router_${index}::ifname)"
        port="$(syscfg get switch::router_${index}::port_numbers)"
        if [ "$intf" = "$wan_intf" ]; then
            continue
        else
            lan_ports="$port $lan_ports"
        fi
    done
    echo "$lan_ports"
}

ModelNumber=$(skuapi -g model_sku | cut -d'=' -f2 | tr -d ' ')
if [ "$ModelNumber" = "WHW01P" ]; then
    # do nothing for nodes_jr plugin as there is no ethernet switch
    exit
fi
echo "Program the switch..." > /dev/console
PARAM=`utctx_cmd get lan_ethernet_physical_ifnames lan_mac_addr wan_physical_ifname wan_mac_addr bridge_mode guest_enabled guest_vlan_id svap_vlan_id ipv6::passthrough_enable ipv6::passthrough_done_in_hw lrhk::vlan_id`
eval $PARAM

ssdk_sh debug reg set 0x200 0x31 4 > /dev/null 2>&1 # drop frame when IPv4 header length check fails
acl_rule_index=1
acl_rule_index=`printf '%02x\n' $acl_rule_index`
ssdk_sh vlan entry flush 0 > /dev/null 2>&1

if [ "$SYSCFG_bridge_mode" != "0" ] ; then
    #if [ "$SYSCFG_guest_enabled" = "1" ] ; then
    ssdk_sh vlan entry create $SYSCFG_guest_vlan_id > /dev/null 2>&1
    ssdk_sh vlan member add $SYSCFG_guest_vlan_id 0 tagged > /dev/null 2>&1
    ssdk_sh vlan member add $SYSCFG_guest_vlan_id 4 tagged > /dev/null 2>&1
    ssdk_sh vlan member add $SYSCFG_guest_vlan_id 5 tagged > /dev/null 2>&1
    #fi
    ssdk_sh vlan entry create $SYSCFG_svap_vlan_id > /dev/null 2>&1
    ssdk_sh vlan member add $SYSCFG_svap_vlan_id 0 tagged > /dev/null 2>&1
    ssdk_sh vlan member add $SYSCFG_svap_vlan_id 4 tagged > /dev/null 2>&1
    ssdk_sh vlan member add $SYSCFG_svap_vlan_id 5 tagged > /dev/null 2>&1

    if [ -n "$SYSCFG_lrhk_vlan_id" ] ; then
        ssdk_sh vlan entry create $SYSCFG_lrhk_vlan_id > /dev/null 2>&1
        ssdk_sh vlan member add $SYSCFG_lrhk_vlan_id 0 tagged > /dev/null 2>&1
        ssdk_sh vlan member add $SYSCFG_lrhk_vlan_id 4 tagged > /dev/null 2>&1
        ssdk_sh vlan member add $SYSCFG_lrhk_vlan_id 5 tagged > /dev/null 2>&1
    fi
else
    ssdk_sh vlan entry create $SYSCFG_guest_vlan_id > /dev/null 2>&1
    ssdk_sh vlan member add $SYSCFG_guest_vlan_id 0 tagged > /dev/null 2>&1
    for lan_port in $(get_lan_port_numbers); do
        ssdk_sh vlan member add $SYSCFG_guest_vlan_id "$lan_port" tagged > /dev/null 2>&1
    done
    
    ssdk_sh vlan entry create $SYSCFG_svap_vlan_id > /dev/null 2>&1
    ssdk_sh vlan member add $SYSCFG_svap_vlan_id 0 tagged > /dev/null 2>&1
    for lan_port in $(get_lan_port_numbers); do
        ssdk_sh vlan member add $SYSCFG_svap_vlan_id "$lan_port" tagged > /dev/null 2>&1
    done
    
    if [ -n "$SYSCFG_lrhk_vlan_id" ] ; then
        ssdk_sh vlan entry create $SYSCFG_lrhk_vlan_id > /dev/null 2>&1
        ssdk_sh vlan member add $SYSCFG_lrhk_vlan_id 0 tagged > /dev/null 2>&1
        for lan_port in $(get_lan_port_numbers); do
            ssdk_sh vlan member add $SYSCFG_lrhk_vlan_id "$lan_port" tagged > /dev/null 2>&1
        done
    fi    
fi

if [ "$SYSCFG_bridge_mode" != "0" ] ; then
    #bridge mode
    #Enable bridge mode, and packets from port 5 is sent to eth1, not eth0.
    echo 1 > /proc/sys/net/edma/bridge_mode

    #port-based VLAN. port 0,4,5 in the same VLAN.
    ssdk_sh vlan entry create 1 > /dev/null 2>&1
    ssdk_sh vlan member add 1 0 tagged > /dev/null 2>&1
    ssdk_sh vlan member add 1 4 untagged > /dev/null 2>&1
    ssdk_sh vlan member add 1 5 untagged > /dev/null 2>&1

    #VLAN_CTRL0 b31:29 ING_PORT_CPRI
    #b27:16 PORT_DEFAULT_CVID
    #b15:13 ING_PORT_SPRI
    #B11:0 PORT_DEFAULT_SVID
    ssdk_sh debug reg set 0x420 0x10001 4 > /dev/null 2>&1 #p0
    ssdk_sh debug reg set 0x440 0x10001 4 > /dev/null 2>&1 #p4
    ssdk_sh debug reg set 0x448 0x10001 4 > /dev/null 2>&1 #p5
    #VLAN_CTRL1 b13:12 EG_VLAN_MODE 01=untagged, 10=tagged
    #b3:2 ING_VLAN_MODE 01=tagged, 10=untagged
    ssdk_sh debug reg set 0x424 0x1040 4 > /dev/null 2>&1 #p0
    ssdk_sh debug reg set 0x444 0x1040 4 > /dev/null 2>&1 #p4
    ssdk_sh debug reg set 0x44c 0x1040 4 > /dev/null 2>&1 #p5
    #LOOKUP_CTRL b20 1=enable hardware learn new MAC address into ARL table
    #b18:16 100=forward mode
    ssdk_sh debug reg set 0x660 0x140330 4 > /dev/null 2>&1 #p0
    ssdk_sh debug reg set 0x690 0x140321 4 > /dev/null 2>&1 #p4
    ssdk_sh debug reg set 0x69c 0x140311 4 > /dev/null 2>&1 #p5 
else
    #router mode
    echo 0 > /proc/sys/net/edma/bridge_mode
    if [ "`syscfg get vlan_tagging::enabled`" = "0" ] ; then
        #set 802.1q mode and port-based VLAN member
        ssdk_sh debug reg set 0x660 0x14033e 4 > /dev/null 2>&1
        #port 1 2 3 is not needed
        #ssdk_sh debug reg set 0x66c 0x14031d 4 > /dev/null 2>&1
        #ssdk_sh debug reg set 0x678 0x14031b 4 > /dev/null 2>&1
        #ssdk_sh debug reg set 0x684 0x140317 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x690 0x14030f 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x69c 0x140301 4 > /dev/null 2>&1

        #set vlan
        ssdk_sh vlan entry create 1 > /dev/null 2>&1
        ssdk_sh vlan member add 1 0 tagged > /dev/null 2>&1
        #ssdk_sh vlan member add 1 1 untagged > /dev/null 2>&1
        #ssdk_sh vlan member add 1 2 untagged > /dev/null 2>&1
        #ssdk_sh vlan member add 1 3 untagged > /dev/null 2>&1
        ssdk_sh vlan member add 1 4 untagged > /dev/null 2>&1
        ssdk_sh vlan entry create 2 > /dev/null 2>&1
        ssdk_sh vlan member add 2 0 tagged > /dev/null 2>&1
        ssdk_sh vlan member add 2 5 untagged > /dev/null 2>&1

        #set port PVID
        ssdk_sh portVlan defaultCVid set 0 0 > /dev/null 2>&1
        #ssdk_sh portVlan defaultCVid set 1 1 > /dev/null 2>&1
        #ssdk_sh portVlan defaultCVid set 2 1 > /dev/null 2>&1
        #ssdk_sh portVlan defaultCVid set 3 1 > /dev/null 2>&1
        ssdk_sh portVlan defaultCVid set 4 1 > /dev/null 2>&1
        ssdk_sh portVlan defaultCVid set 5 2 > /dev/null 2>&1

        ssdk_sh portVlan defaultSVid set 0 0 > /dev/null 2>&1
        #ssdk_sh portVlan defaultSVid set 1 1 > /dev/null 2>&1
        #ssdk_sh portVlan defaultSVid set 2 1 > /dev/null 2>&1
        #ssdk_sh portVlan defaultSVid set 3 1 > /dev/null 2>&1
        ssdk_sh portVlan defaultSVid set 4 1 > /dev/null 2>&1
        ssdk_sh portVlan defaultSVid set 5 2 > /dev/null 2>&1
        echo 1 > /proc/sys/net/edma/default_lan_tag
        echo 2 > /proc/sys/net/edma/default_wan_tag
    else # vlan_tagging::enabled = 1
        wan_vid=`syscfg get wan_1::vlan_id`
        wan_ifname=`syscfg get wan::port`
        for i in 1 2 ; do
            if [ "`syscfg get switch::router_$i::ifname`" = "$wan_ifname" ] ; then
                wan_port=`syscfg get switch::router_$i::port_numbers`
                break
            fi
        done
        if [ $i -eq 1 ] ; then
            # eth1 is wan
            echo $wan_vid > /proc/sys/net/edma/default_lan_tag
            echo 1 > /proc/sys/net/edma/default_wan_tag
            lan_port=`syscfg get switch::router_2::port_numbers`
        elif [ $i -eq 2 ] ; then
            # eth0 is wan
            echo $wan_vid > /proc/sys/net/edma/default_wan_tag
            echo 1 > /proc/sys/net/edma/default_lan_tag
            lan_port=`syscfg get switch::router_1::port_numbers`
        fi
        vlan1_ports="0 $lan_port"
        ssdk_sh vlan entry create 1 > /dev/null 2>&1
        for port in $vlan1_ports ; do
            reg_dec=`printf '%d\n' 0x420`
            reg_dec=`expr $reg_dec + 8 \* $port`
            reg=`printf '%03x\n' $reg_dec`
            if [ "$port" = "0" ] ; then
                ssdk_sh vlan member add 1 0 tagged > /dev/null 2>&1
            else
                ssdk_sh vlan member add 1 $port untagged > /dev/null 2>&1
            fi
            ssdk_sh debug reg set 0x$reg 0x10001 4 > /dev/null 2>&1
            reg_dec=`expr $reg_dec + 4`
            reg=`printf '%03x\n' $reg_dec`
            ssdk_sh debug reg set 0x$reg 0x0040 4 > /dev/null 2>&1
        done
        #WRAITH-281
        #LOOKUP_CTRL b20 1=enable hardware learn new MAC address into ARL table
        #b18:16 100=forward mode
        #b9:8 00=802.1q disable, 01=fallback, 10=check, 11=secure
        #b6:0 port-based VLAN member
        reg_dec=`printf '%d\n' 0x660`
        reg_dec=`expr $reg_dec + 12 \* $lan_port`
        reg=`printf '%03x\n' $reg_dec`
        ssdk_sh debug reg set 0x$reg 0x140301 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x660 0x140110 4 > /dev/null 2>&1 #p0 enable 802.1q, very important!!!
        wan_vid_hex=`printf '%03x\n' $wan_vid`
        prio=`syscfg get wan_1::prio`
        prio=`expr $prio \* 2`
        prio=`printf '%x\n' $prio`
        ssdk_sh vlan entry create $wan_vid > /dev/null 2>&1
        ssdk_sh vlan member add $wan_vid 0 tagged > /dev/null 2>&1
        reg_dec=`printf '%d\n' 0x420`
        reg_dec=`expr $reg_dec + 8 \* $wan_port`
        reg=`printf '%03x\n' $reg_dec`
        ssdk_sh debug reg set 0x$reg 0x0${wan_vid_hex}0${wan_vid_hex} 4 > /dev/null 2>&1 #VLAN_CTRL0; priority=0, default-cvid=2
        if [ "`syscfg get switch::router_2::port_tagging`" = "u" ] ; then
            ssdk_sh vlan member add $wan_vid $wan_port untagged > /dev/null 2>&1
        else
            ssdk_sh vlan member add $wan_vid $wan_port tagged > /dev/null 2>&1
            reg_dec=`expr $reg_dec + 4`
            reg=`printf '%03x\n' $reg_dec` 
            ssdk_sh debug reg set 0x$reg 0x2044 4 > /dev/null 2>&1 #VLAN_CTRL1; b3:2=01,only tagged in; b13:12=10, tagged out
        fi
        reg_dec=`printf '%d\n' 0x660`
        reg_dec=`expr $reg_dec + 12 \* $wan_port`
        reg=`printf '%03x\n' $reg_dec`
        ssdk_sh debug reg set 0x$reg 0x140101 4 > /dev/null 2>&1 #LOOKUP_CTRL
        ssdk_sh debug reg set 0x420 0x${prio}${wan_vid_hex}${prio}${wan_vid_hex} 4 > /dev/null 2>&1 #p0, VLAN_CTRL0; priority=0, default-cvid=0xa=10
        ssdk_sh debug reg set 0x424 0x2040 4 > /dev/null 2>&1 #p0, VLAN_CTRL1; b3:2=10,only untagged in; b13:12=01, untagged out
        ssdk_sh debug reg set 0x30 0x80000703 4 > /dev/null 2>&1 # bit1-ACL_EN, MIB_EN
        # Using ACL to set wan vlan priority
        ########### Add MAC pattern ###########
        ssdk_sh debug reg set 0x404 0x00000000 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x408 0x00000000 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x40c 0x00000000 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x410 0x00000${wan_vid_hex} 4 > /dev/null 2>&1
        calculate_source_port 0 $wan_port
        ret=$?
        ssdk_sh debug reg set 0x414 0x000000$ret 4 > /dev/null 2>&1 # Source Port
        ssdk_sh debug reg set 0x400 0x800000$acl_rule_index 4 > /dev/null 2>&1 # ACL_Busy, Write command, Rule and Index to ind-1
        ########### Add MAC mask ###########
        ssdk_sh debug reg set 0x404 0x00000000 4 > /dev/null 2>&1 # DA mask
        ssdk_sh debug reg set 0x408 0x00000000 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x40c 0x00000000 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x410 0x00000fff 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x414 0x000000f9 4 > /dev/null 2>&1 # start & end , MAC rule type, vid-mask MUST be 1
        ssdk_sh debug reg set 0x400 0x800001$acl_rule_index 4 > /dev/null 2>&1 # ACL_Busy, Write command, Mask and Index to ind-1
        ########### Add MAC action ###########
        ssdk_sh debug reg set 0x404 0x${prio}0000000 4 > /dev/null 2>&1 # Ctag-pri bits [31:29]
        ssdk_sh debug reg set 0x408 0x00000200 4 > /dev/null 2>&1 # b41=1, ctag_pri_remap_en
        ssdk_sh debug reg set 0x40c 0x00000000 4 > /dev/null 2>&1 #forward
        ssdk_sh debug reg set 0x410 0x00000000 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x414 0x00000000 4 > /dev/null 2>&1
        ssdk_sh debug reg set 0x400 0x800002$acl_rule_index 4 > /dev/null 2>&1 # ACL_Busy, Write command, Result and Index to ind-1
        acl_rule_index=`expr $acl_rule_index + 1`
        acl_rule_index=`printf '%02x\n' $acl_rule_index`
    fi
fi

ip link set $SYSCFG_lan_ethernet_physical_ifnames down
ip link set $SYSCFG_lan_ethernet_physical_ifnames addr $SYSCFG_lan_mac_addr
ip link set $SYSCFG_lan_ethernet_physical_ifnames up

#if [ $SYSCFG_bridge_mode = "0" ] ; then
    ip link set $SYSCFG_wan_physical_ifname down
    ip link set $SYSCFG_wan_physical_ifname addr $SYSCFG_wan_mac_addr
    ip link set $SYSCFG_wan_physical_ifname up
#fi

if [ "$SYSCFG_ipv6_passthrough_enable" = "1" ] && [ "$SYSCFG_ipv6_passthrough_done_in_hw" = 1 ] ; then
    ssdk_sh debug reg set 0x30 0x80000703 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x610 0x001b5560 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x614 0x80050002 4 > /dev/null 2>&1

    ssdk_sh debug reg set 0x404 0x00000000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x408 0x00000000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x40c 0x00000000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x410 0x86dd0000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x414 0x0000003f 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x400 0x800000$acl_rule_index 4 > /dev/null 2>&1

    ssdk_sh debug reg set 0x404 0x00000000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x408 0x00000000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x40c 0x00000000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x410 0xffff0000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x414 0x000000c9 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x400 0x800001$acl_rule_index 4 > /dev/null 2>&1

    ssdk_sh debug reg set 0x404 0x00050000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x408 0x00002000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x40c 0x00000000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x410 0x00000000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x414 0x00000000 4 > /dev/null 2>&1
    ssdk_sh debug reg set 0x400 0x800002$acl_rule_index 4 > /dev/null 2>&1

    ssdk_sh debug reg set 0x660 0x14013e 4 > /dev/null 2>&1 #p0
    ssdk_sh debug reg set 0x66c 0x14013d 4 > /dev/null 2>&1 #p1
    ssdk_sh debug reg set 0x678 0x14013b 4 > /dev/null 2>&1 #p2
    ssdk_sh debug reg set 0x684 0x140137 4 > /dev/null 2>&1 #p3
    ssdk_sh debug reg set 0x690 0x14012f 4 > /dev/null 2>&1 #p4
    ssdk_sh debug reg set 0x69c 0x14011f 4 > /dev/null 2>&1 #p5
fi

#there are some garbage fdb entries produced during switch initialization, flush them
ssdk_sh fdb entry flush 0 > /dev/null 2>&1
