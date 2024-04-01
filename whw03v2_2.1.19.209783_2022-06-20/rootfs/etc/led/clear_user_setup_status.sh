#!/bin/sh
. /etc/led/lib_led_functions.sh

l_sec=$1
l_sec=${l_sec:=100}

LEDLog LED log "clear_user_setup_status.sh"

ClearSetupActive()
{
	Setup_SetClear
	LEDLog LED log "ClearSetupActive"
	LEDPrintEnv
	IfBackhaulDownLED
	/etc/led/show_internet_state_after.sh 0 &
}

CustomDoAfter "$l_sec" led_clear_setup_timer ClearSetupActive
