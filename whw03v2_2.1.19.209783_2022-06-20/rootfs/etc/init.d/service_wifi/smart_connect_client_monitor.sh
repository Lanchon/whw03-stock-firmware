source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_sta_utils.sh
SERVICE_NAME="wifi_smart_connect_client"
WIFI_DEBUG_SETTING=`syscfg get ${SERVICE_NAME}_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
if [ "wraith" = "`cat /etc/product`" ] && [ "`sysevent get backhaul::set_intf`" = "" ] ; then
		sysevent set backhaul::set_intf "5GL"
fi
STATUS=`sysevent get wifi-status`
while [ "started" != "$STATUS" ] || [ "starting" = "$STATUS" ];
do
	STATUS=`sysevent get wifi-status`
	sleep 5
done
SETUP_AP_LIST='/tmp/setup_ap_list'
AP_LIST_SORT='/tmp/ap_list_sort'
SETUP_LAN_IFNAME=`syscfg get svap_lan_ifname`
SETUP_NETMASK=`syscfg get ldal_wl_setup_vap_netmask`
SETUP_SUBNET=`syscfg get ldal_wl_setup_vap_subnet`
SETUP_LASTERROR=""
if [ "`syscfg get smart_mode::mode`" = "1" ] && [ "" = "`sysevent get smart_connect::setup_status`" ];then
		sysevent set smart_connect::setup_status DONE
fi
if [ "`cat /etc/product`" = "wraith" ]; then
    EXTRA_INT="ath8"
else
    EXTRA_INT=""
fi
while [ 1 ]
do
	if [ "0" = "`syscfg get smart_mode::mode`" ] || [ "1" = "`syscfg get smart_mode::mode`" ] ; then
		if [ "START" = "`sysevent get smart_connect::setup_status`" ] ; then
			SETUP_CNT=0
		fi
		while [ "START" = "`sysevent get smart_connect::setup_status`" ] || [ "TEMP-AUTH" = "`sysevent get smart_connect::setup_status`" ]; 
		do 
			if [ "1" = "`sysevent get smart_connect::setup_duration_timeout`" ] ; then
				echo "smart connect client:Fail due to retry timeout, abort(`date`)" > /dev/console
				PROC_PID_LINE="`ps -w | grep "wpa_supplicant" | grep -v grep`"
				if [ ! -z "$PROC_PID_LINE" ]; then
					killall -9 wpa_supplicant
					sleep 2
				fi
 				ifconfig ath8 down
				sysevent set smart_connect::setup_status ERROR
				sysevent set smart_connect::setup_lasterror $SETUP_LASTERROR
				sysevent set smart_connect::pin_used 0
				exit
			fi
			sysevent set smart_connect::setup_status START
			/etc/init.d/service_wifi/smart_connect_client_utils.sh connect_setup_VAP $EXTRA_INT
			RET=$?
			if [ "0" = "$RET" ];then
				SETUP_LASTERROR="SETUPAP_ERROR"
				SETUP_CNT=`expr $SETUP_CNT + 1`
				continue
			fi
			
			sysevent set smart_connect::setup_status TEMP-AUTH
			/etc/init.d/service_wifi/smart_connect_client_utils.sh get_server_pre_auth
			RET=$?
			if [ "0" = "$RET" ];then
				echo "smart connect client:get pre_auth fail" > /dev/console 
				SETUP_LASTERROR="PRE-AUTH_ERROR" 
				continue
			fi
			/etc/init.d/service_wifi/smart_connect_client_utils.sh get_server_primary_info
			RET=$?
			if [ "0" = "$RET" ];then
				echo "smart connect client:successfully do pre-auth,fail do auth,change to AUTH mode " > /dev/console  
				sysevent set smart_connect::setup_status AUTH
				sysevent set smart_connect::setup_lasterror AUTH_ERROR
			else
				echo "smart connect client:change to DONE mode " > /dev/console  
				sysevent set smart_connect::setup_status DONE
				sysevent set smart_connect::setup_lasterror ""
			fi
			if [ "`syscfg get smart_connect::auth_login`" != "" ] && [ "`syscfg get smart_connect::auth_pass`" != "" ] ; then
				syscfg set smart_mode::mode 1
                [ "$(syscfg get wan_auto_detect_enable)" != "0" ] && syscfg set wan_auto_detect_enable 0
				sysevent set btsetup-update
				sysevent set wan_intf_auto_detect-stop
			fi
			killall -9 wpa_supplicant
			sleep 2
			ifconfig ath8 down
			syscfg set bridge_mode 1
			syscfg set wifi_bridge::mode 2
			sysevent set backhaul::preferred_bssid "00:00:00:00:00:00"
            sysevent set setup_dhcp_client-stop
			sysevent set forwarding-restart
			exit
		done
		if [ "AUTH" = "`sysevent get smart_connect::setup_status`" ]; then
			while [ "1" ];
			do 
				/etc/init.d/service_wifi/smart_connect_client_utils.sh connect_config_VAP $EXTRA_INT
				RET=$?
				if [ "1" = "$RET" ];then
					break
				fi
			done
			
			sysevent set smart_connect::setup_status DONE
			if [ "`cat /etc/product`" = "wraith" ] ; then
                /etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-stop ath8
		    fi
			killall -9 wpa_supplicant
			sleep 2
			ifconfig ath8 down
			sysevent set backhaul::preferred_bssid "00:00:00:00:00:00"
		fi
		if [ "DONE" = "`sysevent get smart_connect::setup_status`" ]; then
			if [ "" = "`sysevent get backhaul::status`" ] || [ "" = "`sysevent get backhaul::preferred_bssid`" ] || [ "00:00:00:00:00:00" = "`sysevent get backhaul::preferred_bssid`" ]; then
				echo "smart connect client:enter pre-reconnect mode,try to connect the user VAP" > /dev/console 
				RET=0
				MQT_BSSID="`sysevent get mqttsub::bh_bssid | tr [:upper:] [:lower:]`"
				MQT_CHAN="`sysevent get mqttsub::bh_channel`"
				if [ "" != "$MQT_BSSID" ] && [ "" != "$MQT_CHAN" ];then
					echo "smart connect client:try to connect MQTT BSSID" > /dev/console 
					/etc/init.d/service_wifi/smart_connect_client_utils.sh connect_user_VAP "$MQT_BSSID" "$MQT_CHAN" "MQTT_BACKHAUL_SELECTOR"
					RET=$?
					if [ "0" = "$RET" ];then
						echo "smart connect client:fail to connect MQTT BSSID,redo backhaul selector" > /dev/console 
					fi
				fi
				if [ "0" = "$RET" ];then
					/etc/init.d/service_wifi/smart_connect_client_utils.sh backhaul_selector
					RET=$?
					if [ "0" = "$RET" ];then
						sysevent set smart_connect::setup_status AUTH
						continue
					fi
				fi
				sysevent set backhaul::preferred_bssid "`sysevent get smart_connect::tmp_mac`"
				sysevent set backhaul::preferred_chan "`sysevent get smart_connect::tmp_chan`"
				echo "smart connect client: successfully connect to the user VAP,change to reconnect mode (`date`)" > /dev/console 
				sysevent set backhaul::status up 
				echo "smart connect client: turn up AP interfaces"		
				AP_interface_up
				/etc/init.d/service_wifi/service_wifi.sh wifi_config_changed "cli_monitor"
				Refresh_channel
				bh_repeater_refresh_and_wait "`sysevent get backhaul::intf`"
				syscfg commit
				/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-release
				/etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-renew
			fi
			if [ "up" = "`sysevent get backhaul::status`" ]; then
				CURRENT_BACKHAUL="`sysevent get backhaul::intf`"
				if [ "" = "$CURRENT_BACKHAUL" ];then
					STATUS="Not-Associated"
				else
					STATUS="`iwconfig $CURRENT_BACKHAUL | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
				fi
				
				if [ "Not-Associated" = "$STATUS" ] || [ "" = "$STATUS" ]; then
					echo "smart connect client: disconnected... (`date`)" > /dev/console
					if [ "" != "$CURRENT_BACKHAUL" ];then
						sleep 5
					fi
					if [ "" = "$CURRENT_BACKHAUL" ];then
						STATUS="Not-Associated"
					else
						STATUS="`iwconfig $CURRENT_BACKHAUL | grep Access | cut -d ':' -f 4 | tr -d '[[:space:]]'`"
					fi
					if [ "" != "$CURRENT_BACKHAUL" ] && [ "Not-Associated" != "$STATUS" ] && [ "" != "$STATUS" ]; then
						echo "smart connect client: reconnected(by driver)! (`date`)" > /dev/console 
					else	
						if [ "WPA_WRONG_KEY" = "`sysevent get backhaul::progress`" ];then
						    echo "smart connect client: Re-associate WRONG KEY,change to AUTH,relearning wifi credentials(`date`)" > /dev/console
						    sysevent set smart_connect::setup_status AUTH
						    sysevent set backhaul::progress IDLE
						fi
						echo "smart connect client: down AP interfaces"
						AP_interface_down
						sysevent set backhaul::status down
						sleep 2
						continue
					fi
				else 
					UPSTREAM_MAC="`iwconfig $CURRENT_BACKHAUL|grep "Access Point"|awk '{print $6}' | tr [:upper:] [:lower:]`"
					if [ "$UPSTREAM_MAC" != "`sysevent get backhaul::preferred_bssid | tr [:upper:] [:lower:]`" ];then
							echo "smart connect client:change upstream reouter unexpectly,backhaul::status down (`date`)" > /dev/console
							echo "smart connect client: down AP interfaces"
							AP_interface_down
							killall -9 wpa_supplicant
							sysevent set backhaul::status down
							sleep 2
							if [ "${CURRENT_BACKHAUL:0:3}" != "eth" ] ; then 
							    ifconfig $CURRENT_BACKHAUL down
							fi
							continue
					fi
				fi
			fi #backhaul::status=up
			if [ "down" = "`sysevent get backhaul::status`" ];then
				if [ "WPA_WRONG_KEY" = "`sysevent get backhaul::progress`" ];then
				    echo "smart connect client: Re-associate WRONG KEY,change to AUTH,relearning wifi credentials(`date`)" > /dev/console
				    sysevent set smart_connect::setup_status AUTH
				    sysevent set backhaul::progress IDLE
				    continue
				fi
				echo "smart connect client: still disconnected, try to reconnect to the old upstream" > /dev/console
				RC_BSSID="`sysevent get backhaul::preferred_bssid | tr [:upper:] [:lower:]`"
				RC_CHAN="`sysevent get backhaul::preferred_chan`"
				/etc/init.d/service_wifi/smart_connect_client_utils.sh connect_user_VAP "$RC_BSSID" "$RC_CHAN" "RECONNECT"
				RET=$?
				if [ "0" = "$RET" ];then
					sysevent set backhaul::preferred_bssid "00:00:00:00:00:00"
				  	if [ "" != "$CURRENT_BACKHAUL" ];then
				    	killall -9 wpa_supplicant
						sleep 2
						if [ "${CURRENT_BACKHAUL:0:3}" != "eth" ] ; then 
						    ifconfig $CURRENT_BACKHAUL down
						fi
				  	fi
				  	if [ "WPA_WRONG_KEY" = "`sysevent get backhaul::progress`" ];then
				    	echo "smart connect client: WRONG KEY,change to AUTH,relearning wifi credentials(`date`)" > /dev/console					    
						sysevent set smart_connect::setup_status AUTH
				    	sysevent set backhaul::progress IDLE
				    	continue
				  	fi
				fi
				continue	
			fi #backhaul::status=down
		fi #DONE
		sleep 5
	else
		sleep 300
	fi
done
