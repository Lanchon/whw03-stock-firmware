#!/bin/sh
#------------------------------------------------------------------
# © 2020 Linksys and/or its affiliates. All rights reserved.
#------------------------------------------------------------------

source /etc/init.d/ulog_functions.sh

if [ ! -f "$1" ]; then
    echo "File: $1 not existed"
    exit 1
fi
if echo "$1" | grep -q '.*.ipt6'; then
    IPT_REST=ip6tables-restore
    IPT_SAVE=ip6tables-save
else
    IPT_REST=iptables-restore
    IPT_SAVE=iptables-save
fi

# save duplicated rule to file
echo '*filter' > "$1"_duplicated
$IPT_SAVE -t filter | awk 'seen[$0]++' | sed 's/^-[A|I]/-D/g' >> "$1"_duplicated
echo 'COMMIT' >> "$1"_duplicated
#remove duplicated
$IPT_REST -n < "$1"_duplicated
rm -f "$1"_duplicated
