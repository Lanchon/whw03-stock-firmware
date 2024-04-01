#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/service_misc_functions.sh
assign_value()
{
    QUAL="$1"
    if [ "$QUAL" == "Bad" ]; then
        return 1
    elif [ "$QUAL" == "Good" ]; then
        return 2
    elif [ "$QUAL" == "Already" ]; then
        return 3
    else
        return 0
    fi
}
get_rounds()
{
    MAX_DEVICE_ROUND=10
    BOTS="$1"
    ATH0_COUNT=0
    ATH1_COUNT=0
    ATH10_COUNT=0
    
    OLD_IFS="$IFS"
    IFS=','
    for BOT in $BOTS; do
        INTF=$( echo $BOT | cut -d ':' -f 1 )
        
        if [ "$INTF" = "ath0" ]; then
            ATH0_COUNT=$( expr $ATH0_COUNT + 1 )
        elif [ "$INTF" = "ath0" ]; then
            ATH1_COUNT=$( expr $ATH1_COUNT + 1 )
        else
            ATH10_COUNT=$( expr $ATH10_COUNT + 1 )
        fi
        
    done
    IFS=$OLD_IFS
    
    ATH0_ROUNDS=$(( ($ATH0_COUNT + 9) / $MAX_DEVICE_ROUND ))
    ATH1_ROUNDS=$(( ($ATH1_COUNT + 9) / $MAX_DEVICE_ROUND ))
    ATH10_ROUNDS=$(( ($ATH10_COUNT + 9) / $MAX_DEVICE_ROUND ))
    
    local ROUNDS=0
    for i in $ATH0_ROUNDS $ATH1_ROUNDS $ATH10_ROUNDS; do
        if [ $i -gt $ROUNDS ]; then
            ROUNDS=$i
        fi
    done
    return $ROUNDS
}
FORMATTED_MAC_LIST="$1"
SCANNED_BOT_LIST="/tmp/scanned_bot_list"
LOCAL_SCANNED_BOT_LIST="/tmp/local_scanned_bot_list"
MOTION_DIR="/tmp/msg/MOTION"
MASTER_SCANNED_BOT_LIST="$MOTION_DIR/master/scanned_bots"
MAX_SCAN_RESULTS_WAIT_TIME=20
MIN_DURATION_ROUND=130
MAX_DEVICE_ROUND=10
START_TIME=$( sysevent get origin::bot_scanning_starttime )
sysevent set origin::bot_scanning_status Running
if [ "$(syscfg get origin::enabled)" == "1" ]; then
    PROC_PID_LINE="`ps -w | grep "origind" | grep -v grep`"
    PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
    if [ -z "$PROC_PID" ]; then
        /usr/sbin/origind -D
        sysevent set restart_after_bot_scan 1
    fi
    ( csi_check $FORMATTED_MAC_LIST > $LOCAL_SCANNED_BOT_LIST )
    RET_CODE=$?
    echo "date: $( date +%s )" >> $LOCAL_SCANNED_BOT_LIST
else
    /usr/sbin/origind -D
    ( csi_check $FORMATTED_MAC_LIST > $LOCAL_SCANNED_BOT_LIST )
    RET_CODE=$?
    echo "date: $( date +%s )" >> $LOCAL_SCANNED_BOT_LIST
    killall_if_running origind 15
