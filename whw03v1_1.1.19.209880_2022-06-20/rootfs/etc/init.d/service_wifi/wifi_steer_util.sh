log_to=$(cat /tmp/wifi_steer_log_to 2>/dev/null)
dbg_log()
{
    case "$log_to" in
        console)
            echo "<<`date -u +%D-%H:%M:%S`:$*>>" > /dev/console
            ;;
        syslog)
            ulog wlan steer "<<`date -u +%D-%H:%M:%S`:$*>>"
            ;;
        *)
            ulog wlan steer "<<`date -u +%D-%H:%M:%S`:$*>>"
            ;;
    esac
}
band_to_ap()
{
    local band="$1"
    local product="$(cat /etc/product)"
    ap_intf=""
    
    case "$product" in
        nodes)
            case "$band" in
                24G)
                    ap_intf="`syscfg get wl0_user_vap`"
                    ;;
                5GL)
                    ap_intf="`syscfg get wl1_user_vap`"
                    ;;
                5GH)
                    ap_intf="`syscfg get wl2_user_vap`"
                    ;;
                *)
                    dbg_log "$band is invalid, pleaee check"
                    ;;
            esac
            ;;
        nodes-jr)
            case "$band" in
                24G)
                    ap_intf="`syscfg get wl0_user_vap`"
                    ;;
                5GL)
                    ap_intf="`syscfg get wl1_user_vap`"
                    ;;
                *)
                    dbg_log "$band is invalid, pleaee check"
                    ;;
            esac
            ;;
        *)
            dbg_log "$product is invalid, pleaee check"
            ;;
    esac
    echo "$ap_intf"
}
ap_to_bssid()
{
    local ap_intf="$1"
    ap_bssid=""
    
    mode=`iwconfig $ap_intf | sed -n '2p' | awk '{print $1}' | cut -d: -f2`
    access_point=`iwconfig $ap_intf |  sed -n '2p' | awk '{print $6}'`
    if [ "$mode" = "Master" ]; then
        ap_bssid="$access_point"
    fi
    echo $ap_bssid
}
bssid_to_ap()
{
    local bssid="$1"
    if [ -z "$bssid" ]; then
        return 2
    fi
    for ap in $(syscfg get lan_wl_physical_ifnames)
    do
        mode=`iwconfig $ap | sed -n '2p' | awk '{print $1}' | cut -d: -f2`
        access_point=`iwconfig $ap |  sed -n '2p' | awk '{print $6}'`
        if [ "$mode" = "Master" -a "$access_point" = "$bssid" ]; then
            echo "$ap"
            return 1
        fi
    done
    echo ""
    return 0
}
get_bssid_chan()
{
    local bssid="$1"
    if [ -z "$bssid" ]; then
        echo "" && return 0
    fi
    local msg_root_path="/tmp/msg/WLAN"
    local units=$(ls -d $msg_root_path/*/)
    local status_file
    local band
    if [ -z "$units" ]; then
        echo "" && return 0
    fi
    for unit in $units; do
        status_file=${unit}"status"
        for band in 2G 5GL 5GH; do
            if [ "$bssid" = "$(jsonparse -f $status_file data.userAp${band}_bssid)" ]; then
                echo "$(jsonparse -f $status_file data.userAp${band}_channel)" && return 1
            fi
        done
    done
    echo "" && return 0
<<'com'
    local ap_intf=$(bssid_to_ap $bssid)
    if [ -n "$ap_intf" ]; then
        echo $(iwlist $ap_intf channel | grep "Current Frequency" | awk '{print $NF}' | tr -d ')') && return 1
    else
        echo "" && return 0
    fi
com
}
force_disassociate_client()
{
    local client_mac
    local vap
    vap="$1"
    client_mac="$2"
    if [ -z "$client_mac" -o -z "$vap" ]; then
        dbg_log "client mac or vap not specified"
        return 1
    fi
    local client_exist
    client_exist="$(wlanconfig "$vap" list sta | grep -i "$client_mac" | awk '{print $1}')"
    
    if [ -z "$client_exist" ]; then
        dbg_log "client $client_mac is not associated to AP $vap"
        return 1
    fi
    iwpriv "$vap" kickmac "$client_mac"
    dbg_log "client $client_mac is kicked from $vap"
    return 0
}
add_client_into_blacklist()
{
    local clnt_mac
    local vap
    vap="$1"
    clnt_mac="$2"
    
    if [ -z "$clnt_mac" -o -z "$vap" ]; then
        dbg_log "client mac or vap not specified"
        return 1
    fi
    is_ap_working "$vap"
    if [ "$?" != "1" ]; then
        return 1
    fi
    local clnt_in_bl
    clnt_in_bl="$(iwpriv $vap getmac_sec | grep -i $clnt_mac)"
    if [ -n "$clnt_in_bl" ]; then
        dbg_log "client $clnt_mac is already in blacklist of $vap"
        return 1
    fi
    local wps_state=$(iwpriv $vap get_wps | awk -F ':' '{print $2}')
    if [ "$wps_state" != "0" ]; then
        iwpriv "$vap" wps 0
    fi
    
    iwpriv "$vap" addmac_sec $clnt_mac
    
    if [ "2" != "$(iwpriv $vap get_maccmd_sec | cut -d: -f2)" ]; then
        iwpriv "$vap" maccmd_sec 2
    fi
    dbg_log "client $clnt_mac is add into blacklist of $vap"
    return 0
}
add_client_into_blacklist_unit()
{
    local ap
    local client_mac="$1"
    if [ -z "$client_mac" ]; then
        dbg_log "client mac is not specified"
        return 1
    fi
    for ap in $(syscfg get lan_wl_physical_ifnames)
    do
        add_client_into_blacklist "$ap" "$client_mac"
    done
    if [ "$(syscfg get vivint::enabled)" = "1" ]; then
        for ap in $(syscfg get vivint::wl0_vap) $(syscfg get vivint::wl1_vap) $(syscfg get vivint::wl2_vap)
        do
            add_client_into_blacklist "$ap" "$client_mac"
        done
    fi
    return 0
}
ap_hide_ssid()
{
    vap="$1"
    hide_ssid="$2"
    if [ -z "$vap" -o -z "$hide_ssid" ]; then
        return 2
    fi
    if [ "$hide_ssid" != "1" ]; then
        hide_ssid="0"
    fi
    dbg_log "hide ssid: $hide_ssid"
    iwpriv "$vap" hide_ssid "$hide_ssid"
}
remove_client_from_blacklist()
{
    local clnt_mac
    local vap
    vap="$1"
    clnt_mac="$2"
    
    if [ -z "$clnt_mac" -o -z "$vap" ]; then
        dbg_log "client mac or vap not specified"
        return 1
    fi
    is_ap_working "$vap"
    if [ "$?" != "1" ]; then
        return 1
    fi
    local clnt_in_bl
    clnt_in_bl=$(iwpriv "$vap" getmac_sec | grep -i "$clnt_mac")
    if [ -z "$clnt_in_bl" ]; then
        dbg_log "client $clnt_mac is not in blacklist of $vap"
        return 1
    fi
    iwpriv "$vap" delmac_sec "$clnt_mac"
    dbg_log "client $clnt_mac is removed from blacklist of $vap"
    return 0
}
remove_client_from_blacklist_unit()
{
    local ap
    local client_mac="$1"
    if [ -z "$client_mac" ]; then
        dbg_log "client mac is not specified"
        return 1
    fi
    for ap in $(syscfg get lan_wl_physical_ifnames)
    do
        remove_client_from_blacklist "$ap" "$client_mac"
    done
    
    if [ "$(syscfg get vivint::enabled)" = "1" ]; then
        for ap in $(syscfg get vivint::wl0_vap) $(syscfg get vivint::wl1_vap) $(syscfg get vivint::wl2_vap)
        do
            remove_client_from_blacklist "$ap" "$client_mac"
        done
    fi
    return 0
}
is_ap_working()
{
    local ap_intf
    local mode
    ap_intf="$1"
    if [ -z "$ap_intf" ]; then
        return 2
    fi
    
    mode=`iwconfig $ap_intf | sed -n '2p' | awk '{print $1}' | cut -d: -f2`
    access_point=`iwconfig $ap_intf |  sed -n '2p' | awk '{print $6}'`
    if [ "$mode" = Master"" -a "$access_point" != "Not-Associated" ]; then
        return 1
    fi
    return 0
}
is_client_associated()
{
    local ap_intf
    local client
    ap_intf="$1"
    client="$2"
    if [ -z "$ap_intf" -o -z "$client" ]; then
        return 2
    fi
    local ret
    ret=`wlanconfig "$ap_intf" list sta | grep -i "$client"`
    if [ -n "$ret" ]; then
        return 1
    fi
    return 0
}
is_client_associated_unit()
{
    client="$1"
    serving_ap=""
    
    if [ -z "$client" ]; then
        dbg_log "client mac not specified, abort"
        return 2
    fi
    
    local ap
    for ap in $(syscfg get lan_wl_physical_ifnames)
    do
        is_client_associated "$ap" "$client"
        ret="$?"
        if [ "$ret" = "1" ]; then
            serving_ap="$ap"
            return 1
        fi
    done
    if [ "$(syscfg get vivint::enabled)" = "1" ]; then
        for ap in $(syscfg get vivint::wl0_vap) $(syscfg get vivint::wl1_vap) $(syscfg get vivint::wl2_vap)
        do
            is_client_associated "$ap" "$client"
            ret="$?"
            if [ "$ret" = "1" ]; then
                serving_ap="$ap"
                return 1
            fi
        done
    fi
    return 0
}
steer_11v()
{
    if [ -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
        return 2
    fi
    wifitool "$1" sendbstmreq_target "$2" "1" "1" "255" "$3" "$4" "255" "0" "0"
    return "$?"
}
check_client_signal()
{
    RSSI_TH=$(syscfg get wifi_tb::threshold)
    TB_DURATION=$(syscfg get wifi_tb::duration)
    if [ -z "$RSSI_TH" -o -z "$TB_DURATION" ]; then
        ulog wlan status "temp blacklist: rssi_th or tb_duration config missing"
        return
    fi
    client_mac="$1"
    ap_intf="$2"
    client_rssi="$(expr $3 + 95)"
    if [ -z "$client_mac" -o -z "$ap_intf" -o -z "$client_rssi" ]; then
        ulog wlan status "temp blacklist: client mac or ap intf or client rssi missing"
        return
    fi
    local weak_assoc_time="$(sysevent get ${client_mac}::weak_assoc_time)"
    local current_time="$(date -u +%s)"
    if [ "$client_rssi" -lt "$RSSI_TH" ]; then
        ulog wlan status "client $client_mac conected with weak signal, RSSI=$client_rssi"
        if [ -z "$weak_assoc_time" ] || [ -n "$weak_assoc_time" -a "$weak_assoc_time" -lt "$(expr $current_time - 300)" ] ; then
            ulog wlan status "temp blacklist the client $client_mac"
            sysevent set ${client_mac}::weak_assoc_time "$(date -u +%s)"
            sysevent set blacklist_clients "$client_mac"
        else
            ulog wlan status "just blacklisted the client $client_mac minutes before, it comes back, let it stay"
            sysevent set ${client_mac}::weak_assoc_time ""
        fi
    else
        ulog wlan status "client $client_mac conected with good signal, RSSI=$client_rssi"
        if [ -n "$(sysevent get ${client_mac}::weak_assoc_time)" ]; then
            sysevent set ${client_mac}::weak_assoc_time ""
        fi
    fi
    return
}
check_weak_signal_clients()
{
    local ap="$1"
    local rssi_th="$(syscfg get wifi_tb::threshold)"
    local weak_clients_list=""
    if [ -z "$ap" -o -z "$rssi_th" ]; then
        echo ""
        return 0
    fi
    weak_clients_list=$(wlanconfig $ap list sta | sed -n '2,$p' | awk '{if ($6 > $th) print $1}' th=$rssi_th | xargs)
    if [ -z "$weak_clients_list" ]; then
        echo ""
        return 0
    else
        echo "$weak_clients_list"
        return 1
    fi
}
is_client_rrm_compatible()
{
    local ap="$1"
    local client="$2"
    local rrm=""
    if [ -z "$ap" -o -z "$client" ]; then
        dbg_log "parameter missing, serving ap($ap),client mac($client)"
        return 2
    fi
    rrm=$(wifitool $ap rrm_sta_list | grep -i "$client")
    if [ -z "$rrm" ]; then
        return 0
    else
        return 1
    fi
}
is_client_btm_compatible()
{
    local ap="$1"
    local client="$2"
    local btm=""
    if [ -z "$ap" -o -z "$client" ]; then
        dbg_log "parameter missing, serving ap($ap),client mac($client)"
        return 2
    fi
    btm=$(wifitool $ap btm_sta_list | grep -i "$client")
    if [ -z "$btm" ]; then
        return 0
    else
        return 1
    fi
}
