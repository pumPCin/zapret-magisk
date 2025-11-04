MODPATH="/data/adb/modules/zapret"
while true; do
    if ! pgrep -x "nfqws" > /dev/null; then
        . "$MODPATH/zapret/make-unkillable.sh" &
	    "$MODPATH/zapret/nfqws" --uid=0:0 --qnum=200 $config > "$MODPATH/zapret/latest.log"
    fi
    sleep 5
done
