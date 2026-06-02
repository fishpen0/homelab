# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Model Selection

At session start:
1. Announce which model is running.
2. State what task this session will handle.
3. Assess the right model tier:
   - **Opus**: Complex cross-referencing, multi-source synthesis, architect sessions, first-time builds with design decisions.
   - **Sonnet**: Routine work, editing existing code, file reorganization, most day-to-day tasks.
   - **Haiku**: Simple reads, file copies, formatting, search/lookup, subagent research.
4. If current model is more expensive than needed, immediately ask: "This task would run fine on [model] — want to switch down?"
5. If current model is less capable than needed, immediately ask: "This task really needs Opus — want to switch up?" Wait for answer before proceeding in either case.

## Cost & Context Hygiene

**Before every task**, evaluate cheapest and fastest execution:
1. Can this run on a cheaper model?
2. Can independent tasks run in parallel sessions?
3. Is the context carrying dead weight from finished work?
4. Am I about to run an expensive autonomous loop without checkpoints?

**Proactive context switch alerts.** Flag when:
- A distinct task is finished and the next one is independent
- Context is past ~40-50% and remaining work doesn't need the history
- Cheap work is being taxed by earlier complex context

Do NOT flag when mid-architect or mid-sync where accumulated context IS the value. Surface the tradeoff. Let the user decide.

**Cost logging.** At the end of each session:
- Ask the user to run `/cost` for the session total
- Append an entry to: ~/pm-automation/.state/cost-log.yaml
- Fields: date, task, type, cost, duration_api, duration_wall, code_changes, models (per-model breakdown), notes

## What This Repo Is

GitOps-managed homelab running a 4-node Kubernetes cluster on a TuringPi board. Infrastructure is declared as code and automatically reconciled by Flux CD. Changes to `main` are picked up within 1 minute and reconciled within 10 minutes.

## Cluster Overview

- **OS**: Talos Linux (immutable, no SSH — managed via `talosctl`). Version is pinned in `talos/talconfig.yaml` and bumped by Renovate.
- **Cluster name**: `turingpi`
- **API endpoint**: `https://192.168.1.10:6443` (Talos native VIP, floats across n1–n3)
- **Nodes**: n1–n3 are control planes (scheduling allowed), n4 is the worker
- **Node IPs**: n1=192.168.1.234, n2=192.168.1.235, n3=192.168.1.236, n4=192.168.1.233
- **CNI**: Flannel
- **Storage**: Longhorn (distributed block storage, replicas=2, worker nodes only)
- **GitOps**: Flux v2 watches `kubernetes/`

## Repository Structure

```
homelab/
├── kubernetes/                       # Kubernetes manifests
│   ├── flux-system/                  # Flux bootstrap manifests
│   └── apps/                         # All deployed apps + infrastructure, grouped by namespace
│       ├── cert-manager/             # cert-manager operator + ClusterIssuer config
│       ├── external-secrets/         # ESO operator + 1Password Connect + ClusterSecretStore
│       ├── kube-system/              # metrics-server, kubelet-csr-approver
│       ├── longhorn-system/          # Distributed storage + UI ingress
│       ├── manyfold/                 # 3D print model library (will fold into default later)
│       ├── observability/            # kube-prometheus-stack, Loki, Alloy
│       └── tailscale/                # Tailscale operator (VPN ingress class)
├── talos/                            # Talos cluster config (talconfig.yaml, SOPS secrets)
├── tofu/                             # OpenTofu (Terraform) — currently manages Flux bootstrap
└── TODO/                             # Work tracking
```

Each app dir follows: `<category>/<app>/{ks.yaml, kustomization.yaml, app/}`. Infrastructure components live in their own namespace (cert-manager, longhorn-system, etc.); user-facing apps go in `default` per bbck/onedr0p homelab convention.

## Key Conventions

- **All apps deploy via HelmRelease** — no raw Deployments. Add new apps as a HelmRelease + Flux Kustomization under `kubernetes/apps/<category>/<app>/`. For apps with no upstream chart, wrap raw images in `bjw-s` `app-template` (see `manyfold` for an example).
- **Kustomize overlays** wire everything together. Every directory has a `kustomization.yaml` that must include new resources explicitly.
- **Secrets use SOPS + age** encryption. The age key is at `talos/age-key.txt` (gitignored). Encrypted files end in `.sops.yaml`.
- **Longhorn PVCs** use the `longhorn` storage class.

