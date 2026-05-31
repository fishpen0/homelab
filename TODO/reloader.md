# Stakater Reloader (auto-restart on secret/configmap change)

Deploy Stakater Reloader cluster-wide so workloads automatically roll when a
Secret or ConfigMap they consume changes. Closes the credential-**rotation** gap
that the rest of our setup doesn't cover.

## Why

Most controllers/apps read their secrets **once at startup** and cache them in
memory — they never re-read the mounted file when the data changes. So when a
secret is rotated (SOPS re-encrypt, ESO refresh, manual `kubectl`), the running
pod keeps using the **old** value until something restarts it. If the old
credential is then revoked upstream, the workload silently breaks.

This is exactly the tailscale-operator failure mode: the operator booted with
stale `operator-oauth` creds and 401'd for 8 days until a manual
`rollout restart`. Making `operator-oauth` SOPS-single-owned fixed the
**cold-boot** race, but **rotation** is still unguarded — a deliberate
restart is currently the only way to pick up new creds.

Reloader watches referenced Secrets/ConfigMaps and rolls the owning
Deployment/StatefulSet automatically on change.

## Setup steps

- [ ] Add Reloader as a HelmRelease under `kubernetes/apps/<category>/reloader/`
      (chart `oci://ghcr.io/stakater/charts/reloader` or the stakater Helm repo)
- [ ] Decide default mode: opt-in (`reloader.stakater.com/auto: "true"` per
      workload) vs watch-everything. Prefer **opt-in** to avoid surprise rollouts.
- [ ] Annotate workloads that consume rotatable secrets, using **targeted**
      annotations where possible: `secret.reloader.stakater.com/reload: <secret-name>`

## Per-app wiring

- [ ] **tailscale-operator** — needs the reload annotation on the operator
      Deployment, but the chart doesn't expose pod/deployment annotations, so
      inject it via a Flux **post-render** kustomize patch on the HelmRelease.
      Target secret: `operator-oauth`.
- [ ] Audit other apps for the same pattern (anything reading SOPS/ESO secrets
      at startup): grafana-admin, manyfold secrets, 1Password Connect, etc.
      Add `reloader.stakater.com/auto` or targeted annotations as appropriate.

## Notes

- Reloader only helps where the K8s Secret data actually changes. SOPS rotations
  must still be committed + reconciled; ESO refreshes happen on its interval.
- It does **not** fix cold-boot ordering — that's handled separately
  (single-owner secret + `dependsOn`). Reloader is the rotation half.
