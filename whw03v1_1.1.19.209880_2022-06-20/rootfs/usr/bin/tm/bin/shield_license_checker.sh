#!/bin/sh
if [ "`sysevent get shield-status`" == "started" ] ; then
  LICENSE_ID="`syscfg get shield::license_id`"
	cd /tmp && /usr/bin/tm/bin/shn_ctrl -a get_license -l $LICENSE_ID -p ./
	sleep 5
	IS_LICENSED=`cat /proc/bw_dpi_conf | grep "License Status" | cut -d':' -f2 | tr -d ' '`
	if [ "`sysevent get shield::is_licensed`" == "" ] ; then
		echo "Initial shield license check = $IS_LICENSED" >> /dev/console
		sysevent set shield::is_licensed $IS_LICENSED
	else
		logger "verifying shield license"
		if [ "`sysevent get shield::is_licensed`" != "$IS_LICENSED" ] ; then
			if [ "$IS_LICENSED" != "activated" ] ; then
				sysevent set shield::subscription_status "inactive"
				logger "shield license activivty change: is licensed = $IS_LICENSED"
				echo "shield license activivty change: is licensed = $IS_LICENSED" >> /dev/console
			else
				logger "Shield license is active"
			fi
		fi
	fi
fi
