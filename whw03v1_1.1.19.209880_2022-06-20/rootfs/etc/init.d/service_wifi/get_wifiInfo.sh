#!/bin/sh
source /etc/sysinfo/scripts/sysinfo_function_helper.sh
if [ "`sysevent get wifi-status`" != "started" ] ; then
  PID=$!
	echo "var WifiInfo${PID} = {"
	echo "\"title\": \"WifiInfo${PID}\","
	echo "\"description\": \"WifiInfo${PID} - Wifi is Down\","
	echo "\"timestamp\": \"00:00:00.00-00-00\","
	echo "\"data\": {}"
	echo "};"
	exit 0
fi
LOGEFILE="/tmp/.errorLogForGetWifiInfo"
LEGACYHISTORY_DATA="/tmp/var/config/GetWifiInfoData_LegacyClient"
DATA_DIR="`syscfg get sysinfo::data_dir`"
if [ -z $DATA_DIR ] || [ $DATA_DIR = "" ];then
	DATA_DIR="/tmp"
fi
TMP_FILEPREFIX="${DATA_DIR}/.GetWifiINfoTMp_$$"
FILEPREFIX_IWLIST="${TMP_FILEPREFIX}_iwlistResult"
FILEPREFIX_ACSREPORT="${TMP_FILEPREFIX}_acsReport"
FILEPREFIX_TMPDATA="${TMP_FILEPREFIX}_tmpData"
FILEPREFIX_SAMEAPDATA="${TMP_FILEPREFIX}_sameAPData"
FILEPREFIX_ERRORLOG="${TMP_FILEPREFIX}_errorLog"
GLOBAL_CMD_TIMEOUT=40
GLOBAL_MULTIPLE_TASK_ENABLED=1
PrintLog()
{
echo "pid:$$--${PROCEED_NAME}: $1" >&2
}
ScanChannel_old()
{
PHYSICAL_NUM=`syscfg get lan_wl_physical_ifnames | awk '{print NF}'`
for PHY_IF in $PHYSICAL_IF_LIST; do
	WL_SYSCFG=`syscfg get ${PHY_IF}_syscfg_index`
	CHANNEL_LIST=`syscfg get ${WL_SYSCFG}_available_channels | sed 's/,/ /g' `
	CHANNEL_NUM=`syscfg get ${WL_SYSCFG}_available_channels | sed 's/,/\n/g' | wc -l `
	if [ ! -f "${FILEPREFIX_ACSREPORT}_${PHY_IF}" ];then
		iwpriv ${PHY_IF} acsmindwell 1000 && iwpriv ${PHY_IF} acsmaxdwell 1500
		wifitool ${PHY_IF} setchanlist ${CHANNEL_LIST}
		iwpriv ${PHY_IF} acsreport 1
		INDEX=1
		while true ;do
		    sleep 1
		    INDEX=`expr ${INDEX} + 1`
		    NUMBER=`wifitool ${PHY_IF} acsreport | grep ") " | wc -l`
		    if [[ ${NUMBER} -ge ${CHANNEL_NUM}  ]]; then
			break
		    fi
		    if [[ $INDEX -ge $GLOBAL_CMD_TIMEOUT ]] ; then
				PrintLog "showCAInfoForAllChannel failed to get result, time out"
			return
		    fi
		done
		wifitool ${PHY_IF} acsreport | grep ") " | tr -s " "  > ${FILEPREFIX_ACSREPORT}_${PHY_IF}
	fi
done
}
ScanChannel()
{
PHYSICAL_IF_LIST=`syscfg get lan_wl_physical_ifnames`
SCAN_LIST=""
SCAN_NUMBER=0
for PHY_IF in $PHYSICAL_IF_LIST; do
	if [ ! -f "${FILEPREFIX_ACSREPORT}_${PHY_IF}" ];then
		WL_SYSCFG=`syscfg get ${PHY_IF}_syscfg_index`
		CHANNEL_LIST=`syscfg get ${WL_SYSCFG}_available_channels | sed 's/,/ /g' `
		CHANNEL_NUM=`syscfg get ${WL_SYSCFG}_available_channels | sed 's/,/\n/g' | wc -l `
		iwpriv ${PHY_IF} acsmindwell 1000 && iwpriv ${PHY_IF} acsmaxdwell 1500
		wifitool ${PHY_IF} setchanlist ${CHANNEL_LIST}
		iwpriv ${PHY_IF} acsreport 1
		SCAN_LIST="$SCAN_LIST $PHY_IF"
		SCAN_NUMBER=`expr ${SCAN_NUMBER} + 1`
	fi
done
FINISHED_NUM=0
INDEX=1
while [ $FINISHED_NUM -lt $SCAN_NUMBER ];do
	INDEX=`expr ${INDEX} + 1`
    if [[ $INDEX -ge $GLOBAL_CMD_TIMEOUT ]] ; then
		PrintLog "ScanChannel failed to get result, time out"
		if [  "$GLOBAL_MULTIPLE_TASK_ENABLED" = "0" ];then
			sysevent set getwifiinfo-status stopped
		fi
		rm ${TMP_FILEPREFIX}* -f
		exit
    fi
	sleep 1
	for PHY_IF in $SCAN_LIST; do
		WL_SYSCFG=`syscfg get ${PHY_IF}_syscfg_index`
		CHANNEL_NUM=`syscfg get ${WL_SYSCFG}_available_channels | sed 's/,/\n/g' | wc -l `
		NUMBER=`wifitool ${PHY_IF} acsreport | grep ") " | wc -l`
		if [[ ${NUMBER} -ge ${CHANNEL_NUM}  ]]; then
			FINISHED_NUM=`expr ${FINISHED_NUM} + 1`
			SCAN_LIST=`echo $SCAN_LIST | sed "s/\<${PHY_IF}\>//"`
			wifitool ${PHY_IF} acsreport | grep ") " | tr -s " "  > ${FILEPREFIX_ACSREPORT}_${PHY_IF}
		fi
	done
done
}
PHYSICAL_IF_LIST=`syscfg get lan_wl_physical_ifnames`
ShowBasicInfo()
{
echo "var WifiBasicInfo={"
echo "\"title\": \"Basic Info\","
echo "\"description\": \"basic information about platform\","
echo "\"timestamp\": \"$(timestamp)\","
echo "\"data\": [{"
echo "  \"vendor\": \"${VENDOR}\","
echo "  \"CountryCode\": \"`syscfg get device::cert_region`\","
echo "  \"WifiDriverVer\": \"\","
echo "  \"radioNumber\": \"`syscfg get lan_wl_physical_ifnames | awk '{print NF}'`\""
echo "}]"
echo "};"
}
APNUM_SAMECHANNEL_WL0=0
APNUM_SAMECHANNEL_WL1=0
showCAInfoForAllChannel()
{
ScanChannel
echo "var WifiMyCAInfo={"
echo "\"title\": \"working channel analysis\","
echo "\"description\": \"the analysis information about channel in use \","
echo "\"timestamp\": \"$(timestamp)\","
echo "\"data\": ["
FIRST_INTERFACE=1
for PHY_IF in $PHYSICAL_IF_LIST; do
	WL_SYSCFG=`syscfg get ${PHY_IF}_syscfg_index`
	MYCHANNEL=`iwlist ${PHY_IF} channel | sed 's/)//'|awk  '/Current Frequency/ {print $5}'`
	if [ "$WL_SYSCFG" = "wl0" ] ; then
		RADIO_TYPE="2.4GHz"
	else
		RADIO_TYPE="5GHz"
	fi
	if [ "$FIRST_INTERFACE" = "1" ];then
		FIRST_INTERFACE=0
	else
echo "  ,"
	fi
echo	"  {\"interface\": \"${PHY_IF}\","
echo	"   \"type\": \"${RADIO_TYPE}\","
echo 	"   \"channel\": \"`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF} | grep "([ ]*${MYCHANNEL})" | awk -F')' '{print $1}' | awk -F '(' '{print $2}' | sed 's/ //g' `\","
echo    "   \"band\": \"`syscfg get ${WL_SYSCFG}_radio_band`\","
echo 	"   \"bssnumber\": \"`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF}  | grep "([ ]*${MYCHANNEL})"  | awk -F')' '{print $2}' | awk '{print $1}'`\","
	MAXRSSI=`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF} | grep "([ ]*${MYCHANNEL})"  | awk -F')' '{print $2}' | awk '{print $3}' | sed "s/ //g" `
	NOISE=`cat "${FILEPREFIX_ACSREPORT}_${PHY_IF}" | grep "([ ]*${MYCHANNEL})"  | awk -F')' '{print $2}' | awk '{print $4}' | sed "s/ //g"`
	POWER=`expr ${MAXRSSI} + ${NOISE} `
echo 	"   \"minrssi\": \"`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF}  | grep "([ ]*${MYCHANNEL})"  | awk -F')' '{print $2}' | awk '{print $2}'`\","
echo 	"   \"maxrssi\": \"${MAXRSSI}\","
echo 	"   \"noise\": \"${NOISE}\","
echo	"   \"power\": \"${POWER}\","
echo    "   \"txpower\": \"`iwlist ${PHY_IF} txpower | grep "Current Tx-Power" | awk -F ':' '{print $2}' | awk '{print $1}'`\","
echo 	"   \"load\": \"`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF}  | grep "([ ]*${MYCHANNEL})"  | awk -F')' '{print $2}' | awk '{print $5}'`\""
echo	"  }"
done
echo "  ]"
echo "};"
echo "var WifiAllCAInfo={"
echo "  \"title\": \"all channels' analysis\","
echo "  \"description\": \"the information about all channels\","
echo "  \"timestamp\": \"$(timestamp)\","
echo "  \"data\": ["
echo > ${FILEPREFIX_TMPDATA}
FIRST_PRINTED_CHANNEL=1
for PHY_IF in $PHYSICAL_IF_LIST; do
	WL_SYSCFG=`syscfg get ${PHY_IF}_syscfg_index`
	if [ "$WL_SYSCFG" = "wl0" ] ; then
		RADIO_TYPE="2.4GHz"
	else
		RADIO_TYPE="5GHz"
	fi
	CHANNEL_NUM=`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF} | wc -l`
	INDEX=1
	while [ ${INDEX} -le ${CHANNEL_NUM} ]
	do
		CHANNEL=`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF} | sed -n "${INDEX}p"  | awk -F')' '{print $1}' | awk -F '(' '{print $2}' | sed 's/ //g' `
		RESULT=`grep '"'^${CHANNEL}$'"' ${FILEPREFIX_TMPDATA}`
		if [ ! -z $RESULT ] ; then
			INDEX=`expr $INDEX + 1`
			continue
		else
			echo "${CHANNEL}" >> ${FILEPREFIX_TMPDATA}
		fi
		if [ "$FIRST_PRINTED_CHANNEL" = "1" ];then
			FIRST_PRINTED_CHANNEL=0
		else
			echo "  ,"
		fi
echo		"  {\"interface\": \"${PHY_IF}\","
echo		"   \"type\": \"${RADIO_TYPE}\","
echo 		"   \"channel\": \"${CHANNEL}\","
echo        "   \"band\": \"\","
echo 		"   \"bssnumber\": \"`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF}  | sed -n "${INDEX}p"  | awk -F')' '{print $2}' | awk '{print $1}'`\","
	        MAXRSSI=`cat "${FILEPREFIX_ACSREPORT}_${PHY_IF}" | sed -n "${INDEX}p" | awk -F')' '{print $2}' | awk '{print $3}' | sed "s/ //g" `
	        NOISE=`cat "${FILEPREFIX_ACSREPORT}_${PHY_IF}" | sed -n "${INDEX}p" | awk -F')' '{print $2}' | awk '{print $4}' | sed "s/ //g"`
	        POWER=`expr ${MAXRSSI} + ${NOISE} `
echo 		"    \"minrssi\": \"`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF}  | sed -n "${INDEX}p"  | awk -F')' '{print $2}' | awk '{print $2}'`\","
echo 		"    \"maxrssi\": \"${MAXRSSI}\","
echo 		"    \"noise\": \"${NOISE}\","
echo		"    \"power\": \"${POWER}\","
echo        "    \"txpower\": \"\","
echo 		"    \"load\": \"`cat ${FILEPREFIX_ACSREPORT}_${PHY_IF}  | sed -n "${INDEX}p"  | awk -F')' '{print $2}' | awk '{print $5}'`\"}"
		INDEX=`expr ${INDEX} + 1`
	done
done
echo "  ]" 
echo "};" 
}
ShowRadioInfo()
{
echo "var WifiRadioInfo={"
echo "\"title\": \"radio information\","
echo "\"description\": \"basic radio information\","
echo "\"timestamp\": \"$(timestamp)\","
PHYSICAL_NUM=`syscfg get lan_wl_physical_ifnames | awk '{print NF}'`
echo "\"number\": \"${PHYSICAL_NUM}\","
echo "\"data\": ["
INDEX=1
for PHY_IF in $PHYSICAL_IF_LIST; do
	GUEST_ENABLED="0"
	GUEST_INTERFACE=""
	GUEST_SSID=""
	GUEST_BROADCAST=""
	GUEST_CLIENTNUMBER=""
	GUEST_SECURITY=""
	GUEST_BSSID=""
	AP_NUM=1
	WL_SYSCFG=`syscfg get ${PHY_IF}_syscfg_index`
	if [ "$WL_SYSCFG" = "wl0" ] ; then
		RADIO_TYPE="2.4GHz"
		if [ "`syscfg get guest_enabled`" = "1" ] && [ "`syscfg get wl0_guest_enabled`" = "1" ]\
		   && [ `syscfg get guest_wifi_phy_ifname` = "$WL_SYSCFG" ]; then
			GUEST_INTERFACE="`syscfg get wl0_guest_vap`"
			GUEST_SSID=`syscfg get guest_ssid`
			GUEST_ENABLED="1"
			GUEST_BROADCAST="`syscfg get guest_ssid_broadcast`"
		fi
	else
		RADIO_TYPE="5GHz"
		if [ "`syscfg get guest_enabled`" = "1" ] && [ "`syscfg get ${WL_SYSCFG}_guest_enabled`" = "1" ]\
		 && [ `syscfg get ${WL_SYSCFG}_guest_wifi_phy_ifname` = "$WL_SYSCFG" ]; then
			GUEST_INTERFACE="`syscfg get ${WL_SYSCFG}_guest_vap`"
			GUEST_SSID=`syscfg get ${WL_SYSCFG}_guest_ssid`
			GUEST_ENABLED="1"
			GUEST_BROADCAST="`syscfg get ${WL_SYSCFG}_guest_ssid_broadcast`"
		fi
	fi
    if [ "$GUEST_ENABLED" = "1" ];then
		GUEST_BSSID="`ifconfig ${GUEST_INTERFACE} | grep HWaddr | awk '{print $5}'`"
		AP_NUM=`expr $AP_NUM + 1`
		GUEST_CLIENTNUMBER="`wlanconfig ${GUEST_INTERFACE} list sta | sed "1d" | wc -l`"
		GUEST_SECURITY="open"
	fi
	STA_EN="0"
	STA_MODE=""
	STA_BANDWIDTH=""
	STA_STATUS=""
	STA_BSSID=""
	STA_SSID=""
	STA_CHANNEL=""
	STA_SECURITY=""
	if [ "`syscfg get wifi_bridge::mode`" = "1" ] && [ "`syscfg get wifi_bridge::radio`" = "${RADIO_TYPE}" ];then
		if [ "${PHY_IF}" = "ath0" ];then
		    STA_EN="1"
		    STA_MODE="IEEE80211_MODE_11NG_HT40PLUS"
		    STA_BANDWIDTH="40MHz"
		elif [ "${PHY_IF}" = "ath1" ];then
		    STA_EN="1"
		    STA_MODE="IEEE80211_MODE_11AC_VHT80"
		    STA_BANDWIDTH="80MHz"
		fi
	fi
	if [ "${STA_EN}" = "1" ];then
		STA_BSSID="`syscfg get wl0_sta_mac_addr | tr -d :`"
		STA_SSID="`syscfg get wifi_bridge::ssid`"
		STA_CHANNEL="`syscfg get wifi_sta_channel`"
		STA_SECURITY="`syscfg get wifi_bridge::security_mode`"
		if [ "`sysevent get wifi_sta_up`" = "1" ];then
		    STA_STATUS="connected"
		else
			STA_STATUS="disconnected"
		fi
	fi
echo "   {\"radio\":\"${RADIO_TYPE}\","
echo "    \"channel\": \"`iwlist ${PHY_IF} channel | sed 's/)//'|awk  '/Fre/ {print $5}'`\","
echo "    \"band\": \"`syscfg get ${WL_SYSCFG}_radio_band`\","
echo "    \"biteRate\": \"`iwlist ${PHY_IF} bitrate| awk -F':' '/Current Bit Rate/ {print $2}'`\","
echo "    \"ComponentID\": \"88W8864\","
echo "    \"beamformingEnable\": \"`syscfg get ${WL_SYSCFG}_txbf_enabled`\","
echo "    \"mumimoEnable\": \"`syscfg get wifi::${WL_SYSCFG}_mumimo_enabled`\","
echo "    \"supportedChannels\": \"`syscfg get ${WL_SYSCFG}_available_channels`\","
echo "    \"supportedSecurity\": \"`syscfg get ${WL_SYSCFG}_supported_sec_types`\","
echo "    \"supportedModes\": \"`syscfg get ${WL_SYSCFG}_network_modes`\","
echo "    \"dfsEnabled\": \"`syscfg get ${WL_SYSCFG}_dfs_enabled`\","
echo "    \"sta_enabled\":\"${STA_EN}\","
echo "    \"sta_supportedSecurity\":\"`syscfg get  wifi_bridge::${WL_SYSCFG}_supported_sec_types`\","
echo "    \"sta_bssid\":\"$STA_BSSID\","
echo "    \"sta_status\":\"${STA_STATUS}\","
echo "    \"sta_ssid\":\"$STA_SSID\","
echo "    \"sta_channel\":\"$STA_CHANNEL\","
echo "    \"sta_security\":\"$STA_SECURITY\","
echo "    \"sta_mode\":\"${STA_MODE}\","
echo "    \"sta_bandwidth\":\"${STA_BANDWIDTH}\","
echo "    \"userAp_interface\": \"${PHY_IF}\","
echo "    \"userAp_ssid\": \"`syscfg get ${WL_SYSCFG}_ssid`\","
echo "    \"userAp_broadcast\": \"`syscfg get ${WL_SYSCFG}_ssid_broadcast`\","
echo "    \"userAp_bssid\": \"`ifconfig ${PHY_IF} | grep HWaddr | awk '{print $5}'`\","
echo "    \"userAp_security\": \"`syscfg get ${WL_SYSCFG}_security_mode`\","
echo "    \"userAp_mode\": \"`syscfg get ${WL_SYSCFG}_network_mode`\","
echo "    \"userAp_ClientNum\": \"`wlanconfig ${PHY_IF} list sta | sed "1d" | wc -l`\","
echo "    \"guestAp_enabled\": \"${GUEST_ENABLED}\","
echo "    \"guestAp_interface\": \"${GUEST_INTERFACE}\","
echo "    \"guestAp_ssid\": \"${GUEST_SSID}\","
echo "    \"guestAp_broadcast\": \"${GUEST_BROADCAST}\","
echo "    \"guestAp_bssid\": \"$GUEST_BSSID\","
echo "    \"guestAp_security\": \"$GUEST_SECURITY\","
echo "    \"guestAp_ClientNum\": \"$GUEST_CLIENTNUMBER\"}"
	if [ ${INDEX} -ne ${PHYSICAL_NUM} ] ; then
echo "  ,"
	fi
	INDEX=`expr $INDEX + 1`
done
echo "]};"
}
ModeToBandwidth()
{
	BANDWIDTH=""
	MODE="$1"
	case "$1" in
	    "IEEE80211_MODE_11A") 
		BANDWIDTH="20MHz";;
	    "IEEE80211_MODE_11B") 
		BANDWIDTH="20MHz";;
	    "IEEE80211_MODE_11G") 
		BANDWIDTH="20MHz";;
	    "IEEE80211_MODE_11NA_HT20") 
		BANDWIDTH="20MHz";;
	    "IEEE80211_MODE_11NG_HT20") 
		BANDWIDTH="20MHz";;
	    "IEEE80211_MODE_11NA_HT40PLUS") 
		BANDWIDTH="40MHz";;
	    "IEEE80211_MODE_11NA_HT40MINUS") 
		BANDWIDTH="40MHz";;
	    "IEEE80211_MODE_11NG_HT40PLUS") 
		BANDWIDTH="40MHz";;
	    "IEEE80211_MODE_11NG_HT40MINUS") 
		BANDWIDTH="40MHz";;
	    "IEEE80211_MODE_11NG_HT40") 
		BANDWIDTH="40MHz";;
	    "IEEE80211_MODE_11NA_HT40") 
		BANDWIDTH="40MHz";;
	    "IEEE80211_MODE_11AC_VHT20") 
		BANDWIDTH="20MHz";;
	    "IEEE80211_MODE_11AC_VHT40PLUS") 
		BANDWIDTH="40MHz";;
	    "IEEE80211_MODE_11AC_VHT40MINUS") 
		BANDWIDTH="40MHz";;
	    "IEEE80211_MODE_11AC_VHT40") 
		BANDWIDTH="40MHz";;
	    "IEEE80211_MODE_11AC_VHT80") 
		BANDWIDTH="80MHz";;
	    *)
		BANDWIDTH=""
		MODE=""
	esac
	echo "${BANDWIDTH} ${MODE}"
}
_STA_FIRSTDONE=0
TATOL_CLIENT_NUM=0
PrintClientOnInterface()
{
INTERFACE=$1
RADIO_TYPE=$2
APSSID=$3
PRINT_MODE=$4
STANUM=`wlanconfig ${INTERFACE} list sta | sed "1d" | wc -l`
if [ "${STANUM}" = "0" ] ; then
	return
fi
INDEX=1
while [ ${INDEX} -le ${STANUM} ]
do
	CNT=`expr $INDEX + 1`
	INDEX=`expr $INDEX + 1`
	MODE=`wlanconfig ${INTERFACE} list sta | sed -n ${CNT}p | sed 's/IEEE80211/\n&/' | awk NR==2'{print $1}'`
	BANDWIDTH=`ModeToBandwidth ${MODE} | awk '{print $1}'`
	if [ "${PRINT_MODE}" = "legacy" ]; then
		if [ "${MODE}" != "IEEE80211_MODE_11A" ] && [ "${MODE}" != "IEEE80211_MODE_11B" ] && [ "${MODE}" != "IEEE80211_MODE_11G" ]; then
			continue #not a legacy client
		fi
	fi
	CLIENT_RSSI="`wlanconfig ${INTERFACE} list sta | awk NR==${CNT}{'print $6'}`"
	if [ "${PRINT_MODE}" = "poor" ] && [ "$GLOBAL_POORCLIENT_SIGNAL_THRESHOLD" != "0" ]; then
		if [[ "$CLIENT_RSSI" -lt "$GLOBAL_POORCLIENT_SIGNAL_THRESHOLD"  ]]; then
			continue #this client's signal is not poor
		fi
	fi
	if [ "$_STA_FIRSTDONE" != "0" ]; then
		echo "  ,"
	fi
echo "	{\"mac\": \"`wlanconfig ${INTERFACE} list sta | awk NR==${CNT}{'print $1'}`\","
echo "	 \"type\": \"${RADIO_TYPE}\","
echo "	 \"interface\": \"${INTERFACE}\","
echo "	 \"APSSID\": \"${APSSID}\","
echo "	 \"rssi\": \"${CLIENT_RSSI}\","
echo "	 \"mode\": \"${MODE}\","
echo "	 \"rate\": \"`wlanconfig ${INTERFACE} list sta | awk NR==${CNT}{'print $5'}`\","
echo "	 \"bandwidth\": \"${BANDWIDTH}\","
echo "	 \"mumimo\": \"\","
echo "	 \"channel\": \"`wlanconfig ${INTERFACE} list sta | awk NR==${CNT}{'print $3'}`\"}"
	TATOL_CLIENT_NUM=`expr $TATOL_CLIENT_NUM + 1`
	_STA_FIRSTDONE=1
done
}
ShowClientInfo()
{
TATOL_CLIENT_NUM=0
_STA_FIRSTDONE=0
PRINT_MODE=$1
if [ "${PRINT_MODE}" = "legacy" ];then
	echo "var WifiLegacyClientInfo={"
	echo "\"title\": \"legacy wifi clients\","
	echo "\"description\": \"legacy wifi clients, for 802.11abg\","
elif [ "${PRINT_MODE}" = "poor" ] ; then 
	echo "var WifiPoorClientInfo={"
	echo "\"title\": \"poor wifi clients\","
	echo "\"description\": \"wifi clients with the signal worse than ${GLOBAL_POORCLIENT_SIGNAL_THRESHOLD}\","
else
	echo "var WifiClientInfo={"
	echo "\"title\": \"wifi clients\","
	echo "\"description\": \"all wifi clients\","
fi
echo "\"timestamp\": \"$(timestamp)\","
echo "\"data\": ["
for PHY_IF in $PHYSICAL_IF_LIST; do
	GUEST_INTERFACE=""
	GUEST_SSID=""
	AP_NUM=1
	WL_SYSCFG=`syscfg get ${PHY_IF}_syscfg_index`
	if [ "$WL_SYSCFG" = "wl0" ] ; then
		RADIO_TYPE="2.4GHz"
		if [ "`syscfg get guest_enabled`" = "1" ] && [ "`syscfg get wl0_guest_enabled`" = "1" ] && [ `syscfg get guest_wifi_phy_ifname` = "$WL_SYSCFG" ]; then
			GUEST_INTERFACE="`syscfg get wl0_guest_vap`"
			GUEST_SSID=`syscfg get guest_ssid`
			AP_NUM=`expr $AP_NUM + 1`
		fi
	else
		RADIO_TYPE="5GHz"
		if [ "`syscfg get guest_enabled`" = "1" ] && [ "`syscfg get ${WL_SYSCFG}_guest_enabled`" = "1" ] && [ `syscfg get ${WL_SYSCFG}_guest_wifi_phy_ifname` = "$WL_SYSCFG" ]; then
			GUEST_INTERFACE="`syscfg get ${WL_SYSCFG}_guest_vap`"
			GUEST_SSID=`syscfg get ${WL_SYSCFG}_guest_ssid`
			AP_NUM=`expr $AP_NUM + 1`
		fi
	fi
	SSID=`syscfg get ${WL_SYSCFG}_ssid`
	PrintClientOnInterface ${PHY_IF} ${RADIO_TYPE} ${SSID} ${PRINT_MODE}
	if [ "$AP_NUM" -gt "1" ];then
	    PrintClientOnInterface ${GUEST_INTERFACE} ${RADIO_TYPE} ${GUEST_SSID} ${PRINT_MODE}
	fi
done
echo "],"
echo "\"number\": \"${TATOL_CLIENT_NUM}\"};"
}
ShowAllClientInfo()
{
ShowClientInfo "normal"
}
ShowLegacyClientInfo()
{
if [ -f "${LEGACYHISTORY_DATA}" ]; then
	cat "${LEGACYHISTORY_DATA}" | sed '1a''var WifiLastLegacyClientInfo={' | sed '1d'
else
	touch "${LEGACYHISTORY_DATA}"
fi 
echo > "${LEGACYHISTORY_DATA}"
ShowClientInfo "legacy" | tee "${LEGACYHISTORY_DATA}"
}
ShowPoorClientInfo()
{
ShowClientInfo "poor"
}
ShowAP_Nonblocked()
{
TOTAL_CNT=0
APNUMBER=0
for PHY_IF in $PHYSICAL_IF_LIST; do
	NUM=`wlanconfig ${PHY_IF} list ap | sed "1d" | wc -l`
	APNUMBER=`expr $APNUMBER + $NUM`
done
if [ "$GLOBAL_AP_MAX" != "0" ] && [ "$APNUMBER" -gt "$GLOBAL_AP_MAX" ] ; then
	APNUMBER="$GLOBAL_AP_MAX"
fi
echo "var WifiAllAPInfo={"
echo "\"title\": \"site survey\","
echo "\"description\": \"the detail about the adjacent AP\","
echo "\"timestamp\": \"$(timestamp)\","
echo "\"data\": ["
FIRSTDONE=0
DONE2G=0
DONE5G=0
for PHY_IF in $PHYSICAL_IF_LIST; do
	APNUM=`wlanconfig ${PHY_IF} list ap | sed '1d' | wc -l `
	if [ "${APNUM}" = "0" ] ; then
		continue
	fi
	WL_SYSCFG=`syscfg get ${PHY_IF}_syscfg_index`
	if [ "$WL_SYSCFG" = "wl0" ] ; then
		RADIO_TYPE="2.4GHz"
	else
		RADIO_TYPE="5GHz"
	fi
	if [ "$RADIO_TYPE" = "2.4GHz" ] && [ "$DONE2G" = "1" ];then
		continue
	elif [ "$RADIO_TYPE" = "2.4GHz" ] && [ "$DONE2G" = "0" ];then
		DONE2G=1
	elif [ "$RADIO_TYPE" = "5GHz" ] && [ "$DONE5G" = "1" ];then
		continue
	elif [ "$RADIO_TYPE" = "5GHz" ] && [ "$DONE5G" = "0" ];then
		DONE5G=1
	fi
		
	if [ "$FIRSTDONE" = "1" ]; then
echo "  ,"
	fi	
	if [ "$FIRSTDONE" = "0" ]; then
		FIRSTDONE=1
	fi
	INDEX=1
	while [ ${INDEX} -le ${APNUM} ]
	do
		CNT=`expr $INDEX + 1`
echo "	{\"ssid\": \"`wlanconfig ${PHY_IF} list ap | awk NR==${CNT}{'print $1'}`\","
echo "	 \"bssid\": \"\","
echo "	 \"type\": \"${RADIO_TYPE}\","
echo "	 \"channel\": \"`wlanconfig ${PHY_IF} list ap | awk NR==${CNT}{'print $3'}`\","
echo "	 \"rssi\": \"`wlanconfig ${PHY_IF} list ap | awk NR==${CNT}{'print $5'} | awk -F ':' '{print $1}'`\","
echo "	 \"security\": \"\","
echo "	 \"vendor\": \"\","
echo "	 \"bandwidth\": \"\","
echo "	 \"mode\": \"\"}"
		TOTAL_CNT=`expr $TOTAL_CNT + 1`
		if [ "$GLOBAL_AP_MAX" != "0" ] && [ "$TOTAL_CNT" -ge "$GLOBAL_AP_MAX" ]; then
			break
		fi
		if [ ${INDEX} -ne ${APNUM} ] ; then
echo "  ,"
		fi
		INDEX=`expr $INDEX + 1`
	done
	if [ "$GLOBAL_AP_MAX" != "0" ] && [ "$TOTAL_CNT" -ge "$GLOBAL_AP_MAX" ]; then
		break
	fi
done
echo "],"
echo "\"number\": \"${APNUMBER}\""
echo "};"
}
ShowAP_Blocked() 
{
for PHY_IF in $PHYSICAL_IF_LIST; do
	if [ ! -f "${FILEPREFIX_IWLIST}_${PHY_IF}" ];then
	    iwlist ${PHY_IF} scan > ${FILEPREFIX_IWLIST}_${PHY_IF}
	fi
done
ROUTER_SSID_LIST=""
for VAR_IF in $PHYSICAL_IF_LIST; do
	VAR_WL_SYSCFG=`syscfg get ${VAR_IF}_syscfg_index`
	VAR_SSID=`syscfg get ${VAR_WL_SYSCFG}_ssid`
	if [ -n $VAR_SSID ] && [  `echo "$ROUTER_SSID_LIST" | grep " \<$VAR_SSID\> " | wc -l ` = "0" ];then
		ROUTER_SSID_LIST="$ROUTER_SSID_LIST $VAR_SSID "
	fi
	VAR_GUEST_SSID=""
	if [ "$VAR_WL_SYSCFG" = "wl0" ] ; then
		if [ "`syscfg get guest_enabled`" = "1" ] && [ "`syscfg get wl0_guest_enabled`" = "1" ]\
		  && [ `syscfg get guest_wifi_phy_ifname` = "$VAR_WL_SYSCFG" ]; then
			VAR_GUEST_SSID=`syscfg get guest_ssid`
		fi
	else
		if [ "`syscfg get guest_enabled`" = "1" ] && [ "`syscfg get ${VAR_WL_SYSCFG}_guest_enabled`" = "1" ]\
		   && [ `syscfg get ${VAR_WL_SYSCFG}_guest_wifi_phy_ifname` = "$VAR_WL_SYSCFG" ]; then
			VAR_GUEST_SSID=`syscfg get ${VAR_WL_SYSCFG}_guest_ssid`
		fi
	fi
	if [ "$VAR_GUEST_SSID" != "" ] && [ `echo "$ROUTER_SSID_LIST" | grep " \<$VAR_GUEST_SSID\> " | wc -l` = "0" ];then
		ROUTER_SSID_LIST="$ROUTER_SSID_LIST $VAR_GUEST_SSID "
	fi
done
echo > ${FILEPREFIX_SAMEAPDATA}
echo "var WifiAllAPInfo={"
echo "\"title\": \"site survey\","
echo "\"description\": \"the detail about the adjacent AP\","
echo "\"timestamp\": \"$(timestamp)\","
echo "\"data\": ["
TOTAL_CNT=0
FIRSTDONE=0
PRINTED_LIST=""
for PHY_IF in $PHYSICAL_IF_LIST; do
	WL_SYSCFG=`syscfg get ${PHY_IF}_syscfg_index`
	if [ "$WL_SYSCFG" = "wl0" ] ; then
		RADIO_TYPE="2.4GHz"
	else
		RADIO_TYPE="5GHz"
	fi
	ROW_LIST=`sed -n '/Cell [0-9]* - Address:/=' ${FILEPREFIX_IWLIST}_${PHY_IF}`
	APNUM=`echo $ROW_LIST | awk '{print NF}'`
	if [ "${APNUM}" = "0" ] ; then
		continue
	fi
	INDEX=1
	while [ ${INDEX} -le ${APNUM} ]
	do
		RESULTFILE="${FILEPREFIX_IWLIST}_${PHY_IF}_RESULT_"
		if [  ${INDEX} -eq $APNUM ] ; then
			STARTROWNUM=`echo $ROW_LIST | awk '{print $"'$INDEX'" }' `
			sed -n "${STARTROWNUM},$ p" ${FILEPREFIX_IWLIST}_${PHY_IF} > ${RESULTFILE}
		else
			STARTROWNUM=`echo $ROW_LIST | awk '{print $"'$INDEX'" }' `
			ENDROWNUM=`expr ${INDEX} + 1`
			ENDROWNUM=`echo $ROW_LIST | awk '{print $"'$ENDROWNUM'" }' `
			ENDROWNUM=`expr ${ENDROWNUM} - 1`
			sed -n "${STARTROWNUM},${ENDROWNUM}p" ${FILEPREFIX_IWLIST}_${PHY_IF} > ${RESULTFILE}
		fi
		SSID=` grep 'ESSID:' ${RESULTFILE} | awk -F ':' '{print $2}'`
		SSID=`echo "${SSID%?}" | sed 's/"//' `
		if [ "$SSID" = "" ]; then
			INDEX=`expr $INDEX + 1`
			continue
		fi
		BSSID=` grep ' Address: ' ${RESULTFILE} | awk -F ': ' '{print $2}'`
		if [ "$BSSID" = "" ]; then
			INDEX=`expr $INDEX + 1`
			continue
		fi
		if [ `echo "$PRINTED_LIST" | grep " \<${BSSID}=${SSID}\> " | wc -l` = "0" ]; then
			PRINTED_LIST="$PRINTED_LIST ${BSSID}=${SSID} "
		else
			INDEX=`expr $INDEX + 1`
			continue
		fi
		if [ `echo "$ROUTER_SSID_LIST" | grep " \<$SSID\> " | wc -l` = "1" ];then
			cat ${RESULTFILE} >> ${FILEPREFIX_SAMEAPDATA}
		fi
		if [ "$FIRSTDONE" = "1" ]; then
			echo 	"    ,"
		fi	
		if [ "$FIRSTDONE" = "0" ]; then
			FIRSTDONE=1
		fi
		echo "	{\"ssid\": \"${SSID}\","
		echo "	 \"bssid\": \"` grep ' Address: ' ${RESULTFILE} | awk -F ': ' '{print $2}'`\","
		echo "	 \"type\": \"${RADIO_TYPE}\","
		echo "	 \"channel\": \"` grep 'Frequency:' ${RESULTFILE} | awk -F 'Channel ' '{print $2}' | sed 's/)//'`\","
		echo "	 \"rssi\": \"`grep "Signal level=" ${RESULTFILE} | awk -F '=-' '{print $2}' | awk '{print $1}'`\","
		if [ -n "`grep 'Encryption key:on' ${RESULTFILE}`" ] ; then
		echo "	 \"security\": \"`grep "IE:" ${RESULTFILE} | sed -n 1p | awk -F '/' '{print $2}' | awk '{print $1}'`\","
		elif [ -n "`grep 'Encryption key:off' ${RESULTFILE}`"  ] ; then
		echo "	 \"security\": \"off\","
		else
		echo "	 \"security\": \"\","
		fi
		echo "	 \"vendor\": \"\","
		MODE=`grep "phy_mode=" ${RESULTFILE} | awk -F 'phy_mode=' '{print $2}'`
		echo "	 \"bandwidth\": \"`ModeToBandwidth ${MODE} | awk '{print $1}'`\","
		echo "	 \"mode\": \"${MODE}\"}"
		TOTAL_CNT=`expr $TOTAL_CNT + 1`
		if [ "$GLOBAL_AP_MAX" != "0" ] && [ "$TOTAL_CNT" -ge "$GLOBAL_AP_MAX" ]; then
			break
		fi
		INDEX=`expr $INDEX + 1`
	done
	if [ "$GLOBAL_AP_MAX" != "0" ] && [ "$TOTAL_CNT" -ge "$GLOBAL_AP_MAX" ]; then
		break
	fi
done
echo "],"
echo "\"number\": \"${TOTAL_CNT}\""
echo "};"
echo "var WifiSameAPInfo={"
echo " \"title\": \"Same AP information\","
echo " \"description\": \"the information about AP owning the same SSID name with our router's\","
echo " \"timestamp\": \"$(timestamp)\","
echo " \"data\": ["
NUMBER=0
PRINTED_LIST=""
INDEX=1
FIRSTDONE=0
ROW_LIST=`sed -n '/Cell [0-9]* - Address:/=' ${FILEPREFIX_SAMEAPDATA}`
APNUM=`echo $ROW_LIST | awk '{print NF}'`
while [ ${INDEX} -le ${APNUM} ]
do
	RESULTFILE="${FILEPREFIX_SAMEAPDATA}_RESULT_"
	if [  ${INDEX} -eq $APNUM ] ; then
		STARTROWNUM=`echo $ROW_LIST | awk '{print $"'$INDEX'" }' `
		sed -n "${STARTROWNUM},$ p" ${FILEPREFIX_SAMEAPDATA} > ${RESULTFILE}
	else
		STARTROWNUM=`echo $ROW_LIST | awk '{print $"'$INDEX'" }' `
		ENDROWNUM=`expr ${INDEX} + 1`
		ENDROWNUM=`echo $ROW_LIST | awk '{print $"'$ENDROWNUM'" }' `
		ENDROWNUM=`expr ${ENDROWNUM} - 1`
		sed -n "${STARTROWNUM},${ENDROWNUM}p" ${FILEPREFIX_SAMEAPDATA} > ${RESULTFILE}
	fi
	
	SSID=` grep 'ESSID:' ${RESULTFILE} | awk -F ':' '{print $2}'`
	SSID=`echo "${SSID%?}" | sed 's/"//' `
	if [ "$SSID" = "" ]; then
		INDEX=`expr $INDEX + 1`
		continue
	fi
	BSSID=` grep ' Address: ' ${RESULTFILE} | awk -F ': ' '{print $2}'`
	if [ "$BSSID" = "" ]; then
		INDEX=`expr $INDEX + 1`
		continue
	fi
	if [ `echo "$PRINTED_LIST" | grep " \<${BSSID}=${SSID}\> " | wc -l` = "0" ]; then
		PRINTED_LIST="$PRINTED_LIST ${BSSID}=${SSID} "
	else
		INDEX=`expr $INDEX + 1`
		continue
	fi
	if [ "$FIRSTDONE" = "1" ]; then
	    echo "  ,"
	fi
	RADIO_TYPE="2.4GHz"
	if [ `grep 'Frequency:5' ${RESULTFILE} | wc -l` != "0" ];then
		RADIO_TYPE="5GHz"
	fi 
	echo "   {\"ssid\": \"${SSID}\","
	echo "   \"bssid\": \"`grep ' Address: ' ${RESULTFILE} | awk -F ': ' '{print $2}'`\","
	echo "   \"type\": \"${RADIO_TYPE}\","
	echo "   \"channel\": \"`grep 'Frequency:' ${RESULTFILE} | awk -F 'Channel ' '{print $2}' | sed 's/)//'`\","
	echo "   \"rssi\": \"`grep "Signal level=" ${RESULTFILE} | awk -F '=-' '{print $2}' | awk '{print $1}'`\","
	if [ -n "`grep 'Encryption key:on' ${RESULTFILE}`" ] ; then
		echo "   \"security\": \"`grep "IE:" ${RESULTFILE} | sed -n 1p | awk -F '/' '{print $2}' | awk '{print $1}'`\","
	elif [ -n "`grep 'Encryption key:off' ${RESULTFILE}`"  ] ; then
		echo "   \"security\": \"off\","
	else
		echo "   \"security\": \"\","
	fi
	echo "   \"vendor\": \"\","
	MODE=`grep "phy_mode=" ${RESULTFILE} | awk -F 'phy_mode=' '{print $2}'`
	echo "   \"bandwidth\": \"`ModeToBandwidth ${MODE} | awk '{print $1}'`\","
	echo "   \"mode\": \"${MODE}\"}"
	if [ "$FIRSTDONE" = "0" ]; then
		FIRSTDONE=1
	fi
	INDEX=`expr ${INDEX} + 1`
	NUMBER=`expr ${NUMBER} + 1`
	if [ "$WL_SYSCFG" = "wl0" ];then
		APNUM_SAMECHANNEL_WL0=`expr ${APNUM_SAMECHANNEL_WL0} + 1`
	elif [ "$WL_SYSCFG" = "wl1" ]; then
		APNUM_SAMECHANNEL_WL1=`expr ${APNUM_SAMECHANNEL_WL1} + 1`
	fi
done
echo "  ],"
echo " \"number\": \"${NUMBER}\""
echo "};"
}
PROCEED_NAME=`basename $0`
SignalHandler()
{
PrintLog "get termial signal,clear and exit"
if [  "$GLOBAL_MULTIPLE_TASK_ENABLED" = "0" ];then
	sysevent set getwifiinfo-status stopped
fi
rm ${TMP_FILEPREFIX}* -f
}
PrintUsage()
{
echo "$PROCEED_NAME [args args ...]"
echo "    args=\"basic\",        show basic wifi information"
echo "    args=\"ca\",           show channel analysis information"
echo "    args=\"radio\",        show radio information"
echo "    args=\"client\",       show all wifi clients' information"
echo "    args=\"poorclient\",   show wifi clients' with poor signal"
echo "    args=\"legacyclient\", show wifi legacy clients"
echo "    args=\"ap\",           show ap information"
echo "    args=\"all\",          show all information"
echo "    args=\"clean\""
}
trap 'SignalHandler;exit' 1 2 3 15
exec 2>$LOGEFILE
VENDOR=`syscfg get hardware_vendor_name | sed s/[[:space:]]//g`
if [ "$VENDOR" != "QCA" ]; then
	PrintLog "error,this script is for QCA, but syscfg get ${VENDOR}"
	exit
