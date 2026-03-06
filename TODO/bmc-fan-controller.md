# BMC Fan Controller

Deploy an in-cluster fan controller that reads node and NVMe temps via the Kubernetes metrics pipeline and controls the TuringPi system fan via the BMC HTTP API.

## Background
- BMC exposes a simple unauthenticated-after-login HTTP API at `http://turingpi.local/api/bmc`
- Auth: `POST /api/bmc/authenticate` → Bearer token (valid 3hrs)
- Get status: `GET /api/bmc?opt=get&type=cooling`
- Set speed: `GET /api/bmc?opt=set&type=cooling&device=system+fan&speed=<0-6>`
- No `tpi` binary needed in-cluster — plain HTTP calls work
- Temp sources per node (via talosctl sysfs, millidegrees C):
  - SoC package: `/sys/class/thermal/thermal_zone0/temp`
  - NVMe: `/sys/class/hwmon/hwmon8/temp1_input`
- Current idle baseline: SoC ~46–48°C, NVMe ~52°C

## Speed curve (proposed)
| Max temp across all nodes | Fan speed |
|--------------------------|-----------|
| < 45°C                   | 1         |
| 45–50°C                  | 2         |
| 50–55°C                  | 3         |
| 55–60°C                  | 4         |
| 60–65°C                  | 5         |
| > 65°C                   | 6         |

## Steps
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

## Metrics Availability (✅ Confirmed)
- **Node-exporter is already deployed** (via kube-prometheus-stack)
- **SoC temps**: Available via `node_thermal_zone_temp{type="package-thermal"}` (all 4 nodes reporting)
  - n1: 49°C, n2: 49°C, n3: 42.5°C, n4: 45.3°C
- **NVMe temps**: Available via `node_hwmon_temp_celsius{chip="nvme_nvme0",sensor="temp1"}` (composite, all 4 nodes)
  - n1: 49.85°C, n2: 46.85°C, n3: 49.85°C, n4: 41.85°C
  - Also: sensor 2 (hotspot) at `sensor="temp3"` for better thermal monitoring
- **Fan metrics**: Not yet exposed; will need to add custom metric from BMC reads or export current fan state

## Open questions
- Does `turingpi.local` resolve from inside pods? May need to use the BMC IP directly or add a headless Service/ExternalName.
- Should the controller tolerate BMC auth token expiry gracefully (re-auth on 401)?
- Should we query Prometheus directly or scrape metrics via a sidecar? (Prometheus is simpler, avoids custom collectors)
