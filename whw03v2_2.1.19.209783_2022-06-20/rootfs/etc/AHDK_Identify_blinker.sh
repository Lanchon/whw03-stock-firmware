#!/bin/sh
BLINK_TIMER="10"
logger "blinking LED for ${BLINK_TIMER} seconds for AHDK Identify"
/etc/led/nodes_led_blink.sh green 1 &
sleep ${BLINK_TIMER}
/etc/led/solid_normal.sh

