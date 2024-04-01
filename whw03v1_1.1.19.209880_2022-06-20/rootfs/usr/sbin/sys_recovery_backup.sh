#!/bin/sh
#
# sys_backup_cmd - Assist with Node backup process.
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
NODE_UUID=`syscfg get device::uuid`
NODE_MAC_ADDR=`syscfg get device::mac_addr`
# ------------------------------------------------------------------------------------
# function usage
# ------------------------------------------------------------------------------------
usage(){
    printf "Usage:\n"
    printf "%s {option}\n" $PROGNAME
    printf "Where {option} is one of:\n"
    printf "pre_backup  : do pre_backup\n"
    printf "backup      : do backup process\n"
    printf "post_backup : do post backup process\n"
}

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
# function initialize()
# ------------------------------------------------------------------------------------
initialize(){
    # Create backup temporay directory
    if [ "$ARG" = "backup" ]; then
        if [ -d "$BACKUP_TMP_DIR" ]; then
          echo "Remove old backup directory"
          rm -rf $BACKUP_TMP_DIR
        fi

        mkdir -p $BACKUP_TMP_DIR/$NODE_ARCHIVE_NAME
    fi
}

# ------------------------------------------------------------------------------------
# function do_pre_backup
#   Description: check condition before backup
# ------------------------------------------------------------------------------------
do_pre_backup(){
    # check master mode
    master_mode_val=`syscfg get smart_mode::mode`
    if [ "$master_mode_val" != "2" ] ; then
        echo "It's not master mode. Exit"
        exit 3
    fi
    exit 0
}

# ------------------------------------------------------------------------------------
# function do_post_backup
#   Description: do post backup process
# ------------------------------------------------------------------------------------
do_post_backup(){
    exit 0
}

# ------------------------------------------------------------------------------------
# function do_backup_syscfg
#   Output: /tmp/SystemRestore/node_archive/syscfg.json
#   Description: Save current syscfg into JSON format
# ------------------------------------------------------------------------------------
do_backup_syscfg(){
    echo "Do backup syscfg"
    echo "{" > $BACKUP_TMP_DIR/$NODE_ARCHIVE_NAME/syscfg.json
    # get syscfg list | printinto format "key":"value", | remove last line | remove last ','
    syscfg show | awk -F= '{print "\"" $1"\":"  "\""$2"\","}' | sed '$ d' | sed '$s/.$//' >> $BACKUP_TMP_DIR/$NODE_ARCHIVE_NAME/syscfg.json
    echo "}" >> $BACKUP_TMP_DIR/$NODE_ARCHIVE_NAME/syscfg.json
}

# ------------------------------------------------------------------------------------
# function do_backup_devicedb
#   Output: /tmp/SystemRestore/node_archive/devicedb.db
#   Description: copy devicedb to archive later
# ------------------------------------------------------------------------------------
do_backup_devicedb(){
    # stop device db
    echo "Stop devicedb"
    is_devicedb_enable=0
    local_devdb_status=`sysevent get devicedb-status`
    if [ "$local_devdb_status" = "started" ];
    then
        /etc/init.d/service_devicedb.sh devicedb-stop
        is_devicedb_enable=1
    fi

    echo "Do backup devicedb"
    if [ -f /tmp/devicedb/devicedb.db ];
    then
        cp /tmp/devicedb/devicedb.db $BACKUP_TMP_DIR/$NODE_ARCHIVE_NAME/devicedb.db
        error_exit $?
    fi

    # start device db
    if [ "$is_devicedb_enable" = "1" ];
    then
        echo "Start devicedb"
        local_devdb_status=`sysevent get devicedb-status`
        if [ "$local_devdb_status" = "stopped" ];
        then
            /etc/init.d/service_devicedb.sh devicedb-start
        fi
    fi

}

# ------------------------------------------------------------------------------------
# function do_backup_files
#   Description: backup files base on the recent list
# ------------------------------------------------------------------------------------
do_backup_files(){
    echo "Do backup system files"
}

# ------------------------------------------------------------------------------------
# function do_create_manifest
#   Description: create manifest file
# ------------------------------------------------------------------------------------
do_create_manifest(){
    echo "Do create manifest files"
    manifest_file_name=$BACKUP_TMP_DIR/$MANIFEST_NAME
    date_val=`date`
    md5sum_val=`$MD5SUM $BACKUP_TMP_DIR/$NODE_ARCHIVE_NAME.tar.gz | cut -d ' ' -f 1`
    tmp_file_list="$BACKUP_TMP_DIR/files_tmp.txt"

    touch $tmp_file_list
    if [ -f $BACKUP_TMP_DIR/$NODE_ARCHIVE_NAME/syscfg.json ];
    then
        echo \"syscfg.json\":\"$SYSCFG_DAT\" >> $tmp_file_list
    fi

    if [ -f $BACKUP_TMP_DIR/$NODE_ARCHIVE_NAME/devicedb.db ];
    then
        echo ,\"devicedb.db\":\"$DEVICEDB_DB\" >> $tmp_file_list
    fi

    var_file_list=`cat $tmp_file_list`
    # File Manifest
cat <<EOF > $manifest_file_name
{
"uuid":"$NODE_UUID",
"mac":"$NODE_MAC_ADDR",
"create":"$date_val",
"md5sum":"$md5sum_val",
"files":{
$var_file_list
}
}
EOF
    if [ -f $tmp_file_list ];
    then
        rm -f $tmp_file_list
    fi

}

# ------------------------------------------------------------------------------------
# function do_compress
#   Output: create node_archive.tar.gz and SystemRestore.tar.gz
#   Description:
# ------------------------------------------------------------------------------------
do_compress(){
    echo "Do compress"
    # 1. Compress node_archive.tar.gz
    cd $BACKUP_TMP_DIR/
    $TAR czf $NODE_ARCHIVE_NAME.tar.gz $NODE_ARCHIVE_NAME/
    error_exit $?

    # 2. create manifest file
    do_create_manifest

    rm -rf $NODE_ARCHIVE_NAME
    cd -

    # 3. compress SystemRestore.tar.gz
    cd /tmp
    $TAR czf $SYSTEM_RESTORE_ARCHIVE_NAME.tar.gz $SYSTEM_RESTORE_ARCHIVE_NAME/
    cp $SYSTEM_RESTORE_ARCHIVE_NAME.tar.gz /var/config/
    rm $SYSTEM_RESTORE_ARCHIVE_NAME.tar.gz
    rm -rf $BACKUP_TMP_DIR
    cd -
}

# ------------------------------------------------------------------------------------
# function main program
# ------------------------------------------------------------------------------------

case $ARG in
    pre_backup)
        echo "pre_backup process"
        do_pre_backup
        exit 0
    ;;
    backup)
        echo "backup process"
        initialize
        do_backup_syscfg
        do_backup_devicedb
        do_backup_files
        do_compress
        exit 0
    ;;
    post_backup)
        echo "post_backup process"
        do_post_backup
        exit 0
    ;;
    *)
        echo "Usage: $PROGNAME [pre_backup|backup|post_backup]" >&2
        exit 3
    ;;
esac
