#!/bin/sh

echo "`date` LED $0 $1 $2 $3" >> /var/log/messages


pidof fwupd-led.sh > /dev/null
if [ $? = 0 ]; then
	killall fwupd-led.sh
fi

if [ "$2" != "2" ]; then
	/etc/led/fwupd-led.sh fu_success &
else
	/etc/led/fwupd-led.sh fu_success2 &
fi

