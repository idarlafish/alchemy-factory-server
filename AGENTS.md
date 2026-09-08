# AGENTS.md

Docker image running the Windows-only Alchemy Factory dedicated server under Proton on Linux.

## Layout

- `Dockerfile` — `cm2network/steamcmd` base + Proton-GE, runs as `steam`
- `scripts/entrypoint.sh` — update, link saves, render config, fetch mods, supervise the server
- `scripts/config.sh` — renders `Server Config.ini` from env
- `scripts/mods.sh` — optional Workshop download
- `.github/workflows/build.yml` — shellcheck + hadolint, then push to Docker Hub and GHCR

## Hard rules

- **Unreal servers refuse to run as root.** The image runs as `steam`; keep it that way.
- **`linux/amd64` only.** The binary is Windows x86-64 under Proton; do not add ARM.
- **Never break `CFG_*` passthrough.** It is what keeps the image usable when upstream adds
  config keys, so arbitrary keys must always reach `Server Config.ini` verbatim.
- **No RCON exists.** Do not add save-before-backup or player-count healthchecks; the server
  offers no remote control surface.
- Pin `GE_PROTON_VERSION` in the Dockerfile; Renovate/CI bumps it deliberately.

## Facts

- Server app id `4550060` (Tool, anonymous ok). Game app id `3669570`.
- Entrypoint binary `AlchemyFactoryServer.exe -log`; saves at `AlchemyFactory/Saved/SaveGames`.
- Workshop content requires an owning account — anonymous `workshop_download_item` fails.
- Upstream calls the server experimental and warns sessions may need several start attempts.

## Testing

`shellcheck scripts/*.sh` and `hadolint Dockerfile` are what CI runs. The server itself needs
an amd64 host; `docker compose up` with `./data` mounted is the fastest loop.
