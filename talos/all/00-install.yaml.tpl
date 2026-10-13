# Talos >= 1.14 rejects machine.install alongside UnattendedInstallConfig, so
# branch on the node's running version. RuntimeData is empty on an offline
# render; default to 1.14.0 so offline renders (CI) validate the target shape.
{{ if semverCompare ">= 1.14.0-0" (.Node.RuntimeData.TalosVersion | default "1.14.0") -}}
apiVersion: v1alpha1
kind: UnattendedInstallConfig
provisioning:
  diskSelector:
    match: disk.dev_path == "/dev/nvme0n1"
  wipe: false
{{ else -}}
machine:
  install:
    disk: /dev/nvme0n1
{{ end -}}
