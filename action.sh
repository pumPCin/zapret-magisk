#!/system/bin/env sh
if pidof nfqws > /dev/null; then
    zapret stop
else
    zapret start
fi
