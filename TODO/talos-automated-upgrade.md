# Automated Talos Upgrades

Upgrade orchestration is now handled by `topf upgrade` (rolling, control planes
one at a time, drain + stabilization). Renovate PRs for `talosVersion` /
`kubernetesVersion` tell you to upgrade the cluster from the PR branch and merge
afterwards. What's still manual is *running* those commands.

## Remaining goal

Merging (or approving) a Renovate Talos/k8s PR should be the only required action.

## Option — CI-driven topf

A GitHub Actions job on the Renovate PR (or on a `deploy` label) runs:

```bash
topf apply --confirm=false
topf upgrade --confirm=false
# k8s bumps: talosctl upgrade-k8s -n 192.168.1.10 --to <version>
```

then merges the PR on success.

Requires:
- The age key as a GitHub secret (repo is public — scope it to a protected
  environment with required reviewers).
- Network access to the nodes (192.168.1.0/24) from the runner — Tailscale
  GitHub Action with a subnet router, or a self-hosted runner on the LAN.

## Done

- [x] Rolling upgrade orchestration (`topf upgrade`)
- [x] Renovate `ignoreUnstable: true` for `siderolabs/talos` and the kubelet
- [x] PR validation: `.github/workflows/talos-validate.yaml` renders + validates

## Acceptance criteria

- [ ] Approving a Renovate Talos/k8s PR triggers the cluster upgrade from CI
- [ ] PR only merges after the upgrade succeeds (main always matches the cluster)
