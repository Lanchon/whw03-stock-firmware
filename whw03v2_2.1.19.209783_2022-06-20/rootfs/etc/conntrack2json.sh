#!/bin/sh

source /etc/sysinfo/scripts/sysinfo_function_helper.sh

# use below to get data from totals table
get_totals_data() {
first_line=""
for new_line in `sqlite3 /tmp/conntrack.db "SELECT * FROM totals;" | sed "s/ /+/g"`
do
	if [ "$first_line" != "" ] ; then
		echo ","
	fi
	echo "  {"
	ip="`echo $new_line | cut -d'|' -f2`"
	mac="`echo $new_line | cut -d'|' -f3`"
	bytesin="`echo $new_line | cut -d'|' -f4`"
	bytesout="`echo $new_line | cut -d'|' -f5`"
	timestamp=`echo $new_line | cut -d'|' -f6 | sed "s/+/ /g"`
	echo "   \"addr\": \"$ip\","
	echo "   \"mac\": \"$mac\","
	echo "   \"bytesin\": \"$bytesin\","
	echo "   \"bytesout\": \"$bytesout\","
	echo "   \"timestamp\": \"$timestamp\""
	echo -n "  }"
	first_line="$new_line"
done
}

# use below to get data from connections table
get_conns_data() {
first_line=""
for new_line in `sqlite3 /tmp/conntrack.db "SELECT OSrcAddr, total(OBytes), total(RBytes), TimeStamp FROM conns GROUP BY OSrcAddr;" | sed "s/ /+/g"`
do
	if [ "$first_line" != "" ] ; then
		echo ","
	fi
	echo "  {"
	ip="`echo $new_line | cut -d'|' -f1`"
	bytesin="`echo $new_line | cut -d'|' -f2`"
	bytesout="`echo $new_line | cut -d'|' -f3`"
		timestamp=`echo $new_line | cut -d'|' -f4 | sed "s/+/ /g"`
	echo "   \"addr\": \"$ip\","
	echo "   \"total_bytesin\": \"$bytesin\","
	echo "   \"total_bytesout\": \"$bytesout\","
	echo "   \"timestamp\": \"$timestamp\""
	echo -n "  }"
	first_line="$new_line"
done
}

# use below to get data from connections table
get_averages_data() {
first_line=""
for new_line in `sqlite3 /tmp/conntrack.db "SELECT SrcAddr, ROUND(AVG(RBytes)), ROUND(AVG(OBytes)), TimeStamp FROM averages GROUP BY SrcAddr;" | sed "s/ /+/g"`
do
	if [ "$first_line" != "" ] ; then
		echo ","
	fi
	echo "  {"
	ip="`echo $new_line | cut -d'|' -f1`"
	bytesin="`echo $new_line | cut -d'|' -f2`"
	bytesout="`echo $new_line | cut -d'|' -f3`"
		timestamp=`echo $new_line | cut -d'|' -f4 | sed "s/+/ /g"`
	echo "   \"addr\": \"$ip\","
	echo "   \"avg_bytesin\": \"$bytesin\","
	echo "   \"avg_bytesout\": \"$bytesout\","
	echo "   \"timestamp\": \"$timestamp\""
	echo -n "  }"
	first_line="$new_line"
done
}

echo "var Conntrack = {"
echo "  \"title\": \"conntrack connections\"," 
echo "  \"description\": \"1 minute snapshots of conntrack tables\"," 
echo "  \"timestamp\": \"$(timestamp)\","
echo "  \"data\": ["
if [ -f "/tmp/conntrack.db" ] ; then
	get_conns_data
fi
echo "]"
echo "};"

echo "var ConntrackTotals = {"
echo "  \"title\": \"conntrack connection totals\"," 
echo "  \"description\": \"client counters from the conntrack tables\"," 
echo "  \"timestamp\": \"$(timestamp)\","
echo "  \"data\": ["
if [ -f "/tmp/conntrack.db" ] ; then
	get_totals_data
fi
echo "]"
echo "};"

echo "var ConntrackAvg = {"
echo "  \"title\": \"conntrack connection client averages\"," 
echo "  \"description\": \"client averages from conntrack tables\"," 
echo "  \"timestamp\": \"$(timestamp)\","
echo "  \"data\": ["
if [ -f "/tmp/conntrack.db" ] ; then
	get_averages_data
fi
echo "]"
echo "};"
