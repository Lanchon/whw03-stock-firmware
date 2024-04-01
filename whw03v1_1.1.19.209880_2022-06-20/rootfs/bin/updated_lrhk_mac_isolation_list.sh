#!/bin/sh
#

# flush then apply mac isolation list to interfaces
#
/sbin/wlanconfig ath0 isolation flush
/sbin/wlanconfig ath1 isolation flush
/sbin/wlanconfig ath10 isolation flush
for i in `/usr/sbin/lrhk_util -u getMacsWithAllowList`
do
	echo "adding $i to isolation list"
	/sbin/wlanconfig ath0 isolation add $i
	/sbin/wlanconfig ath1 isolation add $i
	/sbin/wlanconfig ath10 isolation add $i
#  /sbin/syscfg set lrhk::mac_list "`/sbin/syscfg get lrhk::mac_list`,$i"
done

	