# Tailscale Terraform Provider

Manage Tailscale tailnet config (ACLs, DNS, OAuth clients) declaratively via the
[`tailscale/tailscale`](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
provider in `tofu/`, instead of hand-editing JSON in the admin console.

## Why
- ACL drift is invisible right now — only source of truth is the admin UI
- The operator OAuth client (`kubernetes/apps/tailscale/.../secret.sops.yaml`) was
  created by hand; rotating it is a multi-step manual process
- `tofu/` already exists for Flux bootstrap, so the provider plugs in cleanly

## Steps
1. [ ] Create a dedicated OAuth client in the admin console with `acl:write`,
       `dns:write`, `auth_keys` (or whichever scopes the resources need); store
       creds in SOPS
2. [ ] Add `tofu/tailscale/provider.tf` pinning the provider version
3. [ ] Extract current ACL into `tofu/tailscale/acl.hujson` and wire up
       `tailscale_acl` referencing it via `file()`
4. [ ] Optional: manage `tailscale_oauth_client` for the operator so its creds
       are TF-managed too (output → SOPS-encrypted file consumed by Flux)
5. [ ] Optional: `tailscale_tailnet_settings` for MagicDNS, key expiry defaults
6. [ ] Document the apply flow alongside the existing Flux-bootstrap notes

## Notes
- Provider does NOT cover daemon-side actions (login, route advertisement from
  the host) — those still happen on the device
- Subnet route *approval* via the API/TF is spotty; may still need a UI click
