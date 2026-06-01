# Auto-updating README cluster banner (kubefetch)

Automate the neofetch-style cluster info banner at the top of `README.md` so it
stays current instead of being a hand-pasted, stale snapshot (currently frozen at
`Cluster Age: 0d`, `No GitOps tool used`, `v1.32.3`, etc.).

## Status

**Mostly built, not merged.** Work lives on branch `claude/confident-lewin-46a7af`
(worktree `.claude/worktrees/confident-lewin-46a7af/`), uncommitted. Blocked only
on a manual GitHub deploy-key step (see below).

## Decisions already made

- **Tool: kubefetch.** It's the only "neofetch for k8s" that exists (confirmed via
  research — the niche is empty). Last commit ~Dec 2024, stale but functional. No
  published container image.
- **Format: plain monochrome text** in a fenced code block, *not* SVG. GitHub
  markdown doesn't render ANSI color, and SVGs get served as `<img>` (text not
  selectable). Plain text stays selectable and gives clean git diffs. Strip ANSI
  with `NO_COLOR=1` + `sed 's/\x1b\[[0-9;]*m//g'`.
- **Trigger: CronJob with diff-then-commit** (daily 07:17 UTC). Rejected
  "run on every Flux reconcile" — Flux runs near-constantly and most reconciles
  are no-ops; pod-count churn would spam commits. The job regenerates, compares to
  the checked-in README, and only commits if the block between
  `<!-- kubefetch:start --> / <!-- kubefetch:end -->` markers changed.
- Ad-hoc runs are possible:
  `kubectl create job --from=cronjob/readme-updater manual-$(date +%s) -n automation`

## Files (exist on the branch above)

```
kubernetes/apps/automation/
  kustomization.yaml                         # added `automation` to apps
  readme-updater/
    ks.yaml                                  # Flux Kustomization
    kustomization.yaml
    app/
      namespace.yaml                         # automation ns
      rbac.yaml                              # SA + ClusterRole, read-only/scoped
      script-configmap.yaml                  # update-readme.sh
      cronjob.yaml                           # daily 07:17 UTC
      kustomization.yaml                     # deploy-key.sops.yaml commented out
```
Plus edits to `README.md` (marker wrapping) and `kubernetes/apps/kustomization.yaml`.

## Remaining steps

1. [ ] Decide image strategy: (a) build kubefetch → GHCR via a GH Action, or
       (b) `alpine + git` image that curls the release binary at pod start.
       Session leaned toward (b) for zero CI changes.
2. [ ] **Manual GitHub step (blocker):**
   ```bash
   ssh-keygen -t ed25519 -N '' -C 'readme-updater@turingpi' -f /tmp/readme-updater-key
   # add /tmp/readme-updater-key.pub at github.com/fishpen0/homelab/settings/keys
   #   as a DEPLOY KEY with "Allow write access" checked
   kubectl create secret generic readme-updater-deploy-key -n automation \
     --from-file=id_ed25519=/tmp/readme-updater-key --dry-run=client -o yaml \
     > kubernetes/apps/automation/readme-updater/app/deploy-key.sops.yaml
   sops --encrypt --in-place --age <age-pubkey> \
     --encrypted-regex '^(data|stringData)$' \
     kubernetes/apps/automation/readme-updater/app/deploy-key.sops.yaml
   # uncomment `- deploy-key.sops.yaml` in app/kustomization.yaml
   rm /tmp/readme-updater-key*
   ```
3. [ ] Fix `.sops.yaml` `path_regex` — still references old `systems/turingpi/...`
       layout instead of `kubernetes/...`.
4. [ ] Add `dependsOn`/health per the new-app checklist (standalone, likely
       `dependsOn: flux-system`).
5. [ ] Bring the branch into main (or cherry-pick the `automation/` tree) and merge.
6. [ ] Test: `kubectl create job --from=cronjob/readme-updater test-1 -n automation`.

## Later / stretch

- Trigger on repo merge (GH Action or Flux Notification Controller `Alert` on
  applied changes) instead of / in addition to the daily cron.
