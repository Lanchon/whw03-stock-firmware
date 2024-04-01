#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
US_CH_LIST_2G="1,2,3,4,5,6,7,8,9,10,11"
US_CH_LIST_5G="36,40,44,48,149,153,157,161,165"
CA_CH_LIST_2G="1,2,3,4,5,6,7,8,9,10,11"
CA_CH_LIST_5G="36,40,44,48,149,153,157,161,165"
EU_CH_LIST_2G="1,2,3,4,5,6,7,8,9,10,11,12,13"
EU_CH_LIST_5G="36,40,44,48"
EU_CH_LIST_5GH="100,104,108,112,116,120,124,128,132,136,140"
AP_CH_LIST_2G="1,2,3,4,5,6,7,8,9,10,11,12,13"
AP_CH_LIST_5G="36,40,44,48,149,153,157,161,165"
AU_CH_LIST_2G="1,2,3,4,5,6,7,8,9,10,11,12,13"
AU_CH_LIST_5G="36,40,44,48,149,153,157,161,165"
AH_CH_LIST_2G="1,2,3,4,5,6,7,8,9,10,11,12,13"
AH_CH_LIST_5G="36,40,44,48,149,153,157,161,165"
NEED_RESTORE=FALSE
US_WL0_CH_WIDTHS="0,20"
US_WL0_CH_0="0,1,2,3,4,5,6,7,8,9,10,11"
US_WL0_CH_20="0,1,2,3,4,5,6,7,8,9,10,11"
US_WL1_CH_WIDTHS="0,20,40"
US_WL1_CH_0="0,36,40,44,48"
US_WL1_CH_20="0,36,40,44,48"
US_WL1_CH_40="0,36,40,44,48"
US_WL1_CH_DFS_0="0,36,40,44,48,52,56,60,64"
US_WL1_CH_DFS_20="0,36,40,44,48,52,56,60,64"
US_WL1_CH_DFS_40="0,36,40,44,48,52,56,60,64"
US_WL2_CH_WIDTHS="0,20,40"
US_WL2_CH_0="0,149,153,157,161,165"
US_WL2_CH_20="0,149,153,157,161,165"
US_WL2_CH_40="0,149,153,157,161"
US_WL2_CH_DFS_0="0,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
US_WL2_CH_DFS_20="0,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
US_WL2_CH_DFS_40="0,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161"
US_5G_CH_WIDTHS="0,20,40"
US_5G_CH_0="0,36,40,44,48,149,153,157,161,165"
US_5G_CH_20="0,36,40,44,48,149,153,157,161,165"
US_5G_CH_40="0,36,40,44,48,149,153,157,161,165"
US_5G_CH_DFS="36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
US_5G_CH_DFS_0="0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
US_5G_CH_DFS_20="0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
US_5G_CH_DFS_40="0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161"
EU_WL0_CH_WIDTHS="0,20"
EU_WL0_CH_0="0,1,2,3,4,5,6,7,8,9,10,11,12,13"
EU_WL0_CH_20="0,1,2,3,4,5,6,7,8,9,10,11,12,13"
EU_WL1_CH_WIDTHS="0,20,40"
EU_WL1_CH_0="0,36,40,44,48"
EU_WL1_CH_20="0,36,40,44,48"
EU_WL1_CH_40="0,36,40,44,48"
EU_WL1_CH_DFS_0="0,36,40,44,48,52,56,60,64"
EU_WL1_CH_DFS_20="0,36,40,44,48,52,56,60,64"
EU_WL1_CH_DFS_40="0,36,40,44,48,52,56,60,64"
EU_WL2_CH_WIDTHS="0,20,40"
EU_WL2_CH_0="0,100,104,108,112,116,120,124,128,132,136,140"
EU_WL2_CH_20="0,100,104,108,112,116,120,124,128,132,136,140"
EU_WL2_CH_40="0,100,104,108,112,116,120,124,128,132,136"
AH_WL0_CH_WIDTHS="0,20"
AH_WL0_CH_0="0,1,2,3,4,5,6,7,8,9,10,11,12,13"
AH_WL0_CH_20="0,1,2,3,4,5,6,7,8,9,10,11,12,13"
AH_WL1_CH_WIDTHS="0,20,40"
AH_WL1_CH_0="0,36,40,44,48"
AH_WL1_CH_20="0,36,40,44,48"
AH_WL1_CH_40="0,36,40,44,48"
AH_WL2_CH_WIDTHS="0,20,40"
AH_WL2_CH_0="0,149,153,157,161,165"
AH_WL2_CH_20="0,149,153,157,161,165"
AH_WL2_CH_40="0,149,153,157,161"
SKU=`skuapi -g model_sku | awk -F"=" '{print $2}' | sed 's/ //g'`
PRODUCT=`echo $SKU | awk -F"-" '{print $1}'`
REGION_CODE=`skuapi -g cert_region | awk -F"=" '{print $2}' | sed 's/ //g'`
PRODUCT_NAME=$(cat /etc/product)
syscfg_set device::cert_region "$REGION_CODE"
syscfg_set device::model_base "$PRODUCT"
for i in `syscfg_get lan_wl_physical_ifnames`
do
        get_wl_index $i
        CURRENT_INDEX=$?
        CH_LIST=`syscfg_get wl"$CURRENT_INDEX"_available_channels`
        if [ -z "$CH_LIST" ]; then
			NEED_RESTORE=TRUE
			break
        fi
