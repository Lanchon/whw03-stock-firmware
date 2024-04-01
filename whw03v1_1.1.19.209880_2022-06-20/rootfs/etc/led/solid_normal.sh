#!/bin/sh
. /etc/led/lib_led_functions.sh
EventName=$1
EventValue=$2
LEDLog LED gotevent "$0 $EventName $EventValue $3"
LEDPrintEnv

l_internet_state=$(sysevent get icc_internet_state)
l_backhaul_status=$(sysevent get backhaul::status)

if [ "${NodeMode}" = "$UnconfiguredMode" ]; then
	[ "$(sysevent get smart_connect::setup_status)" = "" ] && {
		LEDLog LED mask "smart_connect::setup_status READY will make solid purple."
		PrintSysEvent smart_connect::setup_status
		exit 0
	}
	UXUnconfiguredSolid
elif [ "${NodeMode}" = "$MasterMode" ]; then
	LEDLog LED log "Master node: WAN state will reflect LED"
	UXGoodSolid
	/etc/led/show_internet_state_after.sh 30 &
elif [ "${NodeMode}" = "$SlaveMode" ]; then
	IfBackhaulDownLED && exit 0

	[ "$l_internet_state" != "up" ] && {
		LEDLog LED mask "Slave node: internet down"
		exit 0
	}

	UXGoodSolid
else
	UXGoodSolid
fi
