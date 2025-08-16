# Turing Pi Talos Cluster Configuration

## Current Status ✅
- **Fresh Configuration**: All old cluster state has been cleaned up
- **SOPS Encryption**: Properly configured with age encryption keys
- **Longhorn Ready**: Configuration optimized for 4-node cluster with SSDs
- **Best Practices**: Following current Talos v1.10.6 recommendations

## Cluster Configuration
- **Cluster Name**: turingpi
- **Talos Version**: v1.10.6
- **Nodes**: 4 nodes (3 control plane, 1 worker)
- **Network**: 192.168.1.0/24 subnet

### Node Details
| Hostname | IP Address | Role | Install Disk |
|----------|------------|------|--------------|
| n1 | 192.168.1.224 | Control Plane | /dev/nvme0n1 |
| n2 | 192.168.1.226 | Control Plane | /dev/nvme0n1 |
| n3 | 192.168.1.223 | Control Plane | /dev/nvme0n1 |
| n4 | 192.168.1.225 | Worker | /dev/nvme0n1 |

## Longhorn Configuration
- **Replica Count**: 2 (optimal for 4-node cluster)
- **Storage Path**: /var/lib/longhorn (dedicated partition)
- **Performance**: Optimized for SSD workloads
- **Node Selector**: Worker nodes only (n4)

## Deployment Process

### 1. Apply Talos Configuration
```bash
cd systems/turingpi/talos
./deploy.sh
```

### 2. Bootstrap Cluster
```bash
talosctl bootstrap -n 192.168.1.224
```

### 3. Get Kubernetes Access
```bash
talosctl kubeconfig -n 192.168.1.224
```

### 4. Setup Longhorn Prerequisites
```bash
./setup-longhorn.sh
```

### 5. Deploy Infrastructure
The Flux infrastructure will automatically deploy Longhorn and other components.

## File Structure
```
systems/turingpi/talos/
├── talconfig.yaml          # Main Talos configuration
├── talsecret.sops.yaml     # Encrypted cluster secrets
├── age-key.txt             # Age encryption key (keep secure!)
├── .sops.yaml              # SOPS configuration
├── deploy.sh               # Deployment script
├── setup-longhorn.sh       # Longhorn setup script
├── clusterconfig/          # Generated Talos configs
│   ├── turingpi-n1.yaml   # Node 1 config
│   ├── turingpi-n2.yaml   # Node 2 config
│   ├── turingpi-n3.yaml   # Node 3 config
│   ├── turingpi-n4.yaml   # Node 4 config
│   └── talosconfig        # Client config
└── README.md               # This file
```

## Security Notes
- **age-key.txt**: Contains private encryption key - keep secure!
- **talsecret.sops.yaml**: Contains encrypted cluster secrets
- **clusterconfig/**: Contains generated machine configs (gitignored)

## Monitoring & Troubleshooting

### Check Cluster Health
```bash
talosctl health -n 192.168.1.224
```

### Check Node Status
```bash
talosctl -n 192.168.1.224 get nodes
```

### View Logs
```bash
talosctl -n 192.168.1.224 logs -f
```

### Longhorn Status
```bash
kubectl get pods -n longhorn-system
kubectl get nodes -l node-role.kubernetes.io/worker
```

## Next Steps After Deployment
1. Verify all nodes are healthy
2. Deploy Flux infrastructure
3. Monitor Longhorn deployment
4. Create storage classes and volumes
5. Deploy applications

## Support
- **Talos Documentation**: https://www.talos.dev/
- **Longhorn Documentation**: https://longhorn.io/docs/
- **Turing Pi**: https://turingpi.com/