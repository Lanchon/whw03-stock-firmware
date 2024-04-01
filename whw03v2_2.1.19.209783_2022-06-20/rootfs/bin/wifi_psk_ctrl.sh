#!/bin/sh
#
#

PERSISTANT_PSK_FILE="/var/config/hostapd.mpsk"
PSK_FILE="/tmp/hostapd.mpsk"


if [ ! -f "$PSK_FILE" ] ; then
	if [ -f "$PERSISTANT_PSK_FILE" ] ; then
		cp $PERSISTANT_PSK_FILE $PSK_FILE
	else
		touch $PSK_FILE
	fi
fi

find_device () {
	DEV_MAC="$1"
	if [ "$1" ] ; then
		DEV_FOUND=`cat $PSK_FILE | grep "$DEV_MAC"`
		if [ "$DEV_FOUND" ] ; then
			echo "$DEV_MAC"
		fi
	fi
}

remove_device () {
	DEV_MAC="$1"
	DEV=$(find_device "$1" )
	if [ "$DEV" == "$DEV_MAC" ] ; then
		echo "removing device $DEV_MAC"
		cat $PSK_FILE | grep -v "$DEV_MAC" > /tmp/newpsk.txt
		mv /tmp/newpsk.txt $PSK_FILE
	else
		echo "no device $DEV_MAC found"
	fi
}

add_device () {
	DEV_MAC="$1"
	PASSPHRASE="$2"
	if [ "$2" ] ; then
		DEV=$(find_device "$1" )
		if [ "$DEV" == "$DEV_MAC" ] ; then
			echo "DEV=$DEV, DEV_MAC=$DEV_MAC"
			echo "updating device $DEV_MAC"
            if [ "$DEV" != "00:00:00:00:00:00" ] ; then
			    remove_device "$DEV_MAC"
            fi
		fi
	echo "$DEV_MAC $PASSPHRASE" >> $PSK_FILE
	fi
}

case "$1" in
	add)
		if [ "$3" ] ; then
			add_device "$2" "$3"
			cp $PSK_FILE $PERSISTANT_PSK_FILE 
			sysevent set wifi_mpsk_update
		else
			echo "Use:"
			echo "$0 add <MAC> <Passphrase>"
		fi
	;;
	remove)
		if [ "$2" ] ; then
			remove_device "$2"
			cp $PSK_FILE $PERSISTANT_PSK_FILE 
			sysevent set wifi_mpsk_update
		else
			echo "Use:"
			echo "$0 remove <MAC>"
		fi
	;;
	list)
		echo "WPA-PSK device list"
		cat $PSK_FILE | grep -v "^#" | cut -d' ' -f1
		echo ""
	;;
	*)
		echo "Use:"
		echo "$0 <add|remove|list> <MAC> (Passphrase)"
	;;
esac
