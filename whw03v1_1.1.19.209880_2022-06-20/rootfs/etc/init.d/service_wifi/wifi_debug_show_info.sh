#!/bin/sh
source /etc/init.d/syscfg_api.sh
STA_ENABLED=`syscfg get wifi_bridge::mode`
if [ "1" = "$STA_ENABLED" ]; then
	echo "syscfg parameters for sta:"
	echo "`syscfg show | grep wifi_sta`"
	echo "`syscfg show | grep wifi_bridge`"
	echo "`syscfg show | grep lan_wl_physical`"
	STA_IF=`syscfg get wifi_sta_vir_if`
	LINK_STATUS=`iwpriv $STA_IF getlinkstatus | awk -F":" '{print $2}'`
	if [ "1" = "$LINK_STATUS" ]; then
		echo "`iwconfig $STA_IF`"
	else
		echo "STA is not connected!"
	fi
fi
echo "========================== Wi-Fi Development Debug Information =========================="
echo "channel information:"
iwlist ath0 channel
iwlist ath1 channel
if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "dallas" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
	iwlist ath10 channel
fi
echo "Site Survey on 2.4GHz:"
echo "`iwlist ath0 scan`"
echo ""
sleep 2
echo "Site Survey on 5GHz:"
echo "`iwlist ath1 scan`"
echo ""
echo "========================== End Of Wi-Fi Development Debug Information =========================="
echo ""
