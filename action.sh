#!/system/bin/env sh

arch=$(uname -m)

case "$arch" in
    "x86_64")
        nfqws="nfqws_x86_64"
        ;;
    "i386"|"i686")
        nfqws="nfqws_x86"
        ;;
    "armv7l"|"arm"|"armv8l")
        nfqws="nfqws_arm32"
        ;;
    "aarch64")
        nfqws="nfqws_arm64"
        ;;
    "mips")
        nfqws="nfqws_mips"
        ;;
    "mipsel")
        nfqws="nfqws_mipsel"
        ;;
    *)
        echo "Unknown arch: $arch"
        exit 1
        ;;
esac

if pidof "$nfqws" > /dev/null; then
    echo "AntiZapret stopping..."
    zapret stop
else
    echo "AntiZapret running..."
    zapret start
fi
