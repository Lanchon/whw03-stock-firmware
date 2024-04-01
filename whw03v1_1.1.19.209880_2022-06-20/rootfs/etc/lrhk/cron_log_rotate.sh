#!/bin/sh
#
# rotate the log file in a shell script
# meant to run from cron

MAX_LOG_ENTRIES="5000"
ROTATE_BUFFER_SIZE="500"
LOG="/tmp/lrhk.log"
tmp_file="/tmp/`date +%S%M%h`.tmp"

CUR_LOG_SIZE="`/usr/bin/wc -l $LOG | cut -d' '  -f 1`"

if [ $CUR_LOG_SIZE -gt $MAX_LOG_ENTRIES ] ; then
    echo "rotating log file $LOG [ $CUR_LOG_SIZE ]" >> /dev/console
    echo "log rotate @ `date`" > $tmp_file
    /usr/bin/tail -n $ROTATE_BUFFER_SIZE $LOG >> $tmp_file
    /bin/cat $tmp_file > $LOG
    /bin/rm -f $tmp_file
fi
