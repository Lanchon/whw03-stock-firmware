#!/bin/sh

########################################################
# sysinfo.sh ----> /www/sysinfo.cgi
#
# When adding new debug information into this script file
# do the following:
#    1)  create your debug script <your_debug_script.sh>
#    2)  call your debug script in this sysinfo.sh script
#        using the format:
#         if [ -f <your debug script> ]; then
#             ./<your debug script.cgi>
#         fi
########################################################
get_cgi_val () {
  if [ "$1" == "" ] ; then
    echo ""
    return
  fi
  form_var="$1"
  var_value=`echo "$QUERY_STRING" | sed -n "s/^.*$form_var=\([^&]*\).*$/\1/p" | sed "s/%20/ /g" | sed "s/+/ /g" | sed "s/%2F/\//g"`
  echo -n "$var_value"
}

# This script assumes that its working directory is /www when it runs.  
# Not everyone runs it from /www directory, so we need to make sure it is in /www
# before doing anything
cd /www

# get interface names from sysevent
wan_ifname=`sysevent get wan_ifname`

SECTION=$(get_cgi_val "section")

echo Content-Type: text/plain
echo ""
echo "page generated on `date`"
echo ""
echo "UpTime:"
echo "`uptime`"
echo ""

if [ "$SECTION" == "" ] || [ "$SECTION" == "fwinfo" ] ; then
# echo "section=fwinfo"
# MFG DATA / Firmware information
echo "Firmware Version: `cat /etc/version`"
echo "Firmware Builddate: `cat /etc/builddate`"
echo "Product.type: `cat /etc/product.type`"
echo "Linux: `cat /proc/version`"
echo "Board: `cat /proc/bdutil/boardid`"
echo ""
if [ -f bootloader_info.cgi ] ; then
  ./bootloader_info.cgi
