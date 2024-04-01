#!/bin/sh
#
# A script to publish MQTT messages to the node network
#
#


print_use () {
	echo "Use:"
	echo "$0 \"<topic>\" \"<message>\""
	echo "Examples:"
	echo "$0 \"network/xxx-xxx-xxx-xxx/omsg/1234/notification\" \"Hello There\""
	echo "$0 \"network/xxx-xxx-xxx-xxx/zb/5678/log\" \"/tmp/file.log\""
	exit 1
}


HOSTIP="$(sysevent get master::ip)"
if [ ! "$HOSTIP" ] ; then
	echo "$0 can not find host ip"
	exit 1
fi

TOPIC="$1"
if [ -f "$2" ] ; then
	MSG_FLAG="-f"
else
	MSG_FLAG="-m"
fi

if [ "$HOSTIP" ] && [ "$TOPIC" ] && [ "$MSG_FLAG" ] && [ "$2" ] ; then
	/usr/sbin/mosquitto_pub -h ${HOSTIP} -t "${TOPIC}" ${MSG_FLAG} "$2"
else
	print_use
fi





