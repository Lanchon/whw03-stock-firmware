#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/syscfg_api.sh
SERVICE_NAME="autochannel"
[ "`syscfg get ${SERVICE_NAME}_debug`" = "1" ] && DEBUG=1
echo "wifi, ${SERVICE_NAME}, sysevent received: $1"
SELF_NAME="`basename $0`"
MODE=$(syscfg get smart_mode::mode)
UNCONFIGURED_MODE=0
SLAVE_MODE=1
MASTER_MODE=2
MASTER_BHData_Dir="/tmp/msg/BH"
TMPFILE="/tmp/.${SERVICE_NAME}_tmpData"
SLAVE_QUEITDate_Dir="/tmp/msg/AC"
SignalHandler()
{
echo "${SERVICE_NAME}: error, get termial signal,clear and exit"
sysevent set ${SERVICE_NAME}-status "idle"
sysevent set ${SERVICE_NAME}-errinfo "error:got terminal signal"
}
CheckFileExistence(){
FLAG=0
CHECKLIST=$@
for arg in $CHECKLIST; do
	if [ ! -f "$arg" ];then
		echo "miss $arg" > /dev/console
		FLAG=1
		break
	fi
done
echo $FLAG
}
run_master_handler(){
	ulog ${SERVICE_NAME} status ": running master_handler"
	echo "${SERVICE_NAME}: running master_handler"
	sysevent set ${SERVICE_NAME}-errinfo "scheduling ..."
	SLAVE_PUBLISHED_LIST=""	
	iwlist ath0 scan > $TMPFILE
	echo "${SERVICE_NAME}: inform the slave with wireless backhaul"
	FILELIST=`ls $MASTER_BHData_Dir 2>/dev/null`
	CHECKLIST=""
	CHECKTIME=0
	for FileName in $FILELIST ;do
		FileDir="${MASTER_BHData_Dir}/${FileName}/status"
		if [ ! -f "$FileDir" ];then
			continue
		fi
		SLAVE_WIRELSS_TYPE=`cat $FileDir 2>/dev/null | grep '"type": "WIRELESS"' -c`
		SLAVE_WIRED_TYPE=`cat $FileDir 2>/dev/null | grep '"type": "WIRED"' -c`
		SLAVE_STATUS=`cat $FileDir 2>/dev/null | awk -F'"' '/state/ {print $4}'`
		SLAVE_2GBSSID=`cat $FileDir 2>/dev/null | awk -F'"' '/userAp2G_bssid/ {print $4}'`
		CHECK_2GBSSID=`echo $SLAVE_2GBSSID | sed 's/ //g' | egrep "^[0-9a-fA-F:]{17}$" -c`
		SLAVE_UUID=`cat $FileDir 2>/dev/null | awk -F'"' '/uuid/ {print $4}'`
		CHECK_UUID=`echo $SLAVE_UUID | sed "s/-//g" | egrep "^[0-9a-zA-Z]+$" -c`
		if [ "$SLAVE_STATUS" != "up" ] || [ "$CHECK_UUID" != "1" ] || [ "$CHECK_2GBSSID" != "1" ] ;then
			echo "error, -$SLAVE_WIRELSS_TYPE=$SLAVE_STATUS=$SLAVE_UUID=$SLAVE_2GBSSID,next"
			continue
		fi
		RSSI=`sed -n '/Address: '$SLAVE_2GBSSID'/,/Address:/ p' $TMPFILE | grep "Signal level" | awk -F'=' '{print $3}' | awk '{print $1}' | sed 's/-//g'`
		CHECK_RSSI=`echo $RSSI | egrep "^[0-9]+$" -c`
		if [ "$CHECK_RSSI" != "1" ];then
			RSSI="10000"
		fi
		if [ "$SLAVE_WIRED_TYPE" = "1" ];then
			SLAVE_MAC=`cat $FileDir 2>/dev/null|awk -F'"' '/mac/ {print $4}'|sed 's/://g'`
			if [ "" != "$SLAVE_MAC" ];then
				RSSI="-10000"
			fi
		fi
		SLAVE_PUBLISHED_LIST="$SLAVE_PUBLISHED_LIST $RSSI<$SLAVE_UUID>"
		CHECKLIST="${MASTER_BHData_Dir}/${FileName}/status $CHECKLIST"
	done
	if [ "$SLAVE_PUBLISHED_LIST" != "" ];then
		SORTED_LIST=`echo $SLAVE_PUBLISHED_LIST | sed 's/ /\n/g' | sort -k1,1n | tr -d '\n' | sed 's/>/ /g'`
		Quiet_TIME=0
		for ARG in $SORTED_LIST; do
			UUID=`echo $ARG | awk -F'<' '{print $2}'`
			RSSI=`echo $ARG | awk -F'<' '{print $1}'`
			Quiet_TIME=`expr $Quiet_TIME + 1`
			let "CHECKTIME=${Quiet_TIME}"
			ulog ${SERVICE_NAME} status "restart slave wifi,uuid=$UUID,quiet time=$Quiet_TIME"
			echo "${SERVICE_NAME}: restart slave wifi uuid=$UUID,quiet time=$Quiet_TIME"
			pub_autochannel_config $UUID $Quiet_TIME
		done
	fi
	sleep 10
	ulog ${SERVICE_NAME} status "begin to restart self wifi"
	echo "${SERVICE_NAME}: begin to restart self wifi"
	sysevent set wifi-restart
	SLAVEREADY=0
	if [ "$CHECKLIST" != "" ] && [ "$CHECKTIME" -ne "0" ] ;then
		echo "remove files: $CHECKLIST"
		rm $CHECKLIST -rf
		QuietInterval=`syscfg get autochannel::quiettime`
		echo "$QuietInterval" | egrep "^[0-9]+$" 2>&1 > /dev/null
		if [ $? -eq 1 ]; then
			echo "${SERVICE_NAME}: wrong value autochannel::quiettime=$QuietInterval"
			QuietInterval=60
		fi
		let "CHECKTIME=${CHECKTIME}*${QuietInterval}"
		ulog ${SERVICE_NAME} status "wait $CHECKTIME seconds for all nodes to be reconnected"
		echo "wait $CHECKTIME seconds for all nodes to be reconnected"
		sysevent set ${SERVICE_NAME}-errinfo "waiting $CHECKTIME seconds for all slaves"
		sleep $CHECKTIME
		echo "begin to check reconnected nodes"
		CNT=0
		while [ "$CNT" -lt "15" ] ; do
			RESULT=`CheckFileExistence $CHECKLIST`
			if [ "$RESULT" -eq "0" ];then
				SLAVEREADY=1
				break
			fi	
			CNT=`expr $CNT + 1`
			echo "failed at ${CNT}rd time and sleep 10"
			sleep 10
		done
	else
		SLAVEREADY=1
	fi
	if [ "$SLAVEREADY" -eq "1" ];then
		ulog ${SERVICE_NAME} status "finished auto channel and all slave are reconnected"
		echo "finished auto channel and all slave are reconnected"
		sysevent set ${SERVICE_NAME}-errinfo "done"
	else
		ulog ${SERVICE_NAME} status "error:timeout and lose some nodes"
		echo "finished auto channel. but lose some slave"
		sysevent set ${SERVICE_NAME}-errinfo "error:timeout and lose some nodes"
	fi
	sysevent set ${SERVICE_NAME}-status "idle"
	rm $TMPFILE -rf
}
run_slave_handler(){
	UUID=`syscfg get device::uuid`
	DATAFILE="$SLAVE_QUEITDate_Dir/$UUID/config"
	ulog ${SERVICE_NAME} status "running slave_handler"
	echo "${SERVICE_NAME}: running slave_handler"
	
	if [ ! -f $DATAFILE ];then
		ulog ${SERVICE_NAME} status "$DATAFILE is missing, exit"
		echo "${SERVICE_NAME}: $DATAFILE is missing, exit"
		sysevent set ${SERVICE_NAME}-errinfo "data file does not exit"
		sysevent set ${SERVICE_NAME}-status "idle"
		return
	fi
	QUIET_TIME=`cat $DATAFILE | awk -F'"' '/quiettime/ {print $4}'`
	CHECKNUM=`echo $QUIET_TIME | egrep "^[0-9]+$" -c`
	if [ "$CHECKNUM" != "1" ];then
		ulog ${SERVICE_NAME} status "error, wrong value=${QUIET_TIME}, exit"
		echo "${SERVICE_NAME}: wrong value=${QUIET_TIME}, exit"
		sysevent set ${SERVICE_NAME}-errinfo "wrong queit time"
		sysevent set ${SERVICE_NAME}-status "idle"
		rm $DATAFILE -rf
		return
	fi
	BACKHAUL="`sysevent get backhaul::intf`"
	if [ ! -z "$BACKHAUL" -a "${BACKHAUL:0:3}" != "eth" ]; then
		[ $DEBUG ] && echo "$SERVICE_NAME: clear preferred backhaul on $UUID"
		sysevent set backhaul::preferred_bssid ""
		sysevent set backhaul::preferred_chan ""
	fi
	QuietInterval=`syscfg get autochannel::quiettime`
	echo "$QuietInterval" | egrep "^[0-9]+$" 2>&1 > /dev/null
	if [ $? -eq 1 ]; then
		echo "${SERVICE_NAME}: wrong value autochannel::quiettime=$QuietInterval"
		QuietInterval=60
	fi
	let "QUIET_TIME=${QUIET_TIME}*${QuietInterval}"
	ulog ${SERVICE_NAME} status "stop wifi, then keep queit for ${QUIET_TIME} seconds, and then start wifi"
	sysevent set ${SERVICE_NAME}-errinfo "keeping wifi quiet for ${QUIET_TIME} seconds"
	echo "${SERVICE_NAME}: stop wifi, then keep queit for ${QUIET_TIME} seconds, and then start wifi"
	sysevent set node-off-stop
	sysevent set wifi-stop
	sleep $QUIET_TIME
	sysevent set wifi-start
	sysevent set ${SERVICE_NAME}-errinfo "done"
	sysevent set ${SERVICE_NAME}-status "idle"
	rm $DATAFILE -rf
}
service_start() {
	status="`sysevent get ${SERVICE_NAME}-status`"
    if [ "$status" = "running" ];then
		ulog ${SERVICE_NAME} status "wifi $SERVICE_NAME service: already running, exit"
		exit
	else
		echo "Start service $SERVICE_NAME" > /dev/console
		ulog ${SERVICE_NAME} status "wifi $SERVICE_NAME service start"
    fi
	sysevent set ${SERVICE_NAME}-errinfo ""
	sysevent set ${SERVICE_NAME}-status "running"
	if [ "$MODE" -eq "$MASTER_MODE" ] ;then
		run_master_handler &
	elif [ "$MODE" -eq "$SLAVE_MODE" ];then
		run_slave_handler &
	fi
	echo "$SERVICE_NAME: parent procceed exit"
	return 0
}
service_stop () {
	echo "Stop service $SERVICE_NAME" > /dev/console
	ulog ${SERVICE_NAME} status "service $SERVICE_NAME is stopped" 
	sysevent set ${SERVICE_NAME}-errinfo ""
	sysevent set ${SERVICE_NAME}-status "idle"
	killall $SELF_NAME 2>/dev/null
}
service_init() {
	ulog ${SERVICE_NAME} status "wifi autochannel service init"
    ENABLED="`syscfg get autochannel::enabled`"
	if [ "$ENABLED" != "1" ] ; then
		ulog ${SERVICE_NAME} status "$PID service $SERVICE_NAME: syscfg is disabled, exit"
		echo "service $SERVICE_NAME: syscfg is disabled, exit"
		sysevent set ${SERVICE_NAME}-status "idle"
		sysevent set ${SERVICE_NAME}-errinfo "syscfg is disabled"
		exit
	fi
	if [ "$MODE" -ne "$MASTER_MODE" ] && [ "$MODE" -ne "$SLAVE_MODE" ];then
		ulog ${SERVICE_NAME} status "$PID service $SERVICE_NAME: mode($MODE) is wrong, exit"
		sysevent set ${SERVICE_NAME}-status "idle"
		sysevent set ${SERVICE_NAME}-errinfo "mode($MODE) is wrong"
		exit
	fi
	trap 'SignalHandler;exit' 1 2 3 15
}
service_init
case "$1" in
	${SERVICE_NAME}-start)
		service_start
		;;
	*)
		echo "Usage: $SELF_NAME [${SERVICE_NAME}-start]" >&2
		exit 3
		;;
esac
