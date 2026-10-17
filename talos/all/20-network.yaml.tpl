# The interface is `end0` on the Rockchip SoC (not `eth0` — that name doesn't
# exist and silently disabled any DHCP/route config applied through it).
machine:
  network:
    interfaces:
      - interface: end0
        addresses:
          - {{ .Node.IP }}/24
{{- if eq .Node.Role "control-plane" }}
        vip:
          ip: 192.168.1.10
{{- end }}
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.1.254
---
apiVersion: v1alpha1
kind: ResolverConfig
nameservers:
  - address: 192.168.1.42