done
if [ "1" = "`syscfg_get wifi::multiregion_support`" -a "1" = "`syscfg_get wifi::multiregion_enable`" -a "1" = "`get_multiregion_region_validation`" ] ; then
    echo " Multi-region is supported and enabled"
    REGION_CODE=`syscfg_get wifi::multiregion_region`
    if [ "`cat /etc/product`" = "nodes" ] ; then
    	if [ -f /tmp/nodes_hw_version ] && [ "`cat /tmp/nodes_hw_version`" = "2" ] ; then
    		REGION_CODE=`syscfg_get wifi::multiregion_region`
    	else
    		if [ "$REGION_CODE" = "CN" ] ; then
    			REGION_CODE="AH" 
    		fi
    		if [ "$REGION_CODE" = "HK" ] ; then
    			REGION_CODE="CA" 
    		fi
    		if [ "$REGION_CODE" = "SG" ] ; then
    			REGION_CODE="AH" 
    		fi
    	fi
    fi
    COUNTRY=`syscfg_get wifi::multiregion_selectedcountry`
    NEED_RESTORE=TRUE
    echo " Region: $REGION_CODE, Country: $COUNTRY"
else
    echo " Multi-region is not supported or not enabled"
fi
SYSCFG_REGION_CODE=`syscfg_get device::cert_region`
if [ -z "$REGION_CODE" ]; then
	if [ "$SYSCFG_REGION_CODE" != "US" ]; then
		NEED_RESTORE=TRUE
	fi
	REGION_CODE="US"
else
	if [ "$SYSCFG_REGION_CODE" != "$REGION_CODE" ]; then
		NEED_RESTORE=TRUE
	fi
fi
if [ "1" = "`syscfg get wl1_dfs_enabled`" ] && [ "" = "`syscfg get wl1_available_channels | grep "52,56,60,64"`" -a "" = "`syscfg get wl1_available_channels | grep "100,104,108,112,116,120,124,128,132,136,140"`" ] ; then
	NEED_RESTORE=TRUE
fi
if [ "0" = "`syscfg get wl1_dfs_enabled`" ] && [ "" != "`syscfg get wl1_available_channels | grep "52,56,60,64"`" -o "" != "`syscfg get wl1_available_channels | grep "100,104,108,112,116,120,124,128,132,136,140"`" ] ; then
	NEED_RESTORE=TRUE
fi
if [ "1" = "`syscfg get wl2_dfs_enabled`" ] && [ "" = "`syscfg get wl2_available_channels | grep "52,56,60,64"`" -a "" = "`syscfg get wl2_available_channels | grep "100,104,108,112,116,120,124,128,132,136,140"`" ] ; then
	NEED_RESTORE=TRUE
fi
if [ "0" = "`syscfg get wl2_dfs_enabled`" ] && [ "" != "`syscfg get wl2_available_channels | grep "52,56,60,64"`" -o "" != "`syscfg get wl2_available_channels | grep "100,104,108,112,116,120,124,128,132,136,140"`" ] ; then
	NEED_RESTORE=TRUE
