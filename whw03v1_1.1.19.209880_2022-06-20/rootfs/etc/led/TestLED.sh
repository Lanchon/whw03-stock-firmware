#!/bin/sh
. /etc/led/lib_led_functions.sh

MonitorVars()
{
	while true; do
		echo Monitoring
		LEDPrintEnv
		sleep 1
	done
}

GetYesNo()
{
	local action=$1
	local color=$2

	read -p "Is LED *${action}* *${color}*? (y/n)" yn

	case $yn in
		[Nn]* )
			echo "Failed!"
			;;
		* )
			echo "Success!"
			;;
	esac
}

LEDBasicTest()
{
	for ii in ${LedColors}; do
		color=$ii

		[ "$color" = rgb ] && continue;

		combo_pulse "$color" 2
		GetYesNo "pulse" "$color"

		combo_blink "$color" 200
		GetYesNo "blink" "$color"

		combo_solid "$color" "$LedMaxBrightness"
		GetYesNo "solid" "$color"

		combo_solid_percent "$color" 60 "$LedMaxBrightness"
		GetYesNo "solid percent 60" "$color"
	done

	echo "LED basic test finished. Setting LED to Solid Blue."
	combo_solid blue on
}

echo "**LED Test script**"
LEDPrintEnv

echo "Please choose an action"
echo "0) Turn On console LED log"
echo "1) Print env"
echo "2) Basic test"
echo "3) SW timer test"
echo "4) Monitor vars"

read num
case $num in
	0 )
		touch "$FlagLEDShowConsoleLog"
		;;
	1 )
		PrintNodeMode
		LEDPrintEnv
		;;
	2 )
		LEDBasicTest
		;;
	3 )
		echo "Solid Blue On"
		combo_solid blue on
		echo "Pulse Green"
		combo_pulse green 2
		echo "Solid Blue after 3s"
		SetSolidAfter 3
		;;
	4 )
		MonitorVars
		;;
	* )
		LEDPrintEnv
		;;
esac

