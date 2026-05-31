# S3 Proxy to Unraid

Deploy an S3-compatible proxy service that exposes Unraid shares as S3 buckets (likely via `s3proxy` or similar reverse proxy).

Notes:
- Allows K8s cluster and other services to access Unraid storage via S3 API (simpler than SMB/NFS mount)
- Can wrap Garage backend or proxy directly to Unraid storage
- Useful for backup targets, media libraries, and general object storage interface
- May need to run on Unraid itself or in cluster depending on performance/isolation requirements

Steps:
1. [ ] Evaluate s3proxy implementations (minio gateway, s3proxy, wasabi, etc.)
2. [ ] Decide deployment location (Unraid container vs. cluster pod)
3. [ ] Configure bucket mappings to Unraid shares
4. [ ] Set up auth (API keys, IAM policies)
5. [ ] Expose S3 endpoint to cluster
6. [ ] Test with Longhorn/Immich/other consumers
