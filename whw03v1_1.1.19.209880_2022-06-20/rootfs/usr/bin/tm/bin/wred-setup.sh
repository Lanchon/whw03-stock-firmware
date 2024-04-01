#!/bin/sh
LD_LIBRARY_PATH=$(pwd):$LD_LIBRARY_PATH
export LD_LIBRARY_PATH
PID_FILE=wred.pid
MON_INTL=5
run_wre()
{
  cmd="$1"
  [ -z "$cmd" ] && cmd="start"
  shift
  
  case "$cmd" in
    start)
        echo "Start web reputation engine daemon..."
        echo $@
        ./wred -B $@ 
        ;;
    stop)
        echo "Stop web reputation engine daemon..."
        killall -INT wred
        ;;
  esac
}
while [ true ];
do
  if [ ! -e $PID_FILE -o ! -e /proc/`cat $PID_FILE` ]; then 
    run_wre start $@
  fi
  sleep $MON_INTL;
done
