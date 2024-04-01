#!/bin/sh
. /etc/led/lib_led_functions.sh

# Color : red, green, blue
COLOR=purple
DELAY=2

combo_pulse ${COLOR} ${DELAY}

/etc/led/manage_smartconnect_led.sh &

ulog LED status "$0 $1 $2 $3"
