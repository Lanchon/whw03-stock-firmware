#!/bin/sh
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
SERVICE_NAME="lrhk_token"
NAMESPACE=$SERVICE_NAME
STORAGE_DIR="/var/config/lrhk"
PROD_TOKEN_URL="https://token.lswf.net/token-management-service/rest/token"
DEV_TOKEN_URL="https://token-qa.lswf.net/token-management-service/rest/token"
service_start ()
{
	wait_till_end_state ${SERVICE_NAME}
	check_err $? "Couldnt handle start"
	sysevent set ${SERVICE_NAME}-status started
	ulog ${SERVICE_NAME} status "now started"
}
service_stop ()
{
	wait_till_end_state ${SERVICE_NAME}
	check_err $? "Couldnt handle stop"
	sysevent set ${SERVICE_NAME}-status stopped
	ulog ${SERVICE_NAME} status "now stopped"
}
case "$1" in
	${SERVICE_NAME}-start)
		service_start
		;;
	${SERVICE_NAME}-stop)
		service_stop
		;;
	${SERVICE_NAME}-restart)
		service_stop
		service_start
		;;
    wan-started)
				LRHK_SETUP_CODE="`syscfg get lrhk::setup_payload`"
				if [ "$LRHK_SETUP_CODE" == "" ] ; then
					echo "Attempting to get ADK soft token information" >> /dev/console
					logger "Attempting to get ADK soft token information"
					TYPE="`cat /etc/product.type | grep prod`"
					if [ "$TYPE" != "" ] ; then
						echo "using prod URL for token download" >> /dev/console
						/usr/bin/lrhk_token_get $PROD_TOKEN_URL
					else
						/usr/bin/lrhk_token_get $DEV_TOKEN_URL
						echo "using qa cloud for token download"  >> /dev/console
					fi
					SETUP_CODE="`syscfg get lrhk::setup_code`"
					LRHK_UUID="`syscfg get lrhk::software_token_uuid`"
					LRHK_TOKEN="`syscfg get lrhk::software_token`"
					if [ "$SETUP_CODE" != "" ] && [ "$LRHK_UUID" != "" ] && [ "$LRHK_TOKEN" != "" ] ; then
						echo "creating initial pairing information" >> /dev/console
						logger "creating initial pairing information"
						mkdir -p $STORAGE_DIR/hk/.HomeKitStore
						cd $STORAGE_DIR/hk/.HomeKitStore && /usr/bin/lrhkprvsn -v -s $SETUP_CODE -u $LRHK_UUID -t "$LRHK_TOKEN" > /tmp/lrhk.out.log
						mv $STORAGE_DIR/hk/.HomeKitStore/lrhkprvsn.log /tmp/
						syscfg set lrhk::setup_payload "`cat /tmp/lrhk.out.log | grep "Setup Payload" | cut -d '-' -f2-3 | tr -d ' '`"
					else
						if [ "$SETUP_CODE" != "" ] ; then
							echo "ERROR: setup code seems null" >> /dev/console
						fi
						if [ "$LRHK_UUID" != "" ] ; then
							echo "ERROR: UUID seems null" >> /dev/console
						fi
						if [ "$LRHK_TOKEN" != "" ] ; then
							echo "ERROR: token seems null" >> /dev/console
						fi
					fi
					IS_RUNNING="`ps | grep WiFiRouter | grep -v grep`"
					if [ "$IS_RUNNING" != "" ] ; then
						echo "re-starting WiFiRouter Process to get software pairing tokens" >> /dev/console
						killall -9 WiFiRouter
						sleep 1
						sysevent set lrhk-restart
					fi
				else
					echo "unit already contains LRHK ( ADK ) Provisioning information in syscfg" >> /dev/console
				fi
        ;;
    lrhk::refresh_access_list)
				logger "updating lrhk isolation list"
        /bin/updated_lrhk_mac_isolation_list.sh
        ;;
	*)
		echo "error : $1 unknown" > /dev/console 
		echo "Usage: $SERVICE_NAME [ ${SERVICE_NAME}-start | ${SERVICE_NAME}-stop | ${SERVICE_NAME}-restart]" > /dev/console
		exit 3
		;;
esac
