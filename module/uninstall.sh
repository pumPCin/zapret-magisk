#!/system/bin/sh

MODPATH="/data/adb/modules/zapret"

log() {
    printf '%s\n' "$1"
}

safe_kill() {
    local pid="$1"
    [ -z "$pid" ] && return 0
    [ ! -d "/proc/$pid" ] && return 0

    kill -TERM "$pid" 2>/dev/null || true
    local count=0
    while [ $count -lt 25 ]; do
        [ ! -d "/proc/$pid" ] && return 0
        sleep 0.1
        count=$((count + 1))
    done
    kill -KILL "$pid" 2>/dev/null || true
    while [ -d "/proc/$pid" ]; do
        sleep 0.1
    done
    log "- Terminated process: $pid"
}

kill_by_pattern() {
    local pattern="$1" mode="$2"
    local pids=""
    case "$mode" in
        full)
            pids=$(pgrep -f "$pattern" 2>/dev/null || true)
            ;;
        name)
            pids=$(pgrep -x "$pattern" 2>/dev/null || true)
            ;;
    esac
    for pid in $pids; do
        safe_kill "$pid"
    done
}

for pid in $(pgrep -f "$MODPATH" 2>/dev/null || true); do
    [ "$pid" = "$$" ] && continue
    [ "$pid" = "$PPID" ] && continue
    safe_kill "$pid"
done

kill_by_pattern "dnscrypt-proxy" name
kill_by_pattern "nfqws" name
kill_by_pattern "$MODPATH/dnscrypt/dnscrypt.sh" full
kill_by_pattern "$MODPATH/zapret/zapret.sh" full
kill_by_pattern "make-unkillable.sh" full

restore_property() {
    local key="$1" value="$2"
    resetprop "$key" "$value" > /dev/null 2>&1 || true
}

restore_sysctl() {
    local key="$1" value="$2"
    sysctl -w "$key=$value" > /dev/null 2>&1 || true
}

for iface in all default lo; do
    restore_property "net.ipv6.conf.$iface.disable_ipv6" 0
    restore_property "net.ipv6.conf.$iface.accept_redirects" 1
done

restore_sysctl net.netfilter.nf_conntrack_tcp_be_liberal 0
restore_sysctl net.netfilter.nf_conntrack_checksum 1
restore_sysctl net.ipv4.tcp_timestamps 1

if [ -w /proc/sys/net/ipv4/conf/all/route_localnet ]; then
    echo 0 > /proc/sys/net/ipv4/conf/all/route_localnet
fi

remove_rules_matching() {
    local bin="$1" table="$2" chain="$3" pattern="$4"
    while true; do
        local rule
        rule=$($bin -t "$table" -S "$chain" 2>/dev/null | grep -F -- "$pattern" | head -n 1)
        [ -z "$rule" ] && break
        $bin -t "$table" -D "$chain" ${rule#-A $chain } 2>/dev/null || break
    done
}

for proto in udp tcp; do
    remove_rules_matching iptables nat PREROUTING "--dport 53 -j DNAT --to-destination 127.0.0.1:5253"
    remove_rules_matching iptables nat OUTPUT "--dport 53 -j DNAT --to-destination 127.0.0.1:5253"
    remove_rules_matching iptables nat FORWARD "--dport 53 -j DNAT --to-destination 127.0.0.1:5253"

    remove_rules_matching ip6tables nat PREROUTING "--dport 53 -j REDIRECT --to-ports 5253"
    remove_rules_matching ip6tables nat OUTPUT "--dport 53 -j REDIRECT --to-ports 5253"
    remove_rules_matching ip6tables nat FORWARD "--dport 53 -j REDIRECT --to-ports 5253"

    remove_rules_matching iptables filter OUTPUT "--dport 853 -j DROP"
    remove_rules_matching iptables filter FORWARD "--dport 853 -j DROP"
    remove_rules_matching iptables filter INPUT "--dport 853 -j DROP"

    remove_rules_matching ip6tables filter OUTPUT "--dport 853 -j DROP"
    remove_rules_matching ip6tables filter FORWARD "--dport 853 -j DROP"
    remove_rules_matching ip6tables filter INPUT "--dport 853 -j DROP"
done

for chain in PREROUTING POSTROUTING; do
    remove_rules_matching iptables mangle "$chain" "NFQUEUE --queue-num 200 --queue-bypass"
    remove_rules_matching ip6tables mangle "$chain" "NFQUEUE --queue-num 200 --queue-bypass"
    remove_rules_matching iptables mangle "$chain" "NFQUEUE num 200"
    remove_rules_matching ip6tables mangle "$chain" "NFQUEUE num 200"
done

sh "$MODPATH/dnscrypt/custom-files.sh" disappend > /dev/null 2>&1 || true

exit 0