## Common Operations

### Interact with the turing pi BMC
```bash
tpi -h
tpi info
tpi power status
```

### Check cluster/Flux status
```bash
kubectl get nodes
flux get kustomizations -n flux-system
flux get helmreleases -A
```

### Force Flux to reconcile now
```bash
flux reconcile kustomization flux-system --with-source
```

### Apply a kustomization manually
```bash
kubectl apply -k kubernetes/apps/<category>/<component>/app/
```

### Talos cluster management
```bash
# Health check
talosctl health -n 192.168.1.234

# View node logs
talosctl -n 192.168.1.234 logs -f

# Bootstrap (fresh cluster only)
talosctl bootstrap -n 192.168.1.234

# Get kubeconfig
talosctl kubeconfig -n 192.168.1.10
```

### Regenerate Talos node configs (after editing talconfig.yaml)
```bash
cd talos
talhelper genconfig
```

### OpenTofu
```bash
cd tofu
tofu init
tofu plan
tofu apply
```

### Fan & Thermal Monitoring

```bash
# Temps across all nodes (millidegrees C — divide by 1000)
for node in 192.168.1.234 192.168.1.235 192.168.1.236 192.168.1.233; do
  echo -n "$node temp: " && talosctl --nodes $node read /sys/class/thermal/thermal_zone0/temp
done

# Fan speed (pwm-fan, 0–5 scale) across all nodes
for node in 192.168.1.234 192.168.1.235 192.168.1.236 192.168.1.233; do
  echo -n "$node fan state: " && talosctl --nodes $node read /sys/class/thermal/cooling_device0/cur_state
done

# Load averages
for node in 192.168.1.234 192.168.1.235 192.168.1.236 192.168.1.233; do
  echo -n "$node load: " && talosctl --nodes $node read /proc/loadavg
done
```

**Reference values (idle/light load):**
- Temps: ~45–48°C is normal
- Fan states: 1–2/5 is normal; 3+ warrants attention
- n4 runs cooler/quieter (worker only, light Flux + CoreDNS workload)
- Fan audibility differences are often physical resonance, not a thermal issue

## Adding New Infrastructure

1. Create the directory tree `kubernetes/apps/<category>/<app>/` with:
   - `ks.yaml` — Flux Kustomization (with `dependsOn` + `healthChecks` as needed)
   - `kustomization.yaml` — wraps `ks.yaml`
   - `app/` — actual manifests:
     - `kustomization.yaml` listing each resource
     - `namespace.yaml` (only for infrastructure apps in their own namespace; user apps live in `default`)
     - `helmrepository.yaml`, `helmrelease.yaml`, plus any `Secret`/`ConfigMap`/`Ingress`/`ExternalSecret`/PVC files
2. Add `<app>` to the parent `kubernetes/apps/<category>/kustomization.yaml` if it's new in that category
3. Add `<category>` to `kubernetes/apps/kustomization.yaml` if the category is new
4. Commit to `main` — Flux reconciles automatically (≤1 min pickup, ≤10 min to Ready)

**Pattern notes:**
- `HelmRepository` always goes in `namespace: flux-system`
- `HelmRelease` goes in the component's own namespace
- `install.createNamespace: true` is standard on all HelmReleases

### CRD bootstrap: split Kustomizations when a CR consumes a CRD from the same repo

If a custom resource (e.g. `ClusterSecretStore`, `ClusterIssuer`, `Certificate`) lives in the same Flux Kustomization as the HelmRelease that installs its CRD, Flux's upfront server-side dry-run fails with `no matches for kind "Foo" in version "x/y"` — the CRD doesn't exist yet, so the whole Kustomization stalls and the operator never gets deployed. Classic chicken-and-egg.

**Fix:** split into two Flux Kustomizations under the same app dir:

- `<app>/app/` — operator HelmRelease + supporting Secrets/Configs (no CRs)
- `<app>-config/app/` — the CRs that depend on the CRD

The `-config` Kustomization sets `dependsOn: [<app>]` plus `healthChecks` on the operator's HelmRelease so the CRD is guaranteed installed before the CRs apply.

Examples in this repo:
- `cert-manager` (operator) + `cert-manager-config` (ClusterIssuer)
- `external-secrets` (operator + 1password-connect) + `external-secrets-config` (ClusterSecretStore)

