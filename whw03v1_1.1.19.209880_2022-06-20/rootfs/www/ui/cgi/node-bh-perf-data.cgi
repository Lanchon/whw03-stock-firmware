#!/bin/sh
#
# Provide Node backhaul Wi-Fi performance data for sysinfo reports.
#

PREF_DATA_FILE="/tmp/wifi-bh-performance"

if [ -f "$PREF_DATA_FILE" ]; then
    echo "-------------------------[Backhaul Wi-Fi Performance Data]-------------------------"
    echo "# Format is CSV.  Columns are as follows:"
    echo "# UTC date/time,UTC seconds since epoch,rate (Mb/s),delay(ms),jitter(ms)"
    cat "$PREF_DATA_FILE"
    echo "-------------------------[End Backhaul Wi-Fi Performance Data]-------------------------"
 else
    echo "(No backhaul performance data found.)"
fi
