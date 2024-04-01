#!/bin/sh
LD_LIBRARY_PATH=$(pwd):$LD_LIBRARY_PATH
export LD_LIBRARY_PATH
COLL_INTL=1800
CFG_POLL_INTL=43200
PID_FILE=dcd.pid
MON_INTL=5
run_dc()
{
  cmd="$1"
  [ -z "$cmd" ] && cmd="start"
  case "$cmd" in
    start)
        echo "Start dcd..."
        ./dcd -i $COLL_INTL -p $CFG_POLL_INTL -b 
        ;;
    stop)
        echo "Stop dcd..."
        killall -9 dcd
        ;;
  esac
}
while [ true ];
do
  if [ ! -e $PID_FILE ]; then
    run_dc start
  elif [ ! -e /proc/`cat $PID_FILE`/status ]; then 
    run_dc start
  fi
  sleep $MON_INTL;
done