Downstream apps that consume the CR (e.g. an `ExternalSecret` referencing the `ClusterSecretStore`) should `dependsOn` the `-config` Kustomization, not just the operator one — otherwise their own CRs may apply before the SecretStore/Issuer is Ready.

## talhelper genconfig — SOPS Key Required

`talhelper genconfig` will fail with a SOPS decryption error unless the age key is explicitly provided:

```bash
cd talos
SOPS_AGE_KEY_FILE=age-key.txt talhelper genconfig
```

The age key is at `talos/age-key.txt` (gitignored). Without `SOPS_AGE_KEY_FILE` set, the command silently finds no valid decryption key and exits with error.

## NAS-backed SMB shares (Unraid)

Pods mount Unraid SMB shares via `csi-driver-smb`. Kubernetes has no in-tree CIFS volume, so the driver is required (NFS would be in-tree but offers no credential auth and depends on node-IP stability we don't have — see `TODO/ipv6-stability.md`).

Layout (operator + `-config` split, like cert-manager):
- `kube-system/csi-driver-smb/` — the driver HelmRelease.
- `kube-system/csi-driver-smb-config/` — one shared `smb-creds` ExternalSecret (cluster's single SMB identity, 1Password Login item `unraid-k8s-user`) + the share PVs under `app/shares/`. A JSON6902 patch in `app/kustomization.yaml` injects all constant fields (driver, credential, mountOptions, `uid=99,gid=100`, capacity, `Retain`).

**To mount a new share/subfolder:**
1. Add a PV at `csi-driver-smb-config/app/shares/<name>.yaml` — only `metadata.name`, `csi.volumeHandle`, and `csi.volumeAttributes.source` (`//192.168.1.98/<Share>/<subdir>`). Everything else comes from the patch.
2. List it in `csi-driver-smb-config/app/kustomization.yaml`.
3. In the consuming app: a `PersistentVolumeClaim` (`storageClassName: ""`, `volumeName: <name>`, RWX) and mount it with bjw-s `existingClaim`. Add `dependsOn: csi-driver-smb-config` to the app's `ks.yaml`.

No credential work per share — `unraid-k8s-user` has RW on the whole share. A PV↔PVC bind is 1:1, so two apps needing the same subfolder need two PVs (same `source`, different names).

## TLS Architecture Notes

### metrics-server TLS (two separate connections)

1. **API server → metrics-server** (aggregated API): Secured via cert-manager. The `selfsigned-cluster-issuer` ClusterIssuer issues a cert for the metrics-server service; cert-manager's cainjector injects the CA bundle into the `APIService` resource so the API server trusts it. Configured in the metrics-server HelmRelease `values.tls` block.

2. **metrics-server → kubelet** (scraping node stats): Secured via kubelet TLS bootstrap + `kubelet-csr-approver`. Enabled by `serverTLSBootstrap: true` in `talconfig.yaml` (under `machine.kubelet.extraConfig`). Kubelets submit `CertificateSigningRequest` objects; `kubelet-csr-approver` auto-approves them. This replaces `--kubelet-insecure-tls`.

**cert-manager cannot fix connection #2** — kubelet serving CSRs are issued by the kubelet process on each node, not by in-cluster workloads. Both components are needed for full hardening.

### Applying Talos config changes safely

After editing `talconfig.yaml`, regenerate and apply **before** pushing Kubernetes changes that depend on the new config (e.g. removing `--kubelet-insecure-tls`):

```bash
cd talos
SOPS_AGE_KEY_FILE=age-key.txt talhelper genconfig
talosctl apply-config -n 192.168.1.234 -f clusterconfig/turingpi-n1.yaml
talosctl apply-config -n 192.168.1.235 -f clusterconfig/turingpi-n2.yaml
talosctl apply-config -n 192.168.1.236 -f clusterconfig/turingpi-n3.yaml
talosctl apply-config -n 192.168.1.233 -f clusterconfig/turingpi-n4.yaml
```

Verify kubelet CSRs appear after applying:
```bash
kubectl get csr   # expect 4 Pending with signerName: kubernetes.io/kubelet-serving
```

### kubelet patch merging in talconfig.yaml

When adding new `machine.kubelet` config, merge it into the existing `baselonghorn` patch anchor (which already touches `machine.kubelet.extraMounts`). Do not create a separate patch for the same top-level key — Talos merges patch keys, but having two patches that both set `machine.kubelet` can cause unexpected behavior depending on merge strategy.
