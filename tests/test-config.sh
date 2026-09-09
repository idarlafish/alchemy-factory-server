#!/usr/bin/env bash
# Verifies that config.sh renders "Server Config.ini" correctly from the
# environment. Pure file/string logic, so it runs anywhere.
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/config.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0

check() { # name expected_line file
  if grep -qxF "$2" "$3"; then
    echo "  ok: $1"
  else
    echo "  FAIL: $1 — expected '$2'"; sed 's/^/       /' "$3"; fails=$((fails + 1))
  fi
}
absent() {
  if grep -qF "$2" "$3"; then
    echo "  FAIL: $1 — '$2' should be absent"; fails=$((fails + 1))
  else
    echo "  ok: $1"
  fi
}

echo "friendly aliases map to ini keys"
( SERVER_PUBLIC=1 SERVER_RELAY=0 ADMIN_PASSWORD=secret "$SCRIPT" "$tmp/a.ini" >/dev/null )
check "server_public"  "server_public = 1"    "$tmp/a.ini"
check "server_relay"   "server_relay = 0"     "$tmp/a.ini"
check "admin_password" "admin_password = secret" "$tmp/a.ini"

echo "CFG_ passthrough writes unknown keys verbatim"
( CFG_some_new_key=value "$SCRIPT" "$tmp/b.ini" >/dev/null )
check "new key" "some_new_key = value" "$tmp/b.ini"

echo "CFG_ overrides the alias for the same key"
( SERVER_PUBLIC=1 CFG_server_public=0 "$SCRIPT" "$tmp/c.ini" >/dev/null )
check "override wins" "server_public = 0" "$tmp/c.ini"
absent "no duplicate"  "server_public = 1" "$tmp/c.ini"

echo "keys already in the file are preserved"
printf 'existing_key = keepme\nserver_public = 1\n' > "$tmp/d.ini"
( SERVER_PUBLIC=0 "$SCRIPT" "$tmp/d.ini" >/dev/null )
check "preserved"  "existing_key = keepme" "$tmp/d.ini"
check "overwritten" "server_public = 0"    "$tmp/d.ini"

echo "unset variables produce no keys"
( "$SCRIPT" "$tmp/e.ini" >/dev/null )
absent "no stray keys" "=" "$tmp/e.ini" 2>/dev/null || true

if [ "$fails" -ne 0 ]; then echo "$fails check(s) failed"; exit 1; fi
echo "all checks passed"
