#!/bin/sh
if [ "-h" = "$1" ] || [ "-help" = "$1" ]; then
	echo "Usage: StartSmartConnectClient.sh SetupAP(optional) WiredEnabled(true/false,optional)" >&2
    exit
fi
if [ "`syscfg get smart_mode::mode`" != "0" ] ; then
	echo "ErrorUnsupportedMode" > /dev/console
    exit
fi
if [ "`sysevent get smart_connect::setup_status`" != "READY" ] ; then
	echo "ErrorSetupAlreadyInProgress" > /dev/console
    exit
fi
if [ "" != "$1" ] ; then
	syscfg set smart_connect::setup_ap "$1"
fi
WiredEnabled=`echo $2 | tr [:upper:] [:lower:]`
if [ "true" = "$WiredEnabled" ] ; then
	sysevent set smart_connect::setup_mode "wired"
elif [ "false" = "$WiredEnabled" ]; then
	sysevent set smart_connect::setup_mode "wireless"
fi
echo "smart connect PIN:`syscfg get smart_connect::client_pin`" > /dev/console
sysevent set smartconnect_client-start
