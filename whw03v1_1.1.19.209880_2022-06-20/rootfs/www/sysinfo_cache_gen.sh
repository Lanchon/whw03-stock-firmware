#!/bin/sh
if [ ! -f "/tmp/.sysinfo.js" ] ; then
	echo "creating /tmp/sysinfo.js" >> /dev/console
	/www/sysinfo_json.cgi > /tmp/.sysinfo.js
	mv /tmp/.sysinfo.js /tmp/sysinfo.js
	echo "creating /tmp/sysinfo.js done" >> /dev/console
fi

