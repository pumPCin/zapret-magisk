#!/system/bin/sh

if [ -f /data/adb/modules/antizapret/autostart ]; then
    su -c "antizapret start"
fi
