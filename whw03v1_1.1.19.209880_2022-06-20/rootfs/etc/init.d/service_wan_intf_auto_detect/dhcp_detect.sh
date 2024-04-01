#!/bin/sh
source /etc/init.d/ulog_functions.sh
SRV_NAME="wan_intf_auto_detect"
SUB_COMP="dhcp_detect"
prepare_dhcp_client_handler ()
{
    DHCP_CLIENT_HANDLER=/tmp/dhcp_client_handler_tmp_$1.sh
    echo -n > $DHCP_CLIENT_HANDLER
    
cat << EOF >> $DHCP_CLIENT_HANDLER
#!/bin/sh
case "\$1" in 
    deconfig)
        ;;
    bound|renew)
        IP="\$ip"
        INTF="\$interface"
        if [ -z "\$subnet" ]; then
            SUBNET="255.255.255.0"
        else
            SUBNET="\$subnet"
        fi
        if [ -z "\$broadcast" ]; then
            BROADCAST="broadcast +"
        else
            BROADCAST="broadcast \$broadcast"
        fi
        ip -4 addr add \$IP"/"\$SUBNET \$BROADCAST dev \$INTF
        ;;
    *)
        ;;
esac
EOF
chmod u+x $DHCP_CLIENT_HANDLER
}
del_dhcp_client_handler ()
{
    DHCP_CLIENT_HANDLER=/tmp/dhcp_client_handler_tmp_$1.sh
    
    if [ -e $DHCP_CLIENT_HANDLER ]; then
        rm -f $DHCP_CLIENT_HANDLER
    fi
}
if [ "$(syscfg get wan::intf_auto_detect_debug)" = "1" ]; then
    set -x
fi
if [ -z "$1" -o -z "$2" ]; then
    ulog $SRV_NAME $SUB_COMP "interface not specified, dhcp detect abort"
    return 2
fi
pid_file="$2"
echo "$$" > $pid_file
trap 'rm -f "$pid_file"' INT TERM EXIT;
ulog $SRV_NAME $SUB_COMP "dhcp detect starts on $1"
date_start=$(date +%s)
prepare_dhcp_client_handler $1
RESULT="0"
for intf in $1
do
    udhcpc -R -S -a -q -n -s $DHCP_CLIENT_HANDLER -t 5 -T 3 -i $intf > /dev/null 2>&1
    ret=$?
    if [ "$ret" = "0" ]; then
        RESULT="1"
        break
    fi
done
date_end=$(date +%s)
time_spend=$(expr $date_end - $date_start)
if [ "$RESULT" = "1" ]; then
    ASSIGNED_IP=`ip -4 addr show dev $1 | grep inet | awk '{print $2}'`
    if [ -n "$ASSIGNED_IP" ]; then
        ip -4 addr del $ASSIGNED_IP dev "$1"
    fi
    ulog $SRV_NAME $SUB_COMP "detect result: Yes, spent $time_spend seconds"
    sysevent set dhcp_detect_on_${1} "DETECTED"
else
    ulog $SRV_NAME $SUB_COMP "detect result: No, spent $time_spend seconds"
    sysevent set dhcp_detect_on_${1} "FAILED"
fi
if [ -n "$(pidof udhcpc)" ]; then
    pkill -SIGTERM -f "udhcpc -R -S -a -q -n -s $DHCP_CLIENT_HANDLER -t 5 -T 3"
fi
del_dhcp_client_handler $1
rm -f "$2"
return $RESULT
