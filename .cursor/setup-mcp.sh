#!/bin/bash

# Homelab MCP Setup Script
# This script helps set up and test the MCP configuration

set -e

echo "🚀 Setting up MCP servers for Homelab project..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v ssh &> /dev/null; then
        print_error "SSH client is not installed."
        exit 1
    fi
    
    if ! command -v npx &> /dev/null; then
        print_error "npx is not installed. Please install Node.js first."
        exit 1
    fi
    
    print_status "Prerequisites check passed ✓"
}

# Check SSH key setup
check_ssh_setup() {
    print_status "Checking SSH key setup..."
    
    if [ ! -f ~/.ssh/id_rsa ]; then
        print_warning "SSH private key not found at ~/.ssh/id_rsa"
        echo "Generating new SSH key..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
        print_status "SSH key generated ✓"
    else
        print_status "SSH private key found ✓"
    fi
    
    # Set proper permissions
    chmod 600 ~/.ssh/id_rsa
    chmod 644 ~/.ssh/id_rsa.pub
    
    print_status "SSH key permissions set ✓"
}

# Check Kubernetes configuration
check_k8s_config() {
    print_status "Checking Kubernetes configuration..."
    
    if [ ! -f ~/.kube/config ]; then
        print_warning "Kubernetes config not found at ~/.kube/config"
        print_warning "Please ensure your kubeconfig is properly set up"
    else
        print_status "Kubernetes config found ✓"
        
        # Check if turingpi context exists
        if kubectl config get-contexts | grep -q "turingpi"; then
            print_status "Turing Pi context found ✓"
            
            # Test cluster access
            if kubectl cluster-info --context turingpi &> /dev/null; then
                print_status "Cluster access verified ✓"
            else
                print_warning "Cannot access cluster with turingpi context"
            fi
        else
            print_warning "Turing Pi context not found in kubeconfig"
        fi
    fi
}

# Test SSH connectivity to nodes
test_ssh_connectivity() {
    print_status "Testing SSH connectivity to Turing Pi nodes..."
    
    NODES=("192.168.1.223" "192.168.1.224" "192.168.1.225" "192.168.1.226")
    
    for node in "${NODES[@]}"; do
        print_status "Testing connection to $node..."
        if timeout 5 ssh -o ConnectTimeout=5 -o BatchMode=yes talos@$node exit &> /dev/null; then
            print_status "✓ Successfully connected to $node"
        else
            print_warning "✗ Cannot connect to $node"
            print_warning "  - Ensure the node is powered on"
            print_warning "  - Check network connectivity"
            print_warning "  - Verify SSH key is added to authorized_keys"
        fi
    done
}

# Install MCP servers
install_mcp_servers() {
    print_status "Installing MCP servers..."
    
    SERVERS=(
        "mcp-server-kubernetes"
        "@modelcontextprotocol/server-filesystem"
        "@cyanheads/git-mcp-server"
        "@modelcontextprotocol/server-brave-search"
        "@modelcontextprotocol/server-sequential-thinking"
        "mcp-server-code-runner"
    )
    
    for server in "${SERVERS[@]}"; do
        print_status "Installing $server..."
        if npx -y $server --help &> /dev/null; then
            print_status "✓ $server installed successfully"
        else
            print_warning "✗ Failed to install $server"
        fi
    done
}

# Main execution
main() {
    echo "=========================================="
    echo "  Homelab MCP Setup Script"
    echo "=========================================="
    echo
    
    check_prerequisites
    echo
    
    check_ssh_setup
    echo
    
    check_k8s_config
    echo
    
    test_ssh_connectivity
    echo
    
    install_mcp_servers
    echo
    
    echo "=========================================="
    print_status "MCP setup completed!"
    echo
    print_status "Next steps:"
    echo "  1. Add your SSH public key to all Turing Pi nodes:"
    echo "     cat ~/.ssh/id_rsa.pub | ssh talos@192.168.1.223 'cat >> ~/.ssh/authorized_keys'"
    echo "  2. Ensure your Kubernetes cluster is running and accessible"
    echo "  3. Restart Cursor to load the MCP configuration"
    echo "  4. Test MCP functionality in Cursor"
    echo
    print_status "Configuration files created:"
    echo "  - .cursor/mcp.json (MCP server configuration)"
    echo "  - .cursor/README.md (Documentation)"
    echo "  - .cursor/setup-mcp.sh (This setup script)"
    echo
    print_status "Available MCP Servers:"
    echo "  - kubernetes: Cluster management via kubectl"
    echo "  - filesystem: File browsing and management"
    echo "  - git: Git repository operations"
    echo "  - brave-search: Web search capabilities"
    echo "  - sequential-thinking: Problem solving assistance"
    echo "  - code-runner: Execute system commands"
    echo "=========================================="
}

# Run main function
main "$@"
