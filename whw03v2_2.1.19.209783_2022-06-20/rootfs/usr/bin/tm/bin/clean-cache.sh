#!/bin/sh
run_cleancache()
{
        echo 'echo 3 > /proc/sys/vm/drop_caches'
	echo 3 > /proc/sys/vm/drop_caches
}
while [ true ];
do
  run_cleancache
  sleep 600;
done
