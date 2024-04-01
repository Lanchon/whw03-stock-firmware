parse_thrulay_test () {
    local TSEP="/"
    local TDATA="$1"
    local FIELD="$2"
    if [ "$TDATA" ]; then
        case $FIELD in
            rate)      FIELD=1 ;;
            jitter)    FIELD=2 ;;
            delay)     FIELD=3 ;;
            parent_ip) FIELD=4 ;;
            timestamp) FIELD=5 ;;
            *) conslog "parse_thrulay_test: Unknown field '$FIELD'" ; exit 1 ;;
        esac
        echo $TDATA | cut -f$FIELD -d$TSEP
    else
        conslog "parse_thrulay_test: No data to parse"
        exit 1
    fi
}
