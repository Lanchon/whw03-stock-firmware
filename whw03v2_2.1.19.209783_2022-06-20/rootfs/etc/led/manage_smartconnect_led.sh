#!/bin/sh
#
#------------------------------------------------------------------
# © 2013 Belkin International, Inc. and/or its affiliates. All rights reserved.
#------------------------------------------------------------------
#
#
. /etc/led/lib_led_functions.sh
EventName=$1
EventValue=$2
LEDLog LED gotevent "$0 $EventName $EventValue $3"
LEDPrintEnv

case "$EventValue" in
START)
	[ "2" != "$(syscfg get smart_mode::mode)" ] && {
		UXPurplePulse
	}
	[ "0" = "$(syscfg get smart_mode::mode)" ] && {
		touch /tmp/led_sc_started_on_unconfigured
	}
	;;
READY)
	[ "0" = "$(syscfg get smart_mode::mode)" ] && [ "true" = "$(sysevent get setup::presetup)" ] && {
		LEDLog LED mask "Do not set solid purple during presetup"
		exit 0;
	}
	[ "2" != "$(syscfg get smart_mode::mode)" ] && {
		UXUnconfiguredSolid
	}
	;;
DONE)
	[ -f /tmp/led_sc_started_on_unconfigured ] && {
		Setup_SetActive
	}
	/etc/led/solid_normal.sh
	;;
esac
