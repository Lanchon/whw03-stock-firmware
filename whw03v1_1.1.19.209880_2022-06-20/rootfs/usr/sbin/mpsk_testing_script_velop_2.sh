#!/bin/sh

# The purpose of the script is to measure time of
# adding and applying number of passphrases (1, 2, 10...passphrases)
MPSK_CONFIG_FILE="/tmp/hostapd.mpsk"
NUM=1

generate_mpsk_config()
{
    ABC=$(($NUM+$1))
    temp=""
    while [ $NUM -lt $ABC ]
    do
        temp="$temp\n00:00:00:00:00:00 linksys"$NUM""
        NUM=$(($NUM+1))
    done
    echo -e $temp >> $MPSK_CONFIG_FILE
}

echo "Adding 1 passphrase into $MPSK_CONFIG_FILE"
generate_mpsk_config 1
sleep 2
echo "Adding 2 passphrase into $MPSK_CONFIG_FILE"
generate_mpsk_config 2
sleep 2
echo "Adding 10 passphrase into $MPSK_CONFIG_FILE"
generate_mpsk_config 10
sleep 5
echo "Adding 11 passphrase into $MPSK_CONFIG_FILE"
generate_mpsk_config 11
sleep 6
echo "Adding 100 passphrase into $MPSK_CONFIG_FILE"
generate_mpsk_config 100
sleep 45
echo "Adding 101 passphrase into $MPSK_CONFIG_FILE"
generate_mpsk_config 101

