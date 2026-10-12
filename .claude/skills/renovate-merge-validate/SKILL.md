---
name: renovate-merge-validate
description: Triage open Renovate PRs in the homelab repo, then merge and validate several at once using parallel subagents. Use whenever the user asks to "look at renovate PRs", "merge and validate updates", "clear the renovate backlog", "run the dependency updates", or wants any Renovate/Helm chart/image bump merged and verified against the live Talos/Flux cluster, even if they only name one PR.
---

# Renovate merge & validate

Flux deploys whatever lands on `main`, so "merge" means "roll it out to the live cluster". The job is therefore: pick safe PRs, merge, watch Flux roll it out, prove the app is healthy, and report. Subagents parallelise this, but parallel rollouts can interfere with each other, so the main agent decides what is safe to run concurrently.

## 1. Triage (main agent, no subagents yet)

```bash
rtk gh pr list --author "app/renovate" --json number,title,mergeable,statusCheckRollup,labels,headRefName
rtk gh pr diff <n>        # for each candidate
```

Classify every PR, then show the user a short table (PR, bump size, namespace, class, risk) before merging anything:

- **Talos / Kubernetes version (`talos/topf.yaml`)**: do NOT merge. Per CLAUDE.md the cluster is upgraded from the PR branch first (`topf upgrade` / `talosctl upgrade-k8s`), then merged. Report these and leave them to the user.
- **Major bumps or labels `renovate/major` / `needs-review`**: read upstream release notes (WebFetch) and check for breaking changes, CRD changes, or data migrations. Databases (mariadb etc.) and kube-prometheus-stack majors need explicit user approval each.
- **Storage (Longhorn)**: needs volume health (`kubectl get volumes.longhorn.io -n longhorn-system`: all healthy, no rebuilding) and release notes; run alone, never alongside another PR.
- **Patch/minor on a single HelmRelease**: low risk, eligible for parallel runs.
- **PRs with failing or missing checks**: mention it; checks being absent is common here (only `renovate/stability-days` reports), so absence alone is not a blocker, but failure is.

Merging is outward-facing, so get the user's go-ahead on the final list unless they already named PRs or said to proceed.

## 2. Choose a batch

Run PRs concurrently only if they are independent. Serialise when any of these hold:
- Same namespace or one `dependsOn`s the other (see the dependency graph in CLAUDE.md / memory: e.g. `external-secrets` underpins manyfold, grafana, forgejo; `cert-manager` underpins metrics-server).
- Both touch nodes (Longhorn, CSI drivers, node-exporter): rollouts across 4 nodes with n3 possibly absent can strain the cluster.
- Either is a major or storage bump.

Also merge sequentially even when validating in parallel: Renovate uses `rebaseWhen: behind-base-branch`, so merging one PR can force others to rebase and invalidate their checks. Merge one, then `gh pr view <n> --json mergeable` before the next.

## 3. Subagent per PR

Spawn one general-purpose subagent per PR in a single turn (background). Give each this brief, filled in; subagents start cold so be explicit:

> Merge and validate Renovate PR #N (<title>) in /Users/loganstuart/dev/personal/homelab.
> 1. Baseline: record HelmRelease state, pods, and any app-specific resources (ExternalSecrets, Certificates, Ingresses, PVCs) in the target namespace. Check `kubectl` works first.
> 2. Read the diff and (for non-patch) upstream release notes. If you find a breaking change, STOP and report instead of merging.
> 3. `rtk gh pr merge N --squash --delete-branch`.
> 4. `flux reconcile kustomization flux-system --with-source`, then the app's own Kustomization. Never edit manifests by hand or `kubectl apply`; Flux owns the cluster.
> 5. Validate (see checks below). A HelmRelease can still say `Running 'upgrade'` right after rollout finishes; wait ~30s and recheck before judging.
> 6. Report: version before/after, each check with evidence, anything odd (pre-existing errors seen in the baseline count as odd-but-not-yours; say so).
> Do not merge any other PR, do not restart or delete things to "fix" failures; report instead.

Validation checks for the subagent (adapt to the app):
- `flux get helmrelease -n <ns>` shows the new chart version and `Ready=True`.
- `kubectl rollout status` on its deployments/daemonsets/statefulsets; pods Running, restarts 0.
- Functional probe that proves the thing works, not just that pods are up. Examples: ESO → force-sync an ExternalSecret (`kubectl annotate externalsecret ... force-sync=$(date +%s) --overwrite`) and confirm `SecretSynced`; cert-manager → ClusterIssuer and Certificates Ready; metrics-server → APIService Available and `kubectl top nodes`; Longhorn → all volumes healthy, no stuck rebuilds; Tailscale → proxy pods Running and an ingress reachable; Loki/Alloy → pods Ready and logs flowing.
- Kubelet CSR denial is a known cluster issue (AdGuard lacks n1-n4 records), so `kubectl logs/exec/top` may fail for unrelated reasons; use `kubectl get`/`describe`/events and Flux status as the primary evidence and say which checks were blocked.

Follow the repo's debugging discipline: diagnose from logs/events before suggesting any restart or force-sync.

## 4. Report

One table: PR, old → new, result (validated / failed / skipped), key evidence. Call out untested paths honestly (e.g. cert-manager renewal not exercised), failures with logs, and PRs deliberately skipped with the reason. Offer the next-best candidates.

If a PR fails validation: don't revert silently. Show the evidence and propose a revert PR (`rtk gh pr revert` or a revert commit) for the user to approve.

## Notes

- Commits follow Conventional Commits, one line, no Claude attribution trailers (merges here are squash merges of Renovate's own titles, so nothing to write).
- Renovate automerges patch bumps on its own with a 3 day age gate, so remaining patch PRs are usually ones still inside that window or ones that failed.
- At session end, per CLAUDE.md, ask the user for `/cost` and log it.
