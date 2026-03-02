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

- **OS**: Talos Linux v1.10.6 (immutable, no SSH — managed via `talosctl`)
- **Cluster name**: `turingpi`
- **API endpoint**: `https://192.168.1.234:6443`
- **Nodes**: n1–n3 are control planes (scheduling allowed), n4 is the worker
- **Node IPs**: n1=192.168.1.234, n2=192.168.1.235, n3=192.168.1.236, n4=192.168.1.233
- **CNI**: Flannel
- **Storage**: Longhorn (distributed block storage, replicas=2, worker nodes only)
- **GitOps**: Flux v2 watches `systems/turingpi/kubernetes/`

## Repository Structure

```
homelab/
├── systems/turingpi/
│   ├── talos/                  # Talos cluster config (talconfig.yaml, SOPS secrets)
│   └── kubernetes/
│       ├── flux-system/        # Flux bootstrap manifests
│       └── infrastructure/     # All deployed infrastructure
│           ├── longhorn/       # Distributed storage
│           └── tailscale/      # VPN operator for remote access
└── tofu/                       # OpenTofu (Terraform) — currently manages Flux bootstrap
```

## Key Conventions

- **All apps deploy via HelmRelease** — no raw Deployments. Add new apps as a HelmRelease + Kustomization under `infrastructure/`.
- **Kustomize overlays** wire everything together. Every directory has a `kustomization.yaml` that must include new resources explicitly.
- **Secrets use SOPS + age** encryption. The age key is at `systems/turingpi/talos/age-key.txt` (gitignored). Encrypted files end in `.sops.yaml`.
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
kubectl apply -k systems/turingpi/kubernetes/infrastructure/<component>/
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
talosctl kubeconfig -n 192.168.1.234
```

### Regenerate Talos node configs (after editing talconfig.yaml)
```bash
cd systems/turingpi/talos
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

1. Create a directory under `systems/turingpi/kubernetes/infrastructure/<name>/`
2. Add a `namespace.yaml`, `helmrelease.yaml`, and `kustomization.yaml`
3. Reference the new directory in `systems/turingpi/kubernetes/infrastructure/kustomization.yaml`
4. Commit to `main` — Flux reconciles automatically
