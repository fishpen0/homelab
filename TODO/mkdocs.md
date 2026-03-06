# MkDocs Site

Set up MkDocs to publish all documentation in this repo as a browsable static site.

## Steps
1. [ ] Choose a theme — Material for MkDocs is the standard choice
2. [ ] Add `mkdocs.yml` at repo root with nav structure covering:
   - Cluster overview (from CLAUDE.md / README)
   - Infrastructure components (one page per service)
   - TODO items (pull from TODO/)
   - Runbooks / common operations
3. [ ] Decide on hosting — options:
   - GitHub Pages (free, automatic via Actions)
   - Self-hosted in-cluster (Deployment + ingress under `turingpi.local`)
4. [ ] Add a GitHub Actions workflow to build and deploy on push to `main` (if using GitHub Pages)
5. [ ] Audit existing docs (CLAUDE.md, TODO/*.md) and reorganize into `docs/` tree
6. [ ] Add per-service runbooks for anything not already documented
