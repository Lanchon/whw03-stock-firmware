#!/bin/sh
DEV_WAN=eth1
QOS_DEV_WAN=$DEV_WAN
PPP_STATUS=`cat /tmp/ppp/ppp0-status 2> /dev/null`
if [ "$?" = "0" ] ;
then
	echo $PPP_STATUS
	if [ "$PPP_STATUS" = "1" ] ;
	then
		DEV_WAN=ppp0
		QOS_DEV_WAN=ppp0
	fi
fi
DEV_LAN=br0
QOS_DEV_LAN=$DEV_LAN
LD_LIBRARY_PATH=$(pwd):$LD_LIBRARY_PATH
export LD_LIBRARY_PATH
SHN_CTRL_CMD=./shn_ctrl
DPI_CTRL_CMD=./tdts_ctrl
NTPCLIENT_CMD=ntpclient
NTPDATE_CMD=ntpdate
CMD="$1";
[ -z "$CMD" ] && CMD="start"
SESS_NUM=30000
URL_MQUERY=0
UDB_PARAMS="dev_wan=$DEV_WAN"
UDB_PARAMS="$UDB_PARAMS dev_lan=$DEV_LAN"
UDB_PARAMS="$UDB_PARAMS qos_wan=$QOS_DEV_WAN"
UDB_PARAMS="$UDB_PARAMS qos_lan=$QOS_DEV_LAN"
UDB_PARAMS="$UDB_PARAMS sess_num=$SESS_NUM"
UDB_PARAMS="$UDB_PARAMS url_mquery=$URL_MQUERY"
DPI_DEV=/dev/tdts
DPI_DEV_MAJ=190
DPI_DEV_MIN=0
FWD_DEV=/dev/idpfw
FWD_DEV_MAJ=191
FWD_DEV_MIN=0
DPI_KMODULE=tdts.ko
UDB_KMODULE=tdts_udb.ko
FWD_KMODULE=tdts_udbfw.ko
SIG_FILE=rule.trf
SIG_SCHEMA_FILE=rule_schema.trf
SIG_META_DATA_FILE=meta_en-US.dat
GEN_LICENSE_CMD=gen_lic
LICENSE_MGMT_SCRIPT=lic-setup.sh
WRS_STARTUP_SCRIPT=wred-setup.sh
WRS_DAEMON_CMD=wred
WRS_STARTUP_ARGS_FILE=agg_scan_arg
IQOS_STARTUP_SCRIPT=iqos-setup.sh
IQOS_CONF_FILE=qos.conf
DC_MONITOR_SCRIPT=dc_monitor.sh
DC_CMD=dcd
DEMOGUI_HTTP_DAEMON_FOLDER=lighttpd
DEMOGUI_PC_DAEMON_CMD=parentald
ACTIVE_SCANNER_AGENT=shnagent
SFS_CMD=sfsd
WSE_AGENT_CMD=wse_agent
LICENSE_KEY_FILE_STORAGE_PATH=./
WSE_LOG_FILE_STORAGE_PATH=./
LICENSE_ID=28b2ae2827ec03054461f926adf075ef53c95a9e
FILTERDHCP_CHAIN=BWDPI_FILTER
case "$CMD" in
start)
	echo "In `pwd`"
	if [ ! -f "$SIG_FILE" ]; then
		echo "Signature file $SIG_FILE not found"
		exit 1
	fi
	if `command -v $NTPCLIENT_CMD >/dev/null 2>&1` ; then
		$NTPCLIENT_CMD -h time.stdtime.gov.tw -s &
		echo "$NTPCLIENT_CMD -h time.stdtime.gov.tw -s";
	else
		echo "$NTPDATE_CMD time.stdtime.gov.tw";
		$NTPDATE_CMD time.stdtime.gov.tw &
	fi
	echo "Creating device nodes..."
	[ ! -c "$DPI_DEV" ] && mknod $DPI_DEV c $DPI_DEV_MAJ $DPI_DEV_MIN
	[ ! -c "$FWD_DEV" ] && mknod $FWD_DEV c $FWD_DEV_MAJ $FWD_DEV_MIN
	test -c $DPI_DEV || echo "...Create $DPI_DEV failed"
	test -c $FWD_DEV || echo "...Create $FWD_DEV failed"
	echo "Filter WAN DHCP/BOOTP packets..."
	iptables -t mangle -N $FILTERDHCP_CHAIN
	iptables -t mangle -F $FILTERDHCP_CHAIN
	iptables -t mangle -A $FILTERDHCP_CHAIN -i $DEV_WAN -p udp --sport 68 --dport 67 -j DROP
	iptables -t mangle -A $FILTERDHCP_CHAIN -i $DEV_WAN -p udp --sport 67 --dport 68 -j DROP
	iptables -t mangle -A PREROUTING -i $DEV_WAN -p udp -j $FILTERDHCP_CHAIN
	echo "Loading DPI engine module..."
	insmod ./$DPI_KMODULE || exit -1
	echo "Configuring DPI Engine with signature files ($SIG_FILE, $SIG_SCHEMA_FILE)"
	$DPI_CTRL_CMD --op signature_load -1 $SIG_FILE -2 $SIG_SCHEMA_FILE
	sleep 2
	echo "Loading User Database (UDB) module with parameters: $UDB_PARAMS ..."
	insmod ./$UDB_KMODULE $UDB_PARAMS || exit 1
	echo "Loading Forwarding module..."
	insmod ./$FWD_KMODULE || exit 1
	if [ -x ./$GEN_LICENSE_CMD ]; then
		echo "Running license control"
		./$LICENSE_MGMT_SCRIPT &
		sleep 25
	fi
	if [ -x ./$IQOS_STARTUP_SCRIPT ]; then
		./$IQOS_STARTUP_SCRIPT start $IQOS_CONF_FILE
	fi
	if [ -x ./$DC_MONITOR_SCRIPT ]; then
		./$DC_MONITOR_SCRIPT &
	fi
	if [ -x ./$WRS_STARTUP_SCRIPT ]; then
		if [ -e ./$WRS_STARTUP_ARGS_FILE ]; then
			./$WRS_STARTUP_SCRIPT `cat $WRS_STARTUP_ARGS_FILE` &
		else
			./$WRS_STARTUP_SCRIPT &
		fi
		$SHN_CTRL_CMD -a set_wred_conf -R wred.conf
	fi
	$SHN_CTRL_CMD -a set_app_patrol -R ./app_patrol.conf
	$SHN_CTRL_CMD -a set_patrol_tq -R ./patrol_tq.conf
	if [ -x ./$ACTIVE_SCANNER_AGENT ]; then
		./$ACTIVE_SCANNER_AGENT -b
	fi
	if [ -x ./$SFS_CMD ]; then
		./$SFS_CMD
		$SHN_CTRL_CMD -a set_sfs_conf -f ./sfs.conf
		$SHN_CTRL_CMD -a set_sfs_dev -f ./sfs_dev.conf
		$SHN_CTRL_CMD -a get_sfs_status
	fi
	echo "Extract Signature meta data and push to UDB..."
	$SHN_CTRL_CMD -a set_meta_data -R $SIG_META_DATA_FILE
	if [ -d "$DEMOGUI_HTTP_DAEMON_FOLDER" ]; then
		cd $DEMOGUI_HTTP_DAEMON_FOLDER
		./setup.sh
		cd - > /dev/null
	fi
	$SHN_CTRL_CMD -a set_eula_agreed
	if [ -x ./$WSE_AGENT_CMD ]; then
		echo "Verifying License..."
		./$WSE_AGENT_CMD -k $LICENSE_KEY_FILE_STORAGE_PATH -p ./ -l $WSE_LOG_FILE_STORAGE_PATH
		sleep 1 # Wait Agent init
		$SHN_CTRL_CMD -a get_license -l $LICENSE_ID -p ./ > ./license_status
		cat ./license_status
	fi
	;;
