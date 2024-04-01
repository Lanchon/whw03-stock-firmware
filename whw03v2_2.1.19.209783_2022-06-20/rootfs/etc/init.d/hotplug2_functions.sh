#!/bin/sh
NodesResetDuration=6
SetTimer()
{
        sysevent set factory_reset_timeout_sec "$1"
}
GetTimer()
{
        RET_VAL=$(sysevent get factory_reset_timeout_sec)
        if [ -z "${RET_VAL}" ]; then
		RET_VAL=0
	fi
        echo ${RET_VAL}
}
DecTimer()
{
        TIME_OUT=$(GetTimer)
        if [ "$TIME_OUT" -lt 1 ]; then
                TIME_OUT=1;
        fi
	TIME_OUT=$(( TIME_OUT - 1 ))
        SetTimer $TIME_OUT
}
BecomeMasterNode()
{
	/etc/led/nodes_led_pulse.sh white 3
	while true; do
		echo "Checking JNAP..." > /dev/console
		if [ "started" = "$(sysevent get wifi-status)" ] && [ "ready" = "$(sysevent get jnap-status)" ] ; then
			break;
		fi
		sleep 1
	done
	syscfg set User_Accepts_WiFi_Is_Unsecure 1
	/usr/sbin/porter -m master
	echo "" > /dev/console
	echo "MASTER" > /dev/console
	echo "PLEASE WAIT WHILE BECOMING THE MASTER NODE..." > /dev/console
	while true; do
		echo "Checking Node Mode..." > /dev/console
		node_mode=$(syscfg get smart_mode::mode)
		[ "$node_mode" = 2 ] && {
			echo "It's set to Master!" > /dev/console
			break;
		}
		sleep 1
	done
	for ii in $(seq 1 50);
	do
		sleep 1
		echo "AutoMaster $ii ..." > /dev/console
		/etc/led/nodes_led_pulse.sh white 3
		if [ "$ii" -gt 30 ] && [ "started" = "$(sysevent get wifi-status)" ] && [ "READY" = "$(sysevent get smart_connect::setup_status)" ] ; then
			break;
		fi
	done
	/etc/led/nodes_led.sh white off
	/etc/led/solid_normal.sh
}
StartSmartSetup()
{
	echo "Setting syscfg auto_onboarding::bt_enabled" > /dev/console
	syscfg set auto_onboarding::bt_enabled 1
	echo "Triggering sysevent bt_auto_onboard::start" > /dev/console
	sysevent set bt_auto_onboard::start
}
AutoMasterNSmartSetup()
{
	local node_mode=$(syscfg get smart_mode::mode)
	[ "$node_mode" = 0 ] && {
		BecomeMasterNode
		StartSmartSetup
		return 0
	}
	if [ "$node_mode" = 2 ]; then
		StartSmartSetup
		return 0
	fi
	return 1
}
AutoMasterClickTimeWindow=60
AutoMasterClickMaxCount=5
ResetAutoMasterTrigger()
{
	local time_now=$(date +%s)
	sysevent set automaster_count_click 0
	sysevent set automaster_initial_time "$time_now"
	echo "Reset AutoMaster trigger"
	echo "Reset initial_click_time:$time_now" > /dev/console
}
AutoMasterIfTriggered()
{
	local time_now=$(date +%s)
	local initial_click_time=$(sysevent get automaster_initial_time)
	initial_click_time=${initial_click_time:="0"}
	local time_elapsed=$(( time_now - initial_click_time ))
	echo "" > /dev/console
	echo "          time_now:$time_now" > /dev/console
	echo "initial_click_time:$initial_click_time" > /dev/console
	echo "time_elapsed:$time_elapsed" > /dev/console
	local time_left=$(( AutoMasterClickTimeWindow - time_elapsed ))
	echo "AutoMaster trigger will expire in:$time_left" > /dev/console
	if [ "$time_elapsed" -gt "$AutoMasterClickTimeWindow" ]; then
		sysevent set automaster_count_click 1
		sysevent set automaster_initial_time "$time_now"
		initial_click_time="$time_now"
		echo "AutoMaster trigger expired:$AutoMasterClickTimeWindow seconds has passed." > /dev/console
		echo "Recounting the click from count 1" > /dev/console
		echo "Updated initial_click_time:$initial_click_time" > /dev/console
	else
		local count=$(sysevent get automaster_count_click)
		count=${count:="0"}
		count=$(( count + 1))
		sysevent set automaster_count_click "$count"
		echo "count:$count" > /dev/console
	fi
	if [ "${count}" -ge "$AutoMasterClickMaxCount" ]; then
		ResetAutoMasterTrigger
		echo "" > /dev/console
		echo "Triggering AutoMaster..." > /dev/console
		AutoMasterNSmartSetup && exit 0
	fi
}
FactoryResetAfter()
{
	SetTimer ${NodesResetDuration}
	local led_total_time=$(( NodesResetDuration - 1 ))
	local led_transition=$(( 100 / led_total_time ))
        while [ "$(GetTimer)" -gt 0 ]
        do
                if [ "released" = "$(sysevent get reset_hw_button)" ] ; then
			 AutoMasterIfTriggered
                	echo "" > /dev/console
                	echo "Ignore the factory reset within ${NodesResetDuration} seconds" > /dev/console
			/etc/led/solid_normal.sh
                	exit
                fi
                sleep 1
                DecTimer
                local timer_val=$(GetTimer)
                local timer_percent=$(( timer_val * led_transition ))
                [ "${timer_percent}" -gt 100 ] && continue
                [ "${timer_percent}" -eq 100 ] && {
			/etc/led/nodes_solid_percent.sh red 100
                        continue;
                }
                /etc/led/nodes_solid_percent.sh red "${timer_percent}"
        done
        SetTimer 0
	[ "pressed" != "$(sysevent get reset_hw_button)" ] && {
                	echo "" > /dev/console
                	echo "Ignore, button not pressed until the final blip" > /dev/console
			/etc/led/solid_normal.sh
                	exit 0
	}
	echo "" > /dev/console
	echo "RESET TO FACTORY SETTING EVENT DETECTED" > /dev/console
	echo "PLEASE WAIT WHILE REBOOTING THE DEVICE..." > /dev/console
	/etc/led/nodes_solid_percent.sh red 100
	/sbin/utcmd factory_reset
	usleep 250000
	/etc/led/nodes_solid_percent.sh red 0
}
