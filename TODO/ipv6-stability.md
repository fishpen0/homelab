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

4. **Drop IPv6 from the cluster entirely (leading candidate — decision deferred).**
   - The owner is "not sure I actually want IPv6 at all." If the cluster is
     IPv4-only in practice (Flannel pod CIDR is IPv4, VIP is IPv4, all services
     are reached over IPv4/Tailscale), then routable IPv6 on the nodes buys
     nothing and is purely a source of cert-SAN churn and the /48 whitelist hack.
   - Disable IPv6 / RA acceptance on `end0` via Talos
     (`net.ipv6.conf.end0.disable_ipv6: "1"` or `accept_ra: "0"`), drop the ULA
     and routable entries from `nodeIP.validSubnets`, and remove the
     `2600:1700:89c2::/48` whitelist from kubelet-csr-approver entirely.
   - Cleanest end state: kubelet serving certs only ever carry the stable static
     IPv4, so the CSR approver can whitelist just `192.168.1.0/24` (or the exact
     node IPs). No IPv6 moving parts at all.
   - **Deferred** — revisit when touching the IPv4 static-addressing work below,
     since both are edits to the same talconfig network block.

Context for whoever picks this up:
- Discovered during 2026-05-22 cluster recovery when nodes came up at fresh
  DHCPv4 IPs and the kubelet CSRs started including the routable IPv6.
- `kubelet-csr-approver` providerIpPrefixes lives in
  `kubernetes/apps/kube-system/kubelet-csr-approver/app/helmrelease.yaml`.
- Talos network config is per-node in `talos/talconfig.yaml`.

### AT&T gateway IPv6 config (as observed 2026-05-31)

```
Status                          Available
Global Unicast IPv6 Address     2600:1700:89c2:c200::1   <- gateway
Link-local IPv6 Address         fe80::aa40:f8ff:fe60:5a81
IPv6 Addressing Subnet          2600:1700:89c2:c200::/64  <- LAN /64 (SLAAC source)
IPv6 Delegated Prefix Subnet    2600:1700:89c2:c20f::/64
```

Notes:
- The LAN /64 the nodes SLAAC from is `2600:1700:89c2:c200::/64` — the same /64
  whose /48 parent we currently whitelist. Confirms option 1's premise: a single
  stable /64 *is* what's being served today, but it's not guaranteed stable
  across a gateway swap/firmware update.
- There's a separately **delegated** prefix `...:c20f::/64` distinct from the LAN
  /64 — so AT&T is doing some prefix delegation, but the nodes are using the
  plain LAN /64 via SLAAC, not the delegated one.
- Leaning toward **option 4 (drop IPv6)** given the owner doesn't want IPv6;
  decision deferred but flagged as the likely path.

## IPv4 instability is the bigger half (the actual outage trigger)

The IPv6 SAN issue above is downstream of a more fundamental problem: **the node
IPv4 addresses are not stable**. The nodes (n1=.234, n2=.235, n3=.236, n4=.233)
currently sit **inside** the gateway's DHCP pool and have no reservations, so a
reboot / lease expiry can hand them new addresses — which is exactly what
triggered the 2026-05-22 outage.

### AT&T gateway DHCP config (as observed 2026-05-31)

```
Device IPv4 Address     192.168.1.254      <- gateway (note: NOT .1)
DHCPv4 Netmask          255.255.255.0
DHCP Server             On
DHCPv4 Start Address    192.168.1.64
DHCPv4 End Address      192.168.1.253
DHCP Leases Available   163
DHCP Leases Allocated   27
DHCP Primary Pool       Private
Secondary Subnet        Disabled
IP Passthrough Status   Off (private IP address)
```

### Implications for the fix

- **Node IPs .233–.236 are INSIDE the DHCP pool (.64–.253)** → they are
  DHCP-assigned, not reserved. This is the root instability. The VIP
  (192.168.1.10) is *below* the pool start (.64) so it's safe, but the nodes
  themselves are not.
- **The gateway is .254, not .1.** Any docs/config assuming a .1 gateway are
  wrong for this network.
- AT&T gateways have a weak admin UI but *do* support DHCP reservations
  (MAC → IP binding). Preferred fix path:
  1. Reserve .233–.236 to the four node MACs in the gateway, **or**
  2. Move nodes to **static IPv4** in talconfig outside the pool — e.g. use
     `.11`–`.14` (below the .64 pool start, alongside the .10 VIP) so they can
     never collide with a DHCP lease. This is the more robust option since it
     doesn't depend on the flaky gateway honoring reservations across reboots.
- Whichever path: the kubelet-csr-approver IPv4 prefix (`192.168.1.0/24`) already
  covers any choice here, so only the IPv6 whitelist still needs narrowing.

### Added IPv4 steps
5. [ ] Decide: gateway DHCP reservations vs static IPv4 in talconfig (prefer
       static, outside the .64–.253 pool — e.g. .11–.14)
6. [ ] If static: set `machine.network.interfaces[].addresses` per node in
       talconfig.yaml, apply, regenerate kubeconfig if the VIP/endpoint changes
7. [ ] Verify nodes survive a full power-cycle on the intended IPs before
       considering this closed

## Steps
1. [ ] Decide between routable-stable vs ULA-only approach
2. [ ] Implement (talconfig + apply, or DHCPv6 reservation, or sysctl)
3. [ ] Narrow the `kubelet-csr-approver` IPv6 whitelist back down
4. [ ] Document the chosen address plan in CLAUDE.md
