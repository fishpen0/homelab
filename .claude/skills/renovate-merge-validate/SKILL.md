---
name: renovate-merge-validate
description: Triage open Renovate PRs in the homelab repo, research them in parallel with subagents, then merge and validate against the live Talos/Flux cluster. Use whenever the user asks to "look at renovate PRs", "merge and validate updates", "clear the renovate backlog", "run the dependency updates", or wants any Renovate/Helm chart/image bump merged and verified against the live Talos/Flux cluster, even if they only name one PR.
---

# Renovate merge & validate

Flux deploys whatever lands on `main`, so "merge" means "roll it out to the live cluster". The job: list the PRs, research every one in parallel, merge the safe ones in a sensible order, prove each app is healthy, and report.

Design rule: **research is free and parallel, merging is gated and ordered.** Never wait for the user before research. Ask only once, after research, with findings in hand.

## 1. List, bind, and spawn research immediately

```bash
gh pr list --author "app/renovate" --json number,title,url,mergeable,statusCheckRollup,labels,headRefName
```

**Bind every listed PR to the session** (`mcp__ccd_pr__bind_pr` with its `url`), including the ones skipped below. A session holds several bound PRs at once (`get_status` returns one plus `otherBoundPrs`), and the PR bar lets the user watch checks and merge from the app without waiting on this session. Only open PRs bind. If a bind is denied, say so once and carry on; do not loop on it.

Skip Talos/Kubernetes version PRs (`talos/topf.yaml`): per CLAUDE.md the cluster is upgraded from the PR branch first (`topf upgrade` / `talosctl upgrade-k8s`), then merged. List them as "left to the user" and spawn nothing for them.

For every other PR, in the same turn as the list, spawn one general-purpose background subagent for **Phase 1 (read-only)**. Do not wait for a separate triage pass or for user approval. Brief (subagents start cold, so fill it in):

> Prepare Renovate PR #N (<title>) in /Users/loganstuart/dev/personal/homelab. READ-ONLY: do not merge, edit, apply, restart or create anything.
> a. Baseline the app: HelmReleases, pods (restarts), PVCs, ExternalSecrets, Certificates, Ingresses in its namespace, and its current version. Note pre-existing problems. Try `kubectl logs/exec` (the kubelet CSR denial may or may not block them); say what was blocked.
> b. Read the diff and upstream release/upgrade notes for every major between old and new (WebFetch/WebSearch). Look for breaking changes, removed values keys we use (cross-check our helmrelease values), CRD changes (the global patch sets CreateReplace; Longhorn overrides to Skip), data migrations, base-image/arch changes, and whether downgrade is possible.
> c. Check for repo gaps that make the upgrade unsafe (e.g. MariaDB `MARIADB_AUTO_UPGRADE` unset so `mariadb-upgrade` never runs; no backups for a stateful app).
> d. Report: verdict **PROCEED** (no blocker, no irreversible migration), **PROCEED-WITH-SNAPSHOT** (stateful and migration or no rollback), or **HOLD** (blocker, needs a manifest change or user decision), with evidence, the fix if HOLD, and the Phase 2 validation plan. Count baseline alerts/targets exactly, so Phase 2 can compare.
> Stop after reporting; Phase 2 starts only when the main agent messages you.

Classes to tell the subagent about, so its verdict is calibrated:
- **Major bumps / labels `renovate/major`, `needs-review`**: databases and kube-prometheus-stack majors still need a human decision only if research says HOLD or PROCEED-WITH-SNAPSHOT; a clean PROCEED can continue.
- **Storage (Longhorn)**: needs healthy volumes (`kubectl get volumes.longhorn.io -n longhorn-system`: all healthy, none rebuilding); must run alone.
- **Failing checks**: failure is a blocker. Missing checks are common here (only `renovate/stability-days` reports) and are not.

## 2. Decide the plan (main agent)

When the Phase 1 reports arrive, show one table: PR, bump, namespace, verdict, risk, and the planned order. Then:

- **PROCEED** PRs: merge without asking again when the user invoked this skill to merge (or said "do all"/"proceed"). If they only asked to "look at" the PRs, present the table and ask once.
- **PROCEED-WITH-SNAPSHOT**: take the snapshot first (below), then treat as PROCEED. Taking a Longhorn snapshot is non-destructive; do it without asking, but tell the user.
- **HOLD**: do not merge. Say exactly what is needed (e.g. "add `MARIADB_AUTO_UPGRADE: "1"` to the PR branch,") and offer to do it. Editing a Renovate branch is outward-facing, so ask first.

