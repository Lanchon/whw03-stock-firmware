#!/bin/sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/ulog_functions.sh
SERVICE_NAME="guardian"
SELF_NAME="`basename $0`"
BIN=guardian
APP=/usr/bin/${BIN}
_STATUS="sysevent get ${SERVICE_NAME}-status"
_PID="pidof ${BIN}"
PID_FILE=/var/run/${BIN}.pid
PMON=/etc/init.d/pmon.sh
service_kill() {
   if [ -n "`$_PID`" ]; then
      kill -9 `$_PID`;
   fi
   /etc/guardian/unregister.sh
   sysevent set ${SERVICE_NAME}-status "stopped"
}
service_start() {
   ulog ${SERVICE_NAME} status "${SERVICE_NAME} service_start called, current status is `$_STATUS`"
   if [ "`syscfg get bridge_mode`" != "0" ]; then		# "1" or "2"
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} service should not start in bridge mode"
      return 1;
   fi
   wait_till_end_state ${SERVICE_NAME}
   if [ "stopped" != "`$_STATUS`" ]; then
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} not stopped. Cannot start."
      return 1;
   fi
   if [ -z "`$_PID`" ]; then
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} service starting"
      sysevent set ${SERVICE_NAME}-status "starting"
      ulimit -s 2048
      nice -n -10 ${APP} &
      wait_till_end_state ${SERVICE_NAME}
      if [ "starting" == "`$_STATUS`" ]; then
         ulog ${SERVICE_NAME} status "${SERVICE_NAME} did not start in time.  Killing via kill -9"
         service_kill
         return 1
      fi
   fi
   sysevent set guardian-configured
   echo "`$_PID`" > $PID_FILE
   $PMON setproc ${SERVICE_NAME} $BIN $PID_FILE "/etc/init.d/service_${SERVICE_NAME}.sh ${SERVICE_NAME}-restart"
}
service_stop () {
   ulog ${SERVICE_NAME} status "${SERVICE_NAME} service_stop called, current status is `$_STATUS`"
   grep -H -n "guardian" /var/log/messages* > /var/log/guardian_log
   if [ -n "`$_PID`" ]; then
      wait_till_end_state ${SERVICE_NAME}
      if [ "started" != "`$_STATUS`" ]; then
          ulog ${SERVICE_NAME} status "${SERVICE_NAME} not started. Cannot stop."
          return 1;
      fi
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} service is being stopped"
      sysevent set ${SERVICE_NAME}-status "stopping"
      wait_till_end_state ${SERVICE_NAME}
      if [ "stopping" == "`$_STATUS`" ]; then
         ulog ${SERVICE_NAME} status "${SERVICE_NAME} did not stop in time.  Killing via kill -9"
         service_kill
      fi
   else
      if [ "started" == "`$_STATUS`" ];then
	sysevent set ${SERVICE_NAME}-status "stopped"
      fi
   fi
   rm -f $PID_FILE
   $PMON unsetproc ${SERVICE_NAME}
}
echo "service_guardian.sh is called with $1" > /dev/console
case "$1" in
  ${SERVICE_NAME}-start)
      if [ "`syscfg get bridge_mode`" = "0" ] && [ "`sysevent get lan-status`" != "started" ]; then
          ulog wlan status "LAN is not started. So ignore the request"
          exit 0
      fi
      service_start
      ;;
  ${SERVICE_NAME}-stop)
      service_stop
      ;;
  ${SERVICE_NAME}-restart)
      if [ "`syscfg get bridge_mode`" = "0" ] && [ "`sysevent get lan-status`" != "started" ]; then
          ulog wlan status "LAN is not started. So ignore the request"
          exit 0
      fi
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} guardian-restart sequence initiated"
      service_stop
      sysevent set nfqrecv-stop
      wait_till_end_state nfqrecv
      service_start
      sysevent set nfqrecv-start
      wait_till_end_state nfqrecv
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} guardian-restart sequence complete"
      ;;
  lan-status)
      LAN_STATUS=`sysevent get lan-status`
      if [ "started" == "${LAN_STATUS}" ] ; then
          service_start
      elif [ "stopped" == "${LAN_STATUS}" ] ; then
          service_stop
      fi
      ;;
  lan-restart)
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} lan-restart sequence initiated"
      service_stop
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} waiting for end state on lan"
      wait_till_end_state lan
      service_start
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} lan-restart sequence complete"
      ;;
  *)
      echo "Usage: $SELF_NAME [${SERVICE_NAME}-start|${SERVICE_NAME}-stop|${SERVICE_NAME}-restart|lan-status|lan-restart]" >&2
      ;;
esac
