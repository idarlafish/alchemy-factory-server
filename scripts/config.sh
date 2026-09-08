#!/usr/bin/env bash
# Renders "Server Config.ini" from environment variables.
#
#   CFG_<key>=<value>   -> "<key> = <value>"   (verbatim, for keys we don't know yet)
#   friendly aliases    -> mapped to their documented ini keys
#
# Any key upstream adds later is usable immediately via CFG_ without a new image.
set -euo pipefail

CONFIG_FILE="${1:?config path required}"
declare -A cfg=()

alias_map=(
  "SERVER_LAN:server_lan"
  "SERVER_RELAY:server_relay"
  "SERVER_PUBLIC:server_public"
  "SERVER_NAME:server_name"
  "SERVER_PASSWORD:server_password"
  "ADMIN_PASSWORD:admin_password"
  "SERVER_PORT:server_port"
  "MAX_PLAYERS:max_players"
)

for pair in "${alias_map[@]}"; do
  env_name="${pair%%:*}"; ini_key="${pair##*:}"
  value="${!env_name-}"
  [ -n "$value" ] && cfg["$ini_key"]="$value"
done

# CFG_ passthrough wins over aliases so it can always override.
while IFS='=' read -r name value; do
  case "$name" in
    CFG_*) cfg["${name#CFG_}"]="$value" ;;
  esac
done < <(env)

if [ "${#cfg[@]}" -eq 0 ]; then
  echo "config: no overrides set, leaving $CONFIG_FILE as generated"
  exit 0
fi

tmp="$(mktemp)"
for key in "${!cfg[@]}"; do
  printf '%s = %s\n' "$key" "${cfg[$key]}"
done | sort > "$tmp"

# Preserve keys the server generated that we aren't overriding.
if [ -f "$CONFIG_FILE" ]; then
  while IFS= read -r line; do
    key="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*\([A-Za-z0-9_]\+\)[[:space:]]*=.*/\1/p')"
    [ -n "$key" ] || continue
    [ -n "${cfg[$key]-}" ] && continue
    printf '%s\n' "$line" >> "$tmp"
  done < "$CONFIG_FILE"
fi

mv "$tmp" "$CONFIG_FILE"
echo "config: wrote $CONFIG_FILE"
sed 's/\(password[[:space:]]*=[[:space:]]*\).*/\1***/I' "$CONFIG_FILE"