Ordering and concurrency:
- Storage (Longhorn) and anything node-wide (CSI drivers, node-exporter) run **alone and first**; wait until validated healthy before releasing the rest.
- Tailscale operator goes before anything validated over a tailnet ingress: it rolls every `ts-*` proxy, which blips every ingress.
- Anything with Longhorn PVCs waits for a Longhorn upgrade to settle (no rebuilds, engines/instance-managers stable).
- Same namespace, or one `dependsOn`s the other (see the dependency graph in CLAUDE.md / memory): serialise.
- Independent patch/minor HelmReleases in different namespaces may run in parallel.
- Merge sequentially even when validating in parallel: Renovate uses `rebaseWhen: behind-base-branch`, so a merge can invalidate other PRs. Merge one, then `gh pr view <n> --json mergeable,mergeStateStatus` before the next. `UNKNOWN` right after a merge means GitHub is recomputing; merge another clean PR and come back.

### Snapshot step (stateful apps)
For any PR whose app has a Longhorn PVC and an irreversible-looking migration (databases, Grafana, anything the research flags): create a Longhorn Snapshot CR for each PVC's volume before merging, and for databases also a logical dump (`kubectl exec ... mariadb-dump/pg_dump`, copied to the scratchpad). There is no backup target configured, so a snapshot is the only rollback. Record snapshot names in the report.

## 3. Phase 2 (merge and validate)

**The main agent merges; subagents only validate.** Subagent `gh pr merge` calls get denied as "Merge Without Review", so don't hand merges to them. For each PR in order: `gh pr merge N --squash --delete-branch` from the main session, then `flux reconcile kustomization flux-system --with-source` and the app's own Kustomization. If the merge is denied here too, don't retry or route around it: tell the user the PR is bound and ready in the PR bar, and continue with validation once they merge it.

Then message the PR's subagent (SendMessage) with this brief:

> PR #N is merged and Flux has reconciled. Validate per your plan. Never edit manifests by hand or `kubectl apply`; Flux owns the cluster. A HelmRelease can still say `Running 'upgrade'` right after rollout finishes; wait ~30s and recheck before judging. Do not merge anything, and do not restart/delete things to fix failures: report instead.

Validation can also run inline in the main session when the check is short; use `Monitor` with an until-loop to wait on a HelmRelease, never chained `sleep`.

Validation checks (adapt to the app):
- `flux get helmrelease -n <ns>` shows the new chart version and `Ready=True`.
- `kubectl rollout status` on deployments/daemonsets/statefulsets; pods Running, restarts 0 (or explained).
- A functional probe, not just "pods are up". Examples: ESO → force-sync an ExternalSecret and confirm `SecretSynced`; cert-manager → ClusterIssuer and Certificates Ready; metrics-server → APIService Available and `kubectl top nodes`; Longhorn → all volumes healthy, no stuck rebuilds, nodes schedulable; Tailscale → proxy pods Running and an ingress reachable; Loki/Alloy → pods Ready and logs flowing; Prometheus → targets up compared with baseline, firing alerts grouped by alertname compared with baseline (not just a count); databases → server version, upgrade ran, app connected.
- An RWO volume moving to a new node shows `FailedAttachVolume ... waiting on detach` for a few seconds on a Recreate rollout; that is normal, not a failure.
- Kubelet CSR denial (AdGuard lacks n1-n4 records) may block `kubectl logs/exec/top`; fall back to `get`/`describe`/events and Flux status and say which checks were blocked.

Follow the repo's debugging discipline: diagnose from logs/events before suggesting any restart or force-sync.

## 4. Report

One table: PR, old → new, result (validated / failed / held / skipped), key evidence, snapshots taken. Call out untested paths honestly, restart counts that changed and why, pre-existing issues seen in the baseline (odd but not ours), and PRs left to the user with the reason. Offer the next-best candidates.

If a PR fails validation: don't revert silently. Show the evidence and propose a revert PR (`gh pr revert` or a revert commit) for the user to approve.

## Notes

- Commits follow Conventional Commits, one line, no Claude attribution trailers (merges here are squash merges of Renovate's own titles, so nothing to write).
- Renovate automerges patch bumps on its own with a 3 day age gate, so remaining PRs are usually majors, storage, or ones that failed. Expect the hard ones.
- `gh pr close --delete-branch` fails inside a worktree (it tries to check out `main`, which the main checkout holds); close first, then `git push origin --delete <branch>`.
- At session end, per CLAUDE.md, ask the user for `/cost` and log it.
