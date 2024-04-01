#!/bin/sh

# 1. get file-list in dir: '/tmp/msearch/', files are in created date-time order
# 2. sed file name to get time
# 3. compare with current time to detemine if this should be remove or not
#       3.1 if current > got_time + 30 seconds --> execute script and remove file
#       3.2 if not, exit

CHECK_DIR=/tmp/msearch

clean_up_rules ()
{
    if [ ! "$(ls -A $CHECK_DIR)" ] ; then
        # return when directory empty
        return
    fi
    CURRENT_TIME=`date +%s`
    for file in ${CHECK_DIR}/*; do
        echo "${file##*/}"
        time_stamp=`echo "${file##*/}" | cut -f 1 -d "_"`
        echo "got $time_stamp"
        if [ -z "${time_stamp##*[!0-9]*}" ] ; then
            echo "invalid number"
            continue
        fi
        time_stamp=$((time_stamp+30))
        echo "update time-stamp: $time_stamp"
        if [ "$CURRENT_TIME" -gt "$time_stamp" ] ; then
            echo "msearch-rule: existed rule, will remove"
            chmod +x ${file}
            sh ${file}
            rm -f ${file}
        else
            echo "msearch-rule: has just created, will remove next time"
            return
        fi
    done
}

if [ ! -d "$CHECK_DIR" ] ; then
    echo "msearch-rule: dir $CHECK_DIR not exist"
    mkdir -p ${CHECK_DIR}
fi

count=0
while [ "$count" -lt "6" ] ; do
    count=$((count+1))
    clean_up_rules
    sleep 10
done