stop)
	if [ -d "$DEMOGUI_HTTP_DAEMON_FOLDER" ]; then
		cd $DEMOGUI_HTTP_DAEMON_FOLDER
		./setup.sh stop
		cd - > /dev/null
	fi
	killall -9 $SFS_CMD
	killall -9 $ACTIVE_SCANNER_AGENT
	if [ -x ./$IQOS_STARTUP_SCRIPT ]; then
		./$IQOS_STARTUP_SCRIPT stop
		sleep 3
	fi
	kill -9 $(ps | grep $WRS_STARTUP_SCRIPT | grep -v grep | awk {'print $1'})
	killall -9 $WRS_DAEMON_CMD
	killall -9 $DC_MONITOR_SCRIPT
	killall -9 $DC_CMD
	killall -9 $LICENSE_MGMT_SCRIPT
	killall -9 $GEN_LICENSE_CMD
	killall -9 $WSE_AGENT_CMD
	echo "Unloading modules..."
	rmmod $FWD_KMODULE > /dev/null 2>&1
	rmmod $UDB_KMODULE > /dev/null 2>&1
	rmmod $DPI_KMODULE > /dev/null 2>&1
	echo "Removing device nodes..."
	[ -c "$DPI_DEV" ] && rm -f $DPI_DEV 
	[ ! -c "$DPI_DEV" ] || echo "...Remove $dev failed"
	[ -c "$FWD_DEV" ] && rm -f $FWD_DEV
	[ ! -c "$FWD_DEV" ] || echo "...Remove $FWD_DEV failed"
	echo "Remove iptables rules..."
	iptables -t mangle -D PREROUTING -i $DEV_WAN -p udp -j $FILTERDHCP_CHAIN
	iptables -t mangle -F $FILTERDHCP_CHAIN
	iptables -t mangle -X $FILTERDHCP_CHAIN
	
	;;
restart)
	$0 stop
	sleep 5
	$0 start
	;;
esac;
