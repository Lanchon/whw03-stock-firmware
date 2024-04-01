source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_flags
SM_PREFIX="xsm_"
SM_POSTFIX="_async_id"
sm_save_async() {
   if [ "${1}-start" = "$2" ] || [ "${1}-stop" = "$2" ] || [ "${1}-restart" = "$2" ] ; then
      sysevent set ${SM_PREFIX}${1}${SM_POSTFIX}_${2} "${2} ${3}"
   else
      SMSA_IDX=1
      SMSA_TUPLE=`sysevent get ${SM_PREFIX}${1}${SM_POSTFIX}_${SMSA_IDX}`
      until [ -z "$SMSA_TUPLE" ] ; do
         SMSA_IDX=`expr $SMSA_IDX + 1`
         SMSA_TUPLE=`sysevent get ${SM_PREFIX}${1}${SM_POSTFIX}_${SMSA_IDX}`
      done
      sysevent set ${SM_PREFIX}${1}${SM_POSTFIX}_${SMSA_IDX} "${2} ${3}"
   fi
}
sm_rm_event() {
   if [ "${1}-start" = "$2" ] || [ "${1}-stop" = "$2" ] || [ "${1}-restart" = "$2" ] ; then
      SMRM_STR=`sysevent get ${SM_PREFIX}${1}${SM_POSTFIX}_${2}`
      if [ -n "$SMRM_STR" ] ; then
         SMRM_ASYNC=`echo $SMRM_STR | cut -f 2,3 -d ' '`
         if [ -n "$SMRM_ASYNC" ] ; then
            sysevent rm_async $SMRM_ASYNC
            ulog srvmgr status "Unregistered $1 from $2"
         fi
         sysevent set ${SM_PREFIX}${1}${SM_POSTFIX}_${2}
      fi
   else
      SMRM_IDX=1
      SMRM_STR=`sysevent get ${SM_PREFIX}${1}${SM_POSTFIX}_${SMRM_IDX}`
      SMRM_EVENT=`echo $SMRM_STR | cut -f 1 -d ' ' | sed 's/ //'`
      while [ -n "$SMRM_STR" ] && [ "$2" != "$SMRM_EVENT" ] ; do
         SMRM_IDX=`expr $SMRM_IDX + 1`
         SMRM_STR=`sysevent get ${SM_PREFIX}${1}${SM_POSTFIX}_${SMRM_IDX}`
         SMRM_EVENT=`echo $SMRM_STR | cut -f 1 -d ' ' | sed 's/ //'`
      done
      if [ "$2" = "$SMRM_EVENT" ] ; then
         SMRM_ASYNC=`echo $SMRM_STR | cut -f 2,3 -d ' '`
         if [ -n "$SMRM_ASYNC" ] ; then
            sysevent rm_async $SMRM_ASYNC
            ulog srvmgr status "Unregistered $1 from $2"
         fi
         SMRM_NEXT_IDX=`expr $SMRM_IDX + 1`
         SMRM_NEXT_STR=`sysevent get ${SM_PREFIX}${1}${SM_POSTFIX}_${SMRM_NEXT_IDX}`
         until [ -z "$SMRM_NEXT_STR" ] ; do
            sysevent set ${SM_PREFIX}${1}${SM_POSTFIX}_${SMRM_IDX} "$SMRM_NEXT_STR"
            SMRM_IDX=$SMRM_NEXT_IDX
            SMRM_NEXT_IDX=`expr $SMRM_NEXT_IDX + 1`
            SMRM_NEXT_STR=`sysevent get ${SM_PREFIX}${1}${SM_POSTFIX}_${SMRM_NEXT_IDX}`
         done
      fi
   fi
}
sm_register_one_event() {
   SMR_SERVICE=$1
   SMR_EVENT_STRING=$2
   SMR_EVENT_NAME=`echo $SMR_EVENT_STRING | cut -f 1 -d '|' | sed 's/ //'` 
   SMR_EVENT_HANDLER=`echo "$SMR_EVENT_STRING" | cut -f 2 -d '|' | sed 's/ //'`
   SMR_ACTIVATION_FLAGS=`echo $SMR_EVENT_STRING | cut -f 3 -d '|' | sed 's/ //'`
   SMR_TUPLE_FLAGS=`echo $SMR_EVENT_STRING | cut -f 4 -d '|' | sed 's/ //'`
   SMR_PARAMETERS=`echo $SMR_EVENT_STRING | cut -f 5 -d '|' `
   
   if [ -z "$SMR_EVENT_NAME" ] || [ -z "$SMR_EVENT_HANDLER" ] ; then
      return 1
   fi
   if [ "NULL" = "$SMR_EVENT" ] ; then
      return 0
   fi
   sm_rm_event ${SMR_SERVICE} ${SMR_EVENT_NAME}
   if [ -n "$SMR_ACTIVATION_FLAGS" ] && [ "NULL" != "$SMR_ACTIVATION_FLAGS" ] ; then
      asyncid=`sysevent async_with_flags $SMR_ACTIVATION_FLAGS $SMR_EVENT_NAME $SMR_EVENT_HANDLER $SMR_PARAMETERS`;
   else
      asyncid=`sysevent async $SMR_EVENT_NAME $SMR_EVENT_HANDLER $SMR_PARAMETERS`;
   fi
   if [ -n "$asyncid" ] ; then
      if [ -n "$SMR_TUPLE_FLAGS" ] && [ "NULL" != "$SMR_TUPLE_FLAGS" ] ; then
         sysevent setoptions $SMR_EVENT_NAME $SMR_TUPLE_FLAGS
      fi
      sm_save_async $SMR_SERVICE $SMR_EVENT_NAME "$asyncid"
   fi
   ulog srvmgr status "($$) Registered $SMR_SERVICE for $SMR_EVENT_NAME"
} 
sm_register_for_default_events() {
   RDE_SERVICE=$1
   RDE_HANDLER=$2
   if [ -z "$RDE_SERVICE" ] || [ -z "$RDE_HANDLER" ] ; then
      return 1
   fi
   RDE_START_STRING="${RDE_SERVICE}-start|${RDE_HANDLER}|NULL|${TUPLE_FLAG_EVENT}"
   RDE_STOP_STRING="${RDE_SERVICE}-stop|${RDE_HANDLER}|NULL|${TUPLE_FLAG_EVENT}"
   RDE_RESTART_STRING="${RDE_SERVICE}-restart|${RDE_HANDLER}|NULL|${TUPLE_FLAG_EVENT}"
   sm_register_one_event $RDE_SERVICE "$RDE_START_STRING"
   sm_register_one_event $RDE_SERVICE "$RDE_STOP_STRING"
   sm_register_one_event $RDE_SERVICE "$RDE_RESTART_STRING"
}
sm_unregister()
{
    SRV_NAME="$1"
    if [ -n "$SRV_NAME" ]; then
        srvmgr_cmd stop "$SRV_NAME"
    fi
}
sm_register()
{
    SRV_NAME="$1"
    DEF_HANDLER="$2"
    CUSTOM_EVENTS="$3"
    if [ -z "$SRV_NAME" -o -z "$DEF_HANDLER" ]; then
        return 1
    fi
    if [ -n "$CUSTOM_EVENTS" ]; then
        CUSTOM_EVENTS="$(echo $CUSTOM_EVENTS | tr -d ' ')"
    else
        if [ "$CUSTOM_EVENTS" = "NULL" ]; then
            CUSTOM_EVENTS=""
        fi
    fi
    srvmgr_cmd stop "$SRV_NAME"
    srvmgr_cmd start "$SRV_NAME" "$DEF_HANDLER" "$CUSTOM_EVENTS"
    
    return 0
}
