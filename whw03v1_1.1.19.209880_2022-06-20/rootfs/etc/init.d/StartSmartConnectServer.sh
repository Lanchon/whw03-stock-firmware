#!/bin/sh
if [ "" = "$1" ] || [ "-h" = "$1" ] || [ "-help" = "$1" ]; then
	echo "Usage: StartSmartConnectServer.sh PIN duration(optional)" >&2
    exit
fi
if [ "`syscfg get smart_mode::mode`" != "2" ] ; then
	echo "ErrorUnsupportedMode" > /dev/console
    exit
fi
if [ "`sysevent get smart_connect::setup_status`" != "READY" ] ; then
	echo "ErrorSetupAlreadyInProgress" > /dev/console
    exit
fi
if [ "" = "$2" ] ; then
	DURATION=120
else
	DURATION=$2
fi
syscfg set smart_connect::client_pin $1
syscfg set smart_connect::setup_duration $DURATION
sysevent set wifi_smart_connect_setup-run
sysevent set smart_connect::wifi_setupap_ready
