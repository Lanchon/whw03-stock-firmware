#!/bin/sh
. /etc/led/lib_nodes_hw.sh

MasterMode="2"
SlaveMode="1"
UnconfiguredMode="0"

NodeMode=$(syscfg get smart_mode::mode)

NodeIsMaster()
{
	[ "$NodeMode" = "$MasterMode" ] && return 0

	return 1
}

NodeIsSlave()
{
	[ "$NodeMode" = "$SlaveMode" ] && return 0

	return 1
}

NodeIsUnconfigured()
{
	[ "$NodeMode" = "$UnconfiguredMode" ] && return 0

	return 1
}


PrintNodeMode()
{
	local l_str="Error"

	NodeIsMaster && l_str="Master Mode"
	NodeIsSlave && l_str="Slave Mode"
	NodeIsUnconfigured && l_str="Unconfigured Mode"

	local log_msg="Mode: $l_str ($NodeMode)"

	LEDLog LED mode "$log_msg"
}

PrintSysCfg()
{
	local syscfg_name=$1

	local log_msg
	log_msg="${syscfg_name} [$(syscfg get "$syscfg_name")]"

	LEDLog LED syscfg "$log_msg"
}

PrintSysEvent()
{
	local sysevent_name=$1

	local log_msg
	log_msg="${sysevent_name} [$(sysevent get "$sysevent_name")]"

	LEDLog LED sysevent "$log_msg"
}

LEDPrintEnv()
{
	PrintSysCfg smart_mode::mode
	PrintSysCfg bridge_mode
	PrintSysEvent user_setup_active
	PrintSysEvent system-status
	PrintSysEvent icc_internet_state
	PrintSysEvent phylink_wan_state
	PrintSysEvent ipv4_wan_ipaddr
	PrintSysEvent wifi-status
	PrintSysEvent wan-status
	PrintSysEvent autochannel-status
	PrintSysEvent user_setup_active
	PrintSysEvent setup::presetup
	PrintSysEvent setup::stage
	PrintSysEvent setup::progress
	PrintSysEvent backhaul::status
	PrintSysEvent backhaul::l3_perf
	PrintSysEvent backhaul::intf
	PrintSysEvent backhaul::preferred_bssid
	PrintSysEvent backhaul::parent_ip
	PrintSysEvent backhaul::rssi
	PrintSysCfg backhaul::l3_perf_threshold
	PrintSysCfg backhaul::rssi_threshold
	PrintSysEvent smart_connect::setup_status
	PrintSysEvent state_machine-status
	PrintSysEvent fwup_state
}

SetLEDTimer()
{
	local l_sec=$1
	local l_timer_var=$2

        sysevent set "$l_timer_var" "$l_sec"
}

GetLEDTimer()
{
	local l_timer_var=$1

        RET_VAL=$(sysevent get "$l_timer_var")
        if [ -z "${RET_VAL}" ]; then
		RET_VAL=0
	fi

        echo ${RET_VAL}
}

DecLEDTimer()
{
	local l_timer_var=$1

        TIME_OUT=$(GetLEDTimer "$l_timer_var")
        if [ "$TIME_OUT" -lt 1 ]; then
                TIME_OUT=1;
        fi
	TIME_OUT=$(( TIME_OUT - 1))
        SetLEDTimer "$TIME_OUT" "$l_timer_var"
}

WaitTillTimeout()
{
	local l_timer_var=$1
	local l_function=$2

        while [ "$(GetLEDTimer "$l_timer_var")" -gt 0 ]
        do
                ## debug show timer
		LEDLog LED dbg "$l_timer_var:$(GetLEDTimer "$l_timer_var")"
                sleep 1
                DecLEDTimer "$l_timer_var"
        done

        SetLEDTimer 0 "$l_timer_var"

	$l_function
}

CustomDoAfter()
{
	local l_sec=$1
	local l_timer_var=$2
	local l_function=$3

	LEDLog LED log "CustomDoAfter:$l_timer_var"

	TIME_OUT=$(GetLEDTimer "$l_timer_var")
	if [ 0 != "$TIME_OUT" ]; then
		SetLEDTimer "$l_sec" "$l_timer_var"
	else
		SetLEDTimer "$l_sec" "$l_timer_var"
		#WaitTillTimeout "$l_timer_var" "$3"
		WaitTillTimeout "$l_timer_var" "$l_function"
	fi
}

SetSolidAfter()
{
	local l_sec=$1
	local l_timer_var=$2

	CustomDoAfter "$l_sec" "led_timeout_sec" SetLastSolid
}
#{
	#local l_sec=$1
	#local l_timer_var=$2
	#l_timer_var=${l_timer_var:=led_timeout_sec}

	#SetLEDTimer 0 "$l_timer_var"

        #TIME_OUT=$(GetLEDTimer "$l_timer_var")
        #if [ 0 != "$TIME_OUT" ]; then
                #SetLEDTimer "$l_sec" "$l_timer_var"
        #else
                #SetLEDTimer "$l_sec" "$l_timer_var"
                #WaitTillTimeout "$l_timer_var" SetLastSolid
        #fi
#}

SpotFinder_Running()
{
	local l_spotfinder_status
	l_spotfinder_status=$(sysevent get autochannel-status)
	[ "$l_spotfinder_status" = "running" ] && return 0

	return 1
}

Setup_SetActive()
{
	sysevent set user_setup_active 1
	LEDLog LED log "Setup_SetActive"
	LEDPrintEnv
	DeferredClearSetupActive 120
}

Setup_SetClear()
{
	sysevent set user_setup_active 0
	LEDLog LED log "Setup_SetClear"
	LEDPrintEnv
}

Setup_Running()
{
	local l_user_setup_active
	l_user_setup_active=$(sysevent get user_setup_active)

	[ "$l_user_setup_active" = "1" ]
}

UXUnconfiguredSolid()
{
	combo_solid uxpurple on
}

UXGoodSolid()
{
	combo_solid uxblue on
}

UXTooFar()
{
	combo_solid uxyellow on
}

UXErrorSolid()
{
	combo_solid red on
}

UXErrorPulse()
{
	combo_pulse red 2
}

UXPurplePulse()
{
	combo_pulse purple 3
}

UXBluePulse()
{
	combo_pulse blue 3
}

DeferredShowInternetState()
{
	local n_sec=$1
	n_sec=${n_sec:=10}

	LEDLog LED log "DeferredShowInternetState n_sec:$n_sec"

	/etc/led/show_internet_state_after.sh "${n_sec}" &
}

DeferredClearSetupActive()
{
	local n_sec=$1
	n_sec=${n_sec:=100}

	LEDLog LED log "DeferredClearSetupActive n_sec:$n_sec"

	/etc/led/clear_user_setup_status.sh "${n_sec}" &
}

IfBackhaulDownLED()
{
	LEDLog LED dbg "IfBackhaulDownLED"
	local l_backhaul_status
	l_backhaul_status=$(sysevent get backhaul::status)

	[ "$l_backhaul_status" != "up" ] && {
		fwup_updating && {
			LEDLog LED mask "Firmware updating..."
			return 0
		}

		SpotFinder_Running && {
			LEDLog LED mask "Spotfinder running..."
			return 0
		}

		Setup_Running && {
			LEDLog LED mask "Setup running..."
			return 0
		}

		LEDLog LED log "Backhaul down"
		UXErrorPulse
		return 0
	}

	return 1
}
