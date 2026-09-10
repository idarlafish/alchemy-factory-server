#!/usr/bin/env bash
# Verifies that config.sh renders ServerConfig.ini correctly from the
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
precedes() { # name earlier later file
  a=$(grep -nF "$2" "$4" | head -1 | cut -d: -f1)
  b=$(grep -nF "$3" "$4" | head -1 | cut -d: -f1)
  if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then
    echo "  ok: $1"
  else
    echo "  FAIL: $1 — '$2' must precede '$3'"; sed 's/^/       /' "$4"; fails=$((fails + 1))
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

echo "the game's own file structure survives a rewrite"
printf '; Alchemy Factory Dedicated Server config\n[ServerSettings]\nserver_name=Alchemy Factory\nserver_public=1\n; a trailing note\nquery_port=9878\nserver_password =\n' > "$tmp/f.ini"
( SERVER_PUBLIC=0 SERVER_NAME=private-abc SERVER_PASSWORD=hunter2 MAX_PLAYERS=8 "$SCRIPT" "$tmp/f.ini" >/dev/null )
check    "section header kept"  "[ServerSettings]"          "$tmp/f.ini"
check    "leading comment kept" "; Alchemy Factory Dedicated Server config" "$tmp/f.ini"
check    "inner comment kept"   "; a trailing note"         "$tmp/f.ini"
check    "unmanaged key kept"   "query_port=9878"           "$tmp/f.ini"
check    "public overridden"    "server_public = 0"         "$tmp/f.ini"
check    "name overridden"      "server_name = private-abc" "$tmp/f.ini"
check    "empty password filled" "server_password = hunter2" "$tmp/f.ini"
check    "MAX_PLAYERS is max_clients" "max_clients = 8"     "$tmp/f.ini"
absent   "stale public gone"    "server_public=1"           "$tmp/f.ini"
absent   "max_players is not a real key" "max_players"      "$tmp/f.ini"
precedes "keys stay inside the section" "[ServerSettings]" "server_public = 0" "$tmp/f.ini"
precedes "appended keys stay inside the section" "[ServerSettings]" "max_clients = 8" "$tmp/f.ini"

echo "unset variables produce no keys"
( "$SCRIPT" "$tmp/e.ini" >/dev/null )
absent "no stray keys" "=" "$tmp/e.ini" 2>/dev/null || true

if [ "$fails" -ne 0 ]; then echo "$fails check(s) failed"; exit 1; fi
echo "all checks passed"
