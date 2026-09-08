#!/usr/bin/env bash
# Optional Steam Workshop mod download.
#
# Alchemy Factory Workshop content is NOT served to anonymous logins, so this
# needs a Steam account that owns the game and has Steam Guard disabled.
# Skipped entirely unless STEAM_USER and a mod source are both set.
set -euo pipefail

GAME_APP_ID="${GAME_APP_ID:-3669570}"
MODS_DIR="${1:?mods dir required}"
WORK="${DATA_DIR:-/data}/workshop"

[ -n "${WORKSHOP_IDS:-}${WORKSHOP_COLLECTION:-}" ] || { echo "mods: nothing configured, skipping"; exit 0; }

ids=""
if [ -n "${WORKSHOP_COLLECTION:-}" ]; then
  ids="$(curl -sfS -X POST \
      https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/ \
      --data-urlencode "collectioncount=1" \
      --data-urlencode "publishedfileids[0]=${WORKSHOP_COLLECTION}" \
    | tr '{' '\n' | grep -o '"publishedfileid":"[0-9]*"' | grep -o '[0-9][0-9]*' \
    | grep -vx "${WORKSHOP_COLLECTION}" | sort -u)"
  [ -n "$ids" ] || { echo "mods: collection ${WORKSHOP_COLLECTION} resolved to 0 items; is it Public?" >&2; exit 1; }
fi
read -ra extra_ids <<< "${WORKSHOP_IDS:-}"
for id in "${extra_ids[@]-}"; do [ -n "$id" ] && ids="$ids
$id"; done
ids="$(printf '%s\n' "$ids" | sed '/^$/d' | sort -u)"

args=()
while IFS= read -r id; do
  [ -n "$id" ] && args+=(+workshop_download_item "$GAME_APP_ID" "$id")
done <<< "$ids"

# Anonymous is tried first: it costs nothing and starts working the moment the
# developers allow it, without anyone changing their compose file.
if [ -n "${STEAM_USER:-}" ]; then
  steamcmd +force_install_dir "$WORK" \
    +login "$STEAM_USER" "${STEAM_PASS:?STEAM_PASS required when STEAM_USER is set}" \
    "${args[@]}" +quit
elif ! steamcmd +force_install_dir "$WORK" +login anonymous "${args[@]}" +quit; then
  echo "mods: anonymous download failed; this game does not serve Workshop content" >&2
  echo "mods: set STEAM_USER/STEAM_PASS (account owning the game, Steam Guard off)" >&2
  exit 1
fi

mkdir -p "$MODS_DIR"
find "$WORK/steamapps/workshop/content/$GAME_APP_ID" -name '*.pak' \
  -exec cp -v {} "$MODS_DIR/" \; 2>/dev/null || echo "mods: no .pak files found"
