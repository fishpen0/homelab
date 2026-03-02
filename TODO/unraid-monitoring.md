# UnRAID Monitoring

Monitor UnRAID system, Docker containers, and storage via Prometheus + Loki integration with K8s cluster.

## Architecture

```
UnRAID (Docker)
├─ node-exporter       → system/disk/SMART metrics
├─ cAdvisor            → Docker container metrics
└─ Alloy (daemonset)   → scrape metrics + tail logs

All push/export to:
├─ K8s Prometheus      (metrics)
└─ K8s Loki            (logs)
```

## Components to Deploy

### 1. node-exporter (UnRAID)
- **Purpose**: Export system metrics (CPU, memory, disk, temps, SMART data)
- **Deployment**: Docker container on UnRAID
- **Endpoint**: `http://unraid-ip:9100/metrics`
- **Notes**:
  - May be available as UnRAID plugin; check first
  - Need to expose `/proc`, `/sys` volumes for metrics
  - SMART monitoring requires privileged mode or device access

### 2. cAdvisor (UnRAID)
- **Purpose**: Export Docker container metrics (CPU, memory, I/O, network per container)
- **Deployment**: Docker container on UnRAID
- **Endpoint**: `http://unraid-ip:8080/metrics`
- **Notes**:
  - Must run in privileged mode
  - Needs access to Docker socket (`/var/run/docker.sock`)
  - Provides detailed per-container stats automatically

### 3. Alloy (UnRAID)
- **Purpose**: Scrape metrics from node-exporter + cAdvisor; tail Docker logs + syslog
- **Deployment**: Docker container on UnRAID
- **Export targets**:
  - Metrics → Prometheus (K8s)
  - Logs → Loki (K8s)
- **Config needs**:
  - Scrape job for node-exporter (localhost:9100)
  - Scrape job for cAdvisor (localhost:8080)
  - Log tailing for `/var/log/syslog`
  - Log tailing for Docker container logs (`/var/lib/docker/containers/*/`)
  - Labels: `source=unraid`, `hostname=unraid`

## Implementation Checklist

- [ ] Determine UnRAID IP (need to confirm if it's already monitored)
- [ ] Deploy node-exporter Docker container on UnRAID
- [ ] Deploy cAdvisor Docker container on UnRAID
- [ ] Deploy Alloy Docker container on UnRAID with proper config
- [ ] Update K8s Prometheus scrape config (add UnRAID Alloy endpoint)
- [ ] Test metrics ingestion in Prometheus UI
- [ ] Test logs ingestion in Loki
- [ ] Create Grafana dashboard for UnRAID:
  - System metrics (CPU, memory, load, temps)
  - Disk health (SMART attributes, utilization)
  - Docker container metrics (CPU, memory per container)
  - Array status (if available via metrics)
- [ ] Set up AlertManager rules:
  - Disk health warnings (SMART failures, reallocated sectors)
  - Array parity checks (if integrated)
  - Container restart spikes
  - Temp thresholds

## Questions to Clarify

- [ ] UnRAID IP address?
- [ ] Will Alloy run on UnRAID (pushing to K8s) or in K8s (pulling from UnRAID)?
- [ ] Which logs to capture: syslog only, or all Docker container logs?
- [ ] Any custom UnRAID metrics (array health, parity status, UPS)?

## References

- [Unraid Data Monitoring with Prometheus and Grafana](https://unraid.net/blog/prometheus)
- [Monitoring Unraid with Prometheus, Grafana, cAdvisor, NodeExporter](https://forums.unraid.net/topic/77593-monitoring-unraid-with-prometheus-grafana-cadvisor-nodeexporter-and-alertmanager/)
- [testdasi/grafana-unraid-stack](https://github.com/testdasi/grafana-unraid-stack)
- [UnRAID SMART & Disk Health Docs](https://docs.unraid.net/unraid-os/system-administration/monitor-performance/smart-reports-and-disk-health/)
