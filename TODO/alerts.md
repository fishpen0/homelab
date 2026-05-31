# Operational Alerts

The 2026-05-22 cluster recovery exposed a class of failures that ran silently
for ~2.5 months because nothing was firing on them. Capture them as alerts in
prom/loki/alertmanager so the next failure surfaces immediately instead of
being discovered by hand.

## Concrete things to alert on

Most of these have well-known PromQL / Loki queries; this is a starter list of
what we'd have wanted on this incident.

### Cluster reachability / drift from declared state
- [ ] **Node not Ready** for >5m — `kube_node_status_condition{condition="Ready",status="true"} == 0`
- [ ] **etcd quorum lost / leader missing** — `etcd_server_has_leader == 0`
- [ ] **kube-apiserver down** — blackbox probe of `https://192.168.1.10:6443` from outside the cluster (would have caught yesterday on minute one)
- [ ] **Node IP changed from declared** — compare `kube_node_info{internal_ip=~"..."}` against expected `.233-.236`

### Flux health
- [ ] **Kustomization not Ready for >10m** — `gotk_reconcile_condition{type="Ready",status="False"}` (would have caught the `flux-system` path-not-found from day one)
- [ ] **HelmRelease not Ready for >15m**
- [ ] **GitRepository lastFetchedRevision lagging main** — would catch a stuck source-controller

### kubelet / CSR
- [ ] **Pending CSRs accumulating** — `count(kube_certificatesigningrequest_condition{condition="Approved",status="false"}) > 0`
- [ ] **kubelet TLS errors in apiserver audit log** — Loki query on the apiserver logs for `tls: internal error`
- [ ] **kubelet serving cert expiring** soon

### DHCP / network drift (the actual root cause this time)
- [ ] **Node primary IP changed unexpectedly** — diff `kube_node_info` snapshot vs declared
- [ ] **Default gateway changed** — node_exporter `node_network_route_info` or similar
- [ ] **DHCP lease lost on cluster nodes** — exposed via node_exporter if we add a textfile collector that scrapes `/var/lib/dhclient/*`

### Tailscale
- [ ] **`tag:k8s` device offline >10m** — script that polls the Tailscale API and exposes as a Prometheus metric (would have caught the operator going dark in March)
- [ ] **API server proxy device missing** — same poll, specific hostname check

### Storage / Longhorn
- [ ] **Longhorn volume Degraded for >1h**
- [ ] **PVC stuck Pending for >10m**

### Renovate / chart drift
- [ ] **HelmRelease chart version differs from desired** — `flux_helmrelease_chart_version` mismatch alerts so a stuck upgrade doesn't go unnoticed for months

## Plumbing also needed

- [ ] **Route Alertmanager → somewhere I'll actually see it** (Slack? Tailscale-routed email? Pushover? Ntfy?)
- [ ] **Heartbeat alert** — Alertmanager dead-man's switch via a service like healthchecks.io, so "no alerts" doesn't quietly mean "alertmanager is down too"
- [ ] **Blackbox-exporter** for external probes (apiserver, ingress hosts, BMC)
- [ ] **Tailscale API exporter** (small Python/Go script + ServiceMonitor) so device-online status is in Prom
- [ ] **Audit logs through Loki**, not just container stdout — so kubelet TLS errors, RBAC denies, etc. are queryable

## Why this matters

This incident took ~6 hours of live debugging to recover from. The signals were
all there — `kubectl get csr`, Flux Kustomization status, Tailscale device list,
operator pod restarts — but I had to go look. The cost of not alerting on these
is that you don't notice for months, and then you have to rediscover the whole
mental model on the fly.
