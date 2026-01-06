#!/system/bin/sh

MODPATH="/data/adb/modules/zapret"
REFRESH=$(cat "$MODPATH/config/dnscrypt-rules-fix" 2>/dev/null || echo "0")

setup() {
  INTERFACE_ONLY=$(cat "$MODPATH/config/interface-only" 2>/dev/null || echo "")
  IGNORE_DNSCRYPT=$(cat "$MODPATH/config/interface-ignore-dnscrypt" 2>/dev/null || echo "0")
  if [ "$IGNORE_DNSCRYPT" = "1" ]; then
    return 0
  fi
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
  echo 1 >/proc/sys/net/ipv4/conf/all/route_localnet
  add_rule() {
    local cmd=$1 table=$2 chain=$3 match=$4 proto=$5
    shift 5
    if [ -n "$match" ]; then
      $cmd -t "$table" -C "$chain" $match -p "$proto" "$@" 2>/dev/null || \
      $cmd -t "$table" -A "$chain" $match -p "$proto" "$@"
    else
      $cmd -t "$table" -C "$chain" -p "$proto" "$@" 2>/dev/null || \
      $cmd -t "$table" -A "$chain" -p "$proto" "$@"
    fi
  }
  for proto in udp tcp; do
    add_rule iptables nat PREROUTING "$IPT_MATCH_PREROUTING" "$proto" --dport 53 -j DNAT --to-destination 127.0.0.1:5253
    add_rule iptables nat OUTPUT "$IPT_MATCH_OUTPUT" "$proto" --dport 53 -j DNAT --to-destination 127.0.0.1:5253
    add_rule iptables nat FORWARD "$IPT_MATCH_FORWARD_IN" "$proto" --dport 53 -j DNAT --to-destination 127.0.0.1:5253
    if [ "$IPT_MATCH_FORWARD_OUT" != "$IPT_MATCH_FORWARD_IN" ]; then
      add_rule iptables nat FORWARD "$IPT_MATCH_FORWARD_OUT" "$proto" --dport 53 -j DNAT --to-destination 127.0.0.1:5253
    fi
    add_rule ip6tables nat PREROUTING "$IPT_MATCH_PREROUTING" "$proto" --dport 53 -j REDIRECT --to-ports 5253
    add_rule ip6tables nat OUTPUT "$IPT_MATCH_OUTPUT" "$proto" --dport 53 -j REDIRECT --to-ports 5253
    add_rule ip6tables nat FORWARD "$IPT_MATCH_FORWARD_IN" "$proto" --dport 53 -j REDIRECT --to-ports 5253
    if [ "$IPT_MATCH_FORWARD_OUT" != "$IPT_MATCH_FORWARD_IN" ]; then
      add_rule ip6tables nat FORWARD "$IPT_MATCH_FORWARD_OUT" "$proto" --dport 53 -j REDIRECT --to-ports 5253
    fi
    add_rule iptables filter OUTPUT "$IPT_MATCH_OUTPUT" "$proto" --dport 853 -j DROP
    add_rule iptables filter FORWARD "$IPT_MATCH_FORWARD_IN" "$proto" --dport 853 -j DROP
    if [ "$IPT_MATCH_FORWARD_OUT" != "$IPT_MATCH_FORWARD_IN" ]; then
      add_rule iptables filter FORWARD "$IPT_MATCH_FORWARD_OUT" "$proto" --dport 853 -j DROP
    fi
    add_rule ip6tables filter OUTPUT "$IPT_MATCH_OUTPUT" "$proto" --dport 853 -j DROP
    add_rule ip6tables filter FORWARD "$IPT_MATCH_FORWARD_IN" "$proto" --dport 853 -j DROP
    if [ "$IPT_MATCH_FORWARD_OUT" != "$IPT_MATCH_FORWARD_IN" ]; then
      add_rule ip6tables filter FORWARD "$IPT_MATCH_FORWARD_OUT" "$proto" --dport 853 -j DROP
    fi
  done
}

start_bg(){
  [ -x "$MODPATH/dnscrypt/make-unkillable.sh" ] && nohup sh "$MODPATH/dnscrypt/make-unkillable.sh" >/dev/null 2>&1 &
  [ -x "$MODPATH/dnscrypt/dnscrypt-proxy" ] || { echo "dnscrypt-proxy not found" >&2; exit 1; }
  pgrep -x dnscrypt-proxy >/dev/null || "$MODPATH/dnscrypt/dnscrypt-proxy" >/dev/null 2>&1 &
}

start_fg(){
  [ -x "$MODPATH/dnscrypt/make-unkillable.sh" ] && nohup sh "$MODPATH/dnscrypt/make-unkillable.sh" >/dev/null 2>&1 &
  [ -x "$MODPATH/dnscrypt/dnscrypt-proxy" ] || { echo "dnscrypt-proxy not found" >&2; exit 1; }
  "$MODPATH/dnscrypt/dnscrypt-proxy" >/dev/null 2>&1
}

if [ "$REFRESH" = "1" ]; then
  while true; do
    setup
    start_bg
    sleep 5
  done
else
  while true; do
    setup
    start_fg
    sleep 5
  done
fi
