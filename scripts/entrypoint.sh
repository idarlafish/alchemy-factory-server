#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/alchemyfactory}"
DATA_DIR="${DATA_DIR:-/data}"
PROTON_DIR="${PROTON_DIR:-/opt/proton}"
STEAM_APP_ID="${STEAM_APP_ID:-4550060}"

SAVE_DIR="${SERVER_DIR}/AlchemyFactory/Saved"
CONFIG_NAME="${CONFIG_NAME:-Server Config.ini}"
RESTART_DELAY="${RESTART_DELAY:-10}"
MAX_RESTARTS="${MAX_RESTARTS:-0}"   # 0 = unlimited

export STEAM_COMPAT_CLIENT_INSTALL_PATH="${DATA_DIR}/steam"
export STEAM_COMPAT_DATA_PATH="${DATA_DIR}/proton"
mkdir -p "$STEAM_COMPAT_CLIENT_INSTALL_PATH" "$STEAM_COMPAT_DATA_PATH" "$DATA_DIR/Saved"

if [ "${SKIP_UPDATE:-0}" != "1" ]; then
  echo "==> updating app ${STEAM_APP_ID}"
  steamcmd +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$SERVER_DIR" \
    +login anonymous +app_update "$STEAM_APP_ID" validate +quit
else
  echo "==> SKIP_UPDATE=1, using installed build"
fi

# Saves live on the volume; the game only ever sees its own path.
rm -rf "$SAVE_DIR"
mkdir -p "$(dirname "$SAVE_DIR")"
ln -s "$DATA_DIR/Saved" "$SAVE_DIR"

/usr/local/bin/config.sh "${SERVER_DIR}/${CONFIG_NAME}"

/usr/local/bin/mods.sh "${SERVER_DIR}/AlchemyFactory/Content/Paks"

child=""
shutdown() {
  echo "==> SIGTERM received, stopping server"
  [ -n "$child" ] && kill -TERM "$child" 2>/dev/null || true
  wait "$child" 2>/dev/null || true
  exit 0
}
trap shutdown TERM INT

# Upstream warns the network session often needs several attempts, so supervise.
attempt=0
while :; do
  attempt=$((attempt + 1))
  echo "==> starting AlchemyFactoryServer.exe (attempt ${attempt})"
  read -ra extra_args <<< "${EXTRA_ARGS:-}"
  "${PROTON_DIR}/proton" run "${SERVER_DIR}/AlchemyFactoryServer.exe" -log "${extra_args[@]}" &
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
