#!/bin/sh
#
# sys_restore_cmd - Assist with Node restore process.
#
# Version 0.1.0
#
ARG=$1
PROGNAME=$(basename $0)
NODE_ARCHIVE_NAME="node_archive"
SYSTEM_RESTORE_ARCHIVE_NAME="SystemRestore"
MANIFEST_NAME="Manifest.bak"
BACKUP_TMP_DIR="/tmp/$SYSTEM_RESTORE_ARCHIVE_NAME"
SYSCFG_DAT="/var/config/syscfg/syscfg.dat"
DEVICEDB_DB="/var/config/devicedb/devicedb.db"
TAR=`which tar`
MD5SUM=`which md5sum`

# Global variable

# ------------------------------------------------------------------------------------
# function error_exit
# ------------------------------------------------------------------------------------
error_exit()
{
    if [ "$1" != "0" ];
    then
        echo "Error code $1" 1>&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------------
# function usage
# ------------------------------------------------------------------------------------
usage(){
    printf "Usage:\n"
    printf "%s {option}\n" $PROGNAME
    printf "Where {option} is one of:\n"
    printf "pre_restore  : do pre_restore\n"
    printf "restore      : do restore process\n"
    printf "post_restore : do post restore process\n"
}

# ------------------------------------------------------------------------------------
# function do_pre_restore
#   Description: check condition before restore
# ------------------------------------------------------------------------------------
do_pre_restore(){
    # check master mode
    master_mode_val=`syscfg get smart_mode::mode`
    if [ "$master_mode_val" != "2" ] ; then
        echo "It's is not master mode"
        exit 3
    fi
    echo "Stop syscfg before restore"
    #sysevent set system-stop
    echo "Stop devicedb"
    local_devdb_status=`sysevent get devicedb-status`
    if [ "$local_devdb_status" = "started" ];
    then
        /etc/init.d/service_devicedb.sh devicedb-stop
    fi
    exit 0
}

# ------------------------------------------------------------------------------------
# function syscfg_restore_process
#   Description: restore syscfg
# ------------------------------------------------------------------------------------
syscfg_restore_process(){
    backup_file="/tmp/$SYSTEM_RESTORE_ARCHIVE_NAME/$NODE_ARCHIVE_NAME/syscfg.json"
    # Remove {} and "," at the end of line
    sed -i 's/.$//g' $backup_file
    # Change ":" into "="
    sed -i 's/":"/"="/g' $backup_file
    # Remove blank line ^$
    sed -i '/^$/d' $backup_file
    # Remove "
    sed -i 's/"//g' $backup_file
    # Restore file
    cp $backup_file $SYSCFG_DAT
    error_exit $?
}

# ------------------------------------------------------------------------------------
# function do_prevent_sys_commit
#   Description: prevent sys_commit after restore
# ------------------------------------------------------------------------------------
do_prevent_sys_commit(){
   # Prevent sys_commit to violate new restored syscfg
   echo "Prevent sys_commit"
   sysevent set system_stop_no_syscfg_commit 1
}

# ------------------------------------------------------------------------------------
# function do_restore
#   Description: restore processing: syscfg data, devicedb data
# ------------------------------------------------------------------------------------
do_restore(){
    backup_archive="/var/config/$SYSTEM_RESTORE_ARCHIVE_NAME.tar.gz"

    # 1. Check input
    if [ ! -f $backup_archive ];
    then
        echo "Backup archive is not existed, exit"
        exit 3
    fi

    # 2. Remove restore folder if exist.
    if [ -d $BACKUP_TMP_DIR ];
    then
	echo "Remove existing restore folder"
	rm -rf $BACKUP_TMP_DIR
    fi

    # 3. Tar the archive
    $TAR xzf $backup_archive -C /tmp
    error_exit $?

    # Change to location of archive
    cd $BACKUP_TMP_DIR

    # Extract archive of system files, syscfg.json files
    $TAR xzf $NODE_ARCHIVE_NAME.tar.gz -C ./
    error_exit $?

    # Check md5sum
    md5sum_manifest=`sed -n -e '/"md5sum"/ s/.*\: *//p ' /tmp/$SYSTEM_RESTORE_ARCHIVE_NAME/Manifest.bak | sed 's/[",]//g'`
    md5sum_file=`$MD5SUM $NODE_ARCHIVE_NAME.tar.gz | cut -d' ' -f1`
    if [ "$md5sum_manifest" != "$md5sum_file" ];
    then
        echo "Invalid md5sum"
        exit 3
    fi

    # 4. Restore syscfg, devicedb, file systems
    if [ -f /tmp/$SYSTEM_RESTORE_ARCHIVE_NAME/$NODE_ARCHIVE_NAME/syscfg.json ];
    then
			echo "restoring syscfg" >> /dev/console
			syscfg_restore_process
			error_exit $?
    fi

    # Restore devicedb
    if [ -f /tmp/$SYSTEM_RESTORE_ARCHIVE_NAME/$NODE_ARCHIVE_NAME/devicedb.db ];
    then
			echo "restoring devicedb" >> /dev/console
			cp /tmp/$SYSTEM_RESTORE_ARCHIVE_NAME/$NODE_ARCHIVE_NAME/devicedb.db $DEVICEDB_DB
			rm -f /tmp/devicedb/devicedb.db
			error_exit $?
    fi

    # Return
    cd -
    exit 0
}

# ------------------------------------------------------------------------------------
# function do_post_restore
#   Description: may reboot system
# ------------------------------------------------------------------------------------
do_post_restore(){
    # Prevent sys_commit
    do_prevent_sys_commit

    echo "Restarting system for new restored syscfg to take effect"
    # It may restart services or reboot system
    reboot
    exit 0
}

case $ARG in
    pre_restore)
    echo "Do pre_restore process"
    do_pre_restore
    ;;
    restore)
    echo "Do restore process"
    do_restore
    ;;
    post_restore)
    echo "Do post_restore process"
    do_post_restore
    ;;
    *)
        echo "Usage: $PROGNAME [pre_restore|restore|post_restore]" >&2
        exit 3
    ;;
esac
