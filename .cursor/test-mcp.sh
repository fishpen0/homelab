#!/bin/bash

# Quick MCP Server Test Script
# Tests which MCP servers are working

set -e

echo "🧪 Testing MCP servers for Homelab project..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Test individual MCP servers
test_mcp_server() {
    local server_name=$1
    local package_name=$2
    
    echo "Testing $server_name ($package_name)..."
    
    # MCP servers typically start up and then get terminated by timeout
    # This is normal behavior, so we look for startup messages
    if timeout 10 npx -y $package_name --help 2>&1 | grep -q "Starting\|MCP server\|Received SIGTERM"; then
        print_status "$server_name is working (started successfully)"
        return 0
    else
        print_warning "$server_name failed to start or test"
        return 1
    fi
}

# Test Kubernetes access
test_kubernetes() {
    echo "Testing Kubernetes access..."
    
    if kubectl cluster-info --context turingpi &> /dev/null; then
        print_status "Kubernetes cluster is accessible"
        kubectl get nodes --context turingpi
    else
        print_warning "Cannot access Kubernetes cluster"
        print_warning "Check if cluster is running and kubeconfig is correct"
    fi
}

# Test file system access
test_filesystem() {
    echo "Testing file system access..."
    
    if [ -d "systems" ] && [ -d ".cursor" ]; then
        print_status "File system access working - can see project structure"
        ls -la systems/
    else
        print_warning "File system access issues"
    fi
}

# Test code runner
test_code_runner() {
    echo "Testing code runner..."
    
    if command -v kubectl &> /dev/null; then
        print_status "kubectl is available"
        kubectl version --client
    else
        print_warning "kubectl not found"
    fi
    
    if command -v talosctl &> /dev/null; then
        print_status "talosctl is available"
        talosctl version
    else
        print_warning "talosctl not found"
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "  MCP Server Test Results"
    echo "=========================================="
    echo
    
    echo "1. Testing MCP Servers:"
    echo "------------------------"
    test_mcp_server "Kubernetes" "mcp-server-kubernetes"
    test_mcp_server "File System" "@modelcontextprotocol/server-filesystem"
    test_mcp_server "Git" "@cyanheads/git-mcp-server"
    test_mcp_server "Code Runner" "mcp-server-code-runner"
    echo
    
    echo "2. Testing Infrastructure Access:"
    echo "--------------------------------"
    test_kubernetes
    echo
    test_filesystem
    echo
    test_code_runner
    echo
    
    echo "=========================================="
    print_status "Test completed!"
    echo
    print_status "Working MCP servers can be used in Cursor"
    print_status "Failed servers may need manual installation or network fixes"
    echo "=========================================="
}

main "$@"
