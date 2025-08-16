# Homelab MCP Configuration

This directory contains the Model Context Protocol (MCP) configuration for managing your homelab infrastructure.

## MCP Servers Configured

### 1. Kubernetes Server (`kubernetes`)
- **Purpose**: Manage Kubernetes cluster operations via kubectl
- **Server**: mcp-server-kubernetes
- **Context**: turingpi
- **Namespace**: default
- **Access**: cluster-admin

**Setup Required**:
- Ensure `~/.kube/config` exists and contains turingpi context
- Verify cluster access: `kubectl cluster-info --context turingpi`

**Usage**: Deploy applications, monitor cluster health, manage Longhorn storage, configure Flux GitOps

### 2. File System Server (`filesystem`)
- **Purpose**: Browse and manage files across nodes
- **Server**: @modelcontextprotocol/server-filesystem
- **Root Path**: `/`
- **Allowed Paths**: `/etc`, `/var/lib`, `/home`, `/opt`

**Usage**: Browse configuration files, logs, and application data

### 3. Git Server (`git`)
- **Purpose**: Manage Git operations for infrastructure as code
- **Server**: @cyanheads/git-mcp-server
- **Root**: Current workspace

**Usage**: Commit changes, manage branches, sync with remote repositories

### 4. Brave Search Server (`brave-search`)
- **Purpose**: Search for documentation and troubleshooting information
- **Server**: @modelcontextprotocol/server-brave-search
- **Setup**: Requires Brave API key (optional)

**Usage**: Find solutions, documentation, and troubleshooting guides

### 5. Sequential Thinking Server (`sequential-thinking`)
- **Purpose**: Assist with complex problem solving and planning
- **Server**: @modelcontextprotocol/server-sequential-thinking

**Usage**: Break down complex infrastructure tasks, plan deployments, troubleshoot issues

### 6. Code Runner Server (`code-runner`)
- **Purpose**: Execute system commands and manage processes
- **Server**: mcp-server-code-runner
- **Allowed Commands**: systemctl, docker, kubectl, talosctl, ps, top, htop

**Usage**: Check service status, monitor resource usage, manage containers

## Installation and Setup

1. **Install MCP Servers**:
   ```bash
   # The servers will be installed automatically via npx when first used
   # Or install manually:
   npm install -g mcp-server-kubernetes
   npm install -g @modelcontextprotocol/server-filesystem
   npm install -g @cyanheads/git-mcp-server
   npm install -g @modelcontextprotocol/server-brave-search
   npm install -g @modelcontextprotocol/server-sequential-thinking
   npm install -g mcp-server-code-runner
   ```

2. **Configure SSH Access** (for manual node management):
   ```bash
   # Generate SSH key if not exists
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   
   # Copy to Turing Pi nodes
   ssh-copy-id talos@192.168.1.223
   ssh-copy-id talos@192.168.1.224
   ssh-copy-id talos@192.168.1.225
   ssh-copy-id talos@192.168.1.226
   ```

3. **Verify Kubernetes Access**:
   ```bash
   kubectl config current-context  # Should show 'turingpi'
   kubectl get nodes              # Should list your Turing Pi nodes
   ```

## Usage Examples

### Kubernetes Operations
- Deploy applications: "Deploy the Longhorn storage operator to the cluster"
- Monitor cluster health: "Check the status of all pods in the cluster"
- Manage storage: "Show Longhorn volume information and status"
- Configure GitOps: "Deploy Flux to the cluster for GitOps management"

### File System Operations
- Browse configuration files: "Show the contents of /etc/kubernetes/"
- View logs and metrics: "List log files in /var/log/"
- Manage application data: "Browse Longhorn storage directories"

### Git Operations
- Commit infrastructure changes: "Commit the current Talos configuration changes"
- Manage branches: "Create a new branch for testing Longhorn configuration"
- Sync repositories: "Pull latest changes from the infrastructure repository"

### Problem Solving
- Troubleshoot issues: "Help me diagnose why Longhorn volumes are failing"
- Plan deployments: "Create a step-by-step plan for deploying monitoring stack"
- Optimize performance: "Analyze cluster resource usage and suggest improvements"

## Troubleshooting

1. **Kubernetes Access Issues**:
   - Ensure kubeconfig is valid
   - Verify cluster is running and accessible
   - Check RBAC permissions

2. **MCP Server Issues**:
   - Check server installation: `npx mcp-server-kubernetes --help`
   - Verify environment variables
   - Check Cursor MCP logs

3. **Command Execution Issues**:
   - Verify allowed commands in code-runner configuration
   - Check system permissions
   - Ensure required tools are installed

## Security Notes

- Kubernetes access should be limited to necessary operations
- File system access is restricted to safe paths
- Command execution is limited to essential operations
- API keys should be kept secure and not committed to version control

## Next Steps

1. Test Kubernetes cluster access via MCP
2. Configure Longhorn storage partitions
3. Deploy Flux for GitOps
4. Set up monitoring and alerting
5. Test MCP functionality for infrastructure management

## Alternative SSH Management

Since there's no official SSH MCP server, you can manage your Turing Pi nodes using:

1. **Direct SSH commands** in your terminal
2. **Talos CLI** for cluster management
3. **Kubernetes node management** via kubectl
4. **Custom scripts** for repetitive tasks

The MCP servers provide comprehensive cluster and infrastructure management capabilities while maintaining security best practices.
