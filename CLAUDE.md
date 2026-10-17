# CLAUDE.md

## Session Start

1. Announce the running model and the session's task.
2. If a cheaper model would do, ask "This task would run fine on [model] — want to switch down?" If a more capable one is needed, ask "This task really needs Opus — want to switch up?" Wait for the answer.
   - **Opus**: cross-referencing, multi-source synthesis, architecture, first-time builds with design decisions.
   - **Sonnet**: routine work, editing existing code, most day-to-day tasks.
   - **Haiku**: simple reads, copies, formatting, lookups, subagent research.

## New Tools

Stop and tell the user before adding any new tool to the toolchain (CLI tools, `mise.toml` entries, package-manager installs, new dependencies, or wrappers like new runtimes). Wait for approval.

## Cost & Context Hygiene

Before each task, consider: cheaper model? independent tasks in parallel sessions? dead-weight context from finished work? an expensive autonomous loop without checkpoints?

Flag a context switch when a distinct task finishes and the next is independent, or context is past ~40-50% and the remaining work doesn't need it. Don't flag mid-architect or mid-sync. Surface the tradeoff; the user decides.

At session end, ask the user to run `/cost`, then append an entry to `~/pm-automation/.state/cost-log.yaml` with: date, task, type, cost, duration_api, duration_wall, code_changes, models (per-model breakdown), notes.

## What This Repo Is

GitOps homelab: a 4-node Kubernetes cluster on a TuringPi board, reconciled by Flux CD from `kubernetes/`. Changes to `main` are picked up within 1 minute and reconciled within 10.

- **OS**: Talos Linux (immutable, no SSH — use `talosctl`). Versions pinned in `talos/topf.yaml`, bumped by Renovate. Configs rendered/applied with [topf](https://github.com/postfinance/topf).
- **API endpoint**: `https://192.168.1.10:6443` (Talos VIP across n1–n3). Cluster name `turingpi`, CNI Flannel.
- **Nodes**: n1=192.168.1.234, n2=.235, n3=.236 (control planes, schedulable); n4=.233 (worker).
- **Storage**: Longhorn, replicas=2, a disk on every node (`/var/mnt/longhorn`, see below), hard anti-affinity. A node reboot leaves volumes `degraded` until rebuilt — wait for all volumes `healthy` before taking down another node.

## Repository Structure

```
kubernetes/flux-system/   Flux bootstrap
kubernetes/apps/<namespace>/<app>/{ks.yaml, kustomization.yaml, app/}
talos/                    topf.yaml, schematic.yaml, secrets.sops.yaml, all/ + control-plane/ patches
tofu/                     OpenTofu (Flux bootstrap)
TODO/                     work tracking
mise.toml                 pinned CLI tools + SOPS_AGE_KEY_FILE
```

Run `mise install` once. Infrastructure lives in its own namespace; user-facing apps go in `default`.

## Key Conventions

- **Everything deploys via HelmRelease** — no raw Deployments. Wrap plain images in bjw-s `app-template` (see `manyfold`).
- Every directory's `kustomization.yaml` must list new resources explicitly.
- **Secrets**: SOPS + age (`*.sops.yaml`, key at `talos/age-key.txt`, gitignored) or ExternalSecrets from 1Password.
- Longhorn PVCs use the `longhorn` storage class.

## Common Operations

```bash
flux get kustomizations -n flux-system
flux get helmreleases -A
flux reconcile kustomization flux-system --with-source
kubectl apply -k kubernetes/apps/<namespace>/<app>/app/   # manual apply
talosctl health -n 192.168.1.234
talosctl kubeconfig -n 192.168.1.10
tpi info; tpi power status                                  # TuringPi BMC
cd tofu && tofu plan                                        # then tofu apply
```

**Thermals** (per node IP): `talosctl -n <ip> read /sys/class/thermal/thermal_zone0/temp` (millidegrees C), `.../cooling_device0/cur_state` (fan 0–5), `/proc/loadavg`. Normal idle: 45–48°C, fan 1–2; 3+ warrants attention. n4 runs cooler. Fan noise differences are often physical resonance.

## Adding New Apps

1. Create `kubernetes/apps/<namespace>/<app>/` with `ks.yaml` (Flux Kustomization, `dependsOn` + `healthChecks` as needed), `kustomization.yaml` (wraps `ks.yaml`), and `app/` (its own `kustomization.yaml`, `helmrelease.yaml`, `helmrepository.yaml`, plus any ExternalSecret/PVC/Ingress; `namespace.yaml` only for infra apps in their own namespace).
2. Add the app to `kubernetes/apps/<namespace>/kustomization.yaml`, and the namespace to `kubernetes/apps/kustomization.yaml` if new.
3. Commit to `main`.

- `HelmRepository` goes in `namespace: flux-system`; `HelmRelease` in the app's namespace with `install.createNamespace: true`.
- OCI-hosted charts use an `OCIRepository` (`ref.tag` + `ref.digest`, helm `layerSelector`) referenced via `chartRef`, not a `type: oci` HelmRepository — Flux's `chart.spec.version` can't hold a digest, so Renovate can't pin it. See `forgejo`.
- A `HelmRepository` used by one app lives in that app's `app/` dir. When a second app needs it, move it to `kubernetes/apps/flux-repositories/helm-repositories/app/` and add `dependsOn: helm-repositories` to every consumer (two Kustomizations can't own the same object). `bjw-s` and `grafana` already live there.

