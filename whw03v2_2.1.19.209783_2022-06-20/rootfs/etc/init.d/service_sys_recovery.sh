#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="sys_recovery"
NAMESPACE=$SERVICE_NAME
BACKUP_TOOL=`which sys_recovery_backup.sh`
RECOVERY_TOOL=`which sys_recovery_restore.sh`
service_start ()
{
    wait_till_end_state ${SERVICE_NAME}
    check_err $? "Couldnt handle start"
    sysevent set ${SERVICE_NAME}-status started
    ulog ${SERVICE_NAME} status "now started"
}
service_stop ()
{
    wait_till_end_state ${SERVICE_NAME}
    check_err $? "Couldnt handle stop"
    sysevent set ${SERVICE_NAME}-status stopped
    ulog ${SERVICE_NAME} status "now stopped"
}
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
        sys_recovery::backup)
            if [ "`sysevent get sys_recovery::status`" != "running" ] ; then
                sysevent set sys_recovery::status "running"
                ${BACKUP_TOOL} pre_backup
                if [ "$?" = "0" ] ; then
                    ${BACKUP_TOOL} backup
		    if [ "$?" = "0" ] ; then
		    ${BACKUP_TOOL} post_backup
		    fi
                fi
                sysevent set sys_recovery::status "stopped"
            else
                echo "sys_recovery is already running"
            fi
        ;;
        sys_recovery::restore)
            if [ "`sysevent get sys_recovery::status`" != "running" ] ; then
                sysevent set sys_recovery::status "running"
                ${RECOVERY_TOOL} pre_restore
                if [ "$?" = "0" ] ; then
                    ${RECOVERY_TOOL} restore
		    if [ "$?" = "0" ] ; then
		    ${RECOVERY_TOOL} post_restore
		    fi
                fi
                sysevent set sys_recovery::status "stopped"
            else
                echo "sys_recovery is already running"
            fi
        ;;
    *)
        echo "error : $1 unknown" > /dev/console
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
        exit 3
        ;;
esac
