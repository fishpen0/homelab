# IPv6 Stability for Cluster Nodes

Right now the kubelet on each node binds whatever IPv6 address it acquires via
SLAAC from the AT&T gateway. That address is in the routable ISP prefix
(`2600:1700:89c2:c200::/64`), so it ends up in the kubelet serving-cert SAN
list. To make `kubelet-csr-approver` accept those certs we currently whitelist
the entire `2600:1700:89c2::/48` — the AT&T-delegated /48 — as a stopgap.

Goals for the proper fix (in order of preference):

1. **Make the routable IPv6 address itself stable and use it intentionally.**
   - AT&T delegates a /48. The /64 the LAN sees is normally stable across power
     events but can change when the gateway is replaced or firmware-updated.
   - If we can get a guaranteed-stable /64 from AT&T (DHCPv6-PD reservation?
     gateway setting?), set static addresses on each node within that /64 and
     scope the kubelet-csr-approver whitelist to the exact /64 instead of /48.

2. **Use ULA only and drop the routable IPv6 from the kubelet altogether.**
   - Statically assign each node an address in `fdd7:ad7c:fa:4181::/64` (the ULA
     already listed in `nodeIP.validSubnets`).
   - Block SLAAC for the routable prefix on `end0` via Talos sysctl
     (`net.ipv6.conf.end0.accept_ra_pinfo: "0"` keeps RA-derived routes but
     ignores prefix info; verify ULA isn't lost).
   - Remove the `2600:1700:89c2::/48` whitelist entry.

3. **Stop including the IPv6 in the kubelet cert SAN.**
   - Either via kubelet config (`tlsBindAddress` / specific IPs) or by ensuring
     only the desired IPs are on the interface. Same end state as (2) but with
     more granular control.

Context for whoever picks this up:
- Discovered during 2026-05-22 cluster recovery when nodes came up at fresh
  DHCPv4 IPs and the kubelet CSRs started including the routable IPv6.
- `kubelet-csr-approver` providerIpPrefixes lives in
  `kubernetes/apps/kube-system/kubelet-csr-approver/app/helmrelease.yaml`.
- Talos network config is per-node in `talos/talconfig.yaml`.

## Steps
1. [ ] Decide between routable-stable vs ULA-only approach
2. [ ] Implement (talconfig + apply, or DHCPv6 reservation, or sysctl)
3. [ ] Narrow the `kubelet-csr-approver` IPv6 whitelist back down
4. [ ] Document the chosen address plan in CLAUDE.md