### Split Kustomizations when a CR consumes a CRD from the same repo

A CR (`ClusterSecretStore`, `ClusterIssuer`, ...) in the same Kustomization as the HelmRelease that installs its CRD fails Flux's dry-run (`no matches for kind`). Split into `<app>/app/` (operator) and `<app>-config/app/` (CRs); the `-config` Kustomization sets `dependsOn: [<app>]` plus `healthChecks` on the operator's HelmRelease. Examples: `cert-manager`/`cert-manager-config`, `external-secrets`/`external-secrets-config`. Consumers of those CRs should depend on the `-config` Kustomization.

## Talos config with topf

```bash
cd talos
topf render -o output     # offline render to talos/output/ (gitignored, plaintext secrets)
topf apply --dry-run      # diff against live nodes
topf apply                # confirms per node, waits for each to stabilize
```

- Run via mise (it exports `SOPS_AGE_KEY_FILE`); otherwise sops/topf fail with "no key could decrypt".
- **Patch layout**: `all/` → `control-plane/` (or `worker/`) → `node/<host>/`, lexical order, later wins. `*.yaml.tpl` files are Go templates (`.Node.Host`, `.Node.IP`, `.Node.Role`) — prefer them over per-node copies.
- **Config shape (Talos 1.14+)**: topf's base config already contains the multi-doc kinds, so a v1alpha1 patch setting the same thing is rejected (`already set in v1alpha1 config`). Patch the new kinds instead: `machine.install` → `UnattendedInstallConfig`, `machine.network.nameservers` → `ResolverConfig`, `machine.kubelet.*` → `KubeletConfig` + `KubeNodeConfig` (`nodeIP`, labels, taints), `allowSchedulingOnControlPlanes` → `KubeNodeConfig` (taint entry with `$patch: delete`). `extraMounts` has no replacement. Kubelet settings go in `talos/all/10-kubelet.yaml`.
- If a future bump changes the shape while nodes straddle versions, branch on `semverCompare "<constraint>" (.Node.RuntimeData.TalosVersion | default "<target>")` — RuntimeData is empty on offline renders (CI), so the default must be the target version.
- `topf apply --dry-run` against nodes still on the old config shows a large diff (every setting re-expressed as documents). Apply node by node, checking `kubectl get nodes`/pods between each.
- Non-interactive: `topf apply`/`upgrade` auto-decline prompts without a TTY; pass the global `--confirm=false` before the subcommand. `apply` has no `--progress` flag.
- A worktree lacks the gitignored `talos/age-key.txt`; symlink the main checkout's key into `talos/`.
- **CI**: `.github/workflows/talos-validate.yaml` renders every node with throwaway secrets and runs `talosctl validate` on PRs touching `talos/`.
- Apply Talos changes **before** pushing Kubernetes changes that depend on them.