fi
echo ""
echo "-----Boot Data-----"
echo "cat /proc/cmdline: `cat /proc/cmdline`"
echo ""
echo "cat /proc/mtd: `cat /proc/mtd`"
echo ""
echo "----EPROM Manufacturer Data-----"
echo "`/usr/sbin/skuapi -g eeprom_version`"
echo "`/usr/sbin/skuapi -g model_sku`"
echo "`/usr/sbin/skuapi -g hw_version`"
echo "`/usr/sbin/skuapi -g hw_mac_addr`"
echo "`/usr/sbin/skuapi -g date`"
echo "`/usr/sbin/skuapi -g serial_number`"
echo "`/usr/sbin/skuapi -g uuid`"
echo "`/usr/sbin/skuapi -g wps_pin`"
echo ""
echo "----syscfg get device::xxxx ---Manufacturer Data-----"
#echo "`syscfg show | grep device::`"
#ignore the sensitive 
echo "`syscfg show | grep device:: | grep recovery_key -v | grep pass -v`"
echo ""
echo "`syscfg get fwup_server_uri`"
echo ""
fi
if [ "$SECTION" == "" ] || [ "$SECTION" == "debugInfo"] ; then
# echo "section=debugInfo"
# information helpful for debugging
#
echo "syscfg get ui remote_disabled:"
echo "`syscfg get ui remote_disabled`"
echo ""
echo "syscfg get ui remote_stunnel (use SSL):"
echo "`syscfg get ui remote_stunnel`"
echo ""
echo "syscfg get ui remote_host (remote ui host):"
echo "`syscfg get ui remote_host`"
echo ""
echo "syscfg get ui remote_port (remote ui port):"
echo "`syscfg get ui remote_port`"
echo ""
echo "syscfg get ui remote_stunnel_verify (verify remote ui stunnel):"
echo "`syscfg get ui remote_stunnel_verify`"
echo ""
echo "syscfg get cloud stunnel (use cloud SSL):"
echo "`syscfg get cloud stunnel`"
echo ""
echo "syscfg get cloud host (cloud host):"
echo "`syscfg get cloud host`"
echo ""
echo "syscfg get cloud port (cloud port):"
echo "`syscfg get cloud port`"
echo ""
echo "syscfg get cloud stunnel_verify (verify cloud stunnel):"
echo "`syscfg get cloud stunnel_verify`"
echo ""
echo "syscfg get mgmt_http_enable (can manage using http):"
echo "`syscfg get mgmt_http_enable`"
echo ""
echo "syscfg get mgmt_https_enable (can manage using https):"
echo "`syscfg get mgmt_https_enable`"
echo ""
echo "syscfg get mgmt_wifi_access (can manage wirelessly):"
echo "`syscfg get mgmt_wifi_access`"
echo ""
echo "syscfg get xmpp_enabled (can manage remotely)(true if not value not set):"
echo "`syscfg get xmpp_enabled`"
echo ""
echo "sysevent get xrac-status (xrac service state):"
echo "`sysevent get xrac-status`"
echo ""
echo "sysevent get xrac_provision_error:"
echo "`sysevent get xrac_provision_error`"
echo ""
echo "syscfg get owned_network_id:"
echo "`syscfg get owned_network_id`"
echo ""
echo "syscfg get user_set_network_owner:"
echo "`syscfg get user_set_network_owner`"
echo ""
echo "sysevent get phylink_wan_state (wanStatus):"
echo "`sysevent get phylink_wan_state`"
echo ""
echo "syscfg get wan_auto_detect_enable (isDetectingWANType):"
echo "`syscfg get wan_auto_detect_enable`"
echo ""
echo "syscfg get wan_proto (detectedWANType):"
echo "`syscfg get wan_proto`"
echo ""
echo "syscfg get bridge_mode (detectedWANType):"
echo "`syscfg get bridge_mode`"
echo ""
echo "sysevent get wan-status:"
echo "`sysevent get wan-status`"
echo ""
echo "sysevent get ipv4_wan_ipaddr:"
echo "`sysevent get ipv4_wan_ipaddr`"
echo ""
echo "sysevent get current_ipv6_wan_state:"
echo "`sysevent get current_ipv6_wan_state`"
echo ""
echo "---- SQM Debug Info -----"
echo ""
echo "sysevent get self_setup::config_status:"
echo "`sysevent get self_setup::config_status`"
echo ""
echo "sysevent get self_setup::config_error:"
echo "`sysevent get self_setup::config_error`"
echo ""
if [ "$(syscfg get self_setup::configured)" == "1" ]; then
    echo "syscfg get self_setup::last_config_time:"
    echo "$(syscfg get self_setup::last_config_time | TZ=UTC awk '{print strftime("%c",$1)}') UTC"
    echo ""
    echo "syscfg get self_setup::self_provision:"
    echo "`syscfg get self_setup::self_provision`"
    echo ""
    echo "syscfg get self_setup::reprovision:"
    echo "`syscfg get self_setup::reprovision`"
    echo ""
    echo "syscfg get self_setup::provisioned:"
    echo "`syscfg get self_setup::provisioned`"
    echo ""
    echo "sysevent get self_setup::provision_status:"
    echo "`sysevent get self_setup::provision_status`"
    echo ""
    echo "sysevent get self_setup::provision_error:"
    echo "`sysevent get self_setup::provision_error`"
    echo ""
    echo "syscfg get hist_upload::enabled:"
    echo "`syscfg get hist_upload::enabled`"
    echo ""
    echo "syscfg get hist_upload::host:"
    echo "`syscfg get hist_upload::host`"
    echo ""
    echo "syscfg get hist_upload::interval:"
    echo "`syscfg get hist_upload::interval`"
    echo ""
    echo "syscfg get hist_upload::last_upload_time:"
    echo "$(syscfg get hist_upload::last_upload_time | TZ=UTC awk '{print strftime("%c",$1)}') UTC"
    echo ""
    echo "syscfg get fwup_autoupdate_flags:"
    echo "`syscfg get fwup_autoupdate_flags`"
    echo ""
    echo "syscfg get self_setup::last_fwupdate_time:"
    echo "$(syscfg get self_setup::last_fwupdate_time | TZ=UTC awk '{print strftime("%c",$1)}') UTC"
    echo ""
    echo "syscfg get cloud.external_ipaddr:"
    echo "`syscfg get cloud.external_ipaddr`"
    echo ""
