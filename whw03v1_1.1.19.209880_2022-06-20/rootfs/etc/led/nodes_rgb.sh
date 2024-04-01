#!/bin/sh
. /etc/led/lib_led_functions.sh

# Color : red green blue

COLOR=$1
BRIGHTNESS=$2

rgb_solid ${COLOR} ${BRIGHTNESS}

ulog LED status "$0 $1 $2 $3"
