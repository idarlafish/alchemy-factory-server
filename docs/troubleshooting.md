# Troubleshooting

## `FATAL: /data is not writable by uid 1000`

The container runs as uid 1000 because Unreal servers refuse to run as root, and
Docker creates a missing bind-mount directory owned by root.

```bash
chown -R 1000:1000 ./data
```

On Kubernetes set `securityContext.fsGroup: 1000` instead — see
[examples/kubernetes.yaml](../examples/kubernetes.yaml).

## Clients rejected after a game update

The log shows a version mismatch:

```
Client connecting with invalid version. LocalNetworkVersion: 4917, RemoteNetworkVersion: 4930
```

The server is on an older build than the client. Unreal refuses mismatched network
versions, and the client reports it as a connection failure.

Restart the container — the update runs at startup:

```bash
docker compose restart
```

`AUTO_RESTART` handles this daily, so it should only be seen shortly after a patch.

## Direct `IP:port` connections fail

With `SERVER_RELAY=1` traffic goes through Steam and direct joins are unavailable.
Nothing appears in the log because the packets never reach the server.

Use the join code:

```bash
docker compose logs | grep "join code"
```

## `Error! App '4550060' state is 0x6 after update job`

Steam has flagged the app as needing an update while reporting nothing to download,
which then fails on every start. Recovery is automatic since 0.1.1: the manifest is
cleared and the update retried, which re-verifies the installed files.

If it persists, remove the manifest and restart:

```bash
rm /data/server/steamapps/appmanifest_4550060.acf
```

## Nothing in the log for several minutes on first start

Expected. The first start downloads roughly 650 MB of game files before the server
boots. Later starts reuse the volume and are quick.
