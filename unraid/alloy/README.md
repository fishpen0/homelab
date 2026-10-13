# Alloy on Unraid

Config for the `Grafana-Alloy` container on box. Copy to `/mnt/user/appdata/alloy/config/config.alloy`.

The container (Unraid Docker template) needs, beyond the existing config/data mounts:

| Host | Container | Mode |
|---|---|---|
| `/var/run/docker.sock` | `/var/run/docker.sock` | ro |
| `/proc` | `/host/proc` | ro |
| `/sys` | `/host/sys` | ro |
| `/` | `/host/root` | ro |
| `/var/log` | `/host/var/log` | ro |

Extra parameters (box doesn't use MagicDNS, so pin the tailnet proxies' IPs from `tailscale status`):

```
--add-host=loki.ferret-pound.ts.net:<loki tailnet IP> --add-host=prometheus.ferret-pound.ts.net:<prometheus tailnet IP>
```

Alternatively add AdGuard DNS rewrites for both names. Check with `alloy validate` / the logs after a restart.
