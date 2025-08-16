#!/bin/bash

# Turing Pi Talos Cluster Deployment Script
# This script applies the generated Talos configuration to your nodes

set -e

echo "🚀 Deploying Talos configuration to Turing Pi cluster..."

# Set the SOPS age key file path
export SOPS_AGE_KEY_FILE="$(pwd)/age-key.txt"

# Check if we have the required files
if [ ! -f "talsecret.sops.yaml" ]; then
    echo "❌ Error: talsecret.sops.yaml not found"
    exit 1
fi

if [ ! -f "clusterconfig/talosconfig" ]; then
    echo "❌ Error: clusterconfig/talosconfig not found"
    exit 1
fi

# Copy the generated talosconfig to the standard location
echo "📋 Setting up Talos client configuration..."
cp clusterconfig/talosconfig ~/.talos/config

# Apply configuration to each node
echo "🔧 Applying configuration to nodes..."

echo "📡 Applying to n1 (192.168.1.224)..."
talosctl apply-config --insecure -n 192.168.1.224 -f clusterconfig/turingpi-n1.yaml

echo "📡 Applying to n2 (192.168.1.226)..."
talosctl apply-config --insecure -n 192.168.1.226 -f clusterconfig/turingpi-n2.yaml

echo "📡 Applying to n3 (192.168.1.223)..."
talosctl apply-config --insecure -n 192.168.1.223 -f clusterconfig/turingpi-n3.yaml

echo "📡 Applying to n4 (192.168.1.225)..."
talosctl apply-config --insecure -n 192.168.1.225 -f clusterconfig/turingpi-n4.yaml

echo "✅ Configuration applied to all nodes!"
echo ""
echo "🔄 Next steps:"
echo "1. Wait for nodes to reboot and apply the new configuration"
echo "2. Bootstrap the cluster: talosctl bootstrap -n 192.168.1.224"
echo "3. Get kubeconfig: talosctl kubeconfig -n 192.168.1.224"
echo "4. Deploy Longhorn and other infrastructure"
echo ""
echo "📊 Monitor progress with: talosctl health -n 192.168.1.224"
