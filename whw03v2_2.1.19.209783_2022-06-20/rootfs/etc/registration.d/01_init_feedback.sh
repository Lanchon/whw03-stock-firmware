#!/bin/sh

#------------------------------------------------------------------
# © 2013 Belkin International, Inc. and/or its affiliates. All rights reserved.
#------------------------------------------------------------------
source /etc/init.d/feedback_registration_functions.sh
###############################################################################
#	nodes
#
#	Feedback Events
#
#	You may add a new line for a new feedback event
#
# 	The format of each line of a feedback event string is:
# 	name_of_event | path/filename_of_handler ;\
#
#	Optionally if the handler takes a parameter
# 	name_of_event | path/filename_of_handler | parameter ;\
#
###############################################################################

FEEDBACK_EVENTS="\
	system_state-normal|/etc/led/solid_normal.sh ;\
	system_state-error|/etc/led/pulsate.sh ;\
	system_state-heartbeat|/etc/led/pulsate.sh ;\
	phylink_wan_state|/etc/led/manage_wan_led.sh ;\
	wan-status|/etc/led/manage_wan_led.sh ;\
	backhaul::l3_perf|/etc/led/manage_wan_led.sh ;\
	backhaul::rssi|/etc/led/manage_wan_led.sh ;\
	backhaul::status|/etc/led/manage_wan_led.sh ;\
	icc_internet_state|/etc/led/manage_wan_led.sh ;\
	fwupd-start|/etc/led/fwupd-start.sh ;\
	fwupd-success|/etc/led/fwupd-success.sh ;\
	fwupd-failed|/etc/led/fwupd-failed.sh ;\
	setup::presetup|/etc/led/led_presetup.sh;\
	smart_connect::setup_status|/etc/led/manage_smartconnect_led.sh ;\
"

###############################################################################
#	No need to edit below
###############################################################################

register_events_handler "$FEEDBACK_EVENTS"

