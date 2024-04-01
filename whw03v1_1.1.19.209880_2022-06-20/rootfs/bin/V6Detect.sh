#!/bin/sh

#conver addr to string lower case
ipaddr="$(echo "$1" | awk '{print tolower($1)}')"
interface=$2

# use [ipaddr] [interface]
if [ -z "${ipaddr}" ]; then
    exit 1
fi

if [ -z "${interface}" ]; then
    interface="br0"
fi

# Ping local address
ping6 -I ${interface} -c1  ${ipaddr}  > /dev/null 2>&1
if [ $? -gt 0 ]; then
    exit 1
fi

# helper to convert hex to dec (portable version)
hex2dec(){
    [ "$1" != "" ] && printf "%d" "$(( 0x$1 ))"
}

# expand an ipv6 address
expand_ipv6() {
    ip=$1

    # prepend 0 if we start with :
    echo $ip | grep -qs "^:" && ip="0${ip}"

    # expand ::
    if echo $ip | grep -qs "::"; then
        colons=$(echo $ip | sed 's/[^:]//g')
        missing=$(echo ":::::::::" | sed "s/$colons//")
        expanded=$(echo $missing | sed 's/:/:0/g')
        ip=$(echo $ip | sed "s/::/$expanded/")
    fi

    blocks=$(echo $ip | grep -o "[0-9a-f]\+")
    set $blocks

    printf "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x\n" \
        $(hex2dec $1) \
        $(hex2dec $2) \
        $(hex2dec $3) \
        $(hex2dec $4) \
        $(hex2dec $5) \
        $(hex2dec $6) \
        $(hex2dec $7) \
        $(hex2dec $8)
}

# returns a compressed ipv6 address under the form recommended by RFC5952
compress_ipv6() {
    ip=$1

    blocks=$(echo $ip | grep -o "[0-9a-f]\+")
    set $blocks

    # compress leading zeros
    ip=$(printf "%x:%x:%x:%x:%x:%x:%x:%x\n" \
        $(hex2dec $1) \
        $(hex2dec $2) \
        $(hex2dec $3) \
        $(hex2dec $4) \
        $(hex2dec $5) \
        $(hex2dec $6) \
        $(hex2dec $7) \
        $(hex2dec $8)
    )

    # prepend : for easier matching
    ip=:$ip

    # :: must compress the longest chain
    for pattern in :0:0:0:0:0:0:0:0 \
            :0:0:0:0:0:0:0 \
            :0:0:0:0:0:0 \
            :0:0:0:0:0 \
            :0:0:0:0 \
            :0:0:0 \
            :0:0 ; do
        if echo $ip | grep -qs $pattern; then
            ip=$(echo $ip | sed "s/$pattern/::/")
            # if the substitution occured before the end, we have :::
            ip=$(echo $ip | sed 's/:::/::/')
            break # only one substitution
        fi
    done

    # remove prepending : if necessary
    echo $ip | grep -qs "^:[^:]" && ip=$(echo $ip | sed 's/://')

    echo $ip
}

uncompress_ipv6=$(expand_ipv6 "${ipaddr}")
ipv6=$(compress_ipv6 "${uncompress_ipv6}")

ret=`ip -6 neigh show | grep ${ipv6} | awk '{print $5}' | head -1`
if [ -z "$ret" ]; then
    exit 1
else
    echo $ret
fi