### Upgrades: upgrade the cluster, then merge

Merging a version bump changes nothing on the nodes, so upgrade from the PR branch first and merge after, keeping `main` in sync with what's running.

- **Talos**: `topf upgrade --dry-run`, then `topf upgrade` (control planes one at a time, drains each).
- **Kubernetes**: `talosctl upgrade-k8s -n 192.168.1.10 --to <version>`. Never bump the field and `topf apply` — that skips skew checks.
- For minor bumps check the [Talos support matrix](https://docs.siderolabs.com/talos/latest/getting-started/support-matrix).

## Longhorn data path

The data disk is `/var/mnt/longhorn`, a directory on EPHEMERAL declared by `talos/all/30-longhorn-volume.yaml` (`UserVolumeConfig`, `volumeType: directory`); the kubelet sees `/var/mnt` by default. `/var/lib/longhorn` only holds Longhorn's hardcoded engine/socket dirs and is not a data disk. `defaultDataPath` in the HelmRelease only seeds newly created Longhorn nodes.

- Longhorn refuses two disks on one filesystem. To move a node's disk path, evict and remove the old disk first, then add the new one — one node at a time, all volumes `healthy` between nodes.
- Longhorn doesn't create a missing disk directory; apply the `UserVolumeConfig` before adding a new node's disk.
- `replica-auto-balance` is off, so replicas can end up uneven after node-by-node maintenance.

## Database upgrades (grimmory MariaDB)

- Keep `MARIADB_AUTO_UPGRADE: "1"`; without it the entrypoint skips `mariadb-upgrade` on image bumps.
- A `pre-upgrade` Helm hook Job (`dump` controller in `mariadb.yaml`) dumps the live DB before every upgrade, keeping 10 dumps on `grimmory-mariadb-backups`. It blocks the upgrade if the server is unreachable; set `DUMP_REQUIRED: "false"` to ship a fix for a down DB.
- `grimmory-mariadb-data` uses the `snapshot-daily` Longhorn RecurringJob (local snapshots, retain 7).
- The `mariadb-upgrade-rehearsal` workflow rehearses base→head upgrades on arm64; reproduce locally with `.github/scripts/mariadb-upgrade-rehearsal.sh` (OrbStack).

## NAS-backed SMB shares (Unraid)

Pods mount Unraid SMB shares via `csi-driver-smb` (no in-tree CIFS; NFS lacks credential auth and depends on node-IP stability — see `TODO/ipv6-stability.md`). `kube-system/csi-driver-smb-config/` holds one shared `smb-creds` ExternalSecret (1Password Login `unraid-k8s-user`) and the share PVs in `app/shares/`; a JSON6902 patch in `app/kustomization.yaml` injects all constant fields.

To mount a share/subfolder:
1. Add `csi-driver-smb-config/app/shares/<name>.yaml` with only `metadata.name`, `csi.volumeHandle`, and `csi.volumeAttributes.source` (`//192.168.1.98/<Share>/<subdir>`), and list it in `app/kustomization.yaml`.
2. In the consuming app: a PVC (`storageClassName: ""`, `volumeName: <name>`, RWX) mounted via bjw-s `existingClaim`, and `dependsOn: csi-driver-smb-config` in its `ks.yaml`.

PV↔PVC is 1:1, so two apps needing the same subfolder need two PVs (same `source`, different names).

## TLS: metrics-server

1. **API server → metrics-server**: cert-manager's `selfsigned-cluster-issuer` issues the cert; cainjector injects the CA into the `APIService`. Configured in the HelmRelease `values.tls`.
2. **metrics-server → kubelet**: `serverTLSBootstrap: true` in `talos/all/10-kubelet.yaml` (`KubeletConfig.config`) makes kubelets submit serving CSRs, which `kubelet-csr-approver` auto-approves. Replaces `--kubelet-insecure-tls`. cert-manager can't help here — kubelet serving certs are issued per node.

Verify after applying: `kubectl get csr` (kubelet-serving CSRs should be approved, not Pending/Denied).
