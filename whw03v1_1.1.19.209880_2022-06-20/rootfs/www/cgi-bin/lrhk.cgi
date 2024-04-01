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

echo "function doUpdate(){"
echo "cmd = document.getElementById(\"CMD\");" 
echo "cmd.value = \"create_info\";"
echo "document.getElementById(\"lrhk\").submit();" 
echo "}"

echo "function restart(){"
echo "cmd = document.getElementById(\"CMD\");" 
echo "cmd.value = \"restart\";"
echo "document.getElementById(\"lrhk\").submit();" 
echo "}"

echo "function create_poo(){"
echo "cmd = document.getElementById(\"CMD\");" 
echo "cmd.value = \"create_poo\";"
echo "document.getElementById(\"lrhk\").submit();" 
echo "}"

echo "</script>"
echo "</HEAD><BODY>"

echo "<h3>LRHK Setup</h3>"
CMD=$(get_cgi_val "enabled")
if [ "$CMD" != "" ] ; then
	if [ "$CMD" != "`syscfg get lrhk::enabled`" ] ; then
		syscfg set lrhk::enabled $CMD
		syscfg set lrhk::mn_enabled $CMD
		#echo "<p>setting lrhk::enabled to $CMD</p>"
	fi
fi
CMD=$(get_cgi_val "CMD")
if [ "$CMD" == "restart" ] ; then
	#echo "restarting service lrhk<br>"
	sysevent set lrhk-restart
	sleep 1
fi
if [ "$CMD" == "create_poo" ] ; then
	echo "creating proof of ownership token<br>"
	sysevent set lrhk::generate_ownership_token
	sleep 1
	echo "Ownership token: `syscfg get lrhk::ownership_token`<br>"
	echo "<br><br><a href=\"lrhk.cgi\">[ go back to lrhk configuration]</a><br>"
	exit 1
fi

if [ "$CMD" == "create_info" ] ; then
	SETUP_CODE=$(get_cgi_val "setupcode")
	UUID=$(get_cgi_val "uuid")
	TOKEN=$(get_cgi_val "token")
	if [ "$SETUP_CODE" == "" ] ; then
		echo "ERROR: No setup code<br>"
	elif [ "$UUID" == "" ] ; then
		echo "ERROR: No UUID<br>"
	elif [ "$TOKEN" == "" ] ; then
		echo "ERROR: No Token<br>"
	else
		echo "<div><font color=#ff0000>WARNING:</font> DO NOT RELOAD THIS PAGE !!!</div>"
		echo "creating pairing information now using<br>"
		echo "Setup Code: $SETUP_CODE<br>"
		echo "UUID: $UUID<br>"
		echo "Token: $TOKEN<br>"
		sysevent set lrhk-stop
		sleep 1
		mkdir -p /var/config/lrhk/hk/.HomeKitStore.old
#		rm -rf /var/config/lrhk/hk/.HomeKitStore/*
		mv /var/config/lrhk/hk/.HomeKitStore/* /var/config/lrhk/hk/.HomeKitStore.old/
		cd /var/config/lrhk/hk/.HomeKitStore && /usr/bin/lrhkprvsn -s ${SETUP_CODE} -u ${UUID} -t ${TOKEN} 2>&1
		mv /var/config/lrhk/hk/.HomeKitStore/lrhkprvsn.log /tmp/
		syscfg set lrhk::enabled 1
		syscfg set lrhk::mn_enabled 1
		sysevent set lrhk-restart
		sleep 1
#		echo "lrhkprvsn -s ${SETUP_CODE} -u ${UUID} -t ${TOKEN}"
	fi
fi
echo "<form id=\"lrhk\" action=\"lrhk.cgi\">"
	echo "<input type=\"hidden\" id=CMD name=\"CMD\">"
echo "<p><table cellpadding=2 cellspacing=2 border=0><tr>"
echo "<td>Service</td><td>"
echo "<select name=\"enabled\" id=\"enabled\">"
if [ "`syscfg get lrhk::enabled`" == "1" ] ; then
	echo "<option value=\"1\">Enabled</option>"
	echo "<option value=\"0\">Disabled</option>"
else
	echo "<option value=\"0\">Disabled</option>"
	echo "<option value=\"1\">Enabled</option>"
fi
echo "</select>&nbsp;<input type=\"button\" value=\"restart\" onclick=\"restart();\"</td></tr></table>"

if [ "`syscfg get lrhk::enabled`" == "1" ] ; then
	IS_PAIRED="`syscfg get lrhk::ispaired`"
	echo "<b>Status:</b> `sysevent get lrhk-status` &nbsp;"
	if [ "$IS_PAIRED" == "1" ] ; then
		echo "[ PAIRED ]<br>"
	else
		echo "[ <font color=#FF0000>NOT PAIRED</font> ]<br>"
	fi
	LRHKP_LOG="`find /tmp/ -name lrhkprvsn.log`"
	if [ ! -f "$LRHKP_LOG" ]  ; then
		LRHKP_LOG="`find /var/config -name lrhkprvsn.log`"
	fi
	if [ ! -f "$LRHKP_LOG" ] ; then
		echo "<font color=#FF0000>ERROR: lrhkprvsn.log not found</font><br>"
		echo "NOTICE: Please enter UUID in UPERCASE<br>"
		echo "Setup Code: <input type=\"text\" name=\"setupcode\" id=\"setupcode\"><br>"
		echo "UUID: <input type=\"text\" name=\"uuid\" id=\"uuid\"><br>"
		echo "Token: <input type=\"text\" name=\"token\" id=\"token\" width=80><br>"
	else
		echo "Pairing information:<br>"
		echo "<font size=0><pre>"
		cat $LRHKP_LOG
		echo "</pre></font>"
	fi
	echo "<div>"
	if [ ! -f "$LRHKP_LOG" ]  ; then
		echo "<input type=\"button\" value=\"create pairing info\" onclick=\"doUpdate();\">"
	fi
	echo "<br>Ownership token: `syscfg get lrhk::ownership_token`<br><input type=\"button\" value=\"create ownership token\" onclick=\"create_poo();\">"
	echo "</div>"
fi
echo "</form>"
echo "</BODY></HTML>"

