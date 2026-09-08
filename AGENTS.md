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
- Saves and the rendered config live under `/data/server` — the whole install is on the volume.
- Workshop content needs an owning Steam account; anonymous downloads fail for this game.
- Upstream calls the server experimental and Windows-only.

## Hard-won constraints — do not regress these

Each cost a debugging cycle. All are load-bearing:

- **`PROTON_USE_WINED3D=1`.** UE's NNERuntimeORT plugin probes for D3D12; under vkd3d it
  gets `E_FAIL` and dereferences null in `dxgi.dll`. wined3d returns `E_INVALIDARG`, which
  the plugin survives. `-nullrhi` and software Vulkan both failed to help.
- **Debian trixie or newer.** Proton-GE links `GLIBC_2.38`; bookworm ships 2.36.
- **Xvfb plus `/tmp/.X11-unix`.** UE initialises graphics even in server builds. The socket
  directory must be created at build time — uid 1000 cannot create it.
- **Launch the shipping exe, not `AlchemyFactoryServer.exe`.** The launcher hangs under Wine
  and never spawns the real binary.

## Testing

`shellcheck scripts/*.sh` and `hadolint Dockerfile` are what CI runs. The server itself needs
an amd64 host; `docker compose up` with `./data` mounted is the fastest loop.
