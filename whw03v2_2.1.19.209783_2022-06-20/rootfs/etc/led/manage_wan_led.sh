#!/bin/sh
#
#------------------------------------------------------------------
# © 2013 Belkin International, Inc. and/or its affiliates. All rights reserved.
#------------------------------------------------------------------
#
# Manages WAN LED
#
# normal wan is white
# alternate wan is amber, i.e. altblink means amber blink
#
# If link is down, flash amber (physical connection problem)
# If link is up, but no protocol connectivity, flash white (establishing link)
# if link is up and protocol is up, solid white
#
# If Belkin ICC (Internet Connection Checking) is disabled, the as long as the
# WAN proto is up, then it will be solid white
#

. /etc/led/lib_led_functions.sh

ThresholdSpeed=$(syscfg get backhaul::l3_perf_threshold)
#ThresholdSpeed=${ThresholdSpeed:=300}
ThresholdRssi=$(syscfg get backhaul::rssi_threshold)
StatusWifi=$(sysevent get wifi-status)
StatusWan=$(sysevent get wan-status)


EventName=$1
EventValue=$2

LEDLog LED gotevent "$0 $1 $2 $3"
LEDPrintEnv

[ -z "$EventName" ] && {
	LEDLog LED mask "Event:<$EventName>"
	exit 0
}

ReflectInternetState()
{
	local link
	local internet_state
	link=$(sysevent get phylink_wan_state)
	internet_state=$(sysevent get icc_internet_state)

	[ "$EventName" = "phylink_wan_state" ] && {
		[ "$EventValue" = "up" ] && {
			[ "$StatusWan" = "stopped" ] && {
				LEDLog LED mask "WAN status: $StatusWan"
				exit 0
			}
			UXBluePulse
			DeferredShowInternetState
			LEDLog LED sysevent "Link up"
			exit 0
		}

		[ "$EventValue" = "down" ] && {
			UXErrorPulse
			# fall through
		}
	}

	[ "$internet_state" = "up" -a "$link" = "up" ] && {
		UXGoodSolid
		exit 0
	}

	[ "$internet_state" = "down" ] && {
		# if the state is explicitly "down", then it is not noise.
		DeferredShowInternetState
		exit 0
	}
	[ "$internet_state" != "up" -a "$link" = "up" ] && {
		[ "$StatusWan" = "starting" ] && {
			LEDLog LED mask "WAN status: $StatusWan"
			exit 0
		}

		DeferredShowInternetState
		exit 0
	}
	[ "$internet_state" != "up" -a "$link" = "down" ] && {

		[ "$EventName" = "wan-status" -a "$EventValue" = "stopped" ] && {
			LEDLog LED mask "$EventName $EventValue for icc_internet_state"
			exit 0
		}

		[ "$StatusWan" = "starting" ] && {
			LEDLog LED mask "WAN status: $StatusWan"
			exit 0
		}

		DeferredShowInternetState
		exit 0
	}
}

HandleMasterMode()
{
	local link
	link=$(sysevent get phylink_wan_state)

	[ "$EventName" = backhaul::status ] && {
		DeferredShowInternetState 30
		exit 0
	}

	ReflectInternetState
}

IfUplinkWired()
{
	local link
	link=$(sysevent get phylink_wan_state)

	[ "$link" = "up" ]
}

ReflectBackhaulRssi()
{
	local l_backhaul_rssi
	l_backhaul_rssi=$(sysevent get backhaul::rssi)

	IfUplinkWired && {
		UXGoodSolid
		DeferredShowInternetState
		exit 0
	}

	# Current values are absolute, but they mean negative.
	# Negate it before comparision.
	echo "$l_backhaul_rssi" | grep "-" || {
		l_backhaul_rssi="-"$l_backhaul_rssi
	}

	echo "$ThresholdRssi" | grep "-" || {
		ThresholdRssi="-"$ThresholdRssi
	}

	if [ "$l_backhaul_rssi" -lt "$ThresholdRssi" ]; then
		UXTooFar
		exit 0
	else
		UXGoodSolid
		exit 0
	fi

}


