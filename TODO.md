# Homelab TODO

## Longhorn Backups
Configure an external backup target so Longhorn volumes survive intentional node wipes (beyond the existing 2-replica in-cluster redundancy).

Two options available on the NAS host:
- **NFS** — already available; Longhorn supports NFS backup targets natively
- **S3-compatible** — set up MinIO (or similar) on the NAS host; Longhorn supports S3-compatible targets

Either works. S3 gives better flexibility (can also be used by other tools). NFS is simpler to stand up.

Steps:
1. Choose NFS or S3-compatible (MinIO on NAS)
2. If S3: deploy MinIO on NAS, create a bucket + access credentials
3. Configure Longhorn `backupTarget` and `backupTargetCredentialSecret` in the HelmRelease
4. Set a recurring backup schedule (RecurringJob) — e.g. daily snapshot + weekly backup

## Observability Stack
- [ ] Add Grafana (dashboards)
- [ ] Add Prometheus (metrics collection)
- [ ] Add Loki (log aggregation)
- [ ] Add Tempo (distributed tracing)
- [ ] Cry about the cluster being too small to justify mimir or thanos
