# AGENTS.md

Docker image running the Windows-only Alchemy Factory dedicated server under Proton on Linux.

## Layout

- `Dockerfile` — steamcmd base + Proton, runs as uid 1000
- `scripts/helpers.sh` — shared paths and `log()`, sourced by the rest
- `scripts/entrypoint.sh` — preflight, then install → config → `exec run.sh`
- `scripts/install.sh` — SteamCMD install/update, recovers a stuck app manifest
- `scripts/config.sh` — renders `Server Config.ini` from env
- `scripts/auto_restart.sh` — daily restart signal
- `scripts/run.sh` — display, supervision, shutdown
- `tests/` — shell tests that run without Proton
- `.github/workflows/build.yml` — shellcheck, hadolint, tests, then push

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
- Workshop mods are not supported: this game refuses anonymous Workshop downloads, so it
  would require a Steam account that owns the game with Steam Guard disabled.
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

`shellcheck -S style -x scripts/*.sh tests/*.sh`, `hadolint Dockerfile` and `./tests/test-config.sh`
are what CI runs. The tests avoid Proton so they run on any machine, including bash 3.2 — keep
them that way. The server itself needs
an amd64 host; `docker compose up` with `./data` mounted is the fastest loop.
