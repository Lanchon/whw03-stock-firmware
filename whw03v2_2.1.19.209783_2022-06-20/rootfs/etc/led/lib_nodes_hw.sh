#!/bin/sh

#------------------------------------------------------------------
# © 2013 Belkin International, Inc. and/or its affiliates. All rights reserved.
#------------------------------------------------------------------
. /etc/init.d/ulog_functions.sh
. /etc/init.d/event_handler_functions.sh

FlagLEDShowConsoleLog=/tmp/var/config/log.led
LEDShowConsoleLog=0

[ -f "$FlagLEDShowConsoleLog" ] && LEDShowConsoleLog=1

FileLEDLastAction=/tmp/led_last_action

SaveLEDLastAction()
{
	echo "$@" > "$FileLEDLastAction"
}

GetLEDLastAction()
{
	[ ! -f "$FileLEDLastAction" ] && touch "$FileLEDLastAction"
	cat "$FileLEDLastAction"
}

IsLastActionSame()
{
	local l_action="$*"
	local l_last_action
	l_last_action=$(GetLEDLastAction)

	[ "$l_last_action" = "$l_action" ]
}

LEDLog()
{
    local COMP=$1
    local SUBCOMP=$2
    local MESG=$3

    [ "$SUBCOMP" = "action" ] && SaveLEDLastAction "$MESG"

    UL_MESG="$COMP.$SUBCOMP $MESG"
    if [ "$LEDShowConsoleLog" = 1 ] ; then
	    echo "$(date -u +%T) $UL_MESG"
    fi

    ulog "$COMP" "$SUBCOMP" "$MESG"
}

# Nodes HW has following

LedColors="red green blue purple yellow cyan white rgb"
LedMaxBrightness=255

led_trigger_action()
{
	local l_color=$1
	local l_trigger=$2
	local l_action=$3

	local l_full_path="/sys/class/leds/pca963x:${l_color}/${l_trigger}"

	[ -e "$l_full_path" ] && {
		echo "${l_action}" > "${l_full_path}" || {
			sleep 0.02
			echo "${l_action}" > "${l_full_path}"
		}
		sleep 0.005
	}
}

super_pulse_rgb()
{
	local l_red=$1
	local l_green=$2
	local l_blue=$3

	led_trigger_action rgb max_red "$l_red"
	led_trigger_action rgb max_green "$l_green"
	led_trigger_action rgb max_blue "$l_blue"
}

super_pulse_color()
{
	local l_color=$1

	case $l_color in
		red )
			super_pulse_rgb 255 0 0
			;;
		green )
			super_pulse_rgb 0 255 0
			;;
		blue )
			super_pulse_rgb 0 0 255
			;;
		yellow )
			super_pulse_rgb 255 255 0
			;;
		purple )
			super_pulse_rgb 255 0 255
			;;
		cyan )
			super_pulse_rgb 0 255 255
			;;
		white )
			super_pulse_rgb 255 255 255
			;;
		uxyellow )
			super_pulse_rgb 255 150 0
			;;
		uxblue )
			super_pulse_rgb 0 60 255
			;;
		uxpurple )
			super_pulse_rgb 140 0 255
			;;
		* )
			super_pulse_rgb 0 0 255
			;;
	esac
}

rgb_all_none()
{
	local l_brightness=0

	for ii in ${LedColors}; do
		led_trigger_action "${ii}" trigger none
	done
}

super_pulse_setup()
{
	local l_action=$1
	local l_color=$2
	local l_delay=$3
	local l_step=5

	rgb_all_none

	led_trigger_action rgb trigger custompulse

	led_trigger_action rgb step_up "$l_step"
	led_trigger_action rgb step_down "$l_step"

	led_trigger_action rgb delay_up "$l_delay"
	led_trigger_action rgb delay_down "$l_delay"

	led_trigger_action rgb min_red 0
	led_trigger_action rgb min_green 0
	led_trigger_action rgb min_blue 0

	super_pulse_color "$l_color"

	case $l_action in
		on )
			led_trigger_action rgb first_down 1
			led_trigger_action rgb stop_on_max 1
			led_trigger_action rgb stop_on_min 0
			;;
		off )
			led_trigger_action rgb first_down 1
			led_trigger_action rgb stop_on_max 0
			led_trigger_action rgb stop_on_min 1
			;;
		pulse )
			led_trigger_action rgb first_down 1
			led_trigger_action rgb stop_on_max 0
			led_trigger_action rgb stop_on_min 0
			;;
		* )
			# on
			led_trigger_action rgb first_down 1
			led_trigger_action rgb stop_on_max 1
			led_trigger_action rgb stop_on_min 0
			;;
	esac
}

