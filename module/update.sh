#!/bin/sh
set +e

MODPATH="/data/adb/modules/zapret"
if [ ! -x "$MODPATH/curl" ]; then
    echo "curl command not found: $MODPATH/curl" >&2
    exit 1
fi
DNSCRYPTLISTSDIR="$MODPATH/dnscrypt"
ZAPRETLISTSDIR="$MODPATH/list"
ZAPRETIPSETSDIR="$MODPATH/ipset"
IPV6ENABLE=$(cat "$MODPATH/config/ipv6-enable" 2>/dev/null || echo "0")
CLOAKINGUPDATE=$(cat "$MODPATH/config/dnscrypt-cloaking-rules-update" 2>/dev/null || echo "0")
BLOCKEDUPDATE=$(cat "$MODPATH/config/dnscrypt-blocked-names-update" 2>/dev/null || echo "0")
BLOCKEDIPSUPDATE=$(cat "$MODPATH/config/dnscrypt-blocked-ips-update" 2>/dev/null || echo "0")
read_link_config() {
    default_value="$1"
    shift
    for name in "$@"; do
        file="$MODPATH/config/$name"
        if [ -f "$file" ] && grep -q '[^[:space:]]' "$file" 2>/dev/null; then
            cat "$file"
            return
        fi
    done
    printf '%s\n' "$default_value"
}

DNSCRYPTFILES_cloaking_rules=$(read_link_config "https://raw.githubusercontent.com/sevcator/dnscrypt-proxy-stuff/refs/heads/main/cloaking-rules-2.txt" dnscrypt-cloaking-rules-link custom-cloaking-rules-url)
DNSCRYPTFILES_blocked_names=$(read_link_config "https://raw.githubusercontent.com/sevcator/dnscrypt-proxy-stuff/refs/heads/main/blocked-yandex.txt" dnscrypt-blocked-names-link custom-blocked-names-url)
DNSCRYPTFILES_blocked_ips=$(read_link_config "https://raw.githubusercontent.com/sevcator/dnscrypt-proxy-stuff/refs/heads/main/blocked-ips.txt" dnscrypt-blocked-ips-link custom-blocked-ips-url)
CUSTOMLINKIPSETV4=$(read_link_config "https://raw.githubusercontent.com/sevcator/zapret-lists/refs/heads/main/ipset-v4.txt" ipset-v4-link custom-ipv4-ranges-url)
CUSTOMLINKIPSETV6=$(read_link_config "https://raw.githubusercontent.com/sevcator/zapret-lists/refs/heads/main/ipset-v6.txt" ipset-v6-link custom-ipv6-ranges-url)
CUSTOMLINKREESTR=$(read_link_config "https://raw.githubusercontent.com/sevcator/zapret-lists/refs/heads/main/reestr_filtered.txt" reestr-link custom-rkn-registry-url)

PREDEFINED_LIST_FILES="reestr.txt default.txt google.txt"
PREDEFINED_IPSET_FILES="ipset-v4.txt ipset-v6.txt"
ZAPRETLISTSDEFAULTLINK="https://raw.githubusercontent.com/sevcator/zapret-pocket/refs/heads/main/module/list/"
ZAPRETIPSETSDEFAULTLINK="https://raw.githubusercontent.com/sevcator/zapret-pocket/refs/heads/main/module/ipset/"
IGNORE_FILES="custom.txt exclude.txt"
get_overwrite_url() {
    file="$1"
    case "$file" in
        "reestr.txt") echo "$CUSTOMLINKREESTR" ;;
        "ipset-v4.txt") echo "$CUSTOMLINKIPSETV4" ;;
        "ipset-v6.txt") echo "$CUSTOMLINKIPSETV6" ;;
        *) echo "" ;;
    esac
}

get_dnscrypt_filename() {
    url="$1"
    stripped="${url%%\?*}"
    stripped="${stripped%%#*}"
    basename "${stripped}"
}

