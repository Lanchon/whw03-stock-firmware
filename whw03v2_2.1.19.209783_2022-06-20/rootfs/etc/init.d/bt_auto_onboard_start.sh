#!/bin/sh
source /etc/init.d/ulog_functions.sh
TMP_LST="/tmp/.bt_auto_onboard.lst"
TMP_LST2="/tmp/.bt_auto_onboard3.lst"
TMP_LST3="/tmp/.bt_auto_onboard_done.lst"
TMP_DEVICE="/tmp/.bt_auto_onboard_device"
TMP_DEVICE2="/tmp/.bt_auto_onboard_device2"
TMP_BTSTATE="/tmp/.bt_auto_onboard_state"
TMP_SRPCRED="/tmp/.bt_auto_onboard_srpcred"
MAC_ADDR=""
SRP_ID=""
SRP_PASS=""
SRP_SALT=""
SRP_VERIFIER=""
RETVAL=""
SCSTATUS=`sysevent get smart_connect::setup_status`
if [ "READY" != "$SCSTATUS" ] ; then
	echo "smart_connect::setup_status is not ready and the BT auto onboarding is shut down." >> /dev/console
	exit 1
fi
SETUP_AP="`syscfg get smart_connect::setup_vap_ssid`"
generating_srp_cred () {
	gen_srp_cred > $TMP_SRPCRED
	if [ "$?" != "0" ] ; then
		echo "Failed to create srp credential" >> /dev/console
		RETVAL="false"
		rm -rf $TMP_SRPCRED
		return
	fi
	SRP_ID=`cat $TMP_SRPCRED | grep "id:" | sed "s/id://"`
	SRP_PASS=`cat $TMP_SRPCRED | grep "pass:" | sed "s/pass://"`
	SRP_SALT=`cat $TMP_SRPCRED | grep "salt:" | sed "s/salt://"`
	SRP_VERIFIER=`cat $TMP_SRPCRED | grep "verifier:" | sed "s/verifier://"`
	if [ $SRP_ID == "" ] || [ $SRP_PASS == "" ] || [ $SRP_SALT == "" ] || [ $SRP_VERIFIER == "" ]; then
		echo "Failed to get srp credential" >> /dev/console
		cat $TMP_SRPCRED >> /dev/console
		rm -rf $TMP_SRPCRED
		RETVAL="false"
		return
	fi
	rm -rf $TMP_SRPCRED
	smcdb_auth -M $MAC_ADDR -L $SRP_ID -P $SRP_PASS -S $SRP_SALT -V $SRP_VERIFIER 
	if [ "$?" != "0" ] ; then
		echo "Failed to insert the srp credential into the smartconnect database." >> /dev/console
		RETVAL="false"
		return
	fi
	RETVAL="true"
}
bt_auto_onboarding_run () {
	while read line
	do
		echo $line > $TMP_DEVICE
		cat $TMP_DEVICE | sed 's/},/}/g' > $TMP_DEVICE2
		MAC_ADDR=`jsonparse -f $TMP_DEVICE2 macAddress`
		MODE_LIMIT=`jsonparse -f $TMP_DEVICE2 modeLimit`
		RSSI=`jsonparse -f $TMP_DEVICE2 rssi | tr -d "-"`
		echo "m: $MAC_ADDR, rssi: $RSSI, modeLimit: $MODE_LIMIT"
		echo "----"
		if [ "$MODE_LIMIT" != "MasterOnly" ] ; then
			if [ $RSSI -lt 66 ] ; then
				echo "btsetup attempting to connect to device $MAC_ADDR" >> /dev/console
				MAX_RETRY=3
				RETRY=0
				while [ "$RETRY" -lt "$MAX_RETRY" ] ; do
					if [ "$RETRY" -gt "0" ] ; then
						echo "Retry to connect to device $MAC_ADDR (retry : $RETRY)"
					fi
					/usr/bin/btsetup_central --connect=$MAC_ADDR > $TMP_BTSTATE
					STAT=`jsonparse -f $TMP_BTSTATE status`
					cat $TMP_BTSTATE >> /dev/console
					if [ "$STAT" == "Connected" ] ; then
						echo "Generating srp credential for $MAC_ADDR ..." >> /dev/console
						generating_srp_cred
						if [ "$RETVAL" == "false" ]; then
							break
						fi
						sleep 1
						echo "bt_auto_onboarding : SmartConnectConfigure JNAP is calling to $MAC_ADDR" >> /dev/console
						/usr/bin/btsetup_central -f -A "$CONFIG_VAP_SSID" -P "$CONFIG_VAP_PASS" -L "$SRP_ID" -R "$SRP_PASS" > $TMP_BTSTATE
						STAT=`jsonparse -f $TMP_BTSTATE result`
						if [ "$STAT" == "" ] ; then
							echo "Success to call the SmartConnectConfigure JNAP" >> /dev/console
						elif [ "$STAT" == "error_not_connected" ] ; then
							RETRY=`expr $RETRY + 1`
							echo "Master lost a BT connection." >> /dev/console
							continue
						else
							echo "Failed to call the SmartConnectConfigure JNAP" >> /dev/console
							cat $TMP_BTSTATE
						fi
						sleep 1
						echo "terminating connection" >> /dev/console
						/usr/bin/btsetup_central -t
						break
					else
						sysevent set bt_auto_onboard::result "connect-error"
						echo "could not connect to device $MAC_ADDR" >> /dev/console
						RETRY=`expr $RETRY + 1`
					fi
				done
			else
				echo "RSSI ($RSSI) to device $MAC_ADDR is too low - skipping"
			fi
		else
			echo "$MAC_ADDR device supports only Master Mode." >> /dev/console
		fi
		sleep 1
		break
	done < $TMP_LST
	rm -rf $TMP_DEVICE
	rm -rf $TMP_DEVICE2
	rm -rf $TMP_BTSTATE
}
sysevent set bt_auto_onboard::result ""
if [ "`syscfg get auto_onboarding::bt_enabled`" == "1" ] && [ "`syscfg get smart_mode::mode`" == "2" ] ; then
	if [ ! "`sysevent get bt_auto_onboard::status`" ] ; then
		sysevent set bt_auto_onboard::status running
		MAC_ADDR="`sysevent get bt_auto_onboard::dev_addr`"
		DEV_ADDR=0
		> $TMP_LST3
		if [ "$MAC_ADDR" ] ; then
			echo "using bt address $MAC_ADDR for bt_auto_onboard setup" >> /dev/console
			echo "{\"name\": \"Linksys\", \"macAddress\": \"$MAC_ADDR\", \"rssi\": -78}," > $TMP_LST
			sysevent set bt_auto_onboard::dev_addr ""
			DEV_ADDR=1
		else
			/etc/led/nodes_led_pulse.sh white 3
			
			echo "scanning for bt devices 10 seconds" >> /dev/console
			/usr/bin/btsetup_central -d 10 | grep macAddress | grep Linksys > $TMP_LST
			/etc/led/nodes_led.sh white off
			/etc/led/solid_normal.sh bt_auto_onboard_start
			/etc/led/manage_wan_led.sh bt_auto_onboard_start
		fi
		DEVICE_MAC="`syscfg get device::mac_addr`"
		if [ -z "$DEVICE_MAC" ]; then
			echo "Could not get mac address of device."
			exit 1
		fi
		CONFIG_VAP_SSID="`syscfg get smart_connect::configured_vap_ssid`"
		CONFIG_VAP_PASS="`syscfg get smart_connect::configured_vap_passphrase`"
		if [ "$CONFIG_VAP_SSID" == "" ] || [ "$CONFIG_VAP_PASS" == "" ]; then
			echo "Could not get config ap info or auth info." >> /dev/console
			echo "CONFIG_VAP_SSID : $CONFIG_VAP_SSID, CONFIG_VAP_PASS : $CONFIG_VAP_PASS" >> /dev/console
			exit 1
		fi
		MAX_COUNT=20
		COUNT=0
		while [ "$COUNT" -lt "$MAX_COUNT" ] ; do
			if [ ! -f $TMP_LST ] ; then
				break
			fi
			if [ ! -s $TMP_LST ] ; then
				break
			fi
			COUNT=`expr $COUNT + 1`
			bt_auto_onboarding_run
			echo "$MAC_ADDR" >> $TMP_LST3
			if [ "$DEV_ADDR" -eq "1" ] ; then
				break
			fi
			sleep 1
			while read line
			do
			    sed /$line/d $TMP_LST > $TMP_LST2
				cp $TMP_LST2 $TMP_LST
			done < $TMP_LST3
		done
		sysevent set bt_auto_onboard::status ""
	else
		echo "bt_auto_onboard::status `sysevent get bt_auto_onboard::status`" >> /dev/console
	fi
else
	sysevent set bt_auto_onboard::result "not-enabled"
	echo "auto_onboarding::bt_enabled not enabled" >> /dev/console
fi