fi
if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ]; then
    echo "---- Nodes Debug Info -----"
    echo ""
    port0_num="`syscfg get switch::router_2::port_numbers`"
    port1_num="`syscfg get switch::router_1::port_numbers`"
    echo "syscfg get smart_mode::mode"
    echo "`syscfg get smart_mode::mode`"
    echo ""
    echo "syscfg get wan::intf_auto_detect_enabled"
    echo "`syscfg get wan::intf_auto_detect_enabled`"
    echo ""
    echo "sysevent get wan::detected_proto"
    echo "`sysevent get wan::detected_proto`"
    echo ""
    echo "sysevent get wan::proto_detection_status"
    echo "`sysevent get wan::proto_detection_status`"
    echo ""
    echo "sysevent get wan::detected_intf"
    echo "`sysevent get wan::detected_intf`"
    echo ""
    echo "sysevent get wan::intf_detection_status"
    echo "`sysevent get wan::intf_detection_status`"
    echo ""
    echo "syscfg get wan::detected_type"
    echo "`syscfg get wan::detected_type`"
    echo ""
    echo "syscfg get wan::port"
    echo "`syscfg get wan::port`"
    echo ""
    echo "sysevent get backhaul::status"
    echo "`sysevent get backhaul::status`"
    echo ""
    echo "sysevent get icc_internet_state"
    echo "`sysevent get icc_internet_state`"
    echo ""
    echo "sysevent get backhaul::intf"
    echo "`sysevent get backhaul::intf`"
    echo ""    
    echo "sysevent get backhaul::media"
    echo "`sysevent get backhaul::media`"
    echo "" 
    echo "sysevent get lldp::root_accessible"
    echo "`sysevent get lldp::root_accessible`"
    echo ""       
    echo "sysevent get lldp::root_intf"
    echo "`sysevent get lldp::root_intf`"
    echo ""                 
fi
fi

if [ "$SECTION" == "" ] || [ "$SECTION" == "logs" ] ; then
if [ -f /var/log/guardian_log ];then
echo "guardian logs:"
echo "`cat /var/log/guardian_log`"
fi
# echo "section=logs"
# Generic log information information
echo "tail -200 /var/log/messages:"
echo ""
echo "`tail -200 /var/log/messages`"
echo ""
echo "========================== Last 70 LED Information on messages.0 =========================="
cat /var/log/messages.0 | grep '\bLED\b' | tail -70
echo ""
echo "========================== Last 80 LED Information on messages =========================="
cat /var/log/messages | grep '\bLED\b' | tail -80
echo ""
echo "/var/log/ipv6.log:"
echo ""
echo "`cat /var/log/ipv6.log`"
echo ""
echo "dmesg | tail -200:"
echo ""
echo "`dmesg | tail -200`"
echo ""
# More counter information
if [ -f get_counter_info.cgi ]; then
  ./get_counter_info.cgi
fi
fi

if [ -d /etc/sysinfo.d ];then
        execute_dir /etc/sysinfo.d/
fi

if [ "$SECTION" == "" ] || [ "$SECTION" == "motion" ] ; then
    if [ -f /etc/init.d/service_origin.sh ];then
        echo "========================== Motion Sensing =========================="
        echo ""
        echo "origin_control-status: $(sysevent get origin_control-status)"
        echo "origin-status: $(sysevent get origin-status)"
        echo "origin::enabled: $(syscfg get origin::enabled)"
        echo ""
        echo "ps | grep -i origin:"
        echo "$(ps | grep -i origin)"
        echo ""
        echo "/tmp/sounder.conf:"
        if [ -f /tmp/sounder.conf ];then
          cat /tmp/sounder.conf
        fi
        echo ""
        echo "/var/run/origind.log | tail -100:"
        if [ -f /var/run/origind.log ];then
          cat /var/run/origind.log | tail -100
        fi
        echo ""
        echo "/var/run/origin-fusion.log | tail -100:"
        if [ -f /var/run/origin-fusion.log ];then
          cat /var/run/origin-fusion.log | tail -100
        fi
        echo "========================== End Motion Sensing =========================="
    fi
fi

