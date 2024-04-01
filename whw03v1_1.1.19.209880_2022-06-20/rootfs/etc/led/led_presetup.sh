#!/bin/sh
. /etc/led/lib_led_functions.sh

MODE=$(syscfg get smart_mode::mode)
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1

if [ "$MODE" = $MASTER_MODE ] ; then
    exit 0
fi

case "$2" in
   true)
        UXPurplePulse
        ;;
   false)
	/etc/led/solid_normal.sh
        ;;
esac

ulog LED status "$0 $1 $2 $3"
