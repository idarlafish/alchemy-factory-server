#!/usr/bin/env bash
# Verifies the stdout filter and the joincode helper against a fake engine log,
# including the rename-and-recreate the engine does on every start. No Proton.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0
# Must match the pattern hardcoded in scripts/logstream.sh.
FILTER='[ServerConfig]'

expect() { # name expected actual
  if [ "$2" = "$3" ]; then
    echo "  ok: $1"
  else
    echo "  FAIL: $1 — expected '$2', got '$3'"; fails=$((fails + 1))
  fi
}

# The helpers source path is absolute in the image, so stage the scripts the same way.
bin="$tmp/bin"; mkdir -p "$bin"
sed "s#/usr/local/bin/helpers.sh#$bin/helpers.sh#" "$ROOT/scripts/joincode" > "$bin/joincode"
cp "$ROOT/scripts/helpers.sh" "$bin/helpers.sh"
chmod +x "$bin/joincode"

export LOG_FILE="$tmp/AlchemyFactory.log"
: > "$LOG_FILE"

echo "joincode reports the latest code"
{
  echo '[2026.01.01-00.00.00:000][  0]LogTemp: [ServerConfig] join code: AAAAAAAAAAAAAA'
  echo '[2026.01.01-00.01.00:000][  1]LogTemp: [ServerConfig] join code: BBBBBBBBBBBBBB'
} >> "$LOG_FILE"
expect "last wins" "BBBBBBBBBBBBBB" "$("$bin/joincode")"

echo "joincode fails cleanly when there is no code"
: > "$LOG_FILE"
set +e; out="$("$bin/joincode" 2>/dev/null)"; rc=$?; set -e
expect "exit code" "1" "$rc"
expect "no output"  ""  "$out"

echo "joincode fails cleanly when the log is missing"
set +e; ( LOG_FILE="$tmp/nope.log" "$bin/joincode" >/dev/null 2>&1 ); rc=$?; set -e
expect "exit code" "1" "$rc"

echo "the stdout filter passes ServerConfig and drops passwords"
cat > "$tmp/sample.log" <<'LOG'
[0]LogTemp: [ServerConfig] join code: CCCCCCCCCCCCCC
[1]LogNet: Login request: ?Password=10293847?Name=Echo userId: STEAM:UNKNOWN
[2]LogStreaming: Display: UWorld::AddToWorld took 25.68 ms
[3]LogPoseSearch: Warning: Couldn't find BoneIndexType 7
LOG
kept="$(grep -cF "$FILTER" "$tmp/sample.log" || true)"
expect "one line kept" "1" "$kept"
expect "password dropped" "0" "$(grep -F "$FILTER" "$tmp/sample.log" | grep -c Password || true)"

echo "tail -F survives the engine's rename-and-recreate"
: > "$LOG_FILE"
( timeout 20 tail -n 0 -F "$LOG_FILE" 2>/dev/null \
    | grep --line-buffered -F "$FILTER" > "$tmp/streamed.txt" ) &
sleep 2
echo '[0]LogTemp: [ServerConfig] before' >> "$LOG_FILE"
sleep 2
mv "$LOG_FILE" "$tmp/AlchemyFactory-backup.log"; : > "$LOG_FILE"
sleep 2
echo '[1]LogTemp: [ServerConfig] after' >> "$LOG_FILE"
sleep 5
expect "before rotation" "1" "$(grep -c before "$tmp/streamed.txt" || true)"
expect "after rotation"  "1" "$(grep -c after  "$tmp/streamed.txt" || true)"
wait 2>/dev/null || true

if [ "$fails" -ne 0 ]; then echo "$fails check(s) failed"; exit 1; fi
echo "all checks passed"
