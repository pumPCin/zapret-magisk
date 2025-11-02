#!/system/bin/sh
MODPATH="/data/adb/modules/zapret"
SELF="$$"
PARENT="$PPID"
SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
PIDS_FROM_DIR="$(pgrep -f "$MODPATH" 2>/dev/null || true)"
INTERFACE_ONLY=$(cat "$MODPATH/config/interface-only" 2>/dev/null || echo "")
IGNORE_DNSCRYPT=$(cat "$MODPATH/config/interface-ignore-dnscrypt" 2>/dev/null || echo "0")
remove_rules_by_pattern() {
    local cmd="$1"
    local table="$2"
    local chain="$3"
    local pattern="$4"
    while true; do
        local rule=$($cmd -t "$table" -S "$chain" 2>/dev/null | grep -F "$pattern" | head -n1)
        [ -z "$rule" ] && break
        local spec=${rule#-A $chain }
        $cmd -t "$table" -D "$chain" $spec 2>/dev/null || break
    done
}

remove_dnscrypt_rule() {
    local cmd=$1 table=$2 chain=$3 match=$4 proto=$5
    shift 5
    while true; do
        if [ -n "$match" ]; then
            $cmd -t "$table" -D "$chain" $match -p "$proto" "$@" 2>/dev/null || break
        else
            $cmd -t "$table" -D "$chain" -p "$proto" "$@" 2>/dev/null || break
        fi
    done
}

remove_dnscrypt_rules() {
    if [ "$IGNORE_DNSCRYPT" = "1" ]; then
        return
    fi

    local IPT_MATCH_PREROUTING IPT_MATCH_OUTPUT IPT_MATCH_FORWARD_IN IPT_MATCH_FORWARD_OUT

    if [ -n "$INTERFACE_ONLY" ]; then
        IPT_MATCH_PREROUTING="-i $INTERFACE_ONLY"
        IPT_MATCH_OUTPUT="-o $INTERFACE_ONLY"
        IPT_MATCH_FORWARD_IN="-i $INTERFACE_ONLY"
        IPT_MATCH_FORWARD_OUT="-o $INTERFACE_ONLY"
    else
        IPT_MATCH_PREROUTING=""
        IPT_MATCH_OUTPUT=""
        IPT_MATCH_FORWARD_IN=""
        IPT_MATCH_FORWARD_OUT=""
    fi

    for proto in udp tcp; do
        remove_dnscrypt_rule iptables nat PREROUTING "$IPT_MATCH_PREROUTING" "$proto" --dport 53 -j DNAT --to-destination 127.0.0.1:5253
        remove_dnscrypt_rule iptables nat OUTPUT "$IPT_MATCH_OUTPUT" "$proto" --dport 53 -j DNAT --to-destination 127.0.0.1:5253
        remove_dnscrypt_rule iptables nat FORWARD "$IPT_MATCH_FORWARD_IN" "$proto" --dport 53 -j DNAT --to-destination 127.0.0.1:5253
        if [ "$IPT_MATCH_FORWARD_OUT" != "$IPT_MATCH_FORWARD_IN" ]; then
            remove_dnscrypt_rule iptables nat FORWARD "$IPT_MATCH_FORWARD_OUT" "$proto" --dport 53 -j DNAT --to-destination 127.0.0.1:5253
        fi

        remove_dnscrypt_rule ip6tables nat PREROUTING "$IPT_MATCH_PREROUTING" "$proto" --dport 53 -j REDIRECT --to-ports 5253
        remove_dnscrypt_rule ip6tables nat OUTPUT "$IPT_MATCH_OUTPUT" "$proto" --dport 53 -j REDIRECT --to-ports 5253
        remove_dnscrypt_rule ip6tables nat FORWARD "$IPT_MATCH_FORWARD_IN" "$proto" --dport 53 -j REDIRECT --to-ports 5253
        if [ "$IPT_MATCH_FORWARD_OUT" != "$IPT_MATCH_FORWARD_IN" ]; then
            remove_dnscrypt_rule ip6tables nat FORWARD "$IPT_MATCH_FORWARD_OUT" "$proto" --dport 53 -j REDIRECT --to-ports 5253
        fi

        remove_dnscrypt_rule iptables filter OUTPUT "$IPT_MATCH_OUTPUT" "$proto" --dport 853 -j DROP
        remove_dnscrypt_rule iptables filter FORWARD "$IPT_MATCH_FORWARD_IN" "$proto" --dport 853 -j DROP
        if [ "$IPT_MATCH_FORWARD_OUT" != "$IPT_MATCH_FORWARD_IN" ]; then
            remove_dnscrypt_rule iptables filter FORWARD "$IPT_MATCH_FORWARD_OUT" "$proto" --dport 853 -j DROP
        fi

        remove_dnscrypt_rule ip6tables filter OUTPUT "$IPT_MATCH_OUTPUT" "$proto" --dport 853 -j DROP
        remove_dnscrypt_rule ip6tables filter FORWARD "$IPT_MATCH_FORWARD_IN" "$proto" --dport 853 -j DROP
        if [ "$IPT_MATCH_FORWARD_OUT" != "$IPT_MATCH_FORWARD_IN" ]; then
            remove_dnscrypt_rule ip6tables filter FORWARD "$IPT_MATCH_FORWARD_OUT" "$proto" --dport 853 -j DROP
        fi
    done
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
sh "$MODPATH/dnscrypt/custom-cloaking-rules.sh" disappend > /dev/null 2>&1
