#!/bin/sh
source /etc/init.d/ulog_functions.sh
SCRIPT_NAME=$(basename $0)
ulog wlan status "$SCRIPT_NAME, sysevent received: $1"
LAST_SCAN_TABLE_UPDATE=/tmp/last_scan_table_update
LAST_SCAN_TABLE_UPDATE_MIN_AGE=30
check_if_time_for_scan_table_update () {
    local RESULT=0
    if [ "$(find $(dirname $LAST_SCAN_TABLE_UPDATE)    \
             -name $(basename $LAST_SCAN_TABLE_UPDATE) \
             -maxdepth 1                               \
             -mmin -${LAST_SCAN_TABLE_UPDATE_MIN_AGE})" ]; then
        local MSG="$SCRIPT_NAME: Skipping scan table update; one was done < $LAST_SCAN_TABLE_UPDATE_MIN_AGE minutes ago"
        ulog wlan status "$MSG"
        RESULT=1
    fi
    return $RESULT
}
validate_wifi_dfs_channel_info()
{
    if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ]; then
        local wl1_dfs="$(syscfg get wl1_dfs_enabled)"
        local wl1_channel="36,40,44,48"
        local wl1_dfs_channel="36,40,44,48,52,56,60,64"
        if [ "$wl1_dfs" = "0" -a "$wl1_dfs_channel" = "$(syscfg get wl1_available_channels)" ]; then
            echo "wl1 dfs disabled, but channel contains dfs channel, please check" > /dev/console
            exit
        fi
        if [ "$wl1_dfs" = "1" -a "$wl1_channel" = "$(syscfg get wl1_available_channels)" ]; then
            ulog wlan status  "wl1 dfs enabled, but channel does not contains dfs channel, please check" 
            return
        fi
    fi
}
vir_intf_to_phy_intf()
{
    local vif="$1"
    local index
    local pif=""
    if [ -z "$vif" ]; then
        echo ""
        return
    fi
    if [ -e /sys/class/net/$vif/parent ]; then
        pif="$(cat /sys/class/net/$vif/parent)"
        echo "$pif"
        return
    fi
    if [ -e /sys/class/net/$vif/phy80211/index ]; then
        index=$(cat /sys/class/net/$vif/phy80211/index)
        if [ -n "$index" ]; then
            pif="wifi${index}"
            echo "$pif"
            return
        fi
    fi
    echo "$pif"
    return
}
get_channels_to_scan()
{
    local vir_if=$1
    local wl_index
    if [ -z "$vir_if" ]; then 
        echo ""
        return
    fi
    wl_index=$(syscfg get ${vir_if}_syscfg_index)
    case "${wl_index:2:1}" in
        0)
            band="2G"
            ;;
        1|2)
            band="5G[HL]"
            ;;
        3)
            band="6G"
            ;;
        *)
            band=""
            echo "error:invalid wl_index ($wl_index)" > /dev/console
            return
            ;;
    esac
    chan_list="$(grep -h -s -E userAp${band}_channel /tmp/msg/WLAN/*/serving_channels | awk '{print $2}' | tr -d '\",'| sort -u | xargs)"
    echo "$chan_list"
    return
}
scan_table_update_handler()
{
    local MIN_DWELL=100
    local MAX_DWELL=200
    local REST_TIME=100
    local IDLE_TIME=100
    local SCAN_MODE=1
    local MAX_SCAN_TIME=2000
    local chan vir_if phy_if chans max_scan_time
	AP_INTF="`syscfg get lan_wl_physical_ifnames`"
    if [ -n "$AP_INTF" ]; then
        for vir_if in $AP_INTF; do
            
            phy_if=$(vir_intf_to_phy_intf $vir_if)
            chans=$(get_channels_to_scan $vir_if)
            chan_cnt=$(echo "$chans" | wc -w)
            if [ "$(syscfg get ${vir_if}_syscfg_index)" = "wl3" ]; then
                BAND_OPT="--band 3"
            else
                BAND_OPT=""
            fi
            if [ -n "$phy_if" -a -n "$chans" -a "$chan_cnt" != "0" ]; then
                max_scan_time=$(expr $MAX_DWELL \* $chan_cnt)
                if [ $max_scan_time -gt $MAX_SCAN_TIME ]; then
                    max_scan_time=$MAX_SCAN_TIME
                fi
                ulog wlan status "$(date): exttool scan $phy_if, total $chan_cnt channels:$chans"
                exttool --scan --interface $phy_if $BAND_OPT \
                    --mindwell $MIN_DWELL --maxdwell $MAX_DWELL --resttime $REST_TIME \
                    --scanmode $SCAN_MODE --chcount $chan_cnt $chans \
                    --maxscantime $max_scan_time --idletime $IDLE_TIME
                sleep 5
            else
                ulog wlan status "exttool parameter error: ($phy_if), ($chan_cnt), ($chans)"
            fi
        done
    fi
    return 0
}
schedule_nb_rssi_report ()
{
    local cb_id
    local cur_time
    local due_time
    ulog wlan status "schedule a nb rssi report 5 minutes later" > /dev/console
    NB_RSSI_REPORT_CRON_FILE=/tmp/nb_rssi_report.sh
    cb_id=$(sysevent get nb_rssi_report_cb_id)
    if [ -e $NB_RSSI_REPORT_CRON_FILE -o -n "$cb_id" ]; then
        ulog wlan status "there is already a neighbor rssi report scheduled, abort"
        return
    fi
    cat << EOF > $NB_RSSI_REPORT_CRON_FILE
#!/bin/sh
source /etc/init.d/ulog_functions.sh
remove_nb_rssi_report_cron_file ()
{
    local dir
    local file
    dir=\$(cd \$(dirname \$1) && pwd)
    file=\${dir}/\$(basename \$1)
    ulog wlan status "remove \$file"
    rm -f \$file
}
case "\$1" in
    "cron_every_minute")
        ulog wlan status "checking nb rssi report in schedule" > /dev/console
        cur_time=\$(date -u +%s)
        due_time=\$(sysevent get nb_rssi_report_due_time)
        cb_id=\$(sysevent get nb_rssi_report_cb_id)
        if [ -z "\$due_time" ]; then
            ulog wlan status "no due time set for rssi report, clean"
            sysevent rm_async \$cb_id
            sysevent set nb_rssi_report_cb_id
            sysevent set nb_rssi_report_due_time
            remove_nb_rssi_report_cron_file \$0
        fi
        if [ \$cur_time -gt \$due_time ]; then
            ulog wlan status "time to report neighbor rssi, action..."
            sysevent set report_nb_rssi
            sysevent rm_async \$cb_id
            sysevent set nb_rssi_report_cb_id
            sysevent set nb_rssi_report_due_time
            remove_nb_rssi_report_cron_file \$0
            ulog wlan status "neighbor rssi reported, done"
        else
            ulog wlan status "current time: \$cur_time, due time: \$due_time, will come back a min later"
        fi
        ;;
    esac
EOF
    chmod u+x $NB_RSSI_REPORT_CRON_FILE
    cur_time=$(date -u +%s)
    due_time=$(expr $cur_time + 300)
    sysevent set nb_rssi_report_due_time "$due_time"
    cb_id=$(sysevent async cron_every_minute /tmp/nb_rssi_report.sh)
    sysevent set nb_rssi_report_cb_id "$cb_id"
    ulog wlan status "scheduled a nb rssi report at $due_time, current time is $cur_time"
}
case "$1" in
    scan_table_update)
        if [ "$(sysevent get wifi-status)" != "started" ]; then
            ulog wlan status "wifi status is not started, abort update scan table"
            exit
        fi
        if [ -n "$2" -a "$2" = "2" ]; then
            touch $LAST_SCAN_TABLE_UPDATE
            scan_table_update_handler
            schedule_nb_rssi_report
        else
            if check_if_time_for_scan_table_update; then
                touch $LAST_SCAN_TABLE_UPDATE
                scan_table_update_handler
                schedule_nb_rssi_report
            fi
        fi
        ;;
	*)
	echo "$SCRIPT_NAME unknown event $1" > /dev/console
		;;
esac
