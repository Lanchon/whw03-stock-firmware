#!/bin/sh
. /etc/led/lib_led_functions.sh

l_sec=$1
l_sec=${l_sec:=3}

ShowInternetStateLED()
{
	local internet_state
	internet_state=$(sysevent get icc_internet_state)

	LEDLog LED log "ShowInternetStateLED"
	PrintSysEvent icc_internet_state

	NodeIsMaster && {
		local link
		link=$(sysevent get phylink_wan_state)

		LEDLog LED dbg "Master"
		PrintSysEvent phylink_wan_state

		[ "$internet_state" = "up" -a "$link" = "up" ] && {
			UXGoodSolid
			exit 0
		}

		[ "$internet_state" != "up" -a "$link" = "up" ] && {
			UXErrorSolid
			exit 0
		}
		[ "$internet_state" != "up" -a "$link" = "down" ] && {
			UXErrorPulse
			exit 0
		}

		exit 0
	}

	NodeIsSlave && {
		LEDLog LED dbg "Slave"

		IfBackhaulDownLED && exit 0

		[ "$internet_state" != "up" ] && {
			Setup_Running && {
				LEDLog LED mask "Setup running..."
				return 0
			}

			UXErrorSolid
			exit 0
		}

		UXGoodSolid
		exit 0
	}
}

CustomDoAfter "$l_sec" led_internet_timer ShowInternetStateLED
