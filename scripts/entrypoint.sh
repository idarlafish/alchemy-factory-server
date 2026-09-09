#!/usr/bin/env bash
# Orchestrates startup: preflight, install, configure, then run.
set -euo pipefail
# shellcheck source=scripts/helpers.sh
. /usr/local/bin/helpers.sh

export STEAM_COMPAT_CLIENT_INSTALL_PATH="${DATA_DIR}/steam"
export STEAM_COMPAT_DATA_PATH="${DATA_DIR}/proton"

if [ ! -w "$DATA_DIR" ]; then
  echo "FATAL: $DATA_DIR is not writable by uid $(id -u). Run: chown -R 1000:1000 <your data dir>" >&2
  exit 1
fi
mkdir -p "$STEAM_COMPAT_CLIENT_INSTALL_PATH" "$STEAM_COMPAT_DATA_PATH" "$SERVER_DIR"

/usr/local/bin/install.sh
/usr/local/bin/config.sh "${SERVER_DIR}/${CONFIG_NAME}"

exec /usr/local/bin/run.sh
