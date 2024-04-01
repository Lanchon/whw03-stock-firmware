#!/bin/sh
TIMEOUT=3m
OUTFILE=/tmp/sysinfo.txt
SECTIONS=$1
UPLOAD=$2
{
   sleep $TIMEOUT
   kill -9 $$
   sysevent set sysinfo::process_id ""
} &
sysevent set sysinfo::process_id $$
sysevent set sysinfo::last_triggered `date +%s`
sysevent set sysinfo::upload_id ""
sysevent set sysinfo::upload_error_code ""
sysevent set sysinfo::upload_error_desc ""
/www/sysinfo_json.cgi "CMD=sync SECTION=$SECTIONS UPLOAD=$UPLOAD" > $OUTFILE 2>/dev/null
