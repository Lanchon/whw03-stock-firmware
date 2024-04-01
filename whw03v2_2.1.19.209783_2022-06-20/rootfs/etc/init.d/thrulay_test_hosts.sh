#!/bin/sh
HOST_LIST="`syscfg get thrulay::host_list`"
TMP_BUF="/tmp/.tmp.buf.$RANDOM"
TEST_TIME="`syscfg get thrulay::test_time`"
LOG_FILE="`syscfg get thrulay::log`"
export TZ=`sysevent get TZ`
touch $HOST_LIST
for i in `cat $HOST_LIST`
do
	IP="`echo $i | cut -d':' -f1`"
	PORT="`echo $i | cut -d':' -f2`"
	if [ "$IP" ] && [ "$PORT" ] ; then
		/usr/bin/logger "running thrulay test to $IP"
		/bin/thrulay -v -t${TEST_TIME} -p ${PORT} ${IP} > $TMP_BUF
		DATE="`date`"
		MBPS="`cat $TMP_BUF | tail -1 | awk '{print $4}'`"
		RTT="`cat $TMP_BUF | tail -1 | awk '{print $5}'`"
		JITTER="`cat $TMP_BUF | tail -1 | awk '{print $6}'`"
		MIN_MBPS="`cat $TMP_BUF | tail -1 | awk '{print $7}'`"
		AVG_MBPS="`cat $TMP_BUF | tail -1 | awk '{print $8}'`"
		MAX_MBPS="`cat $TMP_BUF | tail -1 | awk '{print $9}'`"
		if [ "$IP" ] && [ "$RTT" ] && [ "$AVG_MBPS" ] ; then
			sysevent set thrulay::last_thrulay "$MBPS/$JITTER/$RTT/$IP/$DATE"
			echo "${DATE}, ip:${IP}, mbps:${MBPS}, rtt:${RTT}, jitter:${JITTER}, min:${MIN_MBPS}, avg:${AVG_MBPS}, max:${MAX_MBPS}, duration:${TEST_TIME}" >> $LOG_FILE
			/usr/bin/logger "thrulay to $IP, MBPS:${MBPS}, RTT:${RTT}"
			UUID="`syscfg get device::uuid`"
			/usr/sbin/nodemsg.sh "/network/$UUID/thrulay/$IP/status" "${MBPS}:${RTT}"
		fi
		rm -rf $TMP_BUF
	fi
done
