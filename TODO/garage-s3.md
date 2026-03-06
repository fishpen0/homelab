# Garage (S3-compatible object storage on Unraid)

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
