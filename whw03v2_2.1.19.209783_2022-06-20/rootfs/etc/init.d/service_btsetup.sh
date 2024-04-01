#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="btsetup"
service_init ()
{
    echo "${SERVICE_NAME} service"
}
service_start ()
{
   wait_till_end_state ${SERVICE_NAME}
   SMARTMODE=`syscfg get smart_mode::mode`
   STATUS=`sysevent get ${SERVICE_NAME}-status`
   if [ "started" != "$STATUS" ] ; then
      sysevent set ${SERVICE_NAME}-errinfo 
      sysevent set ${SERVICE_NAME}-status starting
       if [ "2" = "$SMARTMODE" ] ; then
          echo "${SERVICE_NAME}: Master mode and Central role"
          sysevent set ${SERVICE_NAME}-role central
          sysevent set ${SERVICE_NAME}-mode master
          start_bluetoothd "master"
       elif [ "1" = "$SMARTMODE" ] ; then
          echo "${SERVICE_NAME}: Slave mode and Peripheral role"
          sysevent set ${SERVICE_NAME}-role peripheral
          sysevent set ${SERVICE_NAME}-mode slave
          start_bluetoothd
          btsetup &
       else
          echo "${SERVICE_NAME}: Unconfigured mode and Peripheral role"
          sysevent set ${SERVICE_NAME}-role peripheral
          sysevent set ${SERVICE_NAME}-mode unconfigured
          start_bluetoothd
          btsetup &
       fi
      check_err $? "Couldnt handle start"
      sysevent set ${SERVICE_NAME}-status started
   fi
}
service_stop ()
{
   wait_till_end_state ${SERVICE_NAME}
   STATUS=`sysevent get ${SERVICE_NAME}-status`
   ROLE=`sysevent get ${SERVICE_NAME}-role`
   if [ "stopped" != "$STATUS" ] ; then
      sysevent set ${SERVICE_NAME}-errinfo 
      sysevent set ${SERVICE_NAME}-status stopping
      if [ "central" = "$ROLE" ] ; then
            killall -9 bluetoothd
      else
            echo "Disable BLE advertisement" > /dev/console
            hciconfig hci0 noleadv
            killall -9 btsetup
            killall -9 bluetoothd
      fi
      check_err $? "Couldnt handle stop"
      sysevent set ${SERVICE_NAME}-status stopped
   fi
}
service_update_start()
{
    sysevent set ${SERVICE_NAME}-update_status done
    SMARTMODE=`syscfg get smart_mode::mode`
    MODE=`sysevent get ${SERVICE_NAME}-mode`
    if [ "unconfigured" = "$MODE" ] ; then
        if [ "1" = "$SMARTMODE" ] ; then
            echo "${SERVICE_NAME}: Changed smart mode from Unconfigured to Slave."
            sysevent set ${SERVICE_NAME}-role peripheral
            sysevent set ${SERVICE_NAME}-mode slave
            sysevent set ${SERVICE_NAME}-update_advertisement
        elif [ "2" = "$SMARTMODE" ] ; then
            echo "${SERVICE_NAME}: Changed smart mode from Unconfigured to Master."
            echo "${SERVICE_NAME}: Stop btsetup, and restart bluetoothd and hci."
            service_stop
            service_start
        fi
    fi
}
service_update()
{
    PRESETUP=`sysevent get setup::presetup`
    if [ "true" = "$PRESETUP" ] ; then
        echo "${SERVICE_NAME}: Presetup mode. Set the update status to pending"
        sysevent set ${SERVICE_NAME}-update_status pending
    else
        echo "${SERVICE_NAME}: Start updating ${SERVICE_NAME} service"
        service_update_start
    fi
}
service_update_advertisement()
{
    SMARTMODE=`syscfg get smart_mode::mode`
    if [ "0" = "$SMARTMODE" ] || [ "1" = "$SMARTMODE" ] ; then
        echo "${SERVICE_NAME}: Update advertisement data"
        sysevent set ${SERVICE_NAME}-change_advertisement_data
    else
        echo "${SERVICE_NAME}: Not update advertisement data in Master Node"
    fi
}
service_presetup()
{
    PRESETUP=`sysevent get setup::presetup`
    if [ "false" = "$PRESETUP" ] ; then
        SMARTMODE=`syscfg get smart_mode::mode`
        if [ "2" = "$SMARTMODE" ] ; then
            hcisetup "master"
        else
            hcisetup
        fi
        UPDATE_STATUS=`sysevent get ${SERVICE_NAME}-update_status`
        if [ "pending" = "$UPDATE_STATUS" ] ; then
            sysevent set ${SERVICE_NAME}-update
        fi
    fi
}
service_ready()
{
    STATUS=$1
    if [ "READY" = "$STATUS" ] ; then
        service_start
    fi
}
service_init 
echo "${SERVICE_NAME}: $1"
case "$1" in
   ${SERVICE_NAME}-start)
      service_start
      ;;
   ${SERVICE_NAME}-stop)
      service_stop
      ;;
   ${SERVICE_NAME}-restart)
      service_stop
      service_start
      ;;
   ${SERVICE_NAME}-update)
      service_update
      ;;
   ${SERVICE_NAME}-update_advertisement)
      service_update_advertisement
      ;;
    backhaul::status)
      sysevent set ${SERVICE_NAME}-update_advertisement
      ;;
    setup::presetup)
      service_presetup
      ;;
    smart_connect::setup_status)
      service_ready $2
      ;;      
   *)
      echo "${SERVICE_NAME}: Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
      exit 3
      ;;
esac