fi
if [ "TRUE" = "$NEED_RESTORE" ]; then
	echo "SKU is $SKU" > /dev/console
	case "$REGION_CODE" in
		"US")	
			syscfg_set wl0_available_channels "$US_CH_LIST_2G"
			syscfg_set wl1_available_channels "$US_CH_LIST_5G"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$US_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$US_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$US_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_WL1_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_WL1_CH_0"
				syscfg_set wl1_available_channels_20 "$US_WL1_CH_20"
				syscfg_set wl1_available_channels_40 "$US_WL1_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "$US_WL1_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_WL1_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_WL1_CH_DFS_40"
				fi
				syscfg_set wl2_supported_channel_widths "$US_WL2_CH_WIDTHS"
				syscfg_set wl2_available_channels_0 "$US_WL2_CH_0"
				syscfg_set wl2_available_channels_20 "$US_WL2_CH_20"
				syscfg_set wl2_available_channels_40 "$US_WL2_CH_40"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$US_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$US_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$US_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_5G_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_5G_CH_0"
				syscfg_set wl1_available_channels_20 "$US_5G_CH_20"
				syscfg_set wl1_available_channels_40 "$US_5G_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "$US_5G_CH_DFS"
					syscfg_set wl1_available_channels_0 "$US_5G_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_5G_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_5G_CH_DFS_40"
				fi
			fi
			syscfg_commit
			;;
		"EU")
			syscfg_set wl0_available_channels "$EU_CH_LIST_2G"
			syscfg_set wl1_available_channels "$EU_CH_LIST_5G"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				if [ -z "$wl2_available_channels" ]; then
					syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
					syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
					syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
					syscfg_set wl1_supported_channel_widths "$EU_WL1_CH_WIDTHS"
					syscfg_set wl1_available_channels "36,40,44,48"
					syscfg_set wl1_available_channels_0 "$EU_WL1_CH_0"
					syscfg_set wl1_available_channels_20 "$EU_WL1_CH_20"
					syscfg_set wl1_available_channels_40 "$EU_WL1_CH_40"
					if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
						syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
						syscfg_set wl1_available_channels_0 "$EU_WL1_CH_DFS_0"
						syscfg_set wl1_available_channels_20 "$EU_WL1_CH_DFS_20"
						syscfg_set wl1_available_channels_40 "$EU_WL1_CH_DFS_40"
					fi
					syscfg_set wl2_supported_channel_widths "$EU_WL2_CH_WIDTHS"
					syscfg_set wl2_available_channels "$EU_CH_LIST_5GH"
					syscfg_set wl2_available_channels_0 "$EU_WL2_CH_0"
					syscfg_set wl2_available_channels_20 "$EU_WL2_CH_20"
					syscfg_set wl2_available_channels_40 "$EU_WL2_CH_40"
					if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
						syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl2_available_channels_0 "0,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl2_available_channels_20 "0,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl2_available_channels_40 "0,100,104,108,112,116,120,124,128,132,136"
					fi
				fi
			fi
			if [ "$PRODUCT_NAME" = "nodes-jr" ] ; then
					syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
					syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
					syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
					syscfg_set wl1_supported_channel_widths "$EU_WL1_CH_WIDTHS"
					syscfg_set wl1_available_channels "36,40,44,48,100,104,108,112,116,120,124,128,132,136,140"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,100,104,108,112,116,120,124,128,132,136,140"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,100,104,108,112,116,120,124,128,132,136,140"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,100,104,108,112,116,120,124,128,132,136"
					if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
						syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136"
					fi
			fi
			syscfg_commit
			;;
		"AU")
			syscfg_set wl0_available_channels "$AU_CH_LIST_2G"
			syscfg_set wl1_available_channels "$AU_CH_LIST_5G"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_WL1_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_WL1_CH_0"
				syscfg_set wl1_available_channels_20 "$US_WL1_CH_20"
				syscfg_set wl1_available_channels_40 "$US_WL1_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "$US_WL1_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_WL1_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_WL1_CH_DFS_40"
				fi
				syscfg_set wl2_supported_channel_widths "$US_WL2_CH_WIDTHS"
				syscfg_set wl2_available_channels_0 "$US_WL2_CH_0"
				syscfg_set wl2_available_channels_20 "$US_WL2_CH_20"
				syscfg_set wl2_available_channels_40 "$US_WL2_CH_40"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_5G_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_5G_CH_0"
				syscfg_set wl1_available_channels_20 "$US_5G_CH_20"
				syscfg_set wl1_available_channels_40 "$US_5G_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "$US_5G_CH_DFS"
					syscfg_set wl1_available_channels_0 "$US_5G_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_5G_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_5G_CH_DFS_40"
				fi
			fi
			syscfg_commit
			;;
		"CA")
			syscfg_set wl0_available_channels "$CA_CH_LIST_2G"
			syscfg_set wl1_available_channels "$CA_CH_LIST_5G"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$US_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$US_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$US_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_WL1_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_WL1_CH_0"
				syscfg_set wl1_available_channels_20 "$US_WL1_CH_20"
				syscfg_set wl1_available_channels_40 "$US_WL1_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "$US_WL1_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_WL1_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_WL1_CH_DFS_40"
				fi
				syscfg_set wl2_supported_channel_widths "$US_WL2_CH_WIDTHS"
				syscfg_set wl2_available_channels_0 "$US_WL2_CH_0"
				syscfg_set wl2_available_channels_20 "$US_WL2_CH_20"
				syscfg_set wl2_available_channels_40 "$US_WL2_CH_40"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "0,100,104,108,112,116,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_20 "0,100,104,108,112,116,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_40 "0,100,104,108,112,116,132,136,140,149,153,157,161"
				fi
			fi
			if [ "$PRODUCT_NAME" = "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$US_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$US_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$US_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_5G_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_5G_CH_0"
				syscfg_set wl1_available_channels_20 "$US_5G_CH_20"
				syscfg_set wl1_available_channels_40 "$US_5G_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,100,104,108,112,116,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,132,136,140,149,153,157,161"
				fi
			fi
			syscfg_commit
			;;
		"AP")
			syscfg_set wl0_available_channels "$AP_CH_LIST_2G"
			syscfg_set wl1_available_channels "$AP_CH_LIST_5G"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_WL1_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_WL1_CH_0"
				syscfg_set wl1_available_channels_20 "$US_WL1_CH_20"
				syscfg_set wl1_available_channels_40 "$US_WL1_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "$US_WL1_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_WL1_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_WL1_CH_DFS_40"
				fi
				syscfg_set wl2_supported_channel_widths "$US_WL2_CH_WIDTHS"
				syscfg_set wl2_available_channels_0 "$US_WL2_CH_0"
				syscfg_set wl2_available_channels_20 "$US_WL2_CH_20"
				syscfg_set wl2_available_channels_40 "$US_WL2_CH_40"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_5G_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_5G_CH_0"
				syscfg_set wl1_available_channels_20 "$US_5G_CH_20"
				syscfg_set wl1_available_channels_40 "$US_5G_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "$US_5G_CH_DFS"
					syscfg_set wl1_available_channels_0 "$US_5G_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_5G_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_5G_CH_DFS_40"
				fi
			fi
			syscfg_commit
			;;
		"AH")
			syscfg_set wl0_available_channels "1,2,3,4,5,6,7,8,9,10,11,12,13"
			syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64"
				fi
				syscfg_set wl2_supported_channel_widths "0,20,40"
				syscfg_set wl2_available_channels_0 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_20 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_40 "0,149,153,157,161"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48,149,153,157,161"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,149,153,157,161,165"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,149,153,157,161,165"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,149,153,157,161,165"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,149,153,157,161"
				fi
			fi
			syscfg_commit
			;;
		"CN")
			syscfg_set wl0_available_channels "1,2,3,4,5,6,7,8,9,10,11,12,13"
			syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64"
				fi
				syscfg_set wl2_supported_channel_widths "0,20,40"
				syscfg_set wl2_available_channels_0 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_20 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_40 "0,149,153,157,161"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48,149,153,157,161"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,149,153,157,161,165"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,149,153,157,161,165"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,149,153,157,161,165"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,149,153,157,161"
				fi
			fi
			syscfg_commit
			;;
		"IN")
			syscfg_set wl0_available_channels "1,2,3,4,5,6,7,8,9,10,11"
			syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,149,153,157,161,165"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64"
				fi
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl2_supported_channel_widths "0,20,40"
				syscfg_set wl2_available_channels_0 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_20 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_40 "0,149,153,157,161"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "0,149,153,157,161,165"
					syscfg_set wl2_available_channels_20 "0,149,153,157,161,165"
					syscfg_set wl2_available_channels_40 "0,149,153,157,161"
				fi
			fi
			if [ "$PRODUCT_NAME" = "nodes-jr" ] ; then
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,149,153,157,161,165"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,149,153,157,161,165"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,149,153,157,161,165"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,149,153,157,161"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,149,153,157,161,165"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,149,153,157,161,165"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,149,153,157,161,165"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,149,153,157,161"
				fi
			fi
			syscfg_commit
			;;
		"ID")
			syscfg_set wl0_available_channels "1,2,3,4,5,6,7,8,9,10,11,12,13"
			syscfg_set wl1_available_channels "149,153,157,161"
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "149,153,157,161"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20"
				syscfg_set wl1_available_channels_0 "0,149,153,157,161"
				syscfg_set wl1_available_channels_20 "0,149,153,157,161"
			fi
			syscfg_commit
			;;
		"SG")
			syscfg_set wl0_available_channels "1,2,3,4,5,6,7,8,9,10,11,12,13"
			syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64"
				fi
				syscfg_set wl2_supported_channel_widths "0,20,40"
				syscfg_set wl2_available_channels_0 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_20 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_40 "0,149,153,157,161"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48,149,153,157,161"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161"
				fi
			fi
			syscfg_commit
			;;
		"TH")
			syscfg_set wl0_available_channels "1,2,3,4,5,6,7,8,9,10,11,12,13"
			syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64"
				fi
				syscfg_set wl2_supported_channel_widths "0,20,40"
				syscfg_set wl2_available_channels_0 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_20 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_40 "0,149,153,157,161"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "0,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_20 "0,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_40 "0,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48,149,153,157,161"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161"
				fi
			fi
			syscfg_commit
			;;
		"JP")
			syscfg_set wl0_available_channels "$EU_CH_LIST_2G"
			syscfg_set wl1_available_channels "$EU_CH_LIST_5G"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				if [ -z "$wl2_available_channels" ]; then
					syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
					syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
					syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
					syscfg_set wl1_supported_channel_widths "$EU_WL1_CH_WIDTHS"
					syscfg_set wl1_available_channels "36,40,44,48"
					syscfg_set wl1_available_channels_0 "$EU_WL1_CH_0"
					syscfg_set wl1_available_channels_20 "$EU_WL1_CH_20"
					syscfg_set wl1_available_channels_40 "$EU_WL1_CH_40"
					if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
						syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
						syscfg_set wl1_available_channels_0 "$EU_WL1_CH_DFS_0"
						syscfg_set wl1_available_channels_20 "$EU_WL1_CH_DFS_20"
						syscfg_set wl1_available_channels_40 "$EU_WL1_CH_DFS_40"
					fi
					syscfg_set wl2_supported_channel_widths "$EU_WL2_CH_WIDTHS"
					syscfg_set wl2_available_channels "$EU_CH_LIST_5GH"
					syscfg_set wl2_available_channels_0 "$EU_WL2_CH_0"
					syscfg_set wl2_available_channels_20 "$EU_WL2_CH_20"
					syscfg_set wl2_available_channels_40 "$EU_WL2_CH_40"
					if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
						syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl2_available_channels_0 "0,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl2_available_channels_20 "0,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl2_available_channels_40 "0,100,104,108,112,116,120,124,128,132,136"
					fi
				fi
			fi
			if [ "$PRODUCT_NAME" = "nodes-jr" ] ; then
					syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
					syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
					syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
					syscfg_set wl1_supported_channel_widths "$EU_WL1_CH_WIDTHS"
					syscfg_set wl1_available_channels "36,40,44,48,100,104,108,112,116,120,124,128,132,136,140"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,100,104,108,112,116,120,124,128,132,136,140"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,100,104,108,112,116,120,124,128,132,136,140"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,100,104,108,112,116,120,124,128,132,136"
					if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
						syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136"
					fi
			fi
			syscfg_commit
			;;
		"ME")
			syscfg_set wl0_available_channels "$EU_CH_LIST_2G"
			syscfg_set wl1_available_channels "$EU_CH_LIST_5G"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				if [ -z "$wl2_available_channels" ]; then
					syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
					syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
					syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
					syscfg_set wl1_supported_channel_widths "$EU_WL1_CH_WIDTHS"
					syscfg_set wl1_available_channels "36,40,44,48"
					syscfg_set wl1_available_channels_0 "$EU_WL1_CH_0"
					syscfg_set wl1_available_channels_20 "$EU_WL1_CH_20"
					syscfg_set wl1_available_channels_40 "$EU_WL1_CH_40"
					if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
						syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
						syscfg_set wl1_available_channels_0 "$EU_WL1_CH_DFS_0"
						syscfg_set wl1_available_channels_20 "$EU_WL1_CH_DFS_20"
						syscfg_set wl1_available_channels_40 "$EU_WL1_CH_DFS_40"
					fi
					syscfg_set wl2_supported_channel_widths "$EU_WL2_CH_WIDTHS"
					syscfg_set wl2_available_channels "$EU_CH_LIST_5GH"
					syscfg_set wl2_available_channels_0 "$EU_WL2_CH_0"
					syscfg_set wl2_available_channels_20 "$EU_WL2_CH_20"
					syscfg_set wl2_available_channels_40 "$EU_WL2_CH_40"
					if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
						syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl2_available_channels_0 "0,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl2_available_channels_20 "0,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl2_available_channels_40 "0,100,104,108,112,116,120,124,128,132,136"
					fi
				fi
			fi
			if [ "$PRODUCT_NAME" = "nodes-jr" ] ; then
					syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
					syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
					syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
					syscfg_set wl1_supported_channel_widths "$EU_WL1_CH_WIDTHS"
					syscfg_set wl1_available_channels "36,40,44,48,100,104,108,112,116,120,124,128,132,136,140"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,100,104,108,112,116,120,124,128,132,136,140"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,100,104,108,112,116,120,124,128,132,136,140"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,100,104,108,112,116,120,124,128,132,136"
					if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
						syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140"
						syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136"
					fi
			fi
			syscfg_commit
			;;
		"PH")
			syscfg_set wl0_available_channels "$AP_CH_LIST_2G"
			syscfg_set wl1_available_channels "$AP_CH_LIST_5G"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_WL1_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_WL1_CH_0"
				syscfg_set wl1_available_channels_20 "$US_WL1_CH_20"
				syscfg_set wl1_available_channels_40 "$US_WL1_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "$US_WL1_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_WL1_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_WL1_CH_DFS_40"
				fi
				syscfg_set wl2_supported_channel_widths "$US_WL2_CH_WIDTHS"
				syscfg_set wl2_available_channels_0 "$US_WL2_CH_0"
				syscfg_set wl2_available_channels_20 "$US_WL2_CH_20"
				syscfg_set wl2_available_channels_40 "$US_WL2_CH_40"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$EU_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$EU_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$EU_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_5G_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_5G_CH_0"
				syscfg_set wl1_available_channels_20 "$US_5G_CH_20"
				syscfg_set wl1_available_channels_40 "$US_5G_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "$US_5G_CH_DFS"
					syscfg_set wl1_available_channels_0 "$US_5G_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_5G_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_5G_CH_DFS_40"
				fi
			fi
			syscfg_commit
			;;
		"KR")
			syscfg_set wl0_available_channels "1,2,3,4,5,6,7,8,9,10,11,12,13"
			syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64"
				fi
				syscfg_set wl2_supported_channel_widths "0,20,40"
				syscfg_set wl2_available_channels_0 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_20 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_40 "0,149,153,157,161"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11,12,13"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48,149,153,157,161"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,149,153,157,161,165"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,149,153,157,161,165"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,149,153,157,161,165"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,149,153,157,161"
				fi
			fi
			syscfg_commit
			;;
		"HK")
			syscfg_set wl0_available_channels "1,2,3,4,5,6,7,8,9,10,11"
			syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64"
				fi
				syscfg_set wl2_supported_channel_widths "0,20,40"
				syscfg_set wl2_available_channels_0 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_20 "0,149,153,157,161,165"
				syscfg_set wl2_available_channels_40 "0,149,153,157,161"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "0,20"
				syscfg_set wl0_available_channels_0 "0,1,2,3,4,5,6,7,8,9,10,11"
				syscfg_set wl0_available_channels_20 "0,1,2,3,4,5,6,7,8,9,10,11"
				syscfg_set wl1_supported_channel_widths "0,20,40"
				syscfg_set wl1_available_channels_0 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_20 "0,36,40,44,48,149,153,157,161,165"
				syscfg_set wl1_available_channels_40 "0,36,40,44,48,149,153,157,161"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_0 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_20 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl1_available_channels_40 "0,36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,149,153,157,161"
				fi
			fi
			syscfg_commit
			;;
		*)
			ulog wlan status "wifi, Invalid region code, set FCC by default" > /dev/console
			syscfg_set device::cert_region "US"
			
			syscfg_set wl0_available_channels "$US_CH_LIST_2G"
			syscfg_set wl1_available_channels "$US_CH_LIST_5G"
			if [ "$PRODUCT_NAME" == "nodes" -o "$PRODUCT_NAME" == "rogue" -o "$PRODUCT_NAME" == "lion" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48"
				syscfg_set wl2_available_channels "149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$US_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$US_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$US_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_WL1_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_WL1_CH_0"
				syscfg_set wl1_available_channels_20 "$US_WL1_CH_20"
				syscfg_set wl1_available_channels_40 "$US_WL1_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ];then
					syscfg_set wl1_available_channels "36,40,44,48,52,56,60,64"
					syscfg_set wl1_available_channels_0 "$US_WL1_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_WL1_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_WL1_CH_DFS_40"
				fi
				syscfg_set wl2_supported_channel_widths "$US_WL2_CH_WIDTHS"
				syscfg_set wl2_available_channels_0 "$US_WL2_CH_0"
				syscfg_set wl2_available_channels_20 "$US_WL2_CH_20"
				syscfg_set wl2_available_channels_40 "$US_WL2_CH_40"
				if [ "1" = "`syscfg get wl2_dfs_enabled`" ] ; then
					syscfg_set wl2_available_channels "100,104,108,112,116,120,124,128,132,136,140,149,153,157,161,165"
					syscfg_set wl2_available_channels_0 "$US_WL2_CH_DFS_0"
					syscfg_set wl2_available_channels_20 "$US_WL2_CH_DFS_20"
					syscfg_set wl2_available_channels_40 "$US_WL2_CH_DFS_40"
				fi
			fi
			if [ "$PRODUCT_NAME" == "nodes-jr" ] ; then
				syscfg_set wl1_available_channels "36,40,44,48,149,153,157,161,165"
				syscfg_set wl0_supported_channel_widths "$US_WL0_CH_WIDTHS"
				syscfg_set wl0_available_channels_0 "$US_WL0_CH_0"
				syscfg_set wl0_available_channels_20 "$US_WL0_CH_20"
				syscfg_set wl1_supported_channel_widths "$US_5G_CH_WIDTHS"
				syscfg_set wl1_available_channels_0 "$US_5G_CH_0"
				syscfg_set wl1_available_channels_20 "$US_5G_CH_20"
				syscfg_set wl1_available_channels_40 "$US_5G_CH_40"
				if [ "1" = "`syscfg get wl1_dfs_enabled`" ] ; then
					syscfg_set wl1_available_channels "$US_5G_CH_DFS"
					syscfg_set wl1_available_channels_0 "$US_5G_CH_DFS_0"
					syscfg_set wl1_available_channels_20 "$US_5G_CH_DFS_20"
					syscfg_set wl1_available_channels_40 "$US_5G_CH_DFS_40"
				fi
			fi
			syscfg_commit
			;;
	esac
	ulog wlan status "wifi, Channel list and region code is set on syscfg" > /dev/console
else
	ulog wlan status "wifi, Channel list is available. Do nothing" > /dev/console
fi
