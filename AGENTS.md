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

## Runtime constraints

These are required for the server to start. Changing any of them breaks it:

- **`PROTON_USE_WINED3D=1`.** UE's NNERuntimeORT plugin probes for D3D12. Under vkd3d it
  receives `E_FAIL` and dereferences null in `dxgi.dll`; under wined3d it receives
  `E_INVALIDARG` and continues. Neither `-nullrhi` nor a software Vulkan driver avoids this.
- **Debian trixie or newer.** Proton-GE links against `GLIBC_2.38`; bookworm provides 2.36.
- **Xvfb, and `/tmp/.X11-unix` created at build time.** UE initialises graphics even in
  server builds. The socket directory cannot be created by uid 1000 at runtime.
- **Launch the shipping binary directly.** `AlchemyFactoryServer.exe` is a launcher that
  hangs under Wine without starting the server.

## Testing

`shellcheck scripts/*.sh` and `hadolint Dockerfile` are what CI runs. The server itself needs
an amd64 host; `docker compose up` with `./data` mounted is the fastest loop.
