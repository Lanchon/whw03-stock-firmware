#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME=devicedb
BIN_NAME=$SERVICE_NAME
APP_NAME=/usr/sbin/$BIN_NAME
PID_FILE=/var/run/$BIN_NAME.pid
PMON=/etc/init.d/pmon.sh
PMON_RESTART_CMD="/etc/init.d/service_$SERVICE_NAME.sh $SERVICE_NAME-restart"
DEFAULT_UDSPATH=/tmp/devicedb/server_link
DEFAULT_DBFILE=/tmp/devicedb/devicedb.db
DEFAULT_DBTRANSIENT_FILE=/tmp/devicedb/transient.db
DEFAULT_DBBACKUP=/var/config/devicedb/devicedb.db
CRON_TAB_FILE=/tmp/cron/cron.daily/devicedb_backup_daily.sh
DEVICEDB_PURGE_CHECK=/tmp/devicedb/purge_db
DEVICEDB_DIR=/etc/devicedb
DEVICEDB_SCHEMA_CORE=$DEVICEDB_DIR/device_core.sql
DEVICEDB_TRANSIENT_SCHEMA=$DEVICEDB_DIR/device_transient.sql
DEVICEDB_SCHEMA_DIR=$DEVICEDB_DIR/schema
DEVICEDB_RESTART_TIME=/tmp/devicedb/restart_time
start_cron ()
{
    if [ -e $CRON_TAB_FILE ]; then
        return
    fi
(
cat <<'End-of-Text'
#!/bin/sh
/etc/init.d/service_devicedb.sh backup &
End-of-Text
) > $CRON_TAB_FILE
    chmod +x $CRON_TAB_FILE
    echo "DeviceDB Daily Backup Cron job created" > /dev/console
}
stop_cron ()
{
    rm -rf $CRON_TAB_FILE
}
service_init ()
{
    local param=`utctx_cmd get devicedb::udspath devicedb::dbfile devicedb::dbbackup devicedb::dbtransientfile`
    eval $param
    if [ -z "$SYSCFG_devicedb_udspath" ]; then 
        syscfg set devicedb::udspath $DEFAULT_UDSPATH
        SYSCFG_devicedb_udspath=$DEFAULT_UDSPATH
    fi
    if [ -z "$SYSCFG_devicedb_dbfile" ]; then
        syscfg set devicedb::dbfile $DEFAULT_DBFILE
        SYSCFG_devicedb_dbfile=$DEFAULT_DBFILE
    fi
    if [ -z "$SYSCFG_devicedb_dbbackup" ]; then
        syscfg set devicedb::dbbackup $DEFAULT_DBBACKUP
        SYSCFG_devicedb_dbbackup=$DEFAULT_DBBACKUP
    fi
    if [ -z "$SYSCFG_devicedb_dbtransientfile" ]; then
        syscfg set devicedb::dbtransientfile $DEFAULT_DBTRANSIENT_FILE
        SYSCFG_devicedb_dbtransientfile=$DEFAULT_DBTRANSIENT_FILE
    fi
}
restore_or_create_db ()
{
    rm -rf $SYSCFG_devicedb_dbtransientfile
    if [ -e "$SYSCFG_devicedb_dbbackup" ]; then
        cp $SYSCFG_devicedb_dbbackup $SYSCFG_devicedb_dbfile
        return 0
    else
        sqlite3 $SYSCFG_devicedb_dbfile < $DEVICEDB_SCHEMA_CORE
        local schema
        for schema in $DEVICEDB_SCHEMA_DIR/*.sql; do
            sqlite3 $SYSCFG_devicedb_dbfile < $schema
        done
        return 1
    fi
}
check_db ()
{
    local needs_backup="0"
    local needs_init="0"
    mkdir -p `dirname $SYSCFG_devicedb_dbfile`
    mkdir -p `dirname $SYSCFG_devicedb_dbbackup`
    if [ ! -e "$SYSCFG_devicedb_dbfile" ]; then
        restore_or_create_db
        if [ "$?" == "1" ]; then
            needs_backup="1"
        fi
        needs_init="1"
    fi
    if [ ! -e "$SYSCFG_devicedb_dbtransientfile" ]; then
        sqlite3 $SYSCFG_devicedb_dbtransientfile < $DEVICEDB_TRANSIENT_SCHEMA
        needs_init="1"
    fi
    if [ "$needs_init" == "1" ]; then
        local output=`/usr/sbin/devicedb_admin --dbfile $SYSCFG_devicedb_dbfile --dbtransientfile $SYSCFG_devicedb_dbtransientfile --initdb`
        echo "$output" > /dev/console
        echo "$output" | grep -q "upgraded"
        if [ "$?" == "0" ]; then
            needs_backup="1"
        fi
    fi
    if [ "$needs_backup" == "1" ]; then
        cp $SYSCFG_devicedb_dbfile $SYSCFG_devicedb_dbbackup
    fi
}
service_start ()
{
    wait_till_end_state ${SERVICE_NAME}
    local STATUS=`sysevent get ${SERVICE_NAME}-status`
    if [ "$STATUS" != "started" ]; then
        sysevent set ${SERVICE_NAME}-errinfo 
        sysevent set ${SERVICE_NAME}-status starting
        echo "Starting ${SERVICE_NAME} ... "
        check_db
        $APP_NAME --daemon --udspath $SYSCFG_devicedb_udspath --dbfile $SYSCFG_devicedb_dbfile --dbtransientfile $SYSCFG_devicedb_dbtransientfile
        check_err_exit "$?" "Unable to start"
        start_cron
        if import_topodb_devices; then
            echo "TopoDB data imported; backing up DeviceDB" > /dev/console
            backup_db
        else
            echo "TopoDB data not imported" > /dev/console
        fi
        sysevent set ${SERVICE_NAME}-status started
        sysevent setoptions devicedb-backup $TUPLE_FLAG_EVENT
        sysevent setoptions devicedb-ready $TUPLE_FLAG_EVENT
        sysevent set devicedb-ready
        local pid=`pgrep $BIN_NAME`
        echo $pid > $PID_FILE
        $PMON setproc $SERVICE_NAME $BIN_NAME $PID_FILE "$PMON_RESTART_CMD"
   fi
}
service_stop ()
{
   wait_till_end_state ${SERVICE_NAME}
   local STATUS=`sysevent get ${SERVICE_NAME}-status`
   if [ "$STATUS" != "stopped" ] ; then
       sysevent set ${SERVICE_NAME}-errinfo 
       sysevent set ${SERVICE_NAME}-status stopping
       echo "Stopping ${SERVICE_NAME} ... "
       rm -rf $PID_FILE
       $PMON unsetproc $SERVICE_NAME
       stop_cron
       /usr/sbin/devicedb_admin --udspath $SYSCFG_devicedb_udspath --stopserver
       sysevent set ${SERVICE_NAME}-status stopped
   fi
}
backup_db ()
{
    echo "Backing up devicedb database ..."
    /usr/sbin/devicedb_admin --udspath $SYSCFG_devicedb_udspath --dbfile $SYSCFG_devicedb_dbfile --backupfile $SYSCFG_devicedb_dbbackup --backup
}
check_then_backup_db ()
{
    local needed=`/usr/sbin/devicedb_client -c checkBackup`
    if [ "$needed" == "Backup needed" ]; then
        backup_db
    fi
}
service_backup_db ()
{
    if [ ! -f "$DEVICEDB_PURGE_CHECK" ]; then
        if [ -e "$SYSCFG_devicedb_dbfile" ]; then
            local STATUS=`sysevent get ${SERVICE_NAME}-status`
            if [ "$STATUS" == "started" ]; then
                check_then_backup_db
            fi
        fi
    fi
}
service_purge_db ()
{
    touch $DEVICEDB_PURGE_CHECK
    rm -f $SYSCFG_devicedb_dbbackup
}
service_sys_stop ()
{
    if [ ! -f "$DEVICEDB_PURGE_CHECK" ]; then
        local STATUS=`sysevent get ${SERVICE_NAME}-status`
        if [ "$STATUS" == "started" ]; then
            echo "Backing up devicedb database ..."
            /usr/sbin/devicedb_admin --udspath $SYSCFG_devicedb_udspath --dbfile $SYSCFG_devicedb_dbfile --backupfile $SYSCFG_devicedb_dbbackup --backup
        fi
    fi
}
service_init
case "$1" in
    ${SERVICE_NAME}-start)
        service_start
        ;;
    ${SERVICE_NAME}-stop)
        service_stop
        ;;
    ${SERVICE_NAME}-restart)
        /bin/date > $DEVICEDB_RESTART_TIME
        service_stop
        service_start
        ;;
    phylink-start)
        service_start
        ;;
    backup)
        service_backup_db
        ;;
    devicedb-backup)
        service_backup_db
        ;;
    purge_db)
        service_purge_db
        ;;
    system-status)
        SYSTEM_STATUS=`sysevent get system-status`
        if [ "$SYSTEM_STATUS" == "stopping" ]; then
            service_sys_stop
        fi
        ;;
    *)
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart | phylink-start | backup | devicedb-backup | purge_db | system-status ]" > /dev/console
        exit 3
        ;;
esac
