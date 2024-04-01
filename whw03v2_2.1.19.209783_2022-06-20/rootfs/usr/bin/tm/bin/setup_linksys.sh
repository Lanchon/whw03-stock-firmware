#!/bin/sh
TM_DEBUG=`syscfg get shield::debug`
if [ "1" = "$TM_DEBUG" ];then
   	set -x;
fi
QOS_DEV_WAN=$DEV_WAN
DEV_LAN=`syscfg get lan_ifname`
QOS_DEV_LAN=$DEV_LAN
WAN_PROTO=`syscfg get wan_proto`
if [ $WAN_PROTO = "pppoe" -o $WAN_PROTO = "pptp" -o $WAN_PROTO = "l2tp" ];then
	PHYSICAL_DEV_WAN=`syscfg get wan_1::wan_physical_ifname`
	PPP_INTF=`syscfg get pppd_current_wan_ifname`
	DEV_WAN=${PPP_INTF},${PHYSICAL_DEV_WAN}
else
	DEV_WAN=`syscfg get wan_1::wan_physical_ifname`
fi
QOS_DEV_WAN=$DEV_WAN
LD_LIBRARY_PATH=$(pwd):$(pwd)/../lib/:/usr/lib/tm/:/lib
export LD_LIBRARY_PATH
SHN_CTRL_CMD=./shn_ctrl
DPI_CTRL_CMD=./tdts_ctrl
NTPCLIENT_CMD=ntpclient
NTPDATE_CMD=ntpdate
CMD="$1";
[ -z "$CMD" ] && CMD="start"
SESS_NUM=`cat /proc/sys/net/nf_conntrack_max`
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
ACTIVE_SCANNER_AGENT=./shnagent
SFS_CMD=sfsd
WSE_AGENT_CMD=wse_agent
LICENSE_KEY_FILE_STORAGE_PATH=/var/config/tmshn/
WSE_LOG_FILE_STORAGE_PATH=/var/config/tmshn/
LICENSE_ID=ecb92dca66884f36d8e4245d45c864485a53f57d
LICENSE_ID="`syscfg get shield::license_id`"
FILTERDHCP_CHAIN=BWDPI_FILTER
RUID=linksys_ruid
case "$CMD" in
start)
	logger "shield service starting"
        count=1
        while [ $count -lt 10 ];do
                NTPCLIENT_STATUS=`sysevent get ntpclient-status`
                if [ "$NTPCLIENT_STATUS" = "started" ];then
                        echo "shield: ntpclient is started, proceeding..."
                        break;
                fi
                echo "shield: waiting until ntpclient service is started"
                sleep 2
                count=`expr $count + 1`
        done
	echo "In `pwd`"
	echo "Verifying License...(Stage 1)"
	logger "shield attempting to verify license $LICENSE_ID"
	mkdir -p $LICENSE_KEY_FILE_STORAGE_PATH
	./$WSE_AGENT_CMD -k $LICENSE_KEY_FILE_STORAGE_PATH -p ./ -l $WSE_LOG_FILE_STORAGE_PATH -c
	sleep 1 # Wait Agent init
	echo "Attempting to verify shield license with $LICENSE_ID / $RUID" >> /dev/console
	$SHN_CTRL_CMD -a get_license -l $LICENSE_ID -p ./ > ./license_status
	echo ""
	echo ""
	cat ./license_status
	cat ./license_status | grep -e "license_status: activated" -e "license_status: subscribed" > /dev/null
	if [ $? -ne 0 ]; then
		    echo "Error: Could not validate license. Check License ID and try again."
		    if [ "`sysevent get shield::subscription_status`" != "LIC_INVALID" ] ; then
					sysevent set shield::subscription_status "inactive"
		    fi
		    logger "shield verify license $LICENSE_ID - Failed"
			exit 1
	fi
	if [ ! -f "$SIG_FILE" ]; then
		echo "Signature file $SIG_FILE not found"
		exit 1
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
	insmod /lib/modules/`uname -r`/$DPI_KMODULE || exit -1
	echo "Configuring DPI Engine with signature files ($SIG_FILE, $SIG_SCHEMA_FILE)"
	$DPI_CTRL_CMD --op signature_load -1 $SIG_FILE -2 $SIG_SCHEMA_FILE
	sleep 2
	echo "Loading User Database (UDB) module with parameters: $UDB_PARAMS ..."
	insmod /lib/modules/`uname -r`/$UDB_KMODULE $UDB_PARAMS || exit 1
	echo "Loading Forwarding module..."
	insmod /lib/modules/`uname -r`/$FWD_KMODULE || exit 1
	if [ -x ./$GEN_LICENSE_CMD ]; then
		echo "Running license control"
		./$LICENSE_MGMT_SCRIPT &
		sleep 25
	fi
	if [ -x ./$DC_MONITOR_SCRIPT ]; then
		./$DC_MONITOR_SCRIPT & 
		sleep 3
	fi
	if [ -x ./$WRS_STARTUP_SCRIPT ]; then
		if [ -e ./$WRS_STARTUP_ARGS_FILE ]; then
			./$WRS_STARTUP_SCRIPT `cat $WRS_STARTUP_ARGS_FILE` & 
		else
			./$WRS_STARTUP_SCRIPT &
		fi
		sleep 2
		$SHN_CTRL_CMD -a set_wred_conf -R wred.conf
	fi
	echo "Extract Signature meta data and push to UDB..."
	$SHN_CTRL_CMD -a set_meta_data -R $SIG_META_DATA_FILE
	$SHN_CTRL_CMD -a set_eula_agreed
	echo "Verifying License... (Stage 2)"
	killall -9 $WSE_AGENT_CMD
	logger "shield attempting to verify license $LICENSE_ID"
	./$WSE_AGENT_CMD -k $LICENSE_KEY_FILE_STORAGE_PATH -p ./ -l $WSE_LOG_FILE_STORAGE_PATH
	sleep 1 # Wait Agent init
	$SHN_CTRL_CMD -a get_license -l $LICENSE_ID -p ./ > ./license_status
        cat ./license_status | grep -e "license_status: activated" -e "license_status: subscribed" > /dev/null
        if [ $? -ne 0 ]; then
        	echo "Error: Could not validate license. Check License ID and try again."
		if [ "`sysevent get shield::subscription_status`" != "LIC_INVALID" ] ; then
			sysevent set shield::subscription_status "inactive"
		fi
		logger "shield verify license $LICENSE_ID - Failed "
		exit 1
      fi
        echo ""
        echo ""
        echo "Successfully validated license..."
        if [ "`sysevent get shield::subscription_status`" != "LIC_ACTIVATED" ] ; then
                sysevent set shield::subscription_status "active"
        fi
        logger "shield license $LICENSE_ID activated"
		TM_STAMP=`date "+%m-%d-%Y_%H:%M:%S"`
		sysevent set shield::license_validation_success_date $TM_STAMP
        echo""
        echo""
	echo "Setting WRS Config..."
	$SHN_CTRL_CMD -a set_wred_conf -f wred.conf
	echo "Setting WBL config..."
	$SHN_CTRL_CMD -a set_wbl -f wbl.conf
	echo "Current Timezone is $TZ"
	echo "Setting SIB config - Automatic Time Zone Offset..."
	$SHN_CTRL_CMD -a set_sib_conf -t
        echo "Setting SIB config..."
        $SHN_CTRL_CMD -a set_sib_conf -f sib.conf
	conntrack -F
	logger "shield started and running with License id $LICENSE_ID"
	sysevent set shield::license_validation_success_date $TM_STAMP
	echo "SHN started and running. Exiting setup."
	cat /proc/bw_dpi_conf
	;;
stop)
	echo "Stopping shield processes..."
	logger "shield stopping"
	
	killall -9 $WRS_STARTUP_SCRIPT > /dev/null 2>&1
	killall -9 $WRS_DAEMON_CMD > /dev/null 2>&1
	killall -9 $DC_MONITOR_SCRIPT > /dev/null 2>&1
	killall -9 $DC_CMD > /dev/null 2>&1
	killall -9 $LICENSE_MGMT_SCRIPT > /dev/null 2>&1
	killall -9 $GEN_LICENSE_CMD > /dev/null 2>&1
	killall -9 $WSE_AGENT_CMD > /dev/null 2>&1
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
	echo "iptables -t mangle -D PREROUTING -i $DEV_WAN -p udp -j $FILTERDHCP_CHAIN"
	iptables -t mangle -D PREROUTING -i $DEV_WAN -p udp -j $FILTERDHCP_CHAIN
	iptables -t mangle -F $FILTERDHCP_CHAIN
	iptables -t mangle -X $FILTERDHCP_CHAIN
	;;
restart)
	logger "shield restarting"
	$0 stop
	sleep 5
	$0 start
	;;
esac;
