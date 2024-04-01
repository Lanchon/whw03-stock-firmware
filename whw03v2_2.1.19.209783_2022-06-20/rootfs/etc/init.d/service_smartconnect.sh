#!/bin/sh
source /etc/init.d/event_flags
source /etc/init.d/ulog_functions.sh
source /etc/init.d/interface_functions.sh
source /etc/init.d/service_smartconnect/utils.sh
BIN=lsc_server
SERVER=/usr/sbin/${BIN}
PID_FILE=/var/run/${BIN}.pid
PMON=/etc/init.d/pmon.sh
SERVICE_NAME="smart_connect"
DEBUG_SETTING=$(syscfg get ${SERVICE_NAME}_debug)
DEBUG() 
{
    [ "$DEBUG_SETTING" = "1" ] && $@
}
DEBUG set -x
UNCONFIGURED_MODE=0
MASTER_MODE=2
SLAVE_MODE=1
service_init ()
{
    FOO=`utctx_cmd get ldal_wl_setup_vap_netmask ldal_wl_setup_vap_subnet svap_lan_ifname ldal_wl_setup_vap_ipaddr smart_mode::mode smart_connect::wl0_enabled smart_connect::wl1_enabled smart_connect::wl0_setup_vap smart_connect::wl0_configured_vap bridge_mode svap_vlan_id wan_physical_ifname wan::intf_auto_detect_enabled lrhk::ifname lrhk::vlan_id`
  eval $FOO
    SMART_MODE=$SYSCFG_smart_mode_mode
    bridge_ifname=$(syscfg get switch::bridge_1::physical_ifname)
    port_4_ifname=$(syscfg get switch::router_1::physical_ifname)
    port_5_ifname=$(syscfg get switch::router_2::physical_ifname)
    port0_intf="$(syscfg get switch::router_2::ifname)"
    port1_intf="$(syscfg get switch::router_1::ifname)"
    
    port0_number="$(syscfg get switch::router_2::port_numbers)"
    port1_number="$(syscfg get switch::router_1::port_numbers)"
    port0_link_event="ETH::port_${port0_number}_status"
    port1_link_event="ETH::port_${port1_number}_status"
}
add_wired_setup_vlan ()
{
    if [ "$SYSCFG_wan_intf_auto_detect_enabled" = "1" ]; then
        if [ "$(sysevent get ETH::port_1_status)" = "up" ] || [ "$(sysevent get ETH::port_2_status)" = "up" ] || [ "$(sysevent get ETH::port_3_status)" = "up" ] || [ "$(sysevent get ETH::port_4_status)" = "up" ] ; then
            add_vlan_to_backhaul "$port_4_ifname" "$SYSCFG_svap_vlan_id" "$SYSCFG_svap_lan_ifname"
            [ -n "$SYSCFG_lrhk_ifname" ] && add_vlan_to_backhaul "$port_4_ifname" "$SYSCFG_lrhk_vlan_id" "$SYSCFG_lrhk_ifname"
        fi
        if [ "$(sysevent get ETH::port_5_status)" = "up" ] ; then
            add_vlan_to_backhaul "$port_5_ifname" "$SYSCFG_svap_vlan_id" "$SYSCFG_svap_lan_ifname"
            [ -n "$SYSCFG_lrhk_ifname" ] && add_vlan_to_backhaul "$port_5_ifname" "$SYSCFG_lrhk_vlan_id" "$SYSCFG_lrhk_ifname"
        fi
    else
        add_vlan_to_backhaul "$SYSCFG_wan_physical_ifname" "$SYSCFG_svap_vlan_id" "$SYSCFG_svap_lan_ifname"
        [ -n "$SYSCFG_lrhk_ifname" ] && add_vlan_to_backhaul "$SYSCFG_wan_physical_ifname" "$SYSCFG_lrhk_vlan_id" "$SYSCFG_lrhk_ifname" 
    fi
}
client_setup_start ()
{
    if [ "$SYSCFG_smart_mode_mode" != "0" ] || [ "$(syscfg get smart_mode::ML)" == "2" ] ; then
        ulog smart_connect status "Error, Client setup only run router unconfig mode, and Rouge will work as Master only."
        echo "Error, Client setup only run router unconfig mode, and Rouge will work as Master only"
        return 
    fi
    if [ "`sysevent get smart_connect::setup_status`" = "" ]; then
        ulog smart_connect status "smart_connect::setup_status is NULL, client setup not start."
        echo "smart_connect::setup_status is NULL, client setup not start."
        return
    fi
    /etc/init.d/service_bridge/setup_dhcp_link.sh setup_dhcp_client-start
    wifi_monitor_is_running
    wifi_is_running=$?
    if [ "$(sysevent get smart_connect::setup_mode)" = "wired" ] && [ "$wifi_is_running" = "0" ] ; then
        check_ip_connection
        RET=$?
        if [ "$RET" = "0" ] ; then
            add_wired_setup_vlan
            wired_setup_start
        else
            wifi_setup_start
        fi
    else
        wifi_setup_start
    fi
    sysevent set ${SERVICE_NAME}-status started
}
service_start ()
{
    if [ "$SYSCFG_smart_mode_mode" != "2" ] ; then
        return 
    fi
    sysevent set ${SERVICE_NAME}-status started
    RESTART=0
    CURRENT_PID=`cat $PID_FILE`
    if [ -z "$CURRENT_PID" ] ; then
        RESTART=1
    else
        CURRENT_PIDS=`pidof lsc_server`
        if [ -z "$CURRENT_PIDS" ] ; then
            RESTART=1
        else
            RUNNING_PIDS=`pidof lsc_server`
            FOO=`echo $RUNNING_PIDS | grep $CURRENT_PID`
            if [ -z "$FOO" ] ; then
                RESTART=1
            fi
        fi
    fi
    if [ "0" = "$RESTART" ] ; then
        return
    fi
    rm -f $PID_FILE
    $SERVER -d 
    pidof $BIN > $PID_FILE
    $PMON setproc ${SERVICE_NAME} $BIN $PID_FILE "/etc/init.d/service_smartconnect.sh ${SERVICE_NAME}-restart"
    return
}
service_stop ()
{
    if [ "$SYSCFG_smart_mode_mode" = "2" ] ; then
        rm -f $PID_FILE
        $PMON unsetproc ${SERVICE_NAME}
        return
    fi
    sysevent set ${SERVICE_NAME}-status stopped
}
service_restart ()
{
    service_stop
    service_start
}
service_setupap_ready()
{
      echo ""
      echo "smart_connect::wifi_setupap_ready"
      echo ""
      SMC_PIN=$(syscfg get smart_connect::client_pin)
      SMC_DURATION=$(syscfg get smart_connect::setup_duration)
      echo "PIN=${SMC_PIN}, DURATION=${SMC_DURATION}"
      /usr/sbin/lsc_ctl --cmd setup --pin ${SMC_PIN} --duration ${SMC_DURATION}
}
WiFi_Changed_handler () {
  if [ "$SYSCFG_smart_mode_mode" != "2" ] && [ "$SYSCFG_smart_mode_mode" != "0" ] ; then
    return
  fi
  sysevent set smart_connect::WiFi_Changed_status RECV
  SSID="`syscfg get smart_connect::24GHz_ssid`"
  SEC_MODE="`syscfg get smart_connect::24GHz_security_mode`"
  PASS="`syscfg get smart_connect::24GHz_passphrase`"
  syscfg set wl0_ssid "$SSID"
  syscfg set wl0_security_mode "$SEC_MODE"
  syscfg set wl0_passphrase "$PASS"
  SSID="`syscfg get smart_connect::5GHz_ssid`"
  SEC_MODE="`syscfg get smart_connect::5GHz_security_mode`"
  PASS="`syscfg get smart_connect::5GHz_passphrase`"
  syscfg set wl1_ssid "$SSID"
  syscfg set wl1_security_mode "$SEC_MODE"
  syscfg set wl1_passphrase "$PASS"
  if [ "`cat /etc/product`" = "nodes" -o "`cat /etc/product`" = "nodes-jr" -o "`cat /etc/product`" = "rogue" -o "`cat /etc/product`" = "lion" ] ; then
    syscfg set wl2_ssid "$SSID"
    syscfg set wl2_security_mode "$SEC_MODE"
    syscfg set wl2_passphrase "$PASS"
  fi
  syscfg commit
  sysevent set smart_connect::WiFi_Changed_status INPROGRESS
  /etc/init.d/service_wifi/service_wifi.sh wifi_config_changed
}
echo "${SERVICE_NAME}, sysevent received: $1 $2" >&2
service_init
case "$1" in
   ${SERVICE_NAME}-start)
      service_start
      ;;
   ${SERVICE_NAME}-stop)
      service_stop
      ;;
   ${SERVICE_NAME}-restart)
      service_restart
      ;;
   smart_connect::wifi_setupap_ready)
      service_setupap_ready
      ;;
   smart_connect::WiFi_Changed)
      WiFi_Changed_handler
      ;;
   smart_connect::client_setup_start)
      client_setup_start
      ;; 
   wifi-status)
      if  [ "$(sysevent get wifi-status)" = "started" ]; then 
          if [ "$(sysevent get smart_connect::WiFi_Changed_status)" = "INPROGRESS" ] ; then  
              sysevent set smart_connect::WiFi_Changed_status READY
          fi
          if [ "$(sysevent get ${SERVICE_NAME}-status)" != "started" ]; then
              service_start
          fi
      fi
      ;;
   devinfo)
       if [ "$SYSCFG_smart_mode_mode" = "2" ] && smcdb -r; then
           5bp_upgrade "$2"
       else
           echo "$0 $1 $2: Ignoring event, note Master" >&2
       fi
       ;;
   *)
      echo "Usage: $SERVICE_NAME [start|stop|restart]" >&2
      exit 3
      ;;
esac
