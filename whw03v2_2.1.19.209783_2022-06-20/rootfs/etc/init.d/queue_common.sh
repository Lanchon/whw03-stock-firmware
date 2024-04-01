PKG_NAME="senq"
PROGNAME=$(basename $0)
errout () {
    echo "$*" 1>&2
}
debout () {
    [ "$DEBUG" ] && errout $*
}
[ -z "$Q_FILE"    ] && Q_FILE="/tmp/$PKG_NAME"
[ -z "$TMP_FILE"  ] && TMP_FILE="$Q_FILE.tmp"
[ -z "$LOCK_FILE" ] && LOCK_FILE="/var/lock/$PKG_NAME"
flockit() {
    flock 9 || die "Lock fail"
}
debout "Note: \$PROGNAME is $PROGNAME"
debout "Note: \$0 is $0"
debout "Note: LOCK_FILE is $LOCK_FILE"
die() {
    errout "$PROGNAME: " $*
    exit 1
}
enqueue() {
    (
        flockit
        debout "Running with the lock"
        echo "$1" >> $Q_FILE
        debout "Releasing lock"
    ) 9>$LOCK_FILE
}
capped_enqueue() {
    (
        flockit
        debout "Running with the lock"
        MAX_LINES="$1"
        DATA="$2"
        ( cat $Q_FILE 2>/dev/null ; echo "$DATA" ) | \
            tail -n $MAX_LINES > $TMP_FILE && \
            mv $TMP_FILE $Q_FILE
        debout "Releasing lock"
    ) 9>$LOCK_FILE
}
extract_all() {
    (
        flockit
        debout "Running with the lock"
        if [ -f "$Q_FILE" ]; then
            debout mv $Q_FILE $TMP_FILE
            mv $Q_FILE $TMP_FILE
            debout touch $Q_FILE
            touch $Q_FILE
            debout cat $TMP_FILE
            cat $TMP_FILE | sort | uniq
            debout rm $TMP_FILE
            rm $TMP_FILE
        fi
        debout "Releasing lock"
    ) 9>$LOCK_FILE
}
