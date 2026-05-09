# Authentik

Deploy Authentik as a centralized authentication and authorization server for cluster applications.

## Architecture

- Authentik running in-cluster (HelmRelease)
- PostgreSQL backend (use Longhorn PVC)
- Expose via Tailscale ingress for admin UI
- OAuth2/OIDC provider for apps (Grafana, future dashboards, etc.)

## Setup Steps

- [ ] Create Authentik HelmRelease under `infrastructure/authentik/`
- [ ] Configure PostgreSQL database (Helm chart includes option, or use external)
- [ ] Set up SOPS-encrypted admin credentials
- [ ] Expose admin UI via Tailscale ingress
- [ ] Create OAuth2 provider for test application (e.g. Grafana)
- [ ] Integrate Grafana with Authentik for SSO

## Notes

- Consider storing initial admin password in 1Password and syncing via ExternalSecret
- Authentik can auto-create users from OAuth providers if needed (GitHub, Google, etc.)
- Future: LDAP/active directory integration for other services
