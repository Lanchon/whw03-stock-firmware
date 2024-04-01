#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/syscfg_api.sh
DEBUG_SETTING=`syscfg_get smart_connect_debug`
DEBUG() 
{
    [ "$DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
while [ 1 ]
do   
    PORT_1_STATUS=`sysevent get ETH::port_1_status`
    PORT_2_STATUS=`sysevent get ETH::port_2_status`
    PORT_3_STATUS=`sysevent get ETH::port_3_status`
    PORT_4_STATUS=`sysevent get ETH::port_4_status`
    PORT_5_STATUS=`sysevent get ETH::port_5_status`
    if [ "$PORT_1_STATUS" != "up" ] && [ "$PORT_2_STATUS" != "up" ] && [ "$PORT_3_STATUS" != "up" ] && [ "$PORT_4_STATUS" != "up" ] && [ "$PORT_5_STATUS" != "up" ] ;then
        exit
    fi
    if [ "1" = "`syscfg get smart_mode::mode`" ] && [ "`syscfg get bridge_mode`" = "1" ] ; then
        exit    
    fi	
    
    if [ "`sysevent get smart_connect::setup_mode`" != "wired" ] ; then
        exit
    fi
    
    if [ "READY" = "`sysevent get smart_connect::setup_status`" -o "ERROR" = "`sysevent get smart_connect::setup_status`" ] && [ "1" = "`sysevent get smart_connect::setup_duration_timeout`" ] ; then
        echo "smart connect client:Fail at setup_duration_timeout, abort(`date`)" > /dev/console 
        sysevent set smart_connect::setup_status ERROR
        exit
    fi
    if [ "$(sysevent get setup_default_router)" = "" ] ; then
        sleep 2
        /etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew
    fi
    if [ "$(sysevent get setup_default_router)" = "" ] && [ "$(sysevent get default_router)" = "" ]; then
        if [ "1" = "`sysevent get smart_connect::setup_duration_timeout`" ]; then
            sysevent set smart_connect::setup_status ERROR
            ulog smart_connect status "smart connect client: Timeout. Both default_router and setup_default_router are null.(wired)."
            exit
        fi
        continue
    fi
    while [ "START" = "`sysevent get smart_connect::setup_status`" ] || [ "TEMP-AUTH" = "`sysevent get smart_connect::setup_status`" ]; 
    do
        if [ "1" = "`sysevent get smart_connect::setup_duration_timeout`" ] ; then
            echo "smart connect client:Fail at setup_duration_timeout, abort(`date`)" > /dev/console 
            sysevent set smart_connect::setup_status ERROR
            exit
        fi
        
	    if [ "$PORT_1_STATUS" != "up" ] && [ "$PORT_2_STATUS" != "up" ] && [ "$PORT_3_STATUS" != "up" ] && [ "$PORT_4_STATUS" != "up" ] && [ "$PORT_5_STATUS" != "up" ] ;then
		exit
	    fi
        
        echo "smart connect client: Try to get configVAP credentials by Wired" > /dev/console 
        ulog smart_connect status "smart connect client: Try to get configVAP credentials by Wired"
	    /etc/init.d/service_wifi/smart_connect_client_utils.sh get_server_config_info wired
	    RET_VAL=$?
	    while [ "$RET_VAL" = 1 ] ; 
	    do
	    if [ "$PORT_1_STATUS" != "up" ] && [ "$PORT_2_STATUS" != "up" ] && [ "$PORT_3_STATUS" != "up" ] && [ "$PORT_4_STATUS" != "up" ] && [ "$PORT_5_STATUS" != "up" ] ;then
		exit
	    fi
	        if [ "1" = "`sysevent get smart_connect::setup_duration_timeout`" ] ; then
	            echo "smart connect client:Fail at setup_duration_timeout, abort(`date`)" > /dev/console 
	            sysevent set smart_connect::setup_status ERROR
	            exit
	        fi	        
	        echo "ERROR on smartconnect protocol setup phase by wired! will retry..." > /dev/console 
	        sleep 2
	        /etc/init.d/service_wifi/smart_connect_client_utils.sh get_server_config_info wired
	        RET_VAL=$?
	    done
	    
		sysevent set smart_connect::setup_status TEMP-AUTH
	    /etc/init.d/service_wifi/smart_connect_client_utils.sh get_server_pre_auth wired
	    
	    echo "smart connect client: Get ConfigVAP credentials by Wired successful" > /dev/console 
		ulog smart_connect status "smart connect client: Get ConfigVAP credentials by Wired successful"	
	    sysevent set smart_connect::setup_status AUTH
	    if [ "`syscfg get smart_connect::auth_login`" != "" ] && [ "`syscfg get smart_connect::auth_pass`" != "" ] ; then
			syscfg set smart_mode::mode 1
			sysevent set btsetup-update
	    fi
    done
    while [ "AUTH" = "`sysevent get smart_connect::setup_status`" ]; 
    do
	    if [ "$PORT_1_STATUS" != "up" ] && [ "$PORT_2_STATUS" != "up" ] && [ "$PORT_3_STATUS" != "up" ] && [ "$PORT_4_STATUS" != "up" ] && [ "$PORT_5_STATUS" != "up" ] ;then
		exit
	    fi
		echo "smart connect client: Try to get UserVAP credentials by Wired" > /dev/console 
		ulog smart_connect status "smart connect client: Try to get UserVAP credentials by Wired"
		        
        /etc/init.d/service_wifi/smart_connect_client_utils.sh get_server_primary_info wired
        sysevent set smart_connect::setup_status DONE
		echo "smart connect client: Get UserVAP credentials by Wired successful" > /dev/console 
		ulog smart_connect status "smart connect client: Get UserVAP credentials by Wired successful"
		syscfg set bridge_mode 1
		syscfg set wifi_bridge::mode 2
		[ "$(syscfg get wan_auto_detect_enable)" != "0" ] && syscfg set wan_auto_detect_enable 0
		sysevent set wan_intf_auto_detect-stop
		sleep 2
		syscfg commit
		sysevent set forwarding-restart
    done
    
    if [ "DONE" = "`sysevent get smart_connect::setup_status`" ] || [ "" = "`sysevent get smart_connect::setup_status`" ] ; then
        exit
    fi
done
