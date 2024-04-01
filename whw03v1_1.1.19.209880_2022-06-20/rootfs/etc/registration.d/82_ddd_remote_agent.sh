#!/bin/sh

#------------------------------------------------------------------
# © 2013 Belkin International, Inc. and/or its affiliates. All rights reserved.
#------------------------------------------------------------------

# ----------------------------------------------------------------------------
# This script registers the ddd_remote_agent to be notified about events
# which should cause it to reinitialize
#
# It will register handlers for changes to
#    lan-status
#    usb_device_state
#    samba_server_restart
# ----------------------------------------------------------------------------

source /etc/init.d/service_registration_functions.sh

SERVICE_NAME="ddd_remote_agent"

SERVICE_DEFAULT_HANDLER="/etc/init.d/service_${SERVICE_NAME}.sh"

WLAN_TOPIC="mqttsub::wlansubdev"
ETH_TOPIC="mqttsub::ethsubdev"

SERVICE_CUSTOM_EVENTS="\
             $WLAN_TOPIC|$SERVICE_DEFAULT_HANDLER|NULL|$TUPLE_FLAG_EVENT; \
             $ETH_TOPIC|$SERVICE_DEFAULT_HANDLER|NULL|$TUPLE_FLAG_EVENT \
            "


source /etc/init.d/ulog_functions.sh

# name of this script
#SELF_NAME="82_ddd_remote_agent"

srv_register () {
   sm_register "$SERVICE_NAME" "$SERVICE_DEFAULT_HANDLER" "$SERVICE_CUSTOM_EVENTS"
}

srv_unregister () {
   sm_unregister "$SERVICE_NAME"
}

do_start () {
  srv_register
}

do_stop () {
  srv_unregister
}

#-----------------------------------------------------------------------------------
# Main entry point
#
#-----------------------------------------------------------------------------------
case "$1" in
  start|"")
        do_start
        ;;
  restart|reload|force-reload)
       do_stop
       do_start
        ;;
  stop)
       do_stop
        ;;
  *)
        echo "Usage: $SERVICE_NAME [start|stop|restart]" >&2
        exit 3
        ;;
esac

