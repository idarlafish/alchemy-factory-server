#!/usr/bin/env bash
# Echoes the engine's [ServerConfig] lines to stdout. The engine writes only to
# Saved/Logs and its stdout does not cross Proton, so the file is the only source.
# Kept narrow on purpose: Login request lines carry the join password in cleartext.
set -euo pipefail
# shellcheck source=scripts/helpers.sh
. /usr/local/bin/helpers.sh

# -F re-opens by name, so this survives the engine renaming the log on each start
# and waits for the file when it does not exist yet.
exec tail -n 0 -F "$LOG_FILE" 2>/dev/null | grep --line-buffered -F '[ServerConfig]'
