# LGTM Stack for Turing Pi Cluster

## Overview
This directory contains the LGTM (Loki, Grafana, Tempo, Mimir) observability stack deployment for the Turing Pi Kubernetes cluster. The stack provides comprehensive logging, metrics, tracing, and visualization capabilities.

## Components

### 1. Loki (Log Aggregation)
- **Version**: 5.41.4
- **Storage**: 10Gi Longhorn PVC with 7-day retention
- **Resource Limits**: 1 CPU, 2Gi memory
- **Features**: 
  - Single binary mode for simplicity
  - Automatic retention and cleanup
  - Rate limiting and cardinality controls
  - Compaction and optimization

### 2. Grafana (Visualization)
- **Version**: 7.0.19
- **Storage**: 5Gi Longhorn PVC
- **Resource Limits**: 1 CPU, 1Gi memory
- **Features**:
  - Pre-configured datasources (Loki, Tempo, Mimir)
  - Pre-installed dashboards
  - Default admin/admin credentials

### 3. Tempo (Distributed Tracing)
- **Version**: 1.8.0
- **Storage**: 5Gi Longhorn PVC with 7-day retention
- **Resource Limits**: 1 CPU, 1Gi memory
- **Features**:
  - Multiple receiver protocols (Jaeger, OTLP, Zipkin)
  - Local storage backend
  - Automatic retention management

### 4. Mimir (Metrics Storage)
- **Version**: 5.7.0
- **Storage**: 20Gi Longhorn PVC
- **Resource Limits**: 2 CPU, 4Gi memory
- **Features**:
  - High-performance metrics storage
  - Multi-tenancy support
  - Automatic retention and compaction

## Storage Management

### Automatic Storage Management
- **Loki**: 10Gi with 7-day retention
- **Grafana**: 5Gi for dashboards and configs
- **Tempo**: 5Gi with 7-day retention  
- **Mimir**: 20Gi with configurable retention
- **Total**: ~40Gi maximum usage

### Retention Policies
- **Logs (Loki)**: 7 days
- **Traces (Tempo)**: 7 days
- **Metrics (Mimir)**: Configurable via retention rules

### Anti-Disk-Full Measures
1. **Retention Policies**: Automatic cleanup of old data (7 days)
2. **Compaction**: Regular optimization of storage
3. **Storage Limits**: HelmRelease configurations limit PVC sizes
4. **Automatic Management**: No manual intervention required

## Deployment

### Prerequisites
- Flux v2 installed and configured
- Longhorn storage class available
- Cluster with at least 2 worker nodes

### Automatic Deployment
The LGTM stack is automatically deployed via Flux when committed to the main branch:

```bash
# Check deployment status
flux get kustomizations -n flux-system

# Check LGTM resources
kubectl get all -n lgtm
```

### Manual Deployment
```bash
# Apply the kustomization
kubectl apply -k systems/turingpi/kubernetes/infrastructure/lgtm/

# Check status
kubectl get pods -n lgtm
```

## Access

### Via Ingress (Recommended)
Once the ingress controller is deployed, you can access services directly:

- **Grafana**: http://grafana.turingpi.local (admin/admin)
- **Loki**: http://loki.turingpi.local
- **Tempo**: http://tempo.turingpi.local
- **Mimir**: http://mimir.turingpi.local
- **Combined Dashboard**: http://lgtm.turingpi.local

### Setup Local DNS
Run the setup script to add local DNS entries:
```bash
chmod +x systems/turingpi/kubernetes/infrastructure/lgtm/ingress/setup-local-dns.sh
./systems/turingpi/kubernetes/infrastructure/lgtm/ingress/setup-local-dns.sh
```

### Via Port Forward (Alternative)
If you prefer port-forwarding:

- **Grafana**: `kubectl port-forward -n lgtm svc/grafana 3000:80`
- **Loki**: `kubectl port-forward -n lgtm svc/loki 3100:3100`
- **Tempo**: `kubectl port-forward -n lgtm svc/tempo 3200:3200`
- **Mimir**: `kubectl port-forward -n lgtm svc/mimir 9009:9009`



## Maintenance

### Automatic Maintenance
The LGTM stack requires no manual maintenance. All components automatically:

- Clean up old data based on retention policies
- Compact and optimize storage
- Manage resource usage within configured limits
- Handle scaling and recovery automatically

### Status Checks
```bash
# Check component status
kubectl get pods -n lgtm

# Check storage usage
kubectl get pvc -n lgtm

# Check HelmRelease status
kubectl get helmreleases -n lgtm
```

## Troubleshooting

### Common Issues

1. **Storage Full**
   - Check PVC usage: `kubectl get pvc -n lgtm`
   - Trigger retention cleanup
   - Scale down/up components

2. **High Memory Usage**
   - Check resource limits
   - Adjust memory requests/limits in HelmRelease values

3. **Connection Issues**
   - Verify service endpoints
   - Check pod health
   - Review logs for errors

### Logs
```bash
# View component logs
kubectl logs -n lgtm -l app.kubernetes.io/name=loki
kubectl logs -n lgtm -l app.kubernetes.io/name=grafana
kubectl logs -n lgtm -l app.kubernetes.io/name=tempo
kubectl logs -n lgtm -l app.kubernetes.io/name=mimir
```

## Security

### Network Policies
- All services use ClusterIP
- No external ingress enabled by default
- Internal cluster communication only

### RBAC
- Default namespace permissions
- No elevated privileges
- Service account isolation

### Storage
- Longhorn encrypted volumes
- PVC access mode restrictions
- Resource quota enforcement

## Performance Tuning

### Resource Optimization
- **CPU**: Start with requests, monitor usage
- **Memory**: Adjust based on data volume
- **Storage**: Monitor growth patterns

### Scaling
- **Horizontal**: Adjust replica counts
- **Vertical**: Modify resource limits
- **Storage**: Increase PVC sizes as needed

## Backup and Recovery

### Data Backup
- Longhorn snapshots for PVCs
- Regular backup schedules
- Cross-cluster replication (if configured)

### Disaster Recovery
- HelmRelease configurations in Git
- Stateful data in Longhorn
- Configuration in Flux manifests

## Support

For issues or questions:
1. Check the cleanup script output
2. Review component logs
3. Verify resource quotas
4. Check Longhorn storage status
5. Review Flux reconciliation status