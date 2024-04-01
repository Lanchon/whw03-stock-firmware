#!/bin/sh
source /etc/init.d/ulog_functions.sh
PID="($$)"
if [ "1" = "`syscfg get ipv6_verbose_logging`" ]
then
   LOG=/var/log/ipv6.log
else
   LOG=/dev/null
fi
do_start_passthrough() {
   sysevent set ipv6_connection_state "ipv6 link going up"
   sysevent set current_ipv6_link_state up
}
do_stop_passthrough() {
   sysevent set ipv6_connection_state "ipv6 link going down"
   sysevent set current_ipv6_link_state down
}
CURRENT_STATE=`sysevent get current_ipv6_link_state`
DESIRED_STATE=`sysevent get desired_ipv6_link_state`
ulog passthrough_link status "passthrough_link status: $PID entry. parameter=$1"
PHYLINK_STATE=`sysevent get phylink_wan_state`
if [ -z "$CURRENT_STATE" ] ; then
   sysevent set current_ipv6_link_state down
   CURRENT_STATE=down
fi
if [ "started" != "`sysevent get lan-status`" ] 
then
   ulog passthrough_link status "$PID Deferring link up until lan-status is up."
   exit 0
fi
if [ "up" = "$DESIRED_STATE" -a "up" = "$PHYLINK_STATE" ] ; then
   if [ "down" = "$CURRENT_STATE" ] ; then
      ulog passthrough_link status "$PID Starting passthrough link."
      do_start_passthrough
      exit 0
   fi
fi
if [ "down" = "$DESIRED_STATE" -o "down" = "$PHYLINK_STATE" ] ; then
   if [ "up" = "$CURRENT_STATE" ] ; then
      ulog passthrough_link status "$PID Stopping passthrough link."
      do_stop_passthrough
      exit 0
   fi
fi
case "$1" in
   phylink_wan_state)
      ;;
   desired_ipv6_link_state)
      ;;
   lan-status|guest_access-status)
     ;;
  *)
        ulog passthrough_link status "$PID Invalid parameter $1 "
        exit 3
        ;;
esac
