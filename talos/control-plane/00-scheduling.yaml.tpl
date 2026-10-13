# v1alpha1 allowSchedulingOnControlPlanes conflicts with the 1.14 base config's
# KubeNodeConfig; see all/00-install.yaml.tpl for the version-default rationale.
{{ if semverCompare ">= 1.14.0-0" (.Node.RuntimeData.TalosVersion | default "1.14.0") -}}
apiVersion: v1alpha1
kind: KubeNodeConfig
taints:
  node-role.kubernetes.io/control-plane:
    $patch: delete
{{ else -}}
cluster:
  allowSchedulingOnControlPlanes: true
{{ end -}}
