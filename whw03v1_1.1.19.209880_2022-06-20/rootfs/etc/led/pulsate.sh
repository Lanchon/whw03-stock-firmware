#!/bin/sh
. /etc/led/lib_led_functions.sh

combo_pulse purple 4

ulog LED status "$0 $1 $2 $3"
