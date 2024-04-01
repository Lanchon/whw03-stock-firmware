#!/bin/sh
REQUEST_ID=$$_$(date -u +%s)
TIMEOUT=2m
OUTFILE=/tmp/central.txt.${REQUEST_ID}
OPTION="$1 $2"
{
   sleep $TIMEOUT
   kill -9 $$
   rm -f $OUTFILE
} &
echo $REQUEST_ID
/usr/bin/btsetup_central $OPTION > $OUTFILE 2>/dev/null