super_pulse_start()
{
	local l_start=$1
	led_trigger_action rgb start "$l_start"
}

super_pulse_terminate()
{
	led_trigger_action rgb start 0
	led_trigger_action rgb trigger none
}

rgb_solid()
{
	local l_color=$1
	local l_brightness=$2

	if [ "${l_brightness}" != "0" ]; then
		led_trigger_action "${l_color}" trigger default-on
	else
		led_trigger_action "${l_color}" trigger none
	fi

	led_trigger_action "${l_color}" brightness "$2"
}

rgb_all_solid()
{
	local l_brightness=$1

	for ii in ${LedColors}; do
		rgb_solid "${ii}" "${l_brightness}"
	done
}

rgb_all_off_except()
{
	local l_color=$1
	local l_brightness=0

	super_pulse_terminate

	for ii in ${LedColors}; do
		[ "${ii}" = "${l_color}" ] || rgb_solid "${ii}" "${l_brightness}"
	done
}

rgb_all_blink()
{
        local l_timer=$1

	led_trigger_action white trigger timer

	led_trigger_action white delay_on 0
	led_trigger_action white delay_off 0

	led_trigger_action white delay_on "${l_timer}"
	led_trigger_action white delay_off "${l_timer}"
}

rgb_blink_start()
{
	local l_color=$1

	led_trigger_action "$l_color" trigger timer
	led_trigger_action "$l_color" brightness "$LedMaxBrightness"
}

rgb_blink_delayon()
{
	local l_color=$1
	local l_timer=$2

	led_trigger_action "${l_color}" delay_on 0
	led_trigger_action "${l_color}" delay_on "${l_timer}"
}

rgb_blink_delayoff()
{
	local l_color=$1
	local l_timer=$2

	led_trigger_action "${l_color}" delay_off 0
	led_trigger_action "${l_color}" delay_off "${l_timer}"
}

rgb_blink_delayonoff()
{
	local l_color=$1
	local l_timer=$2

	led_trigger_action "${l_color}" delay_on 0
	led_trigger_action "${l_color}" delay_off 0

	led_trigger_action "${l_color}" delay_on "${l_timer}"
	led_trigger_action "${l_color}" delay_off "${l_timer}"
}

rgb_all_timer()
{
	local l_timer=$1

	for ii in ${LedColors}; do
		rgb_blink_delayonoff "${ii}" "${l_timer}"
	done
}

rgb_pulse_start()
{
	local l_color=$1
	local l_delay=$2
	local l_step=5

	led_trigger_action "${l_color}" trigger pulse
	led_trigger_action "${l_color}" first_down 1
	led_trigger_action "${l_color}" active "${LedMaxBrightness}"
	led_trigger_action "${l_color}" min 0
	led_trigger_action "${l_color}" max "${LedMaxBrightness}"
	led_trigger_action "${l_color}" step_up "${l_step}"
	led_trigger_action "${l_color}" step_down "${l_step}"
	led_trigger_action "${l_color}" delay_up "${l_delay}"
	led_trigger_action "${l_color}" delay_down "${l_delay}"
}

SaveLastSolidColor()
{
	local l_color=$1
	local l_brightness=$2

	l_color=${l_color:=blue}
	l_brightness=${l_brightness:=255}

	sysevent set led_color_solid "${l_color}"
	sysevent set led_color_brightness "${l_brightness}"
}

is_valid_color()
{
	local l_color=$1

	for ii in ${LedColors}; do
		[ "${ii}" = "${l_color}" ] && return 0
	done

	[ "$l_color" = "uxblue" ] && return 0
	[ "$l_color" = "uxpurple" ] && return 0
	[ "$l_color" = "uxyellow" ] && return 0

	return 1
}

combo_solid_org()
{
	local l_color=$1
	local l_brightness=$2

	is_valid_color "$l_color" || {
		echo "Invalid color : ${l_color}"
		return 1
	}

	local l_dbg_msg="combo_solid_org, $l_color, $l_brightness"
	IsLastActionSame "$l_dbg_msg" && {
		LEDLog LED mask "Skip same command:$l_dbg_msg"
		return 0
	}

	LEDLog LED action "$l_dbg_msg"

	[ "${l_brightness}" = "on" ] && l_brightness="${LedMaxBrightness}"

	[ "${l_brightness}" = "off" ] && l_brightness=0

	SaveLastSolidColor "${l_color}" "${l_brightness}"

	rgb_all_off_except "${l_color}"
	rgb_solid "${l_color}" "${l_brightness}"
}

