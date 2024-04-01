#!/bin/sh

########################################################
# debug_syslog.sh ----> /www/
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
fi

if [ "$SECTION" == "" ] || [ "$SECTION" == "logs" ] ; then
echo "========================== Information on messages.0 =========================="
cat /var/log/messages.0
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo "========================== Information on messages =========================="
cat /var/log/messages
echo ""
fi