#!/bin/sh

########################################################
# cedar_info.sh ----> /www/
########################################################

echo "Content-Type: text/plain"
echo ""
echo "page generated on `date`"
echo ""
echo "UpTime:"
echo "`uptime`"
echo ""
echo ""

echo "========================== General Info =========================="
echo "Firmware Version: `cat /etc/version`"
echo "Firmware Builddate: `cat /etc/builddate`"
echo "Product.type: `cat /etc/product.type`"
echo "Linux: `cat /proc/version`"
echo "Board: `cat /proc/bdutil/boardid`"
echo ""
echo ""
echo ""

echo "========================== LRHK Config =========================="
syscfg show | grep lrhk | sed '/lrhk::http_admin_password=/c\lrhk::http_admin_password=XXXXXXXX' | sed '/lrhk::admin_password=/c\lrhk::admin_password=XXXXXXXX'
echo ""
echo ""
echo ""

echo "========================== DB Data =========================="
echo "===> Client Profiles <==="
sqlite3 /tmp/lrhk/clientdb.db 'select * from clientprofiles'
echo ""
echo "===> Mac <==="
sqlite3 /tmp/lrhk/clientdb.db 'select * from MacId'
echo ""
echo "===> Mac/Profile <==="
sqlite3 /tmp/lrhk/clientdb.db 'select * from AuthList'
echo ""
echo "===> IP <==="
sqlite3 /tmp/lrhk/clientdb.db 'select * from MacIpMapping'
echo ""
echo "===> WAN Firewall Rules <==="
sqlite3 /tmp/lrhk/clientdb.db 'select * from wanfirewallrule'
echo ""
echo "===> DNS <==="
sqlite3 /tmp/lrhk/clientdb.db 'select * from dnswhitelist'
echo ""
echo "===> LAN Firewall Rules <==="
sqlite3 /tmp/lrhk/clientdb.db 'select * from lanfirewallrule'
echo ""
echo "===> DNS-SD <==="
sqlite3 /tmp/lrhk/clientdb.db 'select * from dnssdservice'
echo ""
echo "===> SSDP <==="
sqlite3 /tmp/lrhk/clientdb.db 'select * from SSDPService'
echo ""

echo "========================== Firewall Tables =========================="
echo "===> FORWARD <==="
iptables -nvL lan2wan_plugin_hk
echo ""
iptables -nvL FORWARD
echo ""
iptables -nvL lan_forward
echo ""
echo "===> INPUT <==="
iptables -nvL lanattack
echo ""
echo ""
echo "===> ebtables <==="
ebtables -L
echo ""
echo ""
echo ""

echo "========================== ADK Logs ( Most Recent ) =========================="
if [ -f "/tmp/lrhk.log" ]; then
    cat /tmp/lrhk.log
else
    echo "Error: no log file."
fi
echo ""
echo ""
echo ""