fi
if [ "$RET_CODE" = "0" ]; then
    pub_scanned_bots
    if [ "$( syscfg get smart_mode::mode)" == "2" ]; then
        get_rounds $FORMATTED_MAC_LIST
        ROUNDS=$?
        TOTAL_WAIT_TIME=$( expr $ROUNDS \* $MIN_DURATION_ROUND )
        CURRENT_TIME=$( date +%s )
        while [ $( expr $CURRENT_TIME - $START_TIME ) -lt $TOTAL_WAIT_TIME ]
        do
            sleep 1
            CURRENT_TIME=$( date +%s )
        done
        MIN_DURATION_ROUND_EXTRA=140
        MAX_DELTA=$(  expr $ROUNDS \* $MIN_DURATION_ROUND_EXTRA )
        MASTER_SCAN_FINISH_TIME=$( tail -n 1 $MASTER_SCANNED_BOT_LIST | awk '{print $2}' )
        for node in $(ls $MOTION_DIR)
        do
            if [ "$node" == "master" ]; then
                continue
            fi
            
            PAYLOAD_PATH="$MOTION_DIR/$node/scanned_bots"
            if [ -f "$PAYLOAD_PATH" ]; then
                SLAVE_SCAN_FINISH_TIME=$( tail -n 1 $PAYLOAD_PATH | awk '{print $2}' )
            else
                SLAVE_SCAN_FINISH_TIME=0
            fi
            DELTA=$( expr $SLAVE_SCAN_FINISH_TIME - $MASTER_SCAN_FINISH_TIME )
            POSITIVE_DELTA=$( echo $DELTA | sed s/-//g )
            
            echo "MASTER_SCAN_FINISH_TIME: $MASTER_SCAN_FINISH_TIME, SLAVE_SCAN_FINISH_TIME:$SLAVE_SCAN_FINISH_TIME, DELTA:$DELTA, POSITIVE_DELTA: $POSITIVE_DELTA" > /dev/console
            while [ $POSITIVE_DELTA -gt $MAX_DELTA ]
            do
                if [ $( expr $CURRENT_TIME - $MASTER_SCAN_FINISH_TIME ) -gt $MAX_SCAN_RESULTS_WAIT_TIME ]; then
                    break
                fi
                
                sleep 1
                if [ -f "$PAYLOAD_PATH" ]; then
                    SLAVE_SCAN_FINISH_TIME=$( tail -n 1 $PAYLOAD_PATH | awk '{print $2}' )
                else
                    SLAVE_SCAN_FINISH_TIME=0
                fi
                DELTA=$( expr $SLAVE_SCAN_FINISH_TIME - $MASTER_SCAN_FINISH_TIME )
                POSITIVE_DELTA=$( echo $DELTA | sed s/-//g )
                CURRENT_TIME=$( date +%s )
            done
        done
        cp $MOTION_DIR/master/scanned_bots $SCANNED_BOT_LIST
        sed '$d' -i "$SCANNED_BOT_LIST"
        for node in $(ls $MOTION_DIR)
        do
            if [ "$node" == "master" ]; then
                continue
            fi
            
            PAYLOAD_PATH="$MOTION_DIR/$node/scanned_bots"
            if ! [ -f "$PAYLOAD_PATH" ]; then
                continue
            fi
            
            while read line
            do
                if [ -n "$( echo $line | grep date )" ]; then
                    continue
                fi
                
                MAC_ADDRESS="$( echo $line | cut -d ' ' -f 2 )"
                QUALITY="$( echo $line | cut -d ' ' -f 3 )"
                assign_value $QUALITY
                QUALITY_VAL=$?
                
                if [ -z "$MAC_ADDRESS" ] || [ -z "$QUALITY" ] || [ -z "$QUALITY_VAL" ]; then
                    continue
                fi
                
                SCANNED_DEVICE="$( cat $SCANNED_BOT_LIST | grep -i $MAC_ADDRESS )"
                if [ -n "$SCANNED_DEVICE" ]; then
                    SCANNED_DEVICE_QUALITY="$( echo $SCANNED_DEVICE | cut -d ' ' -f 3 )"
                    assign_value $SCANNED_DEVICE_QUALITY
                    SCANNED_DEVICE_QUALITY_VAL=$?
                    
                    if [ $QUALITY_VAL -gt $SCANNED_DEVICE_QUALITY_VAL ]; then
                        sed -i "s%$SCANNED_DEVICE%$line%g" "$SCANNED_BOT_LIST"
                    fi
                else
                    echo "$line" >> $SCANNED_BOT_LIST
                fi
                
            done < "$PAYLOAD_PATH"
        done
    fi
    sysevent set origin::bot_scanning_status Success
    if [ "$(sysevent get restart_after_bot_scan)" = "1" ]; then
        sysevent set restart_after_bot_scan 0
        sysevent set origin-restart
    fi
else
    sysevent set origin::bot_scanning_status Error
    if [ "$(sysevent get restart_after_bot_scan)" = "1" ]; then
        sysevent set restart_after_bot_scan 0
        sysevent set origin-restart
    fi
fi