fi
GLOBAL_SECTION_EN_CA="0"
GLOBAL_SECTION_EN_BASIC="0"
GLOBAL_SECTION_EN_RADIO="0"
GLOBAL_SECTION_EN_CLIENT="0"
GLOBAL_SECTION_EN_AP="0"
GLOBAL_SECTION_EN_LEGACYCLIENT="0"
GLOBAL_SECTION_EN_POORCLIENT="0"
GLOBAL_AP_MODE="blocked"
GLOBAL_AP_MAX="200"
GLOBAL_POORCLIENT_SIGNAL_THRESHOLD="0" 
GLOBAL_VAR=""
if [ $# -ge 1 ]; then
	GLOBAL_VAR="$@"
elif [ $QUERY_STRING != "" ];then
	GLOBAL_VAR=`echo $QUERY_STRING | sed 's/&/ /g'`		
fi
if [ "$GLOBAL_VAR" != "" ]; then
	for arg in $GLOBAL_VAR
	do
	    case $arg in 
		"ca") 
			GLOBAL_SECTION_EN_CA="1";;
		"basic") 
			GLOBAL_SECTION_EN_BASIC="1";;
		"radio") 
			GLOBAL_SECTION_EN_RADIO="1";;
		"client") 
			GLOBAL_SECTION_EN_CLIENT="1";;
		"poorclient")
			GLOBAL_SECTION_EN_POORCLIENT="1";;
		"legacyclient") 
			GLOBAL_SECTION_EN_LEGACYCLIENT="1";;
		"ap")
			GLOBAL_SECTION_EN_AP="1";;
		"all")
			GLOBAL_SECTION_EN_CA="1"
			GLOBAL_SECTION_EN_BASIC="1"
			GLOBAL_SECTION_EN_LEGACYCLIENT="1"
			GLOBAL_SECTION_EN_RADIO="1"
			GLOBAL_SECTION_EN_POORCLIENT="1"
			GLOBAL_SECTION_EN_CLIENT="1"
			GLOBAL_SECTION_EN_AP="1";;
		"clean")
			killall $PROCEED_NAME >/dev/null 2>&1
			if [  "$GLOBAL_MULTIPLE_TASK_ENABLED" = "0" ];then
				sysevent set getwifiinfo-status stopped
			fi
			rm ${LEGACYHISTORY_DATA} -rf
			exit;;
		*)
			FLAG_USAGE=1
			NUM=`echo "$arg" | awk -F 'apmax=' '{print $2}'`
			if [ -n "${NUM}" ]; then
				GLOBAL_AP_MAX="$NUM"
				FLAG_USAGE=0
			fi
			MODE=`echo "$arg" | awk -F 'mode=' '{print $2}'`
			if [ -n "${MODE}" ]; then
				if [ "$MODE" = "nonblocked" ]; then
				    GLOBAL_AP_MODE="nonblocked"
					FLAG_USAGE=0
				else
				    GLOBAL_AP_MODE="blocked"
					FLAG_USAGE=0
				fi
			fi
			SIGNAL_THRESHOLD=`echo "$arg" | awk -F 'signalthreshold=' '{print $2}'`
			if [ -n "${SIGNAL_THRESHOLD}" ]; then
				GLOBAL_POORCLIENT_SIGNAL_THRESHOLD="$SIGNAL_THRESHOLD"
				FLAG_USAGE=0
			fi
			if [  "$FLAG_USAGE" = "1"  ];then
				PrintUsage
				exit
			fi
			;;
	    esac
	done
