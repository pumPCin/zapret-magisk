#!/system/bin/sh
MODPATH="/data/adb/modules/zapret"
SELF="$$"
PARENT="$PPID"
SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
PIDS_FROM_DIR="$(pgrep -f "$MODPATH" 2>/dev/null || true)"

kill_processes() {
    local pattern="$1"
    [ -z "$pattern" ] && return 0
    local pids
    pids="$(pgrep $pattern 2>/dev/null || true)"
    for pid in $pids; do
        [ -z "$pid" ] && continue
        if [ -d "/proc/$pid" ]; then
            renice -n 0 -p "$pid" 2>/dev/null
            if [ -w "/proc/$pid/oom_score_adj" ]; then
                echo 0 > "/proc/$pid/oom_score_adj"
            elif [ -w "/proc/$pid/oom_adj" ]; then
                echo 0 > "/proc/$pid/oom_adj"
            fi
            kill -9 "$pid" 2>/dev/null
            while [ -d "/proc/$pid" ]; do
                sleep 0.2
            done
            echo "- Killed process, ID: $pid"
        fi
    done
}
remove_rules_by_pattern() {
    local cmd="$1"
    local table="$2"
    local chain="$3"
    local pattern="$4"
    while true; do
        local rule=$($cmd -t "$table" -S "$chain" 2>/dev/null | grep -F -- "$pattern" | head -n1)
        [ -z "$rule" ] && break
        local spec=${rule#-A $chain }
        $cmd -t "$table" -D "$chain" $spec 2>/dev/null || break
    done
}

remove_dnscrypt_rules() {
    remove_rules_by_pattern iptables nat PREROUTING "--dport 53 -j DNAT --to-destination 127.0.0.1:5253"
    remove_rules_by_pattern iptables nat OUTPUT "--dport 53 -j DNAT --to-destination 127.0.0.1:5253"
    remove_rules_by_pattern iptables nat FORWARD "--dport 53 -j DNAT --to-destination 127.0.0.1:5253"

    remove_rules_by_pattern ip6tables nat PREROUTING "--dport 53 -j REDIRECT --to-ports 5253"
    remove_rules_by_pattern ip6tables nat OUTPUT "--dport 53 -j REDIRECT --to-ports 5253"
    remove_rules_by_pattern ip6tables nat FORWARD "--dport 53 -j REDIRECT --to-ports 5253"

    remove_rules_by_pattern iptables filter OUTPUT "--dport 853 -j DROP"
    remove_rules_by_pattern iptables filter FORWARD "--dport 853 -j DROP"

    remove_rules_by_pattern ip6tables filter OUTPUT "--dport 853 -j DROP"
    remove_rules_by_pattern ip6tables filter FORWARD "--dport 853 -j DROP"
}
for pid in $PIDS_FROM_DIR; do
    [ "$pid" = "$SELF" ] && continue
    [ "$pid" = "$PARENT" ] && continue
    if [ -r "/proc/$pid/cmdline" ] && \
       tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
        continue
    fi
    if [ -d "/proc/$pid" ]; then
        renice -n 0 -p "$pid" 2>/dev/null
        if [ -w "/proc/$pid/oom_score_adj" ]; then
            echo 0 > "/proc/$pid/oom_score_adj"
        elif [ -w "/proc/$pid/oom_adj" ]; then
            echo 0 > "/proc/$pid/oom_adj"
        fi
        kill -9 "$pid" 2>/dev/null
        while [ -d "/proc/$pid" ]; do
            sleep 0.2
        done
        echo "- Killed process, ID: $pid"
    fi
done
kill_processes "-x nfqws"
kill_processes "-x dnscrypt-proxy"
for iface in all default lo; do
    resetprop net.ipv6.conf.$iface.disable_ipv6 0 > /dev/null 2>&1 &
    resetprop net.ipv6.conf.$iface.accept_redirects 1 > /dev/null 2>&1 &
done
sysctl net.netfilter.nf_conntrack_tcp_be_liberal=0 > /dev/null 2>&1 &
sysctl net.netfilter.nf_conntrack_checksum=1 > /dev/null 2>&1 &
echo 0 > /proc/sys/net/ipv4/conf/all/route_localnet
remove_dnscrypt_rules
for chain in PREROUTING POSTROUTING; do
  remove_rules_by_pattern iptables mangle "$chain" "NFQUEUE --queue-num 200 --queue-bypass"
  remove_rules_by_pattern ip6tables mangle "$chain" "NFQUEUE --queue-num 200 --queue-bypass"
done
sh "$MODPATH/dnscrypt/custom-files.sh" disappend > /dev/null 2>&1
