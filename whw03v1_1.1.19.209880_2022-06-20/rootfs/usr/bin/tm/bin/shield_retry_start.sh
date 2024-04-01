#!/bin/sh
MAX_RETRIES=3
SE_FAILURE="shield::activate_failures"
NUM=`sysevent get $SE_FAILURE`
if [ -z "$NUM" ] ; then
	NUM=0
fi
NUM=`expr $NUM + 1`
if [ $NUM -ge $MAX_RETRIES ] ; then
	echo "shield license couldn't be activated within $MAX_RETRIES times of trying..." > /dev/console
	sysevent set shield::license_error
	sysevent set $SE_FAILURE 0
	exit 0
else
	sysevent set $SE_FAILURE $NUM
fi
SE_STATUS=`sysevent get shield-status`
if [ "$SE_STATUS" != "started" -a "$SE_STATUS" != "starting" ]; then
	sysevent set shield::cron_retry
fi
