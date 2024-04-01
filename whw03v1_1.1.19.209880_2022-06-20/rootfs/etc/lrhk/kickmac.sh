#!/bin/sh
source /etc/init.d/service_wifi/wifi_utils.sh
source /etc/init.d/service_wifi/wifi_steer_util.sh
source /etc/init.d/ulog_functions.sh

# This is a module that attempts to address the following issue reported
# by Apple: When a client HK device is switched from main to HK network,
# its IP address does not switch over and remains on the main subnet.
#
# The theory is this may be due to the fact that WiFi devices disconnect
# fequently, invisibile to the user. This may be a reassociation shortcut
# that does not involve WiFi reauthentication, or perhaps it does not
# re-acquire DHCP.
# 
# The solution is to ban the MAC with MAC filtering for a period of time,
# this should force the HK device to restart the full reassociation process
# and acquire a new DHCP address.

# How long to wait before allowing again, in seconds
# KICK_DURATION=15
DEBUG="$( syscfg get lrhk::debug )"
DBG () {
    if [ $DEBUG ]; then
        $*
    fi
}

#------------------------------------------------------------------------------
# Platform dependent kick
# $1 - interface
# $2 - MAC address
#------------------------------------------------------------------------------
kickmac_velop ()
{
    local intf="$1"
    local mac="$2"

    echo "LRHK - Kicking MAC ($intf) $MAC"

    # IMPORTANT: currently client steering also uses the second ACL list
    # (xxx_sec commands) to ban MACs. Since there is no systematic way to
    # do this, LRHK (this code) can stomp on client steering, and client
    # steering can stomp on this code. For this prototype we will turn off
    # client steering (change set 195254) and take over the second ACL. The 
    # system uses the first ACL for something else already, perhaps the UI 
    # configuration to ban MACs.

    # Note for now we are not banning the MAC as that may not be necessary
    # set list to deny
    #iwpriv "$intf" maccmd_sec 2
    
    # Note for now we are not banning the MAC as that may not be necessary
    # add MAC to block
    #iwpriv "$intf" addmac_sec "$mac"

    # kick off MAC
    iwpriv "$intf" kickmac "$mac"
}

#------------------------------------------------------------------------------
# Platform dependent un-kick
# $1 - interface
# $2 - MAC address
#------------------------------------------------------------------------------
unkickmac_velop ()
{
    local intf="$1"
    local mac="$2"

    # IMPORTANT: currently client steering also uses the second ACL list
    # (xxx_sec commands) to ban MACs. Since there is no systematic way to
    # do this, LRHK (this code) can stomp on client steering, and client
    # steering can stomp on this code. For this prototype we will turn off
    # client steering and take over the second ACL. The system uses the
    # first ACL for something else already, perhaps the UI configuration
    # to ban MACs.

    # wait then allow MAC again
    sleep $KICK_DURATION
    iwpriv "$intf" delmac_sec "$mac"
}

#------------------------------------------------------------------------------
# Kick mac from all known interfaces
# $1 - MAC address
#
# There is a problem where the interface name that a device is connected to
# isn't being properly recorded by DeviceDB. For now, the work around is to
# kick the MAC from all known interfaces.
#------------------------------------------------------------------------------
kickmac_all_velop()
{
    local mac="$1"
    local intfList="`syscfg get lan_wl_physical_ifnames`"
    local intf

    for intf in $intfList
    do
        kickmac_velop "$intf" "$mac"
    done
}

#------------------------------------------------------------------------------
# ENTRY
# $1 is sysevent name "lrhk::kickmac"
# $2 is value - "<interface>|<mac>|<uuid>", UUID = "master" for the master
#------------------------------------------------------------------------------

# INTF=`echo "$2" | awk -F "|" '{print $1}'`
# MAC=`echo "$2" | awk -F "|" '{print $2}'`

# using the kick all workaround, for refactor, we may need to root cause why
# interface name isn't being populated in devicedb
# kickmac_all_velop "$MAC"

# Note for now we are not banning the MAC as that may not be necessary
# run unkick in a spawned shell so we can exit right away and not block 
# sysevent
#$(unkickmac_velop "$INTF" "$MAC"; \
#    echo "LRHK - Allowing ($INTF) $MAC" > dev/console)&

client_mac="$1"
serving_ap="" # serving_ap is updated from is_client_associated_unit
is_client_associated_unit $client_mac

if [ "$?" = "0" ]; then
    DBG echo "Client ( $client_mac ) is not associated, do nothing!"
elif [ "$?" = "1" ]; then
    DBG echo "Client ( $client_mac ) is associated, initiate kick! ( MAC=$client_mac, INTF=$serving_ap )"
    
    force_disassociate_client "$serving_ap" "$client_mac"
    if [ "$?" = "0" ]; then
        DBG echo "Client ( $client_mac ) kicked!"
    else
        DBG echo "Error: Client ( $client_mac ) not kicked!"
    fi
else
    DBG echo "Error: unable to determine if client ( $MAC ) is associated, do nothing!"
fi

