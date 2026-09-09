#!/usr/bin/env bash
# Starts the display, supervises the server, and handles shutdown.
set -euo pipefail
# shellcheck source=scripts/helpers.sh
. /usr/local/bin/helpers.sh

RESTART_DELAY="${RESTART_DELAY:-10}"
MAX_RESTARTS="${MAX_RESTARTS:-5}"   # consecutive failures; 0 = unlimited
HEALTHY_AFTER="${HEALTHY_AFTER:-300}"

rm -f "$RESTART_FLAG"

# UE initialises graphical subsystems even in server builds, and Wine blocks
# without a display. Nothing is ever rendered.
if [ "${ENABLE_XVFB:-1}" = "1" ]; then
  Xvfb "${XVFB_DISPLAY:-:99}" -screen 0 1024x768x24 -nolisten tcp &
  xvfb_pid=$!
  export DISPLAY="${XVFB_DISPLAY:-:99}"
  log "Xvfb on ${DISPLAY}"
fi

if [ "${AUTO_RESTART:-1}" = "1" ]; then
  /usr/local/bin/auto_restart.sh &
  scheduler_pid=$!
fi

child=""
cleanup() {
  [ -n "${scheduler_pid:-}" ] && kill "$scheduler_pid" 2>/dev/null
  [ -n "${xvfb_pid:-}" ] && kill "$xvfb_pid" 2>/dev/null
  return 0
}
shutdown() {
  log "SIGTERM received, stopping server"
  if [ -n "$child" ]; then
    kill -TERM "$child" 2>/dev/null || true
  fi
  wait "$child" 2>/dev/null || true
  cleanup
  exit 0
}
trap shutdown TERM INT

# Upstream warns the network session often needs several attempts to establish.
attempt=0
while :; do
  attempt=$((attempt + 1))
  log "starting server (attempt ${attempt})"
  read -ra extra_args <<< "${EXTRA_ARGS:-}"
  "${PROTON_DIR}/proton" run "${SERVER_DIR}/${SERVER_BINARY}" -log "${extra_args[@]}" &
  child=$!
  started=$(date +%s)
  set +e; wait "$child"; code=$?; set -e
  child=""
  ran=$(( $(date +%s) - started ))
  log "server exited with code ${code} after ${ran}s"

  if [ -f "$RESTART_FLAG" ]; then
    rm -f "$RESTART_FLAG"
    log "scheduled restart, exiting for the orchestrator to restart us"
    cleanup
    exit 0
  fi

  # Only consecutive quick failures count towards giving up.
  if [ "$ran" -ge "$HEALTHY_AFTER" ]; then
    attempt=0
  fi
  if [ "$MAX_RESTARTS" != "0" ] && [ "$attempt" -ge "$MAX_RESTARTS" ]; then
    log "reached MAX_RESTARTS=${MAX_RESTARTS}, giving up"
    cleanup
    exit "$code"
  fi
  log "restarting in ${RESTART_DELAY}s"
  sleep "$RESTART_DELAY"
done
