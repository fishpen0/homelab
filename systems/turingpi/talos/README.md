# bootstrap nodes

# turn them on
tpi power on -n1
tpi power on -n2

# wait for it to boot and get the IPs (assumed to be the ones below)
tpi uart -n1 get

# Generate the talos config from the controlplane patch
talosctl gen config turingpi https://192.168.1.10:6443 --config-patch-control-plane @controlplane.patch.yaml

# Add talosconfig to env
export TALOSCONFIG=$(pwd)/talosconfig

# apply talos config to nodes
talosctl apply-config --insecure -n 192.168.1.164 --file controlplane.yaml
talosctl apply-config --insecure -n 192.168.1.158 --file controlplane.yaml

# bootstrap talos on the first node
talosctl bootstrap --nodes 192.168.1.164 --endpoints 192.168.1.164

# Update the talosconfig with the new cluster
talosctl config endpoint 192.168.1.10
talosctl config node 192.168.1.164 192.168.1.158