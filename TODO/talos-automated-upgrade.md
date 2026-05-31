# Automated Talos Upgrades via Renovate

Right now merging a Renovate Talos PR only updates `talconfig.yaml` — the actual
node upgrade still requires running `talosctl upgrade` manually against each node.
Goal: merging the PR should be the only required action.

## Problem

The Renovate PR body template uses `talosctl apply-config`, which only pushes
config changes. An OS upgrade requires `talosctl upgrade`, which reboots the node
into the new installer image. These are two different operations and neither
is automated today.

## Options

### Option A — Flux + Talos machine config image tag
Talos supports in-cluster upgrades via the `upgrade` API. The installer image
reference lives in the machine config (`talosImageURL` in talconfig.yaml). If
talhelper generates the full image tag (e.g.
`factory.talos.dev/installer/<hash>:v1.13.3`) and that config is applied to the
node, Talos detects the image change and performs a self-upgrade + reboot
automatically. This means:
- Renovate bumps `talosVersion`
- A CI job (GitHub Actions) runs `talhelper genconfig` + `talosctl apply-config`
  on merge to main
- Each node sees the new installer image tag in its config and self-upgrades

Requires: GitHub Actions runner with `talosctl` + age key access (via secret),
network access to the cluster API (192.168.1.234:6443) — likely needs Tailscale
in the Actions runner.

### Option B — Talhelper GitHub Action
`talhelper` has a first-party GitHub Action (`siderolabs/talos-action`) that can
run `talosctl upgrade` as a post-merge CI step. Would remove the manual node loop
entirely.

## Also needed

- Fix Renovate config to add `ignoreUnstable: true` to the Talos package rule
  so alpha/rc releases are never proposed (see current incident: nodes landed on
  v1.13.0-alpha.2 because this filter was missing).

## Acceptance criteria

- [ ] Merging a Renovate Talos version bump PR triggers CI
- [ ] CI runs `talhelper genconfig` and applies/upgrades all 4 nodes in rolling order
- [ ] Control planes upgraded one at a time (etcd quorum preserved)
- [ ] Worker upgraded last
- [ ] Renovate `ignoreUnstable: true` added for `siderolabs/talos`
