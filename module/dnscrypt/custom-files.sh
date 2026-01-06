#!/system/bin/sh
set -e

MODPATH=/data/adb/modules/zapret
DNSCRYPT_DIR=$MODPATH/dnscrypt

FILES_DEFINITIONS='
cloaking-rules.txt|custom-cloaking-rules.txt|# custom hosts
blocked-names.txt|custom-blocked-names.txt|# custom blocked names
blocked-ips.txt|custom-blocked-ips.txt|# custom blocked ips
allowed-names.txt|custom-allowed-names.txt|# custom allowed names
allowed-ips.txt|custom-allowed-ips.txt|# custom allowed ips
'

ensure_newline() {
  [ -f "$1" ] || return 0
  [ -s "$1" ] || return 0
  [ "$(tail -c1 "$1")" = "" ] && return 0
  printf "\n" >> "$1"
}

append_file() {
  base_name="$1"
  custom_name="$2"
  marker="$3"

  base_file="$DNSCRYPT_DIR/$base_name"
  custom_file="$DNSCRYPT_DIR/$custom_name"

  [ -f "$custom_file" ] || return 0

  mkdir -p "$(dirname "$base_file")"
  touch "$base_file"

  grep -Fxq "$marker" "$base_file" 2>/dev/null && return 0

  ensure_newline "$base_file"

  add_separator=0
  if [ -s "$base_file" ] && [ -n "$(tail -n1 "$base_file")" ]; then
    add_separator=1
  fi

  {
    [ "$add_separator" -eq 1 ] && printf "\n"
    printf "%s\n" "$marker"
    cat "$custom_file"
  } >> "$base_file"

  ensure_newline "$base_file"
}

escape_sed_delim() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

disappend_file() {
  base_name="$1"
  marker="$2"

  base_file="$DNSCRYPT_DIR/$base_name"
  [ -f "$base_file" ] || return 0

  escaped_marker=$(escape_sed_delim "$marker")
  tmp_file="${base_file}.tmp"
  if grep -Fxq "$marker" "$base_file" 2>/dev/null; then
    sed "/^${escaped_marker}$/,\$d" "$base_file" > "$tmp_file"
    mv "$tmp_file" "$base_file"
  fi
}

append() {
  printf '%s\n' "$FILES_DEFINITIONS" | while IFS='|' read -r base custom marker; do
    [ -n "$base" ] || continue
    append_file "$base" "$custom" "$marker"
  done
}

disappend() {
  printf '%s\n' "$FILES_DEFINITIONS" | while IFS='|' read -r base _ marker; do
    [ -n "$base" ] || continue
    disappend_file "$base" "$marker"
  done
}

case "$1" in
  append)    append   ;;
  disappend) disappend ;;
  *)         exit 1   ;;
esac
