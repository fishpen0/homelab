# 1.14 moved machine.kubelet into KubeletConfig + KubeNodeConfig and dropped
# extraMounts; Longhorn's disk lives under /var/mnt, which the kubelet already
# sees. The <1.14 branch keeps the old shape (incl. the legacy longhorn mount)
# for nodes mid-upgrade.
{{ if semverCompare ">= 1.14.0-0" (.Node.RuntimeData.TalosVersion | default "1.14.0") -}}
apiVersion: v1alpha1
kind: KubeletConfig
config:
  serverTLSBootstrap: true
---
apiVersion: v1alpha1
kind: KubeNodeConfig
nodeIP:
  validSubnets:
    - "192.168.1.0/24"
    - "fdd7:ad7c:fa:4181::/64"
{{ else -}}
machine:
  kubelet:
    extraMounts:
      - destination: /var/lib/longhorn
        type: bind
        source: /var/lib/longhorn
        options:
          - bind
          - rshared
          - rw
    nodeIP:
      validSubnets:
        - "192.168.1.0/24"
        - "fdd7:ad7c:fa:4181::/64"
    extraConfig:
      serverTLSBootstrap: true
{{ end -}}
