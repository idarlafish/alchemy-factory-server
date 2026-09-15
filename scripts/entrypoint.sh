#!/usr/bin/env bash
# Orchestrates startup: preflight, install, configure, then run.
set -euo pipefail
# shellcheck source=scripts/helpers.sh
. /usr/local/bin/helpers.sh

# Started as root: renumber steam to PUID/PGID, take ownership, then drop and re-exec.
# Started as anyone else (--user, Kubernetes runAsUser): run as given, PUID/PGID ignored.
if [ "$(id -u)" = 0 ]; then
  case "$PUID:$PGID" in
    *[!0-9:]*) echo "FATAL: PUID/PGID must be numeric, got PUID=$PUID PGID=$PGID" >&2; exit 1 ;;
  esac

  # Group first, so usermod sees the new group.
  [ "$(id -g steam)" = "$PGID" ] || { log "gid of steam -> $PGID"; groupmod -o -g "$PGID" steam; }
  [ "$(id -u steam)" = "$PUID" ] || { log "uid of steam -> $PUID"; usermod -o -u "$PUID" steam; }

  # Unconditional: correct ownership on a directory says nothing about what is inside it,
  # so a save copied in as another uid still gets fixed. ~2300 files here, about 30 ms.
  mkdir -p "${DATA_DIR}"
  log "chown -R $PUID:$PGID /home/steam ${DATA_DIR} ${PROTON_DIR}"
  chown -R "$PUID:$PGID" /home/steam "${DATA_DIR}" "${PROTON_DIR}"

  log "dropping to steam ($PUID:$PGID)"
  export AF_DROPPED=1
  exec setpriv --reuid="$PUID" --regid="$PGID" --init-groups "$0" "$@"
fi

# Only meaningful when the container was started directly as a non-root user.
if [ -z "${AF_DROPPED:-}" ] && { [ "$PUID" != 1000 ] || [ "$PGID" != 1000 ]; }; then
  log "WARNING: PUID/PGID ignored, already running as uid $(id -u):$(id -g)"
fi

export STEAM_COMPAT_CLIENT_INSTALL_PATH="${DATA_DIR}/steam"
export STEAM_COMPAT_DATA_PATH="${DATA_DIR}/proton"

if [ ! -w "$DATA_DIR" ]; then
  echo "FATAL: $DATA_DIR is not writable by uid $(id -u). chown it to that uid, or start as root and set PUID/PGID." >&2
  exit 1
fi
mkdir -p "$STEAM_COMPAT_CLIENT_INSTALL_PATH" "$STEAM_COMPAT_DATA_PATH" "$SERVER_DIR"

/usr/local/bin/install.sh
/usr/local/bin/config.sh "${SERVER_DIR}/${CONFIG_NAME}"

exec /usr/local/bin/run.sh