combo_solid()
{
	local l_color=$1
	local l_brightness=$2

	is_valid_color "$l_color" || {
		echo "Invalid color : ${l_color}"
		return 1
	}

	local l_dbg_msg="combo_solid, $l_color, $l_brightness"
	IsLastActionSame "$l_dbg_msg" && {
		LEDLog LED mask "Skip same command:$l_dbg_msg"
		return 0
	}

	LEDLog LED action "$l_dbg_msg"

	if [ "${l_brightness}" = "off" ]; then
		l_brightness=0
		super_pulse_setup off "$l_color" 5
	else
		l_brightness="${LedMaxBrightness}"
		super_pulse_setup on "$l_color" 5
	fi

	super_pulse_start 1

	SaveLastSolidColor "${l_color}" "${l_brightness}"
}

combo_solid_percent()
{
	local l_color=$1
	local l_percent=$2
	local l_brightness="${LedMaxBrightness}"

	is_valid_color "$l_color" || {
		echo "Invalid color : ${l_color}"
		return 1
	}

	rgb_all_off_except "${l_color}"

	l_brightness=$(/etc/led/linear2perceptual "${LedMaxBrightness}" "${l_percent}")

	local l_dbg_msg="combo_solid_percent, $l_color, $l_percent, $l_brightness"
	IsLastActionSame "$l_dbg_msg" && {
		LEDLog LED mask "Skip same command:$l_dbg_msg"
		return 0
	}

	LEDLog LED action "$l_dbg_msg"

	rgb_solid "${l_color}" "${l_brightness}"
}

GetLastSolidColor()
{
	local l_color
	l_color=$(sysevent get led_color_solid)
	l_color=${l_color:=blue}

	echo "${l_color}"
}

GetLastSolidBrightness()
{
	local l_brightness
	l_brightness=$(sysevent get led_color_brightness)
	l_brightness=${l_brightness:=255}

	echo "${l_brightness}"
}

SetLastSolid()
{
	local l_color
	local l_brightness
	l_color=$(GetLastSolidColor)
	l_brightness=$(GetLastSolidBrightness)

	combo_solid "${l_color}" "${l_brightness}"
}

combo_blink()
{
	local l_color=$1
	local l_timer=$2

	is_valid_color "$l_color" || {
		echo "Invalid color : ${l_color}"
		return 1
	}

	local l_dbg_msg="combo_blink, $l_color, $l_timer"
	IsLastActionSame "$l_dbg_msg" && {
		LEDLog LED mask "Skip same command:$l_dbg_msg"
		return 0
	}

	LEDLog LED action "$l_dbg_msg"

	rgb_all_off_except "${l_color}"
	rgb_blink_start "${l_color}"
	rgb_blink_delayonoff "${l_color}" "${l_timer}"

	[ "${l_timer}" -eq 0 ] && rgb_all_solid "${l_timer}"
}

combo_pulse_org()
{
	local l_color=$1
	local l_timer=$2

	is_valid_color "$l_color" || {
		echo "Invalid color : ${l_color}"
		return 1
	}

	local l_dbg_msg="combo_pulse_org, $l_color, $l_timer"
	IsLastActionSame "$l_dbg_msg" && {
		LEDLog LED mask "Skip same command:$l_dbg_msg"
		return 0
	}

	LEDLog LED action "$l_dbg_msg"

	rgb_all_off_except "${l_color}"
	rgb_pulse_start "${l_color}" "${l_timer}"

	[ "${l_timer}" -eq 0 ] && rgb_all_solid "${l_timer}"
}

combo_pulse()
{
	local l_color=$1
	local l_timer=$2

	is_valid_color "$l_color" || {
		echo "Invalid color : ${l_color}"
		return 1
	}

	local l_dbg_msg="combo_pulse, $l_color, $l_timer"
	IsLastActionSame "$l_dbg_msg" && {
		LEDLog LED mask "Skip same command:$l_dbg_msg"
		return 0
	}

	LEDLog LED action "$l_dbg_msg"

	super_pulse_setup pulse "$l_color" "$l_timer"
	super_pulse_start 1
}