resolve_dnscrypt_target() {
    name="$1"
    case "$name" in
        cloaking-rules.txt) echo "$DNSCRYPTLISTSDIR/cloaking-rules.txt" ;;
        blocked-ips.txt) echo "$DNSCRYPTLISTSDIR/blocked-ips.txt" ;;
        allowed-names.txt) echo "$DNSCRYPTLISTSDIR/custom-allowed-names.txt" ;;
        allowed-ips.txt) echo "$DNSCRYPTLISTSDIR/custom-allowed-ips.txt" ;;
        *) return 1 ;;
    esac
}

update_dnscrypt_file_from_link() {
    link="$1"
    [ -n "$link" ] || return 1
    name=$(get_dnscrypt_filename "$link")
    target=$(resolve_dnscrypt_target "$name" 2>/dev/null)
    if [ -z "$target" ]; then
        name=${name:-unknown}
        echo "[ $name ] Unsupported"
        return 1
    fi
    update_file "$target" "$link"
}

update_file() {
    file="$1"
    url="$2"
    name=$(basename "$file")

    tmp_file="${file}.tmp"
    for _ in 1 2 3 4 5; do
        if "$MODPATH/curl" -fsSL -o "$tmp_file" "$url" >/dev/null 2>&1; then
            if [ ! -f "$file" ] || ! cmp -s "$tmp_file" "$file"; then
                mv "$tmp_file" "$file"
                echo "[ $name ] Downloaded"
            else
                rm -f "$tmp_file"
                echo "[ $name ] Unchanged"
            fi
            return
        fi
    done
    rm -f "$tmp_file"
    echo "[ $name ] Failed"
}

update_dir() {
    dir="$1"
    base_url="$2"
    predefined_files="$3"

    mkdir -p "$dir"
    updated_files=""

    for file_path in "$dir"/*; do
        [ -f "$file_path" ] || continue
        file_name=$(basename "$file_path")

        case " $IGNORE_FILES " in
            *" $file_name "*) continue ;;
        esac
        case " $updated_files " in
            *" $file_name "*) continue ;;
        esac

        if [ "$dir" = "$ZAPRETIPSETSDIR" ]; then
            url=$(get_overwrite_url "$file_name")
            url="${url:-${base_url}${file_name}}"
        else
            url="${base_url}${file_name}"
        fi

        update_file "$file_path" "$url"
        updated_files="$updated_files $file_name"
    done

    for file_name in $predefined_files; do
        case " $IGNORE_FILES " in
            *" $file_name "*) continue ;;
        esac
        case " $updated_files " in
            *" $file_name "*) continue ;;
        esac

        file_path="$dir/$file_name"
        if [ "$dir" = "$ZAPRETIPSETSDIR" ]; then
            url=$(get_overwrite_url "$file_name")
            url="${url:-${base_url}${file_name}}"
        else
            url="${base_url}${file_name}"
        fi

        update_file "$file_path" "$url"
        updated_files="$updated_files $file_name"
    done
}

if [ "$IPV6ENABLE" != "1" ]; then
    sh "$MODPATH/dnscrypt/custom-files.sh" disappend > /dev/null 2>&1 &
    sleep 2
fi

update_dir "$ZAPRETLISTSDIR" "$ZAPRETLISTSDEFAULTLINK" "$PREDEFINED_LIST_FILES"
update_dir "$ZAPRETIPSETSDIR" "$ZAPRETIPSETSDEFAULTLINK" "$PREDEFINED_IPSET_FILES"

[ "$IPV6ENABLE" != "1" ] && [ "$CLOAKINGUPDATE" = "1" ] && update_dnscrypt_file_from_link "$DNSCRYPTFILES_cloaking_rules"
[ "$IPV6ENABLE" != "1" ] && [ "$BLOCKEDUPDATE" = "1" ] && update_file "$DNSCRYPTLISTSDIR/blocked-names.txt" "$DNSCRYPTFILES_blocked_names"
[ "$IPV6ENABLE" != "1" ] && [ "$BLOCKEDIPSUPDATE" = "1" ] && update_dnscrypt_file_from_link "$DNSCRYPTFILES_blocked_ips"

if [ "$IPV6ENABLE" != "1" ]; then
    sh "$MODPATH/dnscrypt/custom-files.sh" append > /dev/null 2>&1 &
    sleep 2
fi
