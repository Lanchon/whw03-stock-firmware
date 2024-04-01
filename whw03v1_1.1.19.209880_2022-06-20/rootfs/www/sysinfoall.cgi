#!/bin/sh
#
# compress a directory for HTTP Download

FILE_DIR="/tmp/mynet_syscfgs"
if [ ! -d "$FILE_DIR" ] ; then
	mkdir -p "$FILE_DIR"
fi
/usr/bin/get_all_sysinfo -a -p "$FILE_DIR" > /tmp/.sysinfoall.log

echo Content-Type: application/tar+gzip
echo "Content-Disposition: attachment; filename=sysinfo_files.tgz"
echo
cd "$FILE_DIR" && tar czf - *
