#!/bin/sh
. /etc/led/lib_led_functions.sh

# Color : red green blue purple yellow cyan white

COLOR=$1
BRIGHTNESS=$2

combo_solid ${COLOR} ${BRIGHTNESS}

ulog LED status "$0 $1 $2 $3"
