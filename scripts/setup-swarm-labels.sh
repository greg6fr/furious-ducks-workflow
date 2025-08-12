#!/bin/bash

# Setup Docker Swarm Node Labels for Furious Ducks Workflow
# This script labels Docker Swarm nodes for environment-specific deployments

echo "🏷️  Setting up Docker Swarm node labels..."

# Get all node IDs and hostnames
NODES=$(docker node ls --format "{{.ID}} {{.Hostname}}" | grep -v "ID HOSTNAME")

echo "📋 Available nodes:"
echo "$NODES"

# Label nodes based on hostname patterns
while IFS= read -r line; do
    NODE_ID=$(echo "$line" | awk '{print $1}')
    HOSTNAME=$(echo "$line" | awk '{print $2}')
    
    echo "🔧 Processing node: $HOSTNAME ($NODE_ID)"
    
    # Determine environment based on hostname or position
    if [[ "$HOSTNAME" == *"241"* ]] || docker node ls | grep "$NODE_ID" | grep -q "Leader"; then
        # Manager node - typically CI/CD
        echo "  └── Labeling as CI/CD environment"
        docker node update --label-add environment=cicd "$NODE_ID"
        docker node update --label-add role=manager "$NODE_ID"
    elif [[ "$HOSTNAME" == *"183"* ]]; then
        # First worker - Production
        echo "  └── Labeling as Production environment"
        docker node update --label-add environment=prod "$NODE_ID"
        docker node update --label-add role=worker "$NODE_ID"
    elif [[ "$HOSTNAME" == *"211"* ]]; then
        # Second worker - QA
        echo "  └── Labeling as QA environment"
        docker node update --label-add environment=qa "$NODE_ID"
        docker node update --label-add role=worker "$NODE_ID"
    elif [[ "$HOSTNAME" == *"239"* ]]; then
        # Third worker - Development
        echo "  └── Labeling as Development environment"
        docker node update --label-add environment=dev "$NODE_ID"
        docker node update --label-add role=worker "$NODE_ID"
    else
        # Default labeling for unknown nodes
        echo "  └── Labeling as general purpose"
        docker node update --label-add environment=general "$NODE_ID"
        docker node update --label-add role=worker "$NODE_ID"
    fi
    
done <<< "$NODES"

echo ""
echo "✅ Node labeling completed!"
echo ""
echo "📊 Current node labels:"
docker node ls --format "table {{.ID}}\t{{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.ManagerStatus}}"

echo ""
echo "🔍 Detailed node information:"
for node_id in $(docker node ls -q); do
    echo "Node: $(docker node inspect "$node_id" --format '{{.Description.Hostname}}')"
    docker node inspect "$node_id" --format '{{range $k, $v := .Spec.Labels}}  {{$k}}: {{$v}}{{"\n"}}{{end}}'
    echo ""
done

echo "🚀 Ready to deploy services with environment constraints!"
