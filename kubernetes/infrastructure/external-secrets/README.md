# External Secrets + 1Password Integration

This component sets up **external-secrets-operator** with **1Password Connect** to manage Kubernetes secrets from your 1Password vault.

## Architecture

```
1Password Vault
    ↓
1Password Connect Server (Pod in cluster)
    ↓
external-secrets-operator (Controller)
    ↓
Kubernetes Secrets
```

## Components Deployed

1. **external-secrets-operator** — Watches `ExternalSecret` resources and syncs them with 1Password
2. **1password-connect** — Secure API gateway between the operator and your 1Password vault
3. **ClusterSecretStore** — Configures how to reach 1Password (via the Connect server)
4. **onepassword-credentials** — Secret containing your 1Password Connect credentials (SOPS-encrypted)

## Setup Checklist

### Prerequisites (One-Time)

1. **1Password Account**: You need access to 1Password.com

2. **Get Connect Token**:
   - Log into 1Password.com → Account Settings → Integrations
   - Create a new integration (this generates `1password-credentials.json`)
   - The credentials are already encrypted in `secret.sops.yaml` (don't share!)

3. **Create Secrets in 1Password**:
   - Log into 1Password app → your vault
   - Create any secrets you want to sync to the cluster
   - Note the **secret name** (used in `ExternalSecret` resources)

### Verifying the Setup

After Flux reconciles (check `main` branch pushed):

```bash
# Check operator is running
kubectl get deploy -n external-secrets
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets -f

# Check 1Password Connect is running
kubectl get deploy -n external-secrets 1password-connect
kubectl logs -n external-secrets -l app.kubernetes.io/name=connect -f

# Verify ClusterSecretStore is ready
kubectl get clustersecretstores
kubectl describe clustersecretstore onepassword-cluster
```

## Using External Secrets

### Create an ExternalSecret

1. Copy `example-externalsecret.yaml` as a template
2. Update:
   - `metadata.name` — what to call this secret
   - `metadata.namespace` — which namespace to create it in
   - `spec.target.name` — name of the Kubernetes secret that gets created
   - `spec.data[].remoteRef.name` — secret name in 1Password vault
   - `spec.data[].remoteRef.property` — field name within that secret

Example:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword-cluster
    kind: ClusterSecretStore
  target:
    name: my-app-secret  # This creates a Kubernetes Secret called "my-app-secret"
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_PASSWORD
      remoteRef:
        name: "prod-db-password"
        property: "password"
    - secretKey: API_KEY
      remoteRef:
        name: "external-api-key"
        property: "key"
```

3. Deploy the ExternalSecret (Flux will reconcile it)

### Verify It Works

```bash
# Check if the ExternalSecret was synced
kubectl get externalsecrets -n my-app
kubectl describe externalsecret my-app-secrets -n my-app

# Once synced, the actual secret exists
kubectl get secret my-app-secret -n my-app
kubectl get secret my-app-secret -n my-app -o json | jq '.data | keys'
```

## Troubleshooting

### ExternalSecret stuck in `NotReady`

```bash
kubectl describe externalsecret <name> -n <namespace>
```

**Common issues**:

- **"failed to get secret"**: Secret name doesn't exist in 1Password vault
- **"connect error"**: 1Password Connect pod is down or unreachable
- **"authentication failed"**: Invalid credentials in `onepassword-credentials` secret

Check 1Password Connect logs:

```bash
kubectl logs -n external-secrets -l app.kubernetes.io/name=connect
```

### 1Password Connect pod failing

```bash
kubectl logs -n external-secrets <pod-name>
```

Common causes:
- Credentials file is corrupted
- Network issue reaching 1Password.com

## Advanced: Future Hardening

- [ ] Switch `ClusterSecretStore` → `SecretStore` per namespace for RBAC
- [ ] Add pod resource quotas
- [ ] Enable 1Password audit logging
- [ ] Use separate 1Password account for infrastructure

## Files

- `namespace.yaml` — external-secrets namespace
- `helmrepository.yaml` — Helm chart repos for both components
- `external-secrets-operator.yaml` — Operator HelmRelease
- `1password-connect.yaml` — Connect server HelmRelease
- `clustersecretstore.yaml` — ClusterSecretStore resource
- `secret.sops.yaml` — 1Password credentials (encrypted)
- `kustomization.yaml` — Ties everything together
- `example-externalsecret.yaml` — Template for creating new external secrets
