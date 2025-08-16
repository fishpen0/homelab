#!/bin/bash

# Longhorn Setup Script for Turing Pi Cluster
# Run this after the cluster is bootstrapped and running

set -e

echo "🐄 Setting up Longhorn on Turing Pi cluster..."

# Check if we have kubectl access
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    echo "Make sure you have run: talosctl kubeconfig -n 192.168.1.224"
    exit 1
fi

echo "📊 Cluster nodes:"
kubectl get nodes -o wide

echo ""
echo "🔧 Setting up Longhorn prerequisites..."

# Create namespace for Longhorn
kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl apply -f -

# Label nodes for Longhorn (exclude control plane nodes from storage)
echo "🏷️  Labeling nodes for Longhorn..."
kubectl label nodes n1 node-role.kubernetes.io/control-plane=true --overwrite
kubectl label nodes n2 node-role.kubernetes.io/control-plane=true --overwrite
kubectl label nodes n3 node-role.kubernetes.io/control-plane=true --overwrite
kubectl label nodes n4 node-role.kubernetes.io/worker=true --overwrite

# Add node taints to prevent workloads on control plane (optional)
echo "🚫 Adding taints to control plane nodes..."
kubectl taint nodes n1 node-role.kubernetes.io/control-plane:NoSchedule --overwrite
kubectl taint nodes n2 node-role.kubernetes.io/control-plane:NoSchedule --overwrite
kubectl taint nodes n3 node-role.kubernetes.io/control-plane:NoSchedule --overwrite

echo ""
echo "✅ Longhorn prerequisites configured!"
echo ""
echo "🔄 Next steps:"
echo "1. Deploy Longhorn via Flux (already configured in your infrastructure)"
echo "2. Wait for Longhorn to be ready: kubectl get pods -n longhorn-system"
echo "3. Create storage classes and volumes as needed"
echo ""
echo "📊 Monitor Longhorn: kubectl get pods -n longhorn-system"
