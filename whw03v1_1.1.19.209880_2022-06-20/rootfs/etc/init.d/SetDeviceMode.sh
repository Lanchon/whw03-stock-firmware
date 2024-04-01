#!/bin/sh
if [ "" = "$1" ] || [ "-h" = "$1" ] || [ "-help" = "$1" ]; then
	echo "Usage: SetDeviceMode.sh Mode(MASTER or SLAVE)" >&2
    exit
fi
MODE=`echo $1 | tr [:upper:] [:lower:]`
if [ "master" != "$MODE" ] && [ "slave" != "$MODE" ]; then
	echo "Usage: SetDeviceMode.sh Mode(MASTER or SLAVE)" >&2
    exit
fi
if [ "$MODE" = "master" ] && [ "`syscfg get smart_mode::mode`" = "2" ] ; then
	echo "ErrorAlreadyMaster" > /dev/console
    exit
fi
if [ "$MODE" = "slave" ] && [ "`syscfg get smart_mode::mode`" = "1" ] ; then
	echo "ErrorAlreadySlave" > /dev/console
    exit
fi
if [ "$MODE" = "slave" ] && [ "`syscfg get smart_mode::mode`" = "2" ] ; then
	echo "ErrorNeedToFactoryReset" > /dev/console
    exit
fi
if [ "$MODE" = "master" ] && [ "`syscfg get smart_mode::mode`" = "1" ] ; then
	echo "ErrorNeedToFactoryReset" > /dev/console
    exit
fi
if [ "$MODE" = "slave" ] ; then
	echo "Do nothing for SLAVE" > /dev/console
fi
if [ "$MODE" = "master" ] ; then
	syscfg set smart_mode::mode 2
    sysevent set node-mode-restart
	sysevent set lan-restart
	sysevent set smart_connect::setup_status READY
	sysevent set btsetup-update
fi