else
	exit
fi
if [  "$GLOBAL_MULTIPLE_TASK_ENABLED" = "0" ];then
	GETWIFIINFO_STATUS=`sysevent get getwifiinfo-status`
	if [ "${GETWIFIINFO_STATUS}" != "started" ];then
		sysevent set getwifiinfo-status started
	else
		PrintLog "other proceeds is working"
		exit
	fi
fi
rm ${TMP_FILEPREFIX}* -f
if [ "${GLOBAL_SECTION_EN_BASIC}" = "1" ]; then
	ShowBasicInfo
fi
if [ "${GLOBAL_SECTION_EN_RADIO}" = "1" ]; then
	ShowRadioInfo
fi
if [ "${GLOBAL_SECTION_EN_CLIENT}" = "1" ]; then
	ShowAllClientInfo
fi
if [ "${GLOBAL_SECTION_EN_LEGACYCLIENT}" = "1" ]; then
	ShowLegacyClientInfo
fi
if [ "${GLOBAL_SECTION_EN_POORCLIENT}" = "1" ]; then
	ShowPoorClientInfo
fi
if [ "${GLOBAL_SECTION_EN_CA}" = "1" ]; then
	showCAInfoForAllChannel
fi
if [ "${GLOBAL_SECTION_EN_AP}" = "1" ]; then
	if [ "${GLOBAL_AP_MODE}" = "blocked" ]; then
	    ShowAP_Blocked
	else
	    ShowAP_Nonblocked
	fi
fi
rm ${TMP_FILEPREFIX}* -f
if [  "$GLOBAL_MULTIPLE_TASK_ENABLED" = "0" ];then
	sysevent set getwifiinfo-status stopped
fi
exit
