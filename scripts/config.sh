#!/usr/bin/env bash
# Renders the server's ServerConfig.ini from the environment.
#
#   CFG_<key>=<value>   -> "<key> = <value>"   (verbatim, for keys we don't know yet)
#   friendly aliases    -> mapped to their documented ini keys
#
# Any key the game gains later is usable immediately via CFG_ without a new image.
set -euo pipefail

CONFIG_FILE="${1:?config path required}"
pairs="$(mktemp)"
merged="$(mktemp)"
out="$(mktemp)"
trap 'rm -f "$pairs" "$merged" "$out"' EXIT

# env name -> ini key
alias_map="
SERVER_LAN:server_lan
SERVER_RELAY:server_relay
SERVER_PUBLIC:server_public
SERVER_NAME:server_name
SERVER_PASSWORD:server_password
ADMIN_PASSWORD:admin_password
SERVER_PORT:server_port
QUERY_PORT:query_port
MAX_PLAYERS:max_clients
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

awk -F'\t' '{last[$1] = $2} END {for (k in last) print k "\t" last[k]}' "$pairs" | sort > "$merged"

# The game ignores every key outside [ServerSettings]; fresh volumes and 0.1.3-0.1.5 files lack it.
if [ ! -f "$CONFIG_FILE" ]; then
  printf '[ServerSettings]\n' > "$CONFIG_FILE"
elif ! grep -q '^\[ServerSettings\]' "$CONFIG_FILE"; then
  { printf '[ServerSettings]\n'; cat "$CONFIG_FILE"; } > "$out"
  cat "$out" > "$CONFIG_FILE"
fi

# Overridden keys change value in place; header, comments and order survive verbatim.
awk -v pairs="$merged" '
  BEGIN {
    while ((getline line < pairs) > 0) {
      sep = index(line, "\t")
      if (sep == 0) continue
      key = substr(line, 1, sep - 1)
      val[key] = substr(line, sep + 1)
      keys[++n] = key
    }
  }
  {
    if (match($0, /^[ \t]*[A-Za-z0-9_]+[ \t]*=/)) {
      key = $0
      sub(/^[ \t]*/, "", key)
      sub(/[ \t]*=.*$/, "", key)
      if (key in val) {
        # Replace the first occurrence, drop any later duplicate of the same key.
        if (!(key in seen)) { print key " = " val[key]; seen[key] = 1 }
        next
      }
    }
    print
  }
  END {
    for (i = 1; i <= n; i++)
      if (!(keys[i] in seen)) { print keys[i] " = " val[keys[i]]; seen[keys[i]] = 1 }
  }
' "$CONFIG_FILE" > "$out"

cat "$out" > "$CONFIG_FILE"
echo "config: wrote $CONFIG_FILE"
sed 's/\(password[[:space:]]*=[[:space:]]*\).*/\1***/I' "$CONFIG_FILE"
