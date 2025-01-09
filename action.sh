#!/system/bin/env sh
if pidof nfqws > /dev/null; then
    echo "AntiZapret stopping..."
    zapret stop
else
    echo "AntiZapret running..."
    zapret start
fi