if [ "$SECTION" == "motion_full_log" ] ; then
  if [ -f /etc/init.d/service_origin.sh ];then
    echo "========================== Motion Sensing Full Log =========================="
    echo ""
    echo "origin_control-status: $(sysevent get origin_control-status)"
    echo "origin-status: $(sysevent get origin-status)"
    echo "origin::enabled: $(syscfg get origin::enabled)"
    echo ""
    echo "ps | grep -i origin:"
    echo "$(ps | grep -i origin)"
    echo ""
    echo "/tmp/sounder.conf:"
    if [ -f /tmp/sounder.conf ];then
      cat /tmp/sounder.conf
    fi
    echo ""
    echo "/var/run/origind.log:"
    if [ -f /var/run/origind.log ];then
      cat /var/run/origind.log
    fi
    echo ""
    echo "/var/run/origin-fusion.log:"
    if [ -f /var/run/origin-fusion.log ];then
      cat /var/run/origin-fusion.log
    fi
  fi
  echo ""
  echo "cat /var/log/message"
  cat /var/log/messages
  echo ""
  
  echo "========================== End Motion Sensing Full Log =========================="
fi

if [ "$SECTION" == "" ] || [ "$SECTION" == "system" ] ; then
# echo "section=system"
# system running processes and uptime information
echo "ps:"
echo ""
echo "`ps`"
# Disk use information
echo "disk usage:"
echo ""
echo "`df`"
echo ""
# system memory and process use information
echo "Memory Use:"
echo "free"
echo "`free`"
echo ""
echo "cat /proc/locks"
cat /proc/locks
echo ""
echo "cat /proc/modules"
cat /proc/modules
echo ""
echo "cat /proc/slabinfo"
cat /proc/slabinfo
echo ""
echo "cat /proc/vmstat"
cat /proc/vmstat
echo ""
echo "CPU Information"
echo "cat /proc/stat"
cat /proc/stat
echo ""
#it may display the password when changing router password, so filter service_file_sharing.sh
echo "top -bn1"
echo "`top -bn1 | sed '/service_file_sharing/d'`"
echo ""
fi
if [ "$SECTION" == "" ] || [ "$SECTION" == "wifi" ] ; then

if [ -f "/etc/init.d/service_wifi/get_wifi_runtime_info.sh" ] ; then
  echo "`sh /etc/init.d/service_wifi/get_wifi_runtime_info.sh`"
  echo ""
fi

if [ -f "/etc/init.d/service_wifi/wifi_debug_suppliment.sh" ] ; then
  echo "`sh /etc/init.d/service_wifi/wifi_debug_suppliment.sh`"
fi

if [ -f "/etc/init.d/service_wifi/wifi_debug_show_info.sh" ] ; then
  echo "WiFi debug info:"
  echo "`sh /etc/init.d/service_wifi/wifi_debug_show_info.sh`"
fi

fi

if [ "$SECTION" == "" ] || [ "$SECTION" == "ipnet" ] ; then
# echo "section=ipnet"
# IP networking information
echo "ifconfig:"
echo ""
echo "`ifconfig`"
echo ""
echo "cat /etc/resolv.conf:"
echo ""
echo "`cat /etc/resolv.conf`"
echo ""
echo "ip link:"
echo ""
echo "`ip link`"
echo ""
echo "ip neigh:"
echo ""
echo "`ip neigh`"
echo ""
echo "ip -4 addr show:"
echo ""
echo "`ip -4 addr show`"
echo ""
echo "ip -4 route show:"
echo ""
echo "`ip -4 route show`"
echo ""
echo "ip -6 addr show:"
echo ""
echo "`ip -6 addr show`"
echo ""
echo "ip -6 route show:"
echo ""
echo "`ip -6 route show`"
echo ""
echo "ip tunnel show:"
echo ""
echo "`ip tunnel show`"
echo ""
echo "rdisc6 -r1 $wan_ifname:"
echo ""
echo "`rdisc6 -r1 $wan_ifname`"
echo ""
echo "rdisc6 -r1 ppp0:"
echo ""
echo "`rdisc6 -r1 ppp0`"
echo ""
echo "brctl show"
echo ""
echo "`brctl show`"
echo ""
echo "ping www.linksys.com:"
echo ""
echo "`ping -c2 www.linksys.com`"
# echo ""
# echo "ping 8.8.8.8:"
# echo ""
# echo "`ping -c2 8.8.8.8`"
echo ""
# network counters information
echo "NIC Counters"
if [ "" != "`ifconfig br0  2>/dev/null`" ];then
	echo "  br0 : `ifconfig br0 2>/dev/null | grep 'RX bytes:'`"
