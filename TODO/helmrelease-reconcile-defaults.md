# HelmRelease reconcile / remediation defaults

Decide on a repo-wide policy for `spec.install` / `spec.upgrade` retry + remediation on every HelmRelease, then audit existing HRs and standardize.

## Why this matters

Flux's helm-controller defaults `install.remediation.retries: 0` — one shot, then Stall. Any HR that depends on something transiently-not-ready (ExternalSecret resolving from 1Password, CRD just installed, PVC binding to a brand-new Longhorn disk) hits this on first install and requires manual `flux reconcile` to recover. Won't auto-heal.

This is going to bite repeatedly given our stack:
- **ExternalSecrets + 1Password Connect**: any time a 1P item is missing or a token gets rotated, dependent HRs fail-and-stall. Happened to manyfold-postgres on 2026-05-31 — fix was field-not-found in 1P, but the HR stayed Stalled for hours after we fixed it because retries were 0.
- **Renovate auto-bumps**: Helm chart upgrades occasionally fail transiently (Helm timeouts, ordering, value schema gotchas like the 1password connect v1→v2 we just hit). Without retries, every Renovate PR risks landing the repo in a stalled state until someone notices.
- **First boot / cluster rebuild**: dependencies coming up in waves naturally produce transient failures; current config requires hand-holding.

## Questions to answer

- What's the right `install.remediation.retries` value? `-1` (infinite) is appealing but masks real problems. Bounded (e.g. `5`) gives a balance but needs the right interval.
- What about `upgrade.remediation.retries` and `upgrade.remediation.strategy` (`rollback` vs `uninstall`)? Stateful workloads (Postgres) should probably *never* uninstall on failure — rollback only, or stall and alert.
- Should this differ by workload class — stateful (Postgres, Longhorn, ESO operator itself) vs stateless (apps, exporters, sidecars)?
- What does `install.timeout` + `upgrade.timeout` look like for slow-starting workloads (5m default may not be enough for Longhorn manager init, kube-prometheus-stack)?
- Do we want `cleanupOnFail` and/or `force` for upgrades? Trade-offs.

## What to read

- Flux HelmRelease spec: https://fluxcd.io/flux/components/helm/helmreleases/#configuring-failure-remediation
- onedr0p/home-ops — look at his HelmRelease patterns, he tends to set `install`/`upgrade` blocks explicitly across the board
- bbck/homelab — same; check whether their HRs are consistent or one-off per app
- Any postmortems in the Flux community on the "RetriesExceeded → Stalled" trap

## Steps

1. [ ] Read the Flux remediation docs, write down the decision matrix (workload class × install vs upgrade × retries/strategy/timeout)
2. [ ] Survey 5–10 HRs each in onedr0p and bbck, note the patterns
3. [ ] Pick a default for stateless apps and a default for stateful ones
4. [ ] Codify as a brief "HelmRelease checklist" section in `CLAUDE.md`
5. [ ] Audit every existing HR in `kubernetes/apps/` and standardize
6. [ ] Consider a Kustomize `components/` overlay or kyverno policy that enforces the standard so new HRs can't ship without it

## Adjacent concerns (worth noting, not blocking)

- **Alerting on Stalled HRs**: a Stalled HR is currently invisible — only catches your eye when something downstream breaks. Hook into kube-prometheus-stack with a Flux dashboard + alert (`flux_helmrelease_condition` metric → alert when `type=Stalled, status=true` for >15m).
- **Renovate gating for stateful workloads**: separate TODO worth considering — auto-merging chart bumps for Postgres / Longhorn / cert-manager is what produced the 2026-05-18 multi-major mass-bump that took down Longhorn for 89 days. Tighten Renovate config alongside this work.
