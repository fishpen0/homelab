# Talos config (topf)

Machine configs for the `turingpi` cluster are generated and applied with
[topf](https://postfinance.github.io/topf). Tool versions are pinned in the repo
root `mise.toml`; run `mise install` once.

| File | Purpose |
|---|---|
| `topf.yaml` | Cluster name/endpoint, Talos + Kubernetes versions, node list |
| `schematic.yaml` | Image Factory schematic: `sbc-rockchip`/`turingrk1` overlay, `iscsi-tools`, `util-linux-tools` |
| `secrets.sops.yaml` | Talos secrets bundle (`talosctl gen secrets` format), SOPS/age-encrypted |
| `all/` | Patches applied to every node |
| `control-plane/` | Patches applied to control planes only |
| `age-key.txt` | age private key — **gitignored**, back it up outside the repo |

Patches merge `all/` → `<role>/` → `node/<host>/`, in lexical order within each
directory. `*.yaml.tpl` files are Go templates (`.Node.Host`, `.Node.IP`,
`.Node.Role`, ...).

## Nodes

| Host | IP | Role |
|---|---|---|
| n1 | 192.168.1.234 | control-plane |
| n2 | 192.168.1.235 | control-plane |
| n3 | 192.168.1.236 | control-plane |
| n4 | 192.168.1.233 | worker |

API endpoint: `https://192.168.1.10:6443` (Talos VIP on the control planes).

## Common commands

```bash
topf render -o output    # render offline to output/ (gitignored — plaintext secrets)
topf apply --dry-run     # diff against live nodes
topf apply               # apply, one node at a time with stabilization
topf upgrade --dry-run   # what a Talos upgrade would do
topf upgrade             # rolling Talos upgrade (control planes one at a time)
topf kubeconfig          # admin kubeconfig
topf talosconfig         # talosctl client config
```

Kubernetes upgrades go through `talosctl upgrade-k8s -n 192.168.1.10 --to <version>`
first; bump `kubernetesVersion` in `topf.yaml` afterwards.
