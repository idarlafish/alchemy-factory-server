# alchemy-factory-server

Docker image for an [Alchemy Factory](https://store.steampowered.com/app/3669570/) dedicated server.

The server is Windows-only and marked experimental upstream, so it runs under
[Proton-GE](https://github.com/GloriousEggroll/proton-ge-custom). `linux/amd64` only.

## Quick start

```yaml
services:
  alchemy-factory:
    image: idarlafish/alchemy-factory-server:latest
    restart: unless-stopped
    environment:
      ADMIN_PASSWORD: change-me
      SERVER_PASSWORD: join-password
    volumes:
      - ./data:/data
```

`mkdir data && chown 1000:1000 data` first — the container runs as uid 1000.
For Kubernetes see [examples/kubernetes.yaml](examples/kubernetes.yaml).

The log prints a **join code**; share that. Become admin in chat with
`/admin <ADMIN_PASSWORD>`, then `/help`.

## Server settings

Written to `Server Config.ini` on every start.

| Variable | | |
|---|---|---|
| `SERVER_PASSWORD` | | join password |
| `ADMIN_PASSWORD` | | enables `/admin` |
| `SERVER_NAME` | | |
| `SERVER_PUBLIC` | | list in the public server browser |
| `SERVER_RELAY` | `1` | route via Steam; direct IP joins unavailable |
| `SERVER_LAN` | | LAN only |
| `SERVER_PORT` · `MAX_PLAYERS` | | |
| `CFG_<key>` | | any key verbatim, overrides the above |

Upstream documents only `server_lan`, `server_relay` and `server_public`; the rest are
best-effort aliases. `CFG_<key>` works for keys added after this image shipped.

## Runtime

| Variable | Default | |
|---|---|---|
| `AUTO_RESTART` | `1` | daily restart — this is also how Steam patches are picked up |
| `AUTO_RESTART_AT` | `04:00` | container `TZ` |
| `SKIP_UPDATE` | `0` | `1` pins the installed build |
| `MAX_RESTARTS` | `5` | consecutive failures before giving up; `0` = unlimited |
| `HEALTHY_AFTER` | `300` | uptime in seconds that resets the failure counter |
| `RESTART_DELAY` | `10` | seconds between attempts |
| `EXTRA_ARGS` · `TZ` | | |

Without the daily restart, a Steam patch leaves clients rejected on a version mismatch.

## Data

`/data/server` holds the install, saves and config; `/data/proton` and `/data/steam`
hold Proton and SteamCMD state.

The game has no RCON, query protocol or REST API. **It does not save on shutdown** — a
restart loses progress since the last autosave, and backups are crash-consistent.

## Tags

| | |
|---|---|
| `latest`, `X.Y.Z` | releases, from a `v*` git tag |
| `dev` | latest `main`, moves often |
| `sha-<short>` | immutable, for pinning |

## License

Apache-2.0. Not affiliated with the developers of Alchemy Factory.
