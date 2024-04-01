#!/bin/sh
. /etc/led/lib_led_functions.sh

# Color : red green blue purple yellow cyan white

COLOR=$1
PERCENT=$2

combo_solid_percent ${COLOR} ${PERCENT}

ulog LED status "$0 $1 $2 $3"
