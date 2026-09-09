#!/usr/bin/env bash
# Renders "Server Config.ini" from the environment.
#
#   CFG_<key>=<value>   -> "<key> = <value>"   (verbatim, for keys we don't know yet)
#   friendly aliases    -> mapped to their documented ini keys
#
# Any key the game gains later is usable immediately via CFG_ without a new image.
set -euo pipefail

CONFIG_FILE="${1:?config path required}"
pairs="$(mktemp)"
trap 'rm -f "$pairs"' EXIT

# env name -> ini key
alias_map="
SERVER_LAN:server_lan
SERVER_RELAY:server_relay
SERVER_PUBLIC:server_public
SERVER_NAME:server_name
SERVER_PASSWORD:server_password
ADMIN_PASSWORD:admin_password
SERVER_PORT:server_port
MAX_PLAYERS:max_players
"

for pair in $alias_map; do
  env_name="${pair%%:*}"
  ini_key="${pair##*:}"
  value="${!env_name-}"
  [ -n "$value" ] && printf '%s\t%s\n' "$ini_key" "$value" >> "$pairs"
done

# Appended last so CFG_ always wins over an alias for the same key.
while IFS='=' read -r name value; do
  case "$name" in
    CFG_*) printf '%s\t%s\n' "${name#CFG_}" "$value" >> "$pairs" ;;
  esac
done < <(env)

if [ ! -s "$pairs" ]; then
  echo "config: no overrides set, leaving $CONFIG_FILE as generated"
  exit 0
fi

out="$(mktemp)"
awk -F'\t' '{last[$1] = $2} END {for (k in last) print k " = " last[k]}' "$pairs" | sort > "$out"

# Keep any key the server generated that we are not overriding.
if [ -f "$CONFIG_FILE" ]; then
  while IFS= read -r line; do
    key="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*\([A-Za-z0-9_]\{1,\}\)[[:space:]]*=.*/\1/p')"
    [ -n "$key" ] || continue
    grep -q "^${key} = " "$out" && continue
    printf '%s\n' "$line" >> "$out"
  done < "$CONFIG_FILE"
fi

mv "$out" "$CONFIG_FILE"
echo "config: wrote $CONFIG_FILE"
sed 's/\(password[[:space:]]*=[[:space:]]*\).*/\1***/I' "$CONFIG_FILE"
