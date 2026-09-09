#!/usr/bin/env bash
# Signals a daily restart. Runs in the background; run.sh acts on the flag.
set -euo pipefail
# shellcheck source=scripts/helpers.sh
. /usr/local/bin/helpers.sh

at="${AUTO_RESTART_AT:-04:00}"
log "auto-restart daily at ${at}"

while :; do
  now=$(date +%s)
  target=$(date -d "today ${at}" +%s 2>/dev/null || echo 0)
  if [ "$target" -le "$now" ]; then
    target=$(date -d "tomorrow ${at}" +%s)
  fi
  sleep "$((target - now))"
  log "scheduled restart (${at})"
  touch "$RESTART_FLAG"
  pkill -TERM -f "$(basename "$SERVER_BINARY")" || true
done
