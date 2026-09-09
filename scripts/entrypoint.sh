#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/data/server}"
DATA_DIR="${DATA_DIR:-/data}"
PROTON_DIR="${PROTON_DIR:-/opt/proton}"
STEAMCMDDIR="${STEAMCMDDIR:-/home/steam/steamcmd}"
export STEAMCMDDIR
STEAM_APP_ID="${STEAM_APP_ID:-4550060}"

CONFIG_NAME="${CONFIG_NAME:-Server Config.ini}"
SERVER_BINARY="${SERVER_BINARY:-AlchemyFactory/Binaries/Win64/AlchemyFactoryServer-Win64-Shipping.exe}"
RESTART_DELAY="${RESTART_DELAY:-10}"
MAX_RESTARTS="${MAX_RESTARTS:-5}"   # consecutive failures; 0 = unlimited
HEALTHY_AFTER="${HEALTHY_AFTER:-300}"
AUTO_RESTART="${AUTO_RESTART:-1}"
AUTO_RESTART_AT="${AUTO_RESTART_AT:-04:00}"
RESTART_FLAG="${DATA_DIR}/.scheduled-restart"

export STEAM_COMPAT_CLIENT_INSTALL_PATH="${DATA_DIR}/steam"
export STEAM_COMPAT_DATA_PATH="${DATA_DIR}/proton"
if [ ! -w "$DATA_DIR" ]; then
  echo "FATAL: $DATA_DIR is not writable by uid $(id -u). Run: chown -R 1000:1000 <your data dir>" >&2
  exit 1
fi
mkdir -p "$STEAM_COMPAT_CLIENT_INSTALL_PATH" "$STEAM_COMPAT_DATA_PATH" "$SERVER_DIR"

update_app() {
  "${STEAMCMDDIR}/steamcmd.sh" +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$SERVER_DIR" \
    +login anonymous +app_update "$STEAM_APP_ID" validate +quit
}

if [ "${SKIP_UPDATE:-0}" != "1" ]; then
  echo "==> updating app ${STEAM_APP_ID}"
  # Steam can leave the manifest flagged "update required" with nothing to
  # fetch, which fails every subsequent run. Dropping it forces a re-verify
  # against the files already on disk.
  if ! update_app; then
    echo "==> update failed; clearing Steam state and retrying"
    rm -f "${SERVER_DIR}/steamapps/appmanifest_${STEAM_APP_ID}.acf"
    rm -rf "${SERVER_DIR}/steamapps/downloading" "${SERVER_DIR}/steamapps/temp"
    update_app
  fi
else
  echo "==> SKIP_UPDATE=1, using installed build"
fi

/usr/local/bin/config.sh "${SERVER_DIR}/${CONFIG_NAME}"

/usr/local/bin/mods.sh "${SERVER_DIR}/AlchemyFactory/Content/Paks"

# UE initialises graphical subsystems even in server builds, and Wine blocks
# without a display. Xvfb gives it one; nothing is ever rendered.
if [ "${ENABLE_XVFB:-1}" = "1" ]; then
  Xvfb "${XVFB_DISPLAY:-:99}" -screen 0 1024x768x24 -nolisten tcp &
  xvfb_pid=$!
  export DISPLAY="${XVFB_DISPLAY:-:99}"
  echo "==> Xvfb on ${DISPLAY} (pid ${xvfb_pid})"
fi

rm -f "$RESTART_FLAG"

# A scheduled restart exits the container so the orchestrator restarts it,
# which re-runs the update and picks up any Steam patch.
if [ "$AUTO_RESTART" = "1" ]; then
  (
    while :; do
      now=$(date +%s)
      target=$(date -d "today ${AUTO_RESTART_AT}" +%s 2>/dev/null || echo 0)
      if [ "$target" -le "$now" ]; then
        target=$(date -d "tomorrow ${AUTO_RESTART_AT}" +%s)
      fi
      sleep "$((target - now))"
      echo "==> scheduled restart (${AUTO_RESTART_AT})"
      touch "$RESTART_FLAG"
      pkill -TERM -f AlchemyFactoryServer-Win64-Shipping || true
    done
  ) &
  scheduler_pid=$!
  echo "==> auto-restart daily at ${AUTO_RESTART_AT}"
fi

child=""
shutdown() {
  echo "==> SIGTERM received, stopping server"
  if [ -n "$child" ]; then
    kill -TERM "$child" 2>/dev/null || true
  fi
  wait "$child" 2>/dev/null || true
  [ -n "${scheduler_pid:-}" ] && kill "$scheduler_pid" 2>/dev/null
  [ -n "${xvfb_pid:-}" ] && kill "$xvfb_pid" 2>/dev/null
  exit 0
}
trap shutdown TERM INT

# Upstream warns the network session often needs several attempts, so supervise.
attempt=0
while :; do
  attempt=$((attempt + 1))
  echo "==> starting AlchemyFactoryServer.exe (attempt ${attempt})"
  read -ra extra_args <<< "${EXTRA_ARGS:-}"
  "${PROTON_DIR}/proton" run "${SERVER_DIR}/${SERVER_BINARY}" -log "${extra_args[@]}" &
  child=$!
  started=$(date +%s)
  set +e; wait "$child"; code=$?; set -e
  child=""
  ran=$(( $(date +%s) - started ))
  echo "==> server exited with code ${code} after ${ran}s"

  if [ -f "$RESTART_FLAG" ]; then
    rm -f "$RESTART_FLAG"
    echo "==> scheduled restart, exiting for the orchestrator to restart us"
    [ -n "${scheduler_pid:-}" ] && kill "$scheduler_pid" 2>/dev/null
    [ -n "${xvfb_pid:-}" ] && kill "$xvfb_pid" 2>/dev/null
    exit 0
  fi

  # Only consecutive quick failures should count towards giving up.
  if [ "$ran" -ge "$HEALTHY_AFTER" ]; then
    attempt=0
  fi
  if [ "$MAX_RESTARTS" != "0" ] && [ "$attempt" -ge "$MAX_RESTARTS" ]; then
    echo "==> reached MAX_RESTARTS=${MAX_RESTARTS}, giving up"
    exit "$code"
  fi
  echo "==> restarting in ${RESTART_DELAY}s"
  sleep "$RESTART_DELAY"
done
