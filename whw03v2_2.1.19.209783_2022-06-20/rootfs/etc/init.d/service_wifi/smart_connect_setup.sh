#!/bin/sh
source /etc/init.d/syscfg_api.sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/smart_connect_server_utils.sh
WIFI_DEBUG_SETTING=`syscfg_get wifi_debug`
DEBUG() 
{
    [ "$WIFI_DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
SELF_NAME="${SERVICE_NAME}.$(basename $0)"
echo "${SELF_NAME}: smart_connect_setup-run"
for PHY_IF in $PHYSICAL_IF_LIST; do
	wifi_smart_setup_start $PHY_IF "up"
done
SMART_CONNECT_SETUP_TIMEOUT=`syscfg_get smart_connect::setup_duration`
SMART_MODE=$(syscfg get smart_mode::mode)
echo "${SELF_NAME}: setup VAP(s) will remain on for $SMART_CONNECT_SETUP_TIMEOUT seconds (`date`)" > /dev/console
if [ "$SMART_MODE" = "2" ]; then
	sysevent set smart_connect::setup_status START
fi
SLEEP_CNT=0
SMC_PIN=$(syscfg get smart_connect::client_pin)
SMC_UUID=$(sysevent get smart_connect::uuid_${SMC_PIN})
SMC_STATUS=
WL0_SETUP_VAP="`syscfg_get smart_connect::wl0_setup_vap`"
CLIENT_CONN_FILE=client_conn_info
CLIENT_CONN_DETECTED=false
SC_MSG_DIR="$(syscfg get subscriber::file_prefix)/SC"
while [ "$SLEEP_CNT" -lt "$SMART_CONNECT_SETUP_TIMEOUT" ];
do
	SLEEP_CNT=`expr $SLEEP_CNT + 1`
	sleep 1
	if [ "1" = "`sysevent get smart_connect::setup_duration_reset`" ]; then
		sysevent set smart_connect::setup_duration_reset "0"
		SLEEP_CNT=0
		SMART_CONNECT_SETUP_TIMEOUT=`syscfg_get smart_connect::setup_duration`
		echo "${SELF_NAME}: setup VAP(s) reset for $SMART_CONNECT_SETUP_TIMEOUT seconds (`date`)" > /dev/console
	fi
    STA="`wlanconfig $WL0_SETUP_VAP list sta 2>/dev/null | tail +2`"
    if [ -n "$STA" ] && [ $(echo "$STA" | wc -l) -eq 1 ]; then
        CLIENT_CONN_DETECTED=true
        pub_scclient_conn_info
    else # no client connection
        if $CLIENT_CONN_DETECTED; then 
            pub_scclient_conn_info
        fi
        CLIENT_CONN_DETECTED=false
    fi
    if [ "$SMART_MODE" = "2" ]; then
        if  [ -n "$SMC_UUID" ] && [ "$SMC_STATUS" != "config_done" ]; then
            SMC_STATUS=$(sysevent get smart_connect::pin_${SMC_PIN})
            DB_PIN=$(smcdb -s -U $SMC_UUID | tail +2 | cut -d',' -f2)
            if [ -n "$DB_PIN" ] && [ "$DB_PIN" != "$SMC_PIN" ]; then
                echo "$SELF_NAME: ERROR, PIN ${SMC_PIN} UUID mismatch!" >>/dev/console
                sysevent set smart_connect::status_${SMC_UUID} 'failed'
                sysevent set smart_connect::error_${SMC_UUID} "PIN_UUID_MISMATCH"
                unset SMC_UUID
            elif [ -n "$SMC_STATUS" ]; then
                UUID_STATUS=$SMC_STATUS
                sysevent set smart_connect::status_${SMC_UUID} $UUID_STATUS
            fi
        fi
    fi
done
SLEEP_EXTRA=0
while [ "$SLEEP_EXTRA" -lt 5 ];
do
	SLEEP_EXTRA=`expr $SLEEP_EXTRA + 1`
	if [ "" = "`wlanconfig $WL0_SETUP_VAP list sta`" ];then
		break
	fi
	sleep 5
done
if [ "$SMART_MODE" = "2" ]; then
    sysevent set smart_connect::setup_status READY
    SMC_STATUS=$(sysevent get smart_connect::pin_${SMC_PIN})
    if [ -n "$SMC_PIN" ] && [ "$SMC_STATUS" != "config_done" ]; then
        sysevent set smart_connect::pin_${SMC_PIN} "failed"
        if [ -n "$SMC_UUID" ]; then
            sysevent set smart_connect::status_${SMC_UUID} 'failed'
            case "$UUID_STATUS" in
                setup_ready)
                    SMC_ERROR="SETUPAP_ERROR"
                    ;;
                setup_done)
                    SMC_ERROR="PRE-AUTH_ERROR"
                    ;;
                preauth_done)
                    SMC_ERROR="CONFIGAP_ERROR"
                    ;;
                *)
                    SMC_ERROR="UNKNOWN_ERROR"
                    ;;
            esac
            sysevent set smart_connect::error_${SMC_UUID} $SMC_ERROR
            echo "$SELF_NAME: device ${SMC_UUID} setup failed: $SMC_ERROR" >>/dev/console
        fi
    fi
    rm -f $(find $SC_MSG_DIR -name $CLIENT_CONN_FILE)
fi
echo "${SELF_NAME}: setup VAP(s) expired (`date`)" > /dev/console
for PHY_IF in $PHYSICAL_IF_LIST; do
	wifi_smart_setup_stop $PHY_IF
done
