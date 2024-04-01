#!/bin/sh
. /etc/led/lib_led_functions.sh

# Color : red green blue purple yellow cyan white
# Delay : 000, 100, ...

COLOR=$1
COLOR=${COLOR:=blue}
DELAY=$2
DELAY=${DELAY:=0}

combo_blink ${COLOR} ${DELAY}

ulog LED status "$0 $1 $2 $3"
