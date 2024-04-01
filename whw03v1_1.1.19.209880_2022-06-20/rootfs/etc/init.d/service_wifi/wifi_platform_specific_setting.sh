#!/bin/sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/syscfg_api.sh
wifi_simpletap_start ()
{
	return 0
}
wifi_simpletap_stop ()
{
	return 0
}
wifi_simpletap_restart()
{
	wifi_simpletap_stop
	wifi_simpletap_start
	return 0
}
unsecure_page()
{
	return 0
}
set_driver_regioncode()
{
	PHY_IF=$1
	
	if [ "1" = "`syscfg_get wifi::multiregion_support`" -a "1" = "`syscfg_get wifi::multiregion_enable`" -a "1" = "`get_multiregion_region_validation`" ] ; then
	    REGION=`syscfg get wifi::multiregion_region`
	    if [ "`cat /etc/product`" = "nodes" ] ; then
	    	if [ -f /tmp/nodes_hw_version ] && [ "`cat /tmp/nodes_hw_version`" = "2" ] ; then
	    		REGION=`syscfg_get wifi::multiregion_region`
	    	else
	    		if [ "$REGION" = "CN" ] ; then
	    			REGION="AH" 
	    		fi
	    		if [ "$REGION" = "HK" ] ; then
	    			REGION="CA" 
	    		fi
	    		if [ "$REGION" = "SG" ] ; then
	    			REGION="AH" 
	    		fi
	    	fi
	    fi
	else
	    REGION=`syscfg_get device::cert_region`
	fi
	if [ "`cat /etc/product`" = "bronx" -o "`cat /etc/product`" = "lion" ] ; then
		case "$REGION" in
			"EU")
				REGION_CODE="826"
				;;
			"AU")
				REGION_CODE="36"
				;;
			"CA")
				REGION_CODE="124"
				;;
			"AH")
				REGION_CODE="458"
				;;
			"PH")
				REGION_CODE="608"
				;;
			"CN")
				REGION_CODE="156"
				;;
			"JP")
				REGION_CODE="392"
				;;
			"IN")
				REGION_CODE="356"
				;;
			"SG")
				REGION_CODE="702"
				;;
			"TH")
				REGION_CODE="764"
				;;
			"ME")
				REGION_CODE="826"
				;;
			"KR")
				REGION_CODE="410"
				;;
			"HK")
				REGION_CODE="344"
				;;
			*)
				REGION_CODE="840"
				;;
		esac
	else
		case "$REGION" in
			"EU")
				REGION_CODE="826"
				;;
			"AU")
				REGION_CODE="554"
				;;
			"CA")
				REGION_CODE="5001"
				;;
			"AP")
				REGION_CODE="400"
				;;
			"AH")
				if [ "`cat /etc/product`" = "nodes" ] ; then
					if [ -f /tmp/nodes_hw_version ] && [ "`cat /tmp/nodes_hw_version`" = "2" ] ; then
						REGION_CODE="458"
					else
						REGION_CODE="554"
					fi
				elif [ "`cat /etc/product`" = "nodes-jr" ] || [ "`cat /etc/product`" = "rogue" ] ; then
					REGION_CODE="458"
				else
					REGION_CODE="554"
				fi
				;;
			"PH")
				REGION_CODE="608"
				;;
			"CN")
				REGION_CODE="156"
				;;
			"JP")
				REGION_CODE="4015"
				;;
			"IN")
				REGION_CODE="356"
				;;
			"ID")
				REGION_CODE="360"
				;;
			"SG")
				REGION_CODE="702"
				;;
			"TH")
				REGION_CODE="764"
				if [ "`cat /etc/product`" = "nodes" ] ; then
					if [ -f /tmp/nodes_hw_version ] && [ "`cat /tmp/nodes_hw_version`" = "2" ] ; then
						REGION_CODE="764"
					else
						REGION_CODE="554"
					fi
				fi
				;;
			"ME")
				REGION_CODE="826"
				;;
			"KR")
				REGION_CODE="410"
				;;
			"HK")
				REGION_CODE="344"
				if [ "`cat /etc/product`" = "nodes" ] ; then
					if [ -f /tmp/nodes_hw_version ] && [ "`cat /tmp/nodes_hw_version`" != "2" ] ; then
						REGION_CODE="5001"
					fi
				fi
				;;
			*)
				REGION_CODE="843"
				;;
		esac
	fi
	INT=`get_phy_interface_name_from_vap "$PHY_IF"`
	iwpriv $INT setCountryID $REGION_CODE
	return 0
}
set_driver_dfs() 
{
	PHY_IF=$1
	SYSCFG_INDEX=`syscfg_get "$PHY_IF"_syscfg_index`
	DFS=`syscfg_get "$SYSCFG_INDEX"_dfs_enabled`
	INT=`get_phy_interface_name_from_vap "$PHY_IF"`
	if [ "1" = "`syscfg_get wifi::multiregion_support`" -a "1" = "`syscfg_get wifi::multiregion_enable`" -a "1" = "`get_multiregion_region_validation`" ] ; then
	    REGION=`syscfg get wifi::multiregion_region`
	    if [ "`cat /etc/product`" = "nodes" ] ; then
	    	if [ -f /tmp/nodes_hw_version ] && [ "`cat /tmp/nodes_hw_version`" = "2" ] ; then
	    		REGION=`syscfg_get wifi::multiregion_region`
	    	else
	    		if [ "$REGION" = "CN" ] ; then
	    			REGION="AH" 
	    		fi
	    		if [ "$REGION" = "HK" ] ; then
	    			REGION="CA" 
	    		fi
	    		if [ "$REGION" = "SG" ] ; then
	    			REGION="AH" 
	    		fi
	    	fi
	    fi
	else
	    REGION=`syscfg_get device::cert_region`
	fi
	if [ "1" = "$DFS" ] ; then
		iwpriv $INT blockdfslist 0
	else
		iwpriv $INT blockdfslist 1
	fi
	if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" ] ; then
		if [ "$SYSCFG_INDEX" = "wl1" ] ; then
			wifitool $PHY_IF block_acs_channel 0
			wifitool $PHY_IF block_acs_channel 149,153,157,161,165
		elif [ "$SYSCFG_INDEX" = "wl2" ] ; then
			wifitool $PHY_IF block_acs_channel 0
			wifitool $PHY_IF block_acs_channel 36,40,44,48
		fi
	fi
	if [ "IN" = "$REGION" -o "HK" = "$REGION" ] && [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "$SYSCFG_INDEX" = "wl0" ] ; then
		wifitool $PHY_IF block_acs_channel 0
		wifitool $PHY_IF block_acs_channel 12,13
	fi
	if [ "EU" = "$REGION" -o "ME" = "$REGION" -o "JP" = "$REGION" ] && [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] && [ "$SYSCFG_INDEX" = "wl2" ] ; then
		iwpriv $INT blockdfslist 0
		wifitool $PHY_IF block_acs_channel 0
		iwpriv $PHY_IF no_wradar 1
		wifitool $PHY_IF block_acs_channel 116,120,124,128
	fi
	if [ "`cat /etc/product`" = "nodes-jr" ] && [ "$SYSCFG_INDEX" = "wl1" ] ; then
		if [ "EU" = "$REGION" -o "ME" = "$REGION" -o "JP" = "$REGION" ] ; then
			iwpriv $INT blockdfslist 0
		fi
		wifitool $PHY_IF block_acs_channel 0
		if [ "IN" = "$REGION" ] ; then
			wifitool $PHY_IF block_acs_channel 100,104,108,112,116,120,124,128,132,136,140
		elif [ "EU" != "$REGION" -a "ME" != "$REGION" -a "JP" != "$REGION" ] ; then
			wifitool $PHY_IF block_acs_channel 52,56,60,64,100,104,108,112,116,120,124,128,132,136,140
		else
			wifitool $PHY_IF block_acs_channel 52,56,60,64,116,120,124,128
		fi
	fi
}
start_smart_connect_connection_monitor()
{
	if [ "0" != "`syscfg get smart_mode::mode`" ] && [ "1" != "`syscfg get smart_mode::mode`" ] ; then
		return 0
	fi
	PROC_PID_LINE="`ps -w | grep "smart_connect_client_monitor" | grep -v grep`"
	PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
	PROC_PID_LINE_UTIL="`ps -w | grep "smart_connect_client_utils" | grep -v grep`"
	PROC_PID_UTIL="`echo $PROC_PID_LINE_UTIL | awk '{print $1}'`"
	if [ -z "$PROC_PID" ]; then
		if [ ! -z "$PROC_PID_UTIL" ]; then
			kill -9 "$PROC_PID_UTIL"
		fi
		/etc/init.d/service_wifi/smart_connect_client_monitor.sh &
		echo "smart connect client connection monitor started"
	else
		echo "smart connect client connection monitor is already running"
	fi
}
stop_smart_connect_connection_monitor()
{
	if [ "0" != "`syscfg get smart_mode::mode`" ] && [ "1" != "`syscfg get smart_mode::mode`" ]; then
		return 0
	fi
	PROC_PID_LINE="`ps -w | grep "smart_connect_client_monitor" | grep -v grep`"
	PROC_PID="`echo $PROC_PID_LINE | awk '{print $1}'`"
	PROC_PID_LINE_UTIL="`ps -w | grep "smart_connect_client_utils" | grep -v grep`"
	PROC_PID_UTIL="`echo $PROC_PID_LINE_UTIL | awk '{print $1}'`"
	if [ ! -z "$PROC_PID_UTIL" ]; then
		kill -9 "$PROC_PID_UTIL"
	fi
	if [ ! -z "$PROC_PID" ]; then
		kill -9 "$PROC_PID"
		echo "smart connect client connection monitor stopped"
	fi
}
