#!/usr/bin/env bash
# Installs or updates the dedicated server via SteamCMD.
set -euo pipefail
# shellcheck source=scripts/helpers.sh
. /usr/local/bin/helpers.sh

update_app() {
  "${STEAMCMDDIR}/steamcmd.sh" +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$SERVER_DIR" \
    +login anonymous +app_update "$STEAM_APP_ID" validate +quit
}

if [ "${SKIP_UPDATE:-0}" = "1" ]; then
  log "SKIP_UPDATE=1, using installed build"
  exit 0
fi

log "updating app ${STEAM_APP_ID}"
# Steam can leave the manifest flagged "update required" with nothing to fetch,
# which then fails every start. Dropping it forces a re-verify against the
# files already on disk rather than a full re-download.
if ! update_app; then
  log "update failed; clearing Steam state and retrying"
  rm -f "${SERVER_DIR}/steamapps/appmanifest_${STEAM_APP_ID}.acf"
  rm -rf "${SERVER_DIR}/steamapps/downloading" "${SERVER_DIR}/steamapps/temp"
  update_app
fi
