# Homelab TODO

## Longhorn Backups
Configure an external backup target so Longhorn volumes survive intentional node wipes (beyond the existing 2-replica in-cluster redundancy).

Two options available on the NAS host:
- **NFS** — already available; Longhorn supports NFS backup targets natively
- **S3-compatible** — set up Garage on the NAS host (not MinIO — see notes); Longhorn supports S3-compatible targets

Either works. S3 gives better flexibility (can also be used by other tools). NFS is simpler to stand up.

Steps:
1. Choose NFS or S3-compatible (MinIO on NAS)
2. If S3: deploy Garage on NAS (Docker container), create a bucket + access credentials
3. Configure Longhorn `backupTarget` and `backupTargetCredentialSecret` in the HelmRelease
4. Set a recurring backup schedule (RecurringJob) — e.g. daily snapshot + weekly backup

## Garage (S3-compatible object storage on Unraid)
Set up Garage v2.x on `box` (Unraid) as a self-hosted S3 backend for Longhorn backups and Immich storage.

Notes:
- Use Garage, not MinIO (license/maintenance issues) or RustFS (alpha, overclaimed benchmarks)
- Garage stores data content-addressed (opaque directories) — not human-browsable, but recoverable
- Check Immich + Garage presigned URL compatibility before committing (known regression in v2.2.1, verify fixed)
- Consider periodic rclone sync Garage → plain Unraid share for browsable backup copy

Steps:
1. [ ] Deploy Garage as Docker container on Unraid
2. [ ] Create buckets: one for Longhorn backups, one for Immich
3. [ ] Configure Longhorn `backupTarget` + `backupTargetCredentialSecret`
4. [ ] Configure Immich to use Garage S3 endpoint
5. [ ] Set up recurring Longhorn backup schedule (RecurringJob)

## BMC Fan Controller
Deploy an in-cluster fan controller that reads node and NVMe temps via the Kubernetes metrics pipeline and controls the TuringPi system fan via the BMC HTTP API.

### Background
- BMC exposes a simple unauthenticated-after-login HTTP API at `http://turingpi.local/api/bmc`
- Auth: `POST /api/bmc/authenticate` → Bearer token (valid 3hrs)
- Get status: `GET /api/bmc?opt=get&type=cooling`
- Set speed: `GET /api/bmc?opt=set&type=cooling&device=system+fan&speed=<0-6>`
- No `tpi` binary needed in-cluster — plain HTTP calls work
- Temp sources per node (via talosctl sysfs, millidegrees C):
  - SoC package: `/sys/class/thermal/thermal_zone0/temp`
  - NVMe: `/sys/class/hwmon/hwmon8/temp1_input`
- Current idle baseline: SoC ~46–48°C, NVMe ~52°C

### Speed curve (proposed)
| Max temp across all nodes | Fan speed |
|--------------------------|-----------|
| < 45°C                   | 1         |
| 45–50°C                  | 2         |
| 50–55°C                  | 3         |
| 55–60°C                  | 4         |
| 60–65°C                  | 5         |
| > 65°C                   | 6         |

### Steps
1. [ ] Decide on metrics source: Prometheus (preferred, richer) vs metrics-server (simpler, already deployed) — note: neither exposes NVMe or per-zone SoC temps by default; may need node-exporter with custom textfile collector or direct talosctl reads
2. [ ] Determine how to read sysfs temps from inside the cluster — options:
   - DaemonSet with hostPath mounts to `/sys/class/thermal/` and `/sys/class/hwmon/`
   - Prometheus `node-exporter` with `--collector.hwmon` enabled (picks up hwmon devices including NVMe)
   - Custom textfile collector script on each node (harder on Talos — no shell)
3. [ ] Store BMC credentials in a SOPS-encrypted Secret
4. [ ] Build the controller — options:
   - Small Go or Python app (Deployment) that polls metrics API + calls BMC
   - Shell script in a CronJob (simpler but no hysteresis, no real-time UI)
   - Recommendation: lightweight Python Deployment with FastAPI serving the UI
5. [ ] Implement hysteresis: only change fan speed if target has been stable for 2+ consecutive readings (avoid oscillation)
6. [ ] Build the UI — simple web page showing:
   - Per-node SoC temp (package-thermal)
   - Per-node NVMe temp
   - Current fan speed (BMC read)
   - Fan speed history sparkline
   - Color coding: green/yellow/red per threshold
7. [ ] Add ingress rule for the UI under `infrastructure/ingress/rules/`
8. [ ] Add Longhorn PVC or emptyDir for fan speed history (optional — emptyDir fine for sparkline)

### Open questions
- Does Prometheus node-exporter on Talos expose hwmon8 (NVMe) temps? Needs validation.
- Does `turingpi.local` resolve from inside pods? May need to use the BMC IP directly or add a headless Service/ExternalName.
- Should the controller tolerate BMC auth token expiry gracefully (re-auth on 401)?

## Observability Stack
- [ ] Add Grafana (dashboards)
- [ ] Add Prometheus (metrics collection)
- [ ] Add Loki (log aggregation)
- [ ] Add Tempo (distributed tracing)
- [ ] Cry about the cluster being too small to justify mimir or thanos
