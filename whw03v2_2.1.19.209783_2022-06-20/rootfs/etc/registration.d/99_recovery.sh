#!/bin/sh

#------------------------------------------------------------------
# © 2013 Belkin International, Inc. and/or its affiliates. All rights reserved.
#------------------------------------------------------------------

# update auto recovery information

if [ -e /usr/sbin/recovery ]; then
	# This utility is dedicated to the platforms using U-Boot only.
	if [ `cat /etc/product` = "nodes" ];then
		NODES_HW_VERSION=`cat /tmp/nodes_hw_version`
		if [ "$NODES_HW_VERSION" = "1" ];then
			recovery_emmc -c
		else
			recovery -c
		fi
	else
		recovery -c
	fi
fi

if [ -e /usr/sbin/nvram ]; then
	# Broadcom platforms using CFE.
	nvram set partialboots=1
	nvram commit
fi

