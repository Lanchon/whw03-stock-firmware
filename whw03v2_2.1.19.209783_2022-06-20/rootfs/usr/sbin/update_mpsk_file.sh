#!/bin/sh

UPDATE=-1
INTERFACE=""

usage()
{
    echo "The script is to update passphrase and MAC address in mPSK file of interface"
    echo "./update_mpsk_file.sh -d|-a -i interface -m MAC -p passphrase"
    echo "      -d: delete the pair of MAC and passphrase into interface's mPSK file"
    echo "      -a: add the pair of MAC and passphrase into interface's mPSK file"
    echo "      -i: interface selection: ath0, ath1, ath10..."
    echo "      -m: MAC address to be updated in mPSK file"
    echo "      -p: passphrase to be updated in mPSK file"
    exit 1;

}

handle_update_mpsk()
{
    INTERFACE_CONFIG="/tmp/hostapd-${INTERFACE}.conf"
    if [ ! -e "$INTERFACE_CONFIG" ]
    then
        echo "Interface config file doesn't exist"
        exit 1
    fi
    MPSK_FILE=`cat $INTERFACE_CONFIG | grep "wpa_psk_file" | awk -F"=" '{print $2}'`
    if [ -z "$MPSK_FILE" ]
    then
        echo "The interface hasn't mPSK file"
    fi
    TARGET="${MAC} ${PASS}"
    if [ $UPDATE -eq 1 ]
    then
        echo "$TARGET" >> $MPSK_FILE
    else
        if [ -n "$(grep "${TARGET}" ${MPSK_FILE})" ]
        then
            echo "$(awk "!/${TARGET}/" $MPSK_FILE)" > $MPSK_FILE
        else
            echo "There is no deleted information in $MPSK_FILE file"
        fi
    fi

}
while [ $# -gt 0 ]
do
    key="$1"

    case $key in
        -d|--delete)
            if [ $UPDATE -eq -1 ]
            then
                UPDATE=0
            else
                usage
            fi
            shift
            ;;
        -a|--add)
            if [ $UPDATE -eq -1 ]
            then
                UPDATE=1
            else
                usage
            fi
            shift
            ;;
        -i|--interface)
            INTERFACE="$2"
            shift
            shift
            ;;
        -m|mac)
            MAC="$2"
            shift
            shift
            ;;
        -p|passphrase)
            PASS="$2"
            shift
            shift
            ;;
        *|-h|--help)
            usage
            ;;
    esac
done

if [ $UPDATE -eq -1 ] || [ -z $INTERFACE ] || [ -z $MAC ] || [ -z $PASS ]
then
    usage
fi

handle_update_mpsk

