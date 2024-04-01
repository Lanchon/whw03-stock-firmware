#!/bin/sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="autofwup"
Debug()
{
	echo "[fw.sh] $@" >> /dev/console
} 
cron_event()
{
	UPTIME=`cat /proc/uptime | cut -d'.' -f1`
	BASETIME="60"
	if [ $UPTIME -lt $BASETIME ]; then
		return 0
	fi
	
	pidof fwupd > /dev/null
	if [ $? != "0" ] 
	then
		CHECK_AFTER_BOOT=`sysevent get fwup_checked_after_boot`
		if [ "${CHECK_AFTER_BOOT}" = "0" ]; then
			Debug "fwup_checked_after_boot: 0"
			sysevent set fwup_periodic_check 0
			local SYS_FORCED_UPDATE_STATUS="fwup_forced_update_status"
			local FORCED_UPDATE_STATUS=$(syscfg get "$SYS_FORCED_UPDATE_STATUS")
			case "$FORCED_UPDATE_STATUS" in
				"" | 1)
					if [ "$FORCED_UPDATE_STATUS" == 1 ]; then		
						syscfg set fwup_firmware_version 1
					fi
					fwupd -m 3
					FORCED_UPDATE=`sysevent get fwup_forced_update`
					Debug "fwup_forced_update:" $FORCED_UPDATE
					if [ "$FORCED_UPDATE" != "0" ]; then
						sleep 2
						syscfg set fwup_firmware_version 1
						fwupd -m 4 -d &
						sysevent set fwup_periodic_check "done"
					else
						if [ "$(syscfg get fwup_newfirmware_version)" ]; then
							syscfg unset "$SYS_FORCED_UPDATE_STATUS"
						fi
					fi	
					;;	
				0)
					Debug "Forced firmware upate: done"
					Debug	
					syscfg unset "$SYS_FORCED_UPDATE_STATUS"
					syscfg commit
					sleep 4
					sysevent set fwupd-success 2
					sysevent set fwup_periodic_check "done"
					sysevent set fwup_checked_after_boot 1
					;;
				*)
					;;
			esac
		else
			PERIODIC_CHECK=$(sysevent get fwup_periodic_check)
			NODES_MODE=$(syscfg get smart_mode::mode)
			case "$PERIODIC_CHECK" in
				"update")
					Debug "Automatic update"
					sysevent set fwup_periodic_check
					if [ "$NODES_MODE" == 2 ]; then
						update_nodes update &
					else
						fwupd -m 2 &
					fi	
					;;
				"done")
					;; 
				*)
					AUTOFLAG=`utctx_cmd get fwup_autoupdate_flags`
					eval $AUTOFLAG
					if [ "${SYSCFG_fwup_autoupdate_flags}" -ne "0" ]; then
						if [ "$NODES_MODE" != 1 ]; then
							fwupd -e &
						fi
					fi
					;;
			esac
		fi
	fi		
}
check_update()
{
	if [ "$(sysevent get fwup_checked_after_boot)" == 0 ]; then
		cron_event
	fi	
}
update_event()
{
	local UPDATEMODE=`sysevent get update_firmware_now`
	local ALTSERVERURL=`syscfg get fwup_altserver_uri`
	if [ -z "$UPDATEMODE" ]; then
		return;
	fi
	sysevent set update_firmware_now    
	ulog autofwup status "update_firmware_now event : ${UPDATEMODE}, ${ALTSERVERURL}"
	if pidof fwupd > /dev/null || pidof update_nodes > /dev/null; then
		sysevent set fwup_queue $UPDATEMODE
		if ! pidof fwup_queue > /dev/null; then
			fwup_queue &
		fi
	else
		syscfg unset fwup_altserver_uri
		if [ "${UPDATEMODE}" = "1"  -o "${UPDATEMODE}" = "2" ]
		then
			NODES_MODE=$(syscfg get smart_mode::mode)
			if [ "$NODES_MODE" == "2" ]; then
				update_nodes ${UPDATEMODE} &
				return
			fi
			if [ "$NODES_MODE" == "1" ]; then
				update_slave ${UPDATEMODE} &
				return
			fi
			if [ ! -z "${ALTSERVERURL}" ]; then
				fwupd -m ${UPDATEMODE} -u ${ALTSERVERURL} &
			else
				fwupd -m ${UPDATEMODE} &
			fi
		fi
	fi		
}
check_mount() 
{
	PRIROOTFSMTD=`cat /proc/mtd | grep "rootfs" | grep -v "alt_" | cut -d':' -f1 | cut -f2 -d"d"`
	PRIROOTFSMTD2=`expr $PRIROOTFSMTD - 1`
	ALTROOTFSMTD=`cat /proc/mtd | grep "alt_rootfs" | cut -d':' -f1 | cut -f2 -d"d"`
	ALTROOTFSMTD2=`expr $ALTROOTFSMTD - 1`
	MOUNTEDMTD=`cat /proc/self/mountinfo | grep "\/dev\/root" | cut -f3 -d' ' | cut -f2 -d':'`
	if [ -z "$MOUNTEDMTD" ] || [ "$MOUNTEDMTD" == "0" ]; then 
		MOUNTEDMTD=`cat /sys/class/ubi/ubi0_0/device/mtd_num`
	fi
	
	IS_ALT=`cat /proc/mtd | grep mtd${MOUNTEDMTD} | grep "alt_"`
	
	if [ "$IS_ALT" ] ; then
		return 1
	else
		return 0
	fi
}
mount_downloads()
{
	mounted=0
	DOWNLOADS_DIR=/var/downloads
	DOWNLOADS_PARTITION=$(awk -F: '/downloads/ { print $1 }' /proc/mtd)
	if [ -z $DOWNLOADS_PARTITION ]; then
		ulog autofwup status  "Skip to mount downloads partition, /dev/$DOWNLOADS_PARTITION"
	elif mount | grep "/dev/mtd.* on /tmp " > /dev/null; then
		echo /tmp already mounted on MTD partition
		mkdir -p /tmp/var/downloads
	else
		MTD_DEVICE=/dev/${DOWNLOADS_PARTITION}
		MTD_BLOCK_DEVICE=/dev/$(echo ${DOWNLOADS_PARTITION} | sed s/mtd/mtdblock/)
		mkdir -p ${DOWNLOADS_DIR} || echo No mount point for downloads storage.
		if mount -t jffs2 -o noatime $MTD_BLOCK_DEVICE ${DOWNLOADS_DIR}; then
			mounted=1
		else
			echo Downloads persistent storage mount failed, attempting format
			if ! flash_eraseall -j ${MTD_DEVICE}; then
				echo Format downloads persistent storage failed.  Perhaps mkfs.jffs not installed.  Giving up.
			else
				if mount -t jffs2 -o noatime ${MTD_BLOCK_DEVICE} ${DOWNLOADS_DIR}; then
					echo Format succeeded, downloads mount still failed.  Giving up.
				fi
			fi
		fi
	fi
	
	if [ ${mounted} -ne 0 ]; then
		chmod 777 ${DOWNLOADS_DIR}	
	fi
}
init_variables()
{
	sysevent set fwup_state 0
	sysevent set fwup_progress 0
	sysevent set fwup_checked_after_boot 0
	sysevent set fwup_forced_update 0
	sysevent set fwup_forced_update_count 0
	sysevent set fwup_periodic_check 0
	syscfg unset fwup_start_timewindow
	syscfg unset fwup_end_timewindow
	syscfg unset fwup_newfirmware_version
	syscfg unset fwup_newfirmware_date
	syscfg unset fwup_newfirmware_details
	syscfg unset fwup_newfirmware_status_details
	FWVERSION=`cat /etc/version`
	syscfg set fwup_firmware_version ${FWVERSION} 
	BUILDDATE=`cat /etc/builddate.timet`
	syscfg set fwup_firmware_date ${BUILDDATE} 
	if [ -e "/usr/sbin/nvram" ]
	then
		BOOTPART=`nvram get bootpartition`
		PRODUCT=`cat /etc/product`
		if [ "$PRODUCT" == "vail" ]; then
			PART_TMP=$(cat /proc/mtd | awk -F ":" '/image_update/{print $1}')
			case "$PART_TMP" in
			"mtd4")
				BOOTPART=1;
				;;
			"mtd5")
				BOOTPART=0;
				;;
			*)
				;;
			esac
		fi
		if [ $BOOTPART = "1" ]
		then
			syscfg set fwup_boot_part 2
		else
			syscfg set fwup_boot_part 1
		fi
	elif [ -e "/dev/mmcblk0p17" ]; then
		
		ROOT_PART=`cat /proc/cmdline | sed "s/ /\n/g" | grep "root=/dev/"`
		if [ "$ROOT_PART" == "root=/dev/mmcblk0p17" ]; then
			syscfg set fwup_boot_part 2
		else
			syscfg set fwup_boot_part 1
		fi
	else
		syscfg set fwup_boot_part 0
		if [ -e /proc/mtd ] 
		then
			check_mount
			RET=$?
			if [ $RET -eq 0 ] 
			then
				syscfg set fwup_boot_part 1
			fi
			if [ $RET -eq 1 ] 
			then
				syscfg set fwup_boot_part 2
			fi
		fi
	fi
	rm -f /tmp/var/config/downloads/* 
	rm -f /tmp/var/config/*.tmp 
	rm -f /tmp/var/config/lighttpd-upload*
	BOOTPART=`syscfg get fwup_boot_part`
	CONFIGDIR="/tmp/var/config"
	LICENSEDIR="${CONFIGDIR}/license"
	DEFAULTLICENSE="FW_LICENSE_default.pdf"
	WEBLINKFORLICENSE="/tmp/license.pdf"
	if [ -e "${LICENSEDIR}/primary" ]; then
		PRIMARYLICENSE=`cat ${LICENSEDIR}/primary`
		syscfg set fwup_primary_licensefile ${PRIMARYLICENSE}
	else
		PRIMARYLICENSE=
		syscfg unset fwup_primary_licensefile
	fi
	if [ -e "${LICENSEDIR}/alternate" ]; then
		ALTERNATELICENSE=`cat ${LICENSEDIR}/alternate`
		syscfg set fwup_alternate_licensefile ${ALTERNATELICENSE}
	else
		ALTERNATELICENSE=
		syscfg unset fwup_alternate_licensefile
	fi
	if [ "${BOOTPART}" = "1" ]
	then
		if [ ! -z ${PRIMARYLICENSE} ] && [ -e "${LICENSEDIR}/${PRIMARYLICENSE}.gz" ]
		then
			cp -f ${LICENSEDIR}/${PRIMARYLICENSE}.gz /tmp/.
			gzip -df /tmp/${PRIMARYLICENSE}.gz
			mv -f /tmp/${PRIMARYLICENSE} ${WEBLINKFORLICENSE}
		else
			if [ -e "/etc/${DEFAULTLICENSE}.gz" ]
			then
				cp -f /etc/${DEFAULTLICENSE}.gz /tmp/.
				gzip -df /tmp/${DEFAULTLICENSE}.gz
				mv -f /tmp/${DEFAULTLICENSE} ${WEBLINKFORLICENSE}
			fi
		fi
	else
		if [ ! -z ${ALTERNATELICENSE} ] && [ -e "${LICENSEDIR}/${ALTERNATELICENSE}.gz" ]
		then
			cp -f ${LICENSEDIR}/${ALTERNATELICENSE}.gz /tmp/.
			gzip -df /tmp/${ALTERNATELICENSE}.gz
			mv -f /tmp/${ALTERNATELICENSE} ${WEBLINKFORLICENSE}
		else
			if [ -e "/etc/${DEFAULTLICENSE}.gz" ]
			then
				cp -f /etc/${DEFAULTLICENSE}.gz /tmp/.
				gzip -df /tmp/${DEFAULTLICENSE}.gz
				mv -f /tmp/${DEFAULTLICENSE} ${WEBLINKFORLICENSE}
			fi
		fi
	fi
	sysevent set LICENSE_Url ${WEBLINKFORLICENSE}
	KEEP=/var/config/files-to-keep.conf
	TEMPLATE=/etc/files-to-keep.conf
	touch $KEEP
	cat $KEEP $TEMPLATE | sort -u > $KEEP
	mount_downloads
	NODES_MODE=$(syscfg get smart_mode::mode)
	if [ "$NODES_MODE" == "1" ] || [ "$NODES_MODE" == "2" ]; then
		sysevent set fwup_checked_after_boot 1
	fi
}
update_license()
{
	BOOTPART=`syscfg get fwup_boot_part`
	CONFIGDIR="/tmp/var/config"
	LICENSEDIR="${CONFIGDIR}/license"
	mkdir -p ${LICENSEDIR}
	PRIMARYLICENSE=
	if [ -e "${LICENSEDIR}/primary" ]; then
		PRIMARYLICENSE=`cat ${LICENSEDIR}/primary`
	fi
	ALTERNATELICENSE=
	if [ -e "${LICENSEDIR}/alternate" ]; then
		PRIMARYLICENSE=`cat ${LICENSEDIR}/alternate`
	fi
	
	HOWMANYLICENSEDOC=`ls ${LICENSEDIR}/*.gz -1 | wc -l`
	if [ $HOWMANYLICENSEDOC -gt 2 ] 
	then
		mkdir -p /tmp/templicense
		if [ ! -z ${PRIMARYLICENSE} ] && [ -e "${LICENSEDIR}/${PRIMARYLICENSE}.gz" ]
		then
			cp -f ${LICENSEDIR}/${PRIMARYLICENSE}.gz /tmp/templicense/.
		fi
		if [ ! -z ${ALTERNATELICENSE} ] && [ -e "${LICENSEDIR}/${ALTERNATELICENSE}.gz" ]
		then
			cp -f ${LICENSEDIR}/${ALTERNATELICENSE}.gz /tmp/templicense/.
		fi
		if [ -e "${LICENSEDIR}/fw_license.pdf.gz" ]
		then
			cp -f ${LICENSEDIR}/fw_license.pdf.gz /tmp/templicense/.
		fi
		if [ -e "${LICENSEDIR}/primary" ]
		then
			cp -f ${LICENSEDIR}/primary /tmp/templicense/.
		fi
		if [ -e "${LICENSEDIR}/alternate" ]
		then
			cp -f ${LICENSEDIR}/alternate /tmp/templicense/.
		fi
		rm -f ${LICENSEDIR}/*.gz
		mv -f /tmp/templicense/* ${LICENSEDIR}/.
	fi
	if [ ! -z $1 ]
	then
		LICENSE_FILE=`echo "$1" | cut -f3 -d'/'`
		if [ "${BOOTPART}" = "1" ]
		then
			if [ ! -z ${ALTERNATELICENSE} ] && [ -e "${LICENSEDIR}/${ALTERNATELICENSE}.gz" ]
			then
				rm -f ${LICENSEDIR}/${ALTERNATELICENSE}.gz
			fi
			echo "${LICENSE_FILE}" > ${LICENSEDIR}/alternate
		else
			if [ ! -z ${PRIMARYLICENSE} ] && [ -e "${LICENSEDIR}/${PRIMARYLICENSE}.gz" ]
			then
				rm -f ${LICENSEDIR}/${PRIMARYLICENSE}.gz
			fi
			echo "${LICENSE_FILE}" > ${LICENSEDIR}/primary
		fi
		gzip -cf $1 > ${LICENSEDIR}/$LICENSE_FILE.gz
	else
		if [ "${BOOTPART}" = "1" ]
		then
			if [ ! -z ${ALTERNATELICENSE} ] && [ -e "${LICENSEDIR}/${ALTERNATELICENSE}.gz" ]
			then
				rm -f ${LICENSEDIR}/${ALTERNATELICENSE}.gz
			fi
			rm -f ${LICENSEDIR}/alternate
		else
			if [ ! -z ${PRIMARYLICENSE} ] && [ -e "${LICENSEDIR}/${PRIMARYLICENSE}.gz" ]
			then
				rm -f ${LICENSEDIR}/${PRIMARYLICENSE}.gz
			fi
			rm -f ${LICENSEDIR}/primary
		fi
	fi
	touch ${CONFIGDIR}/updated
}
service_start ()
{
   sysevent set ${SERVICE_NAME}-errinfo
   sysevent set ${SERVICE_NAME}-status started
}
service_stop ()
{
   sysevent set ${SERVICE_NAME}-errinfo
   sysevent set ${SERVICE_NAME}-status stopped
}
case "$1" in
   ${SERVICE_NAME}-start)
	  service_start
	  ;;
   ${SERVICE_NAME}-stop)
	  service_stop
	  ;;
   ${SERVICE_NAME}-restart)
	  service_stop
	  service_start
	  ;;
   cron_every_minute)
	  cron_event
	  ;;
   check_update)
	  check_update
	  ;;
   update_firmware_now)
	  update_event
	  ;;   
   init_vars)
	  init_variables
	  ;;   
	 backhaul::status)
		STAT="`sysevent get backhaul::status`"
	  echo "backhaul::status $STAT" >> /dev/console
	  if [ "$STAT" == "up" ] ; then
			FWUP_START="`sysevent get fwupd-start`"
			FWUP_SUCC="`sysevent get fwupd-success`"
			FWUP_FAILED="`sysevent get fwupd-failed`"
			echo "fwupd-start $FWUP_START" >> /dev/console
			echo "fwupd-success $FWUP_SUCC" >> /dev/console
			echo "fwupd-failed $FWUP_FAILED" >> /dev/console
			FWUP_STATE="`sysevent get fwup_state`"
			if [ "$FWUP_STATE" == "3" ] ; then
				echo "sysevent fwup_state = $FWUP_STATE, when backhaul::status came $STAT"  >> /dev/console
				echo "will restart firmware uprgade" >> /dev/console
				killall -s SIGQUIT fwupd
				sleep 8
				echo "firmware update failed downloading - restarting" >> /dev/console
				init_variables
				sysevent set update_firmware_now 2
			fi
	  fi
	  ;;  
   license)
	  update_license "$2" 
	  ;;      
   *)
	  echo "Usage: service-${SERVICE_NAME} [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
	  exit 3
	  ;;
esac