ReflectBackhaulPerf()
{
	local l_backhaul_l3_perf
	l_backhaul_l3_perf=$(sysevent get backhaul::l3_perf)

	IfUplinkWired && {
		UXGoodSolid
		DeferredShowInternetState
		exit 0
	}

	[ -z "$l_backhaul_l3_perf" ] && {
		UXGoodSolid
		exit 0
	}

	if [ "$l_backhaul_l3_perf" -lt "$ThresholdSpeed" ]; then
		UXTooFar
		exit 0
	else
		UXGoodSolid
		exit 0
	fi
}

ReflectBackhaulStatus()
{
	IfBackhaulDownLED && exit 0

	local l_backhaul_status
	l_backhaul_status=$(sysevent get backhaul::status)

	[ "$l_backhaul_status" = "up" ] && {
		UXGoodSolid
		DeferredShowInternetState
		exit 0
	}
}

ReflectBackhaul()
{
	[ -n "$ThresholdRssi" ] && {
		ReflectBackhaulRssi
	}

	[ -n "$ThresholdSpeed" ] && {
		ReflectBackhaulPerf
	}
}

HandleSlaveMode()
{
	local internet_state
	internet_state=$(sysevent get icc_internet_state)
	local l_backhaul_status
	l_backhaul_status=$(sysevent get backhaul::status)

	case "$EventName" in
		"icc_internet_state" )
			[ "$EventValue" = "up" ] && {
				[ "$l_backhaul_status" = "up" ] && Setup_SetClear
				IfBackhaulDownLED && exit 0
				ReflectBackhaul
				exit 0
			}
			[ "$EventValue" != "up" ] && {
				[ "$StatusWifi" != "started" ] && {
					LEDLog LED mask "wifi-status: <$StatusWifi>"
					exit 0
				}

				DeferredShowInternetState
			}
			;;
		"backhaul::rssi" )
			[ -z "$ThresholdRssi" ] && exit 0

			[ "$internet_state" != "up" ] && {
				LEDLog LED mask "icc_internet_state: <$internet_state>"
				exit 0
			}

			ReflectBackhaulRssi
			;;
		"backhaul::l3_perf" )
			[ -z "$ThresholdSpeed" ] && exit 0

			[ "$internet_state" != "up" ] && {
				LEDLog LED mask "icc_internet_state: <$internet_state>"
				exit 0
			}

			ReflectBackhaulPerf
			;;
		"backhaul::status" )
			[ "$EventValue" != "up" ] && {
				# Let's not do this here.  It seems to
				# cause spurious red LED when Internet
				# connectivity is up but MQTT
				# is not.
				# sysevent set icc_internet_state down
				ReflectBackhaulStatus
				exit 0
			}

			[ "$EventValue" = "up" ] && {
				[ "$internet_state" = "up" ] && Setup_SetClear
				ReflectBackhaulStatus
				exit 0
			}
			;;
		*)
			;;
	esac
}

HandleRouterMode()
{
	bridge_mode=$(syscfg get bridge_mode)
	if [ "$bridge_mode" = "0" ]; then
		# ------------------------------------------------------------------------
		# Router mode
		# - ICC is running
		# - phylink_wan_state indicates WAN physical Ethernet link
		# - wan_status indicates protocol up
		# - icc_internet_state indicates internet connectivity
		# ------------------------------------------------------------------------
		link=$(sysevent get phylink_wan_state)
		if [ "$link" = "down" ]
		then
			# link down blink at 0.7HZ
			#combo_blink blue 350
			exit 0
		fi

		wan_status=$(sysevent get wan-status)
		if [ "$wan_status" != "started" ]
		then
			# link up but protocol down
			#combo_blink blue 714
			exit 0
		fi

		# link up, protocol up, and internet up/no internet checking
		UXGoodSolid
	fi
}

HandleUnconfiguredMode()
{
	LEDLog LED mask "LED WAN: Unconfigured mode : No LED action"
}


NodeIsMaster && {
	HandleMasterMode
	exit 0
}

NodeIsSlave && {
	HandleSlaveMode
	exit 0
}

NodeIsUnconfigured && {
	HandleUnconfiguredMode
	exit 0
}

HandleRouterMode
exit 0
