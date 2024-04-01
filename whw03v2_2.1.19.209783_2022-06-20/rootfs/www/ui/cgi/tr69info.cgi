#!/bin/sh

########################################################
# TR-69 information 
########################################################
echo
echo "================================================"
echo "= TR69 CCSP Message Log File (last 2000 lines) ="
echo "================================================"
echo 

# This script will capture the last 2000 lines of the CCSP message log file
if [ -e /var/config/ccsp_config/ccsp_message_log.tgz ] ; then
    echo "**** ccsp_message_log archive found"
    # we need to concatenate the ccsp_message_log in the archive with the message_log in /tmp
    # then extract the last 2000 lines of the resulting file to give us the end result
    mkdir /tmp/tr69.sysinfo_dir
    cd /tmp/tr69.sysinfo_dir
    tar -xvf /var/config/ccsp_config/ccsp_message_log.tgz >/dev/null 2>&1
    cat ccsp_message.log /tmp/ccsp_message.log > whole_ccsp_message.log 2> /dev/null
    tail -n 2000 whole_ccsp_message.log
    cd /tmp
    rm -rf /tmp/tr69.sysinfo_dir
else
    if [ -e /tmp/ccsp_message.log ] ; then
        echo "**** ccsp_message_log archive not found; using /tmp/ccsp_message.log only"
        tail -n 2000 /tmp/ccsp_message.log
    else
        echo "**** No TR69 CCSP Message Logs found."
    fi
fi
echo
echo