fi
if [ "" != "`ifconfig eth0 2>/dev/null`" ];then
	echo " eth0 : `ifconfig eth0 2>/dev/null | grep 'RX bytes:'`"
fi
if [ "" != "`ifconfig eth1 2>/dev/null`" ];then
	echo " eth1 : `ifconfig eth1 2>/dev/null | grep 'RX bytes:'`"
fi
if [ "" != "`ifconfig eth2 2>/dev/null`" ];then
	echo " eth2 : `ifconfig eth2 2>/dev/null | grep 'RX bytes:'`"
fi
if [ "" != "`ifconfig vlan1 2>/dev/null`" ];then
	echo "vlan1 : `ifconfig vlan1 2>/dev/null | grep 'RX bytes:'`"
fi
if [ "" != "`ifconfig vlan2 2>/dev/null`" ];then
	echo "vlan2 : `ifconfig vlan2 2>/dev/null | grep 'RX bytes:'`"
fi
if [ "" != "`ifconfig wl1.2 2>/dev/null`" ];then
	echo "wl1.2 : `ifconfig wl1.2 2>/dev/null | grep 'RX bytes:'`"
fi
echo ""
fi

if [ "$SECTION" == "" ] || [ "$SECTION" == "diskinfo" ] ; then
echo "usb messages to dmesg"
dmesg | grep '^sd\|^scsi'
# mounted disk information
echo ""
echo "disk information:"
echo ""
echo "`for n in /dev/sd?; do parted -s $n print 2>&1; done`"
echo ""
echo "mounted filesystems:"
echo ""
echo "`mount`"
fi

if [ -f qos_info.cgi ] ; then
  ./qos_info.cgi
fi

if [ -f speedtest_info.cgi ] ; then
  ./speedtest_info.cgi
fi

if [ -f usbinfo.cgi ]; then
  ./usbinfo.cgi 1
fi
echo ""

echo "list of open files"
LSOF_PATH=$( which lsof )
if [ -z ${LSOF_PATH} ]; then
    echo "Unable to find lsof command."
else
    $LSOF_PATH
fi
echo ""

echo ""
echo "=================================== Historical Data ==================================="
echo ""
# Historical data extract/upload may not be enabled
if [ -f /tmp/hist_data.json ]; then
    jpp /tmp/hist_data.json 
fi

if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
	echo "========================== Node Information =========================="
	echo "tree /tmp/msg/"
	echo "`tree /tmp/msg/`"

	echo "cat /tmp/msg/DEVINFO/*"
	echo "`cat /tmp/msg/DEVINFO/*`"


	if [ -e "/tmp/msg/BH" ];then
		echo "cat /tmp/msg/BH/*/status"
		echo "`cat /tmp/msg/BH/*/status`"
	fi
	
	echo "bh_report"
	echo "`bh_report`"

	echo "wlan_report"
	echo "`wlan_report`"

        SHOW_DEVICES="/usr/bin/show_devices"
        if [ -x "$SHOW_DEVICES" ]; then
            echo ""
            echo "$(basename $SHOW_DEVICES):"
            $SHOW_DEVICES
        fi

        NODE_BH_PERF_DATA="/www/ui/cgi/node-bh-perf-data.cgi"
        if [ -x "$NODE_BH_PERF_DATA" ]; then
            echo ""
            $NODE_BH_PERF_DATA
        fi

fi

if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
	echo "========================== LLDP Information =========================="
	echo "show neighbors" > /tmp/sn.conf
	/usr/bin/lldpcli -c /tmp/sn.conf
fi

# Prints deviceDB debug data, this is only turned on for non-production
# builds
if [ -f /etc/devicedb/devicedb_debug_log.sh ]; then
    /etc/devicedb/devicedb_debug_log.sh sysinfo
fi

# collect TR-69 Log info if available
if [ -f tr69info.cgi ]; then
  ./tr69info.cgi 
fi

# Prints LRHK debug data, this is only turned on for non-production
# builds
if [ -f /etc/lrhk/lrhk_debug_log.sh ]; then
    /etc/lrhk/lrhk_debug_log.sh sysinfo
fi

echo
echo "**************** End of Sysinfo Output ******************"
echo

