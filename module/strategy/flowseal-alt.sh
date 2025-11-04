# Zapret Configuration
# >.<

config="--filter-tcp=443 --hostlist=$MODPATH/list/google.txt --ip-id=zero --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls=$MODPATH/fake/tls_clienthello_www_google_com.bin --new"
config="$config --filter-tcp=80,443 --hostlist=$MODPATH/list/default.txt --hostlist=$MODPATH/list/reestr.txt --hostlist=$MODPATH/list/custom.txt --hostlist-exclude=$MODPATH/list/exclude.txt --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls=$MODPATH/fake/tls_clienthello_www_google_com.bin --new"
config="$config --filter-tcp=80,443 --ipset=$MODPATH/ipset/ipset-v4.txt --ipset=$MODPATH/ipset/ipset-v6.txt --ipset=$MODPATH/ipset/custom.txt --ipset-exclude=$MODPATH/ipset/exclude.txt --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls=$MODPATH/fake/tls_clienthello_www_google_com.bin --dup=2 --dup-cutoff=n3 --new"
config="$config --filter-udp=443 --ipset=$MODPATH/ipset/ipset-v4.txt --ipset=$MODPATH/ipset/ipset-v6.txt --ipset=$MODPATH/ipset/custom.txt --ipset-exclude=$MODPATH/ipset/exclude.txt --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic=$MODPATH/fake/quic_initial_www_google_com.bin --new"
config="$config --filter-udp=80,443 --hostlist=$MODPATH/list/default.txt --hostlist=$MODPATH/list/reestr.txt --hostlist=$MODPATH/list/custom.txt --hostlist-exclude=$MODPATH/list/exclude.txt --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic=$MODPATH/fake/quic_initial_www_google_com.bin --new"

if [ "$(cat "$MODPATH/config/bypass-calls" 2>/dev/null || echo 0)" = "1" ]; then
   config="$config --filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls=$MODPATH/fake/tls_clienthello_www_google_com.bin --new"
   config="$config --filter-udp=19294,19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --new"
   config="$config --filter-l3=ipv4 --filter-udp=1400 --filter-l7=stun,unknown --dpi-desync=fake --dpi-desync-autottl --dup=2 --dup-autottl --dup-cutoff=n3 --new"
   config="$config --filter-l3=ipv6 --filter-udp=1400 --filter-l7=stun,unknown --dpi-desync=fake --dpi-desync-autottl6 --dup=2 --dup-autottl6 --dup-cutoff=n3"
fi
