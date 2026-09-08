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
MAX_RESTARTS="${MAX_RESTARTS:-5}"   # 0 = unlimited

export STEAM_COMPAT_CLIENT_INSTALL_PATH="${DATA_DIR}/steam"
export STEAM_COMPAT_DATA_PATH="${DATA_DIR}/proton"
if [ ! -w "$DATA_DIR" ]; then
  echo "FATAL: $DATA_DIR is not writable by uid $(id -u). Run: chown -R 1000:1000 <your data dir>" >&2
  exit 1
fi
mkdir -p "$STEAM_COMPAT_CLIENT_INSTALL_PATH" "$STEAM_COMPAT_DATA_PATH" "$SERVER_DIR"

if [ "${SKIP_UPDATE:-0}" != "1" ]; then
  echo "==> updating app ${STEAM_APP_ID}"
  "${STEAMCMDDIR}/steamcmd.sh" +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$SERVER_DIR" \
    +login anonymous +app_update "$STEAM_APP_ID" validate +quit
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

child=""
shutdown() {
  echo "==> SIGTERM received, stopping server"
  if [ -n "$child" ]; then
    kill -TERM "$child" 2>/dev/null || true
  fi
  wait "$child" 2>/dev/null || true
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
  set +e; wait "$child"; code=$?; set -e
  child=""
  echo "==> server exited with code ${code}"
  if [ "$MAX_RESTARTS" != "0" ] && [ "$attempt" -ge "$MAX_RESTARTS" ]; then
    echo "==> reached MAX_RESTARTS=${MAX_RESTARTS}, giving up"
    exit "$code"
  fi
  echo "==> restarting in ${RESTART_DELAY}s"
  sleep "$RESTART_DELAY"
done
