#! /bin/sh

SHN_DIR="/tmp/shn/bin"

echo "---------- start of shield sysinfo -----------"
echo ">> shield syscfgs"
syscfg show | grep shield
echo ">> shield sysevents"
echo "shield service status: `sysevent get shield-status`"
echo "shield subscription status: `sysevent get shield::subscription_status`"
echo "shield license enabled date: `sysevent get shield::license_validation_success_date`"
echo "shield license disabled date: `sysevent get shield::license_validation_failed_date`"
echo ""
echo "-- RAW SHIELD CONFIG --"
if [ -f /var/config/shield_json.cfg ] ; then
	/usr/bin/jpp /var/config/shield_json.cfg
fi
echo ""
echo ">> TM related info"
echo ">>> sib.conf"
cat $SHN_DIR/sib.conf
echo ""
echo ">>> wred.conf"
cat $SHN_DIR/wred.conf
echo ">>> wbl.conf"
cat $SHN_DIR/wbl.conf
if [ -f /proc/bw_dpi_conf ];then 
    echo ">>> tm shn service is running and bw_dpi_conf is:"
    echo "-- BW_DPI_CONF --"
    cat /proc/bw_dpi_conf
    echo
    cwd=$(pwd)
    cd $SHN_DIR
    echo "-- GET_WRS_URL --"
    ./shn_ctrl -a get_wrs_url | sed "s/[^ \t]*\.[^ \t]*//g" | tail -100
    echo ""
    echo "-- GET_VP --"
    ./shn_ctrl -a get_vp | tail -160
    echo ""
    echo "-- GET_ANOMALY --"
    ./shn_ctrl -a get_anomaly | tail -100
    echo ""
    echo ">>> current sib status"
    ./shn_ctrl -a get_sib_status
    cd $cwd
fi
echo "--------- end of shield sysinfo --------------"
echo ""
