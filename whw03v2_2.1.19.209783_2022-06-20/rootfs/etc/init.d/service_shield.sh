#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="shield"
NAMESPACE=$SERVICE_NAME
TEMP_DIR="/tmp/shn"
SHIELD_ROOT_DIR="$TEMP_DIR/bin"
TM_STARTUP_SCRIPT="setup_linksys.sh"
TM_CONFIG_DIR="/tmp/var/config/tmshn"
SIG_FILE="rule.trf"
SIG_SCHEMA_FILE="rule_schema.trf"
SIG_META_DATA_FILE="meta_en-US.dat"
VIRT_PATCH=0x00000004   # Network protection
WRS_SEC=0x00000020      # Malicious website detection
ANOMALY=0x00000040      # Anomaly detection
TRS_FLAG=0x00001000     # Phase 2 features main flag (always set)
PC_SETTINGS_FLAGS=0xc0b
DPI_SETTINGS_FLAGS=0x1c6f 
dfc_debug="0"
dfc_enabled="1"
dfc_pc_enabled="1"
dfc_shield_config="/var/config/shield_json.cfg"
dfc_tmp_shield_config="/tmp/shield_json.cfg"
dfc_shield_config_version="1"
dfc_shield_www_redirect="http://myrouter.local/ui/dynamic/internet-down.html"       #user-blocked.html
dfc_max_allowed_url_string="32"
dfc_max_allowed_urls="232"
dfc_threat_detection_enabled="1"
dfc_malwebsite_detection_enabled="1"
SHIELD_CONF_FILE="`syscfg get shield::config_path`"
SHIELD_TEMP_CONF_FILE="`syscfg get shield::temp_config_path`"
SHIELD_JSON_FILE="$SHIELD_ROOT_DIR/shield.config.json"
SHIELD_RETRY_START_CRON="/etc/cron/cron.everyminute/shield_retry_start.sh"
SHIELD_LICENSE_CHECKER_CRON="/etc/cron/cron.daily/shield_license_checker.sh"
SHIELD_GET_SIGNATURE_CRON="/etc/cron/cron.weekly/shield_get_signature_files.sh"
SHIELD_UPLOAD_LOGS_CRON="/etc/cron/cron.hourly/shield_upload_threat_logs.sh"
syscfg_safe_set_default() {
    if [ "`syscfg get $1`" == "" ] ; then
        syscfg set "$1" "$2"
    fi
}
configure_pc_guardian() {
    echo "shield: notifying olympus parental control to be `syscfg get parental_control_enabled`" > /dev/console
    sysevent set guardian-configured
}
restore_pc_guardian_disable_shield() {
    SYSCFG_shield_pc=`syscfg get shield::pc_enabled`
    SYSCFG_olympus_pc=`syscfg get parental_control_enabled`
    echo "shield: restoring olympus parental control, state from $SYSCFG_olympus_pc to $SYSCFG_shield_pc" > /dev/console
    syscfg set parental_control_enabled $SYSCFG_shield_pc
    sysevent set guardian-configured
    echo "disabling shield service..." > /dev/console
    syscfg set ${NAMESPACE}::enabled 0
    echo "changing subscription status to inactive"
    sysevent set shield::subscription_status "inactive"
    if [ -f $SHIELD_RETRY_START_CRON ];then
        rm -f $SHIELD_RETRY_START_CRON
    fi
}
configure_dpi_settings() {
    local flags=$DPI_SETTINGS_FLAGS 
    if [ "`syscfg get shield::pc_enabled`" != "1" ]; then
        flags=$(( $flags & $(( ~$PC_SETTINGS_FLAGS )) ))
    fi
    if [ "`syscfg get shield::threat_detection_enabled`" != "1" ]; then
        flags=$(( $flags & $(( ~$VIRT_PATCH )) & $(( ~$ANOMALY )) ))
    fi
    if [ "`syscfg get shield::malwebsite_detection_enabled`" == "1" ] ; then
        echo 1 > /proc/bw_wrs_log_flag  # log blocked URLs (exclude 'Accept')
        echo 1 > /proc/bw_wrs_log       # log only malicious website URLs -- not blocked category URLs
    else # Clear the WRS setting flag
        flags=$(( $flags & $(( ~$WRS_SEC )) ))
    fi
    printf "Shield: Setting DPI configuration flags = 0x%x\n" $flags > /dev/console
    echo $(printf "%x" $flags) > /proc/bw_dpi_conf
}
service_init ()
{
    if [ "`syscfg get smart_mode::mode`" != "2" ] ; then
        echo "$SERVICE_NAME will not run on non-master units"
        exit 1
    fi
    timezone=`sysevent get TZ`
    if [ -z $timezone ];then
        timezone=`syscfg get TZ`
    fi
    export TZ=$timezone
    if [ "`syscfg get shield::license_id`" == "" ]; then
        if [ "`syscfg get ${NAMESPACE}::enabled`" == "1" ] ; then
            echo "disabing shield: you do not have a license ID, please subscribe to the service first." > /dev/console
            restore_pc_guardian_disable_shield
            service_stop
            echo "shield service exiting..." > /dev/console
            sysevent set shield::subscription_status "inactive"
            exit 0
        fi
    fi
    if [ "`syscfg get shield::config_version`" == "" ] ; then
        syscfg set shield::config_version $dfc_shield_config_version
    fi
    if [ "`syscfg get shield::max_allowed_url_string`" == "" ] ; then
        syscfg set shield::max_allowed_url_string $dfc_max_allowed_url_string
    fi
    if [ "`syscfg get shield::max_allowed_urls`" == "" ] ; then
        syscfg set shield::max_allowed_urls $dfc_max_allowed_urls
    fi
    if [ "`syscfg get shield::config_path`" == "" ] ; then
        syscfg set shield::config_path $dfc_shield_config
    fi
    if [ "`syscfg get shield::temp_config_path`" == "" ] ; then
        syscfg set shield::temp_config_path $dfc_tmp_shield_config
    fi
    if [ "`syscfg get shield::pc_enabled`" == "" ] ; then
        syscfg set shield::pc_enabled $dfc_pc_enabled
    fi
    if [ "`syscfg get shield::threat_detection_enabled`" == "" ] ; then
        syscfg set shield::threat_detection_enabled $dfc_threat_detection_enabled
    fi
    if [ "`syscfg get shield::malwebsite_detection_enabled`" == "" ] ; then
        syscfg set shield::malwebsite_detection_enabled $dfc_malwebsite_detection_enabled
    fi
    if [ "`syscfg get shield::license_id`" != "" ]; then
        pc_enabled=$(syscfg get shield::pc_enabled)
        td_enabled=$(syscfg get shield::threat_detection_enabled)
        mwd_enabled=$(syscfg get shield::malwebsite_detection_enabled)
        syscfg set ${NAMESPACE}::enabled $(( $pc_enabled | $td_enabled | $mwd_enabled ))
    fi
    if [ ! -d "$TEMP_DIR/bin" ] ; then
        echo "installing TrendMicro for Nodes package to $TEMP_DIR" >> /dev/console
        mkdir -p $TEMP_DIR/
        cp -a /usr/bin/tm/* $TEMP_DIR/
        chmod +x $TEMP_DIR/bin/tdts_ctrl
        chmod +x $TEMP_DIR/bin/$TM_STARTUP_SCRIPT
        for km in /usr/bin/tm/bin/*.ko;do
            mod_name=`basename $km`
            rm $TEMP_DIR/bin/$mod_name
            ln -s /usr/bin/tm/bin/$mod_name $TEMP_DIR/bin/
        done
        BIGFILES="wse_agent dcd shn_ctrl shn_scip wred sample.bin tdts_ctrl"
        for bf in $BIGFILES;do
            rm -f $TEMP_DIR/bin/$bf && ln -s /usr/bin/tm/bin/$bf $TEMP_DIR/bin/$bf
        done
        chmod +x $TEMP_DIR/bin/*.so
        echo 2 > /proc/sys/vm/drop_caches
        rm -rf $TEMP_DIR/bin/sib.conf
        rm -rf $TEMP_DIR/bin/wbl.conf
        rm -rf $TEMP_DIR/bin/wred.conf
        if [ -f $TM_CONFIG_DIR/$SIG_FILE ]; then
            cp -f $TM_CONFIG_DIR/$SIG_FILE $SHIELD_ROOT_DIR
            cp -f $TM_CONFIG_DIR/$SIG_META_DATA_FILE $SHIELD_ROOT_DIR
        fi
    fi
}
service_start ()
{
    if [ "`syscfg get ${NAMESPACE}::enabled`" == "1" ] ; then
        echo "$SERVICE_NAME enabled..."
    else
        echo "$SERVICE_NAME disabled in syscfg"
        sysevent set ${SERVICE_NAME}-status stopped
        exit 1
    fi
    wait_till_end_state ${SERVICE_NAME}
    cd /usr/bin/tm/bin && ./shn_ctrl -a get_all_user | grep "^ipv4 : " | cut -d " " -f3 | while read line; do conntrack -D -s $line -f ipv4 > /dev/null; conntrack -D -d $line -f ipv4 > /dev/null;  done
    STATUS=`sysevent get ${SERVICE_NAME}-status`
    if [ $STATUS != "started" ];then
        configure_pc_guardian
        echo "$SERVICE_NAME starting" >> /dev/console
        sysevent set ${SERVICE_NAME}-status starting
        parse_shield_json_file
        cd $SHIELD_ROOT_DIR && ./$TM_STARTUP_SCRIPT start
        check_err $? "Couldnt handle start"
        sysevent set shield::logging_starttime $(date +%s)
        configure_dpi_settings
        if [ ! $(sysevent get shield::last_signature_check) ]; then
            shield_get_signature_files &
        fi
        local OUR_MAC=$(syscfg get device::mac_addr)
        local MAC1=$(echo $OUR_MAC | awk 'BEGIN{FS=":"} {print $6}')
        local MAC2=$(echo $OUR_MAC | awk 'BEGIN{FS=":"} {print $5}')
        RANDOM=$(($((0x$MAC1)) * $((0x$MAC2))))
        local delay=$(($RANDOM % 60))
        echo -e "#!/bin/sh\n(sleep $delay && shield_get_signature_files)&" > $SHIELD_GET_SIGNATURE_CRON
        chmod +x $SHIELD_GET_SIGNATURE_CRON
        echo -e "#!/bin/sh\n(sleep $delay && shield_upload_threat_logs)&" > $SHIELD_UPLOAD_LOGS_CRON
        chmod +x $SHIELD_UPLOAD_LOGS_CRON
    else
        echo "${SERVICE_NAME} is already started" > /dev/console
    fi
}
parse_shield_json_file()
{
    if [ -f "$SHIELD_CONF_FILE" ] ; then
        echo "parsing shield json config file" >> /dev/console
        cp $SHIELD_CONF_FILE $SHIELD_JSON_FILE
        cd $SHIELD_ROOT_DIR && ./config_parser $SHIELD_JSON_FILE
    else
        if [ -f $SHIELD_JSON_FILE ];then
            cd $SHIELD_ROOT_DIR && ./config_parser $SHIELD_JSON_FILE
        fi
        echo "could not find configuration file for shield service"
    fi
}
reload_shield_config_files()
{
    if [ "`sysevent get ${SERVICE_NAME}-status`" != "started" ];then
        return
    fi
    echo "Current TZ is $TZ" > /dev/console
    echo "Setting SIB config - Automatic Time Zone..." >> /dev/console
    $SHIELD_ROOT_DIR/shn_ctrl -a set_sib_conf -t
    echo "running $SHIELD_ROOT_DIR/shn_ctrl -a set_sib_conf -f $SHIELD_ROOT_DIR/sib.conf" >> /dev/console
    $SHIELD_ROOT_DIR/shn_ctrl -a set_sib_conf -f $SHIELD_ROOT_DIR/sib.conf
    echo "result $?" >> /dev/console
    echo "running $SHIELD_ROOT_DIR/shn_ctrl -a set_wred_conf -f $SHIELD_ROOT_DIR/wred.conf" >> /dev/console
    $SHIELD_ROOT_DIR/shn_ctrl -a set_wred_conf -f $SHIELD_ROOT_DIR/wred.conf
    echo "result $?" >> /dev/console
    echo "running $SHIELD_ROOT_DIR/shn_ctrl -a set_wbl -f $SHIELD_ROOT_DIR/wbl.conf" >> /dev/console
    $SHIELD_ROOT_DIR/shn_ctrl -a set_wbl -f $SHIELD_ROOT_DIR/wbl.conf
    echo "result $?" >> /dev/console
}
service_stop ()
{
    echo "$SERVICE_NAME stopping" >> /dev/console
    sysevent set ${SERVICE_NAME}-status stopping
    if [ -f /etc/cron/cron.daily/shield_license_checker.sh ];then
        rm -f /etc/cron/cron.daily/shield_license_checker.sh
    fi
    rm -f $SHIELD_GET_SIGNATURE_CRON
    rm -f $SHIELD_UPLOAD_LOGS_CRON
    cd $SHIELD_ROOT_DIR/ && ./$TM_STARTUP_SCRIPT stop
    sleep 2
    sysevent set ${SERVICE_NAME}-status stopped
    ulog ${SERVICE_NAME} status "now stopped"
    echo "${SERVICE_NAME} is now stopped" > /dev/console
}
echo "service ${SERVICE_NAME} is called with '$1'" > /dev/console
if [ "`sysevent get shield::subscription_status`" != "inactive" ] ; then
    if [ "`syscfg get ${SERVICE_NAME}::enabled`" == "0" ] ; then
        sysevent set shield::subscription_status "inactive"
    fi
    if [ "`syscfg get ${SERVICE_NAME}::license_id`" == "" ] ; then
        sysevent set shield::subscription_status "inactive"
    fi
fi
service_init
case "$1" in
    ${SERVICE_NAME}-start)
        service_stop
        service_start
        ;;
    ${SERVICE_NAME}-stop)
        service_stop
        ;;
    ${SERVICE_NAME}-restart)
        service_stop
        service_start
        ;;
    wan-started)
        if [ "`syscfg get shield::no_wan_restart`" == "1" ] ; then
            echo "not restarting shield service for WAN restart" >> /dev/console
        else
            service_stop
            service_start
        fi
        ;;
    lan-started)
        if [ "`sysevent get wan-status`" = "started" ] ; then
            service_stop
            service_start
        fi
        ;;
    shield::license_id_changed)
        service_stop
        if [ "`syscfg get shield::preserve_license_id`" != "1" ] ; then
            echo "license id change removing license file at /tmp/var/config/tmshn/license.key" >> /dev/console
            logger "license id change removing license file at /tmp/var/config/tmshn/license.key"
            rm -rf /tmp/var/config/tmshn/license.key
        fi
        service_start
        ;;
    shield::subscription_status)
        if [ "`sysevent get shield::subscription_status`" == "active" ] ; then
            echo "Shield license Activated"
            echo "Installing shield license checker" >> /dev/console
            cp /usr/bin/tm/bin/shield_license_checker.sh $SHIELD_LICENSE_CHECKER_CRON
            chmod +x $SHIELD_LICENSE_CHECKER_CRON
            rm -f $SHIELD_RETRY_START_CRON
            sysevent set ${SERVICE_NAME}-status started
        else
            echo "Shield license Not Activated. license id = `syscfg get shield::license_id`."  > /dev/console
            rm -f $SHIELD_LICENSE_CHECKER_CRON
            if [ "`syscfg get shield::license_id`" != "" ]; then
                cp /usr/bin/tm/bin/shield_retry_start.sh $SHIELD_RETRY_START_CRON
                chmod +x $SHIELD_RETRY_START_CRON
            fi
            service_stop
        fi
        ;;
    shield::config_changed)
        echo "received shield::config_changed event" >> /dev/console
        [ -f $SHIELD_TEMP_CONF_FILE ] && cp $SHIELD_TEMP_CONF_FILE $SHIELD_CONF_FILE
        parse_shield_json_file
        shield_backupconfig &
        if [ `syscfg get ${SERVICE_NAME}::enabled` != "1" ];then
            service_stop
            echo "shield is not enabled - exiting" >> /dev/console
            exit 0
        fi
        if [ "`syscfg get shield::keep_fastpath_tables`" != "1" ] ; then
            echo "clearing current fastpath ECM tables" >> /dev/console
            logger "clearing current fastpath ECM tables"
            echo 1 > /sys/kernel/debug/ecm/ecm_db/defunct_all
        fi
        SE_status=`sysevent get ${SERVICE_NAME}-status`
        if [ "$SE_status" = "started" ];then
            echo "applying shield configuration to engine" >> /dev/console
            reload_shield_config_files
            configure_dpi_settings
        fi
        if [ "$SE_status" = "stopped" -o "$SE_status" = "stopping" ];then
            echo "starting shield service" > /dev/console
            service_start
        fi
        ;;
    shield::signature_file_changed)
        cd $SHIELD_ROOT_DIR
        echo "Configuring DPI Engine with signature files ($SIG_FILE, $SIG_SCHEMA_FILE)" > /dev/console
        ./tdts_ctrl --op signature_load -1 $SIG_FILE -2 $SIG_SCHEMA_FILE
        sleep 2
        echo "Extract Signature meta data and push to UDB..." > /dev/console
        ./shn_ctrl -a set_meta_data -R $SIG_META_DATA_FILE
        ;;
    TZ)
        echo "reloading shield configuration files because TZ changed" > /dev/console
        reload_shield_config_files
        ;;
    shield::license_error)
        if [ "`syscfg get shield::license_id`" != "" ]; then
            echo "shield license ID is invalid or expired, clearing license ID..." > /dev/console
            syscfg unset shield::license_id
            restore_pc_guardian_disable_shield
            service_stop
        fi
        ;;
    shield::cron_retry)
        if [ `syscfg get ${SERVICE_NAME}::enabled` == "1" ];then
            service_stop
            service_start
        else
            echo "ignoring shield::cron_retry signal because service is disabled"
            if [ -f "$SHIELD_RETRY_START_CRON" ] ; then
                echo "removing $SHIELD_RETRY_START_CRON"
                rm -rf $SHIELD_RETRY_START_CRON
            fi
        fi
        ;;
    *)
        echo "error : $1 unknown" > /dev/console
        echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
        exit 3
        ;;
esac
