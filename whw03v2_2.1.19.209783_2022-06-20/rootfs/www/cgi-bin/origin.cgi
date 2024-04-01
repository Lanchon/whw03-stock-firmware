#!/bin/sh
echo "Content-Type: text/html"
echo ""

get_cgi_val () {
  if [ "$1" == "" ] ; then
    echo ""
    return
  fi
  form_var="$1"
  var_value=`echo "$QUERY_STRING" | sed -n "s/^.*$form_var=\([^&]*\).*$/\1/p" | sed "s/%20/ /g" | sed "s/+/ /g" | sed "s/%2F/\//g"`
  echo -n "$var_value"
}

echo "<HTML><HEAD>"
echo "<script type='text/javascript'>" 

echo "function save(){"
echo "document.getElementById(\"settings\").submit();" 
echo "}"

echo "function show(){"
echo "var configs = document.querySelectorAll(\".sounderConfig\");"
echo "configs.forEach(function(config) { config.setAttribute(\"style\", \"visibility: visible;\"); });"
echo "}"

echo "function refresh(){"
echo "location.reload(false);" 
echo "}"

echo "</script>"
echo "</HEAD><BODY>"

SOUNDER_ROUTING_FILE="/tmp/sounder.conf"
ERR="No sounder.conf file; sounder.conf file will be generated once service is enabled and bots(slaves) reconnect."

CMD=$(get_cgi_val "origin")
if [ "$CMD" == "1" ] ; then
    syscfg set origin::enabled 1
elif [ "$CMD" == "0" ] ; then
    syscfg set origin::enabled 0
else
    enabled=$(syscfg get origin::enabled)
    echo "origin::enabled = ${enabled}" > /dev/console
fi

CMD=$(get_cgi_val "wifi-restart")
if [ "$CMD" == "1" ] ; then
    sysevent set wifi-restart
fi


echo "<div>"
echo "<p style=\"display:inline-block;\">ORIGIN</p>"
echo "<form id=\"settings\" action=\"origin.cgi\" style=\"display:inline-block;\">"
    echo "<input type=\"hidden\" id=CMD name=\"CMD\">"
    echo "<select name=\"origin\" id=\"origin\">"
if [ "`syscfg get origin::enabled`" == "1" ] ; then
        echo "<option value=\"1\">Enabled</option>"
        echo "<option value=\"0\">Disabled</option>"
else
        echo "<option value=\"0\">Disabled</option>"
        echo "<option value=\"1\">Enabled</option>"
fi
    echo "</select>"
    echo "<p style=\"display:inline-block;\">WIFI-RESTART</p>"
    echo "<select name=\"wifi-restart\" id=\"wifi-restart\">"
        echo "<option value=\"0\">Disabled</option>"
        echo "<option value=\"1\">Enabled</option>"
    echo "</select>"
echo "<input type=\"button\" value=\"Save Settings\" onclick=\"save()\">"
echo "</form>"
echo "</div>"

echo "<p style=\"display:inline-block;\">SOUNDER.CONF</p>"
echo "<input type=\"button\" value=\"Show\" onclick=\"show()\" style=\"display:inline-block;\">"
echo "<input type=\"button\" value=\"Refresh\" onclick=\"refresh()\" style=\"display:inline-block;\">"

if [ -f $SOUNDER_ROUTING_FILE ]; then
    while read line
    do
        echo "<p class=\"sounderConfig\" style=\"visibility: hidden;\">$line</p>"
    done < "$SOUNDER_ROUTING_FILE"
else
    echo "<p class=\"sounderConfig\" style=\"visibility: hidden;\">$ERR</p>"
fi

echo "</BODY></HTML>"

