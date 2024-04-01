#!/bin/sh
RefreshWirelessNetworks()
{
	if [ "`sysevent get collision_scan`" = "running" ];then
		echo "Another collision scan is running" > /dev/console
		return
	fi
	if [ "`cat /etc/product`" != "nodes" ] ; then
		sysevent set collision_detect FAIL
		echo "support by nodes only" > /dev/console
		return
	fi
	if [ "`sysevent get wifi-status`" != "started" ];then
		sysevent set collision_detect FAIL
		echo "WiFi service is not ready" > /dev/console
		return
	fi
	echo "Start SSID collision detection for $SCAN_SSID  (`date`)" > /dev/console
	sysevent set collision_scan running
	mkdir -p /tmp/wlan/
	SYSCFG_REGION_CODE=`syscfg get device::cert_region`
	if [ "$SYSCFG_REGION_CODE" = "US" ] || [ "$SYSCFG_REGION_CODE" = "CA" ] ; then
		exttool --scan --interface wifi0 --mindwell 100 --maxdwell 200 --resttime 100 --scanmode 1 --chcount 11 1 2 3 4 5 6 7 8 9 10 11 
	elif [ "$SYSCFG_REGION_CODE" = "EU" ] || [ "$SYSCFG_REGION_CODE" = "AP" ] || [ "$SYSCFG_REGION_CODE" = "AU" ] || [ "$SYSCFG_REGION_CODE" = "AH" ] ;then
		exttool --scan --interface wifi0 --mindwell 100 --maxdwell 200 --resttime 100 --scanmode 1 --chcount 13 1 2 3 4 5 6 7 8 9 10 11 12 13
	fi
	if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`sysevent get backhaul::intf`" = "ath9" ]; then
		acfg_tool acfg_offchan_rx ath9 36 100
		acfg_tool acfg_offchan_rx ath9 40 100
		acfg_tool acfg_offchan_rx ath9 44 100
		acfg_tool acfg_offchan_rx ath9 48 100
	else
		exttool --scan --interface wifi1 --mindwell 100 --maxdwell 200 --resttime 100 --scanmode 1 --chcount 4 36 40 44 48
	fi	
	if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`sysevent get backhaul::intf`" = "ath11" ]; then
		if [ "$SYSCFG_REGION_CODE" = "US" ] || [ "$SYSCFG_REGION_CODE" = "CA" ] || [ "$SYSCFG_REGION_CODE" = "AP" ] || [ "$SYSCFG_REGION_CODE" = "AU" ] || [ "$SYSCFG_REGION_CODE" = "AH" ] ; then
			acfg_tool acfg_offchan_rx ath11 149 100
			acfg_tool acfg_offchan_rx ath11 153 100
			acfg_tool acfg_offchan_rx ath11 157 100
			acfg_tool acfg_offchan_rx ath11 161 100
			acfg_tool acfg_offchan_rx ath11 165 100
		elif [ "$SYSCFG_REGION_CODE" = "EU" ] ;then
			acfg_tool acfg_offchan_rx ath11 100 100
			acfg_tool acfg_offchan_rx ath11 104 100
			acfg_tool acfg_offchan_rx ath11 108 100
			acfg_tool acfg_offchan_rx ath11 112 100
			acfg_tool acfg_offchan_rx ath11 116 100
			acfg_tool acfg_offchan_rx ath11 120 100
			acfg_tool acfg_offchan_rx ath11 124 100
			acfg_tool acfg_offchan_rx ath11 128 100
			acfg_tool acfg_offchan_rx ath11 132 100
			acfg_tool acfg_offchan_rx ath11 136 100
			acfg_tool acfg_offchan_rx ath11 140 100
		fi
	else
		if [ "$SYSCFG_REGION_CODE" = "US" ] || [ "$SYSCFG_REGION_CODE" = "CA" ] || [ "$SYSCFG_REGION_CODE" = "AP" ] || [ "$SYSCFG_REGION_CODE" = "AU" ] || [ "$SYSCFG_REGION_CODE" = "AH" ] ; then
			exttool --scan --interface wifi2 --mindwell 100 --maxdwell 200 --resttime 100 --scanmode 1 --chcount 5 149 153 157 161 165
		elif [ "$SYSCFG_REGION_CODE" = "EU" ] ;then
			exttool --scan --interface wifi2 --mindwell 100 --maxdwell 200 --resttime 100 --scanmode 1 --chcount 11 100 104 108 112 116 120 124 128 132 136 140
		fi
	fi
	sleep 5
	iwlist ath0 scanning last > /tmp/wlan/scanned_2.4G.txt
	if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`sysevent get backhaul::intf`" = "ath9" ]; then
		iwlist ath9 scanning last > /tmp/wlan/scanned_5GL.txt
	else
		iwlist ath1 scanning last > /tmp/wlan/scanned_5GL.txt
	fi
	if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "`sysevent get backhaul::intf`" = "ath11" ]; then
		iwlist ath11 scanning last > /tmp/wlan/scanned_5GH.txt
	else
		iwlist ath10 scanning last > /tmp/wlan/scanned_5GH.txt
	fi
	sysevent set collision_scan done
	echo "SSID collision detection finished(`date`)" > /dev/console
}
CheckForSSIDCollision()
{
	SCAN_SSID=$1
	if [ "$SCAN_SSID " = " " ];then
		sysevent set collision_detect FAIL
		echo "Need target SSID to detect" > /dev/console
		return
	fi
	if [ "`sysevent get collision_scan`" = "running" ];then
		echo "RefreshWirelessNetworks is not finish!" > /dev/console
		return
	fi
	SCAN_SSID=ESSID:\"$SCAN_SSID\"
	RET="`cat /tmp/wlan/scanned_2.4G.txt | grep $SCAN_SSID`"
	if [ "" != "$RET" ];then
		echo "collision happen on 2.4G" > /dev/console
		sysevent set collision_detect TRUE
		echo "SSID collision detection finished SUC (`date`)" > /dev/console
		return
	fi
	RET="`cat /tmp/wlan/scanned_5GL.txt | grep -w "$SCAN_SSID"`"
	if [ "" != "$RET" ];then
		echo "collision happen on 5GL" > /dev/console
		sysevent set collision_detect TRUE
		echo "SSID collision detection finished SUC(`date`)" > /dev/console
		return
	fi
	RET="`cat /tmp/wlan/scanned_5GH.txt | grep -w "$SCAN_SSID"`"
	if [ "" != "$RET" ];then
		echo "collision happen on 5GH" > /dev/console
		sysevent set collision_detect TRUE
		echo "SSID collision detection finished SUC(`date`)" > /dev/console
		return
	fi
	sysevent set collision_detect FALSE
}
print_help()
{
	echo "Usage: /etc/init.d/service_wifi/collision_scan.sh <option>" > /dev/console 
	echo "valid options:" > /dev/console 
	echo "	RefreshWirelessNetworks" > /dev/console 
	echo "	CheckForSSIDCollision" > /dev/console 
	exit
}
case "`echo $1`" in
	"RefreshWirelessNetworks")
		RefreshWirelessNetworks
		;;
	"CheckForSSIDCollision")
		CheckForSSIDCollision "$2"
		;;
	*)
		print_help
esac
