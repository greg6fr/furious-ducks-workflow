#!/bin/bash

# Script to join worker nodes to Docker Swarm
# Usage: ./join-swarm.sh <join-token> <manager-ip> [node-type]
# node-type: dev, qa, prod (optional, for labeling)

set -e

JOIN_TOKEN="$1"
MANAGER_IP="$2"
NODE_TYPE="${3:-worker}"

if [ -z "$JOIN_TOKEN" ] || [ -z "$MANAGER_IP" ]; then
    echo "Usage: $0 <join-token> <manager-ip> [node-type]"
    echo "Example: $0 SWMTKN-1-xxx... 10.0.1.168 dev"
    echo "Node types: dev, qa, prod (optional)"
    exit 1
fi

echo "========================================"
echo "Docker Swarm Join Process Started"
echo "========================================"
echo "Manager IP: $MANAGER_IP"
echo "Node Type: $NODE_TYPE"
echo "Join Token: ${JOIN_TOKEN:0:20}..."
echo "Hostname: $(hostname)"
echo "Current Time: $(date)"
echo "========================================"

# Check current swarm status
echo "Checking current Docker Swarm status..."
CURRENT_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")
echo "Current swarm state: $CURRENT_STATE"

# Leave existing swarm if necessary
if [ "$CURRENT_STATE" = "active" ]; then
    echo "Node is already part of a swarm. Leaving current swarm first..."
    docker swarm leave --force || true
    sleep 3
    echo "Left previous swarm successfully"
fi

# Join the swarm
echo "Attempting to join Docker Swarm..."
if docker swarm join --token "$JOIN_TOKEN" "$MANAGER_IP:2377"; then
    echo "Join command executed successfully"
else
    echo "Join command failed with exit code $?"
    exit 1
fi

# Wait a moment for the join to complete
sleep 2

# Verify the join was successful
echo "Verifying swarm membership..."
NEW_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "error")

if [ "$NEW_STATE" = "active" ]; then
    echo "✅ Successfully joined Docker Swarm!"
    echo "Node ID: $(docker info --format '{{.Swarm.NodeID}}' 2>/dev/null || echo 'N/A')"
    echo "Manager Address: $(docker info --format '{{.Swarm.RemoteManagers}}' 2>/dev/null || echo 'N/A')"
    echo "Node Role: $(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null | grep -q 'true' && echo 'Manager' || echo 'Worker')"
    
    # Display node info
    echo "========================================"
    echo "Node Information:"
    docker info --format 'Node ID: {{.Swarm.NodeID}}'
    docker info --format 'Node Address: {{.Swarm.NodeAddr}}'
    echo "Node Type Label: $NODE_TYPE"
    echo "========================================"
else
    echo "❌ Failed to join Docker Swarm!"
    echo "Current state: $NEW_STATE"
    echo "Troubleshooting info:"
    echo "- Check network connectivity to manager"
    echo "- Verify join token is valid"
    echo "- Check firewall rules (ports 2377, 7946, 4789)"
    exit 1
fi

echo "Docker Swarm join process completed successfully!"
