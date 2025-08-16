#!/bin/bash

# Setup local DNS resolution for LGTM services
# This script adds entries to your local /etc/hosts file

echo "🔧 Setting up local DNS resolution for LGTM services"
echo "===================================================="

# Get the ingress controller external IP
echo "📡 Getting ingress controller external IP..."
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$EXTERNAL_IP" ]; then
    echo "❌ Could not get external IP. Make sure ingress-nginx is deployed and has an external IP."
    echo "Check with: kubectl get svc -n ingress-nginx"
    exit 1
fi

echo "✅ External IP: $EXTERNAL_IP"

# Check if entries already exist
if grep -q "turingpi.local" /etc/hosts; then
    echo "⚠️  Found existing turingpi.local entries in /etc/hosts"
    echo "Current entries:"
    grep "turingpi.local" /etc/hosts
    echo ""
    read -p "Do you want to update them? (y/N): " update
    if [[ $update =~ ^[Yy]$ ]]; then
        # Remove existing entries
        sudo sed -i '' '/turingpi.local/d' /etc/hosts
        echo "✅ Removed existing entries"
    else
        echo "❌ Aborted. Please manually update /etc/hosts"
        exit 0
    fi
fi

# Add new entries
echo "📝 Adding DNS entries to /etc/hosts..."
echo "" | sudo tee -a /etc/hosts
echo "# LGTM Stack - Turing Pi Cluster" | sudo tee -a /etc/hosts
echo "$EXTERNAL_IP lgtm.turingpi.local" | sudo tee -a /etc/hosts
echo "$EXTERNAL_IP grafana.turingpi.local" | sudo tee -a /etc/hosts
echo "$EXTERNAL_IP loki.turingpi.local" | sudo tee -a /etc/hosts
echo "$EXTERNAL_IP tempo.turingpi.local" | sudo tee -a /etc/hosts
echo "$EXTERNAL_IP mimir.turingpi.local" | sudo tee -a /etc/hosts

echo ""
echo "✅ DNS entries added successfully!"
echo ""
echo "🌐 You can now access:"
echo "   - Grafana: http://grafana.turingpi.local"
echo "   - Loki: http://loki.turingpi.local"
echo "   - Tempo: http://tempo.turingpi.local"
echo "   - Mimir: http://mimir.turingpi.local"
echo "   - Combined: http://lgtm.turingpi.local"
echo ""
echo "🔑 Grafana credentials: admin/admin"
echo ""
echo "💡 Note: You may need to flush DNS cache:"
echo "   macOS: sudo dscacheutil -flushcache"
echo "   Linux: sudo systemctl restart systemd-resolved"
echo "   Windows: ipconfig /flushdns"