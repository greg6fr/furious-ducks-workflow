#!/bin/bash

# Complete Docker Swarm setup automation script
# This script runs the Ansible playbook to join all worker nodes (dev, qa, prod) to the swarm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "Docker Swarm Complete Setup Automation"
echo "========================================="
echo "Script Directory: $SCRIPT_DIR"
echo "Ansible Directory: $ANSIBLE_DIR"
echo "Current Time: $(date)"
echo "========================================="

# Change to ansible directory
cd "$ANSIBLE_DIR"

# Check if inventory file exists
if [ ! -f "inventory.ini" ]; then
    echo "❌ Error: inventory.ini not found in $ANSIBLE_DIR"
    echo "Please run Terraform first to generate the inventory file."
    exit 1
fi

# Check if join-swarm script exists
if [ ! -f "scripts/join-swarm.sh" ]; then
    echo "❌ Error: join-swarm.sh script not found"
    exit 1
fi

# Make sure join-swarm script is executable
chmod +x scripts/join-swarm.sh

echo "📋 Checking inventory file..."
cat inventory.ini

echo ""
echo "🚀 Starting Docker Swarm worker join process..."
echo "This will join all worker nodes (dev, qa, prod) to the Docker Swarm"

# Run only the Docker Swarm join part of the playbook
echo ""
echo "🔧 Executing Ansible playbook for Docker Swarm join..."
if ansible-playbook -i inventory.ini setup-workflow.yml --tags "swarm-join" -v; then
    echo ""
    echo "✅ Docker Swarm join process completed successfully!"
else
    echo ""
    echo "❌ Docker Swarm join process failed!"
    echo "Attempting to run the full playbook section..."
    
    # If tagged run fails, try running the specific play
    if ansible-playbook -i inventory.ini setup-workflow.yml --limit "dev_server,qa_server,prod_server" --start-at-task "Join other servers to Docker Swarm"; then
        echo "✅ Docker Swarm join completed with alternative method!"
    else
        echo "❌ All attempts failed. Please check the logs above."
        exit 1
    fi
fi

echo ""
echo "🔍 Verifying Docker Swarm cluster status..."

# Get CI/CD server IP from inventory
CI_CD_IP=$(grep -A 10 "\[ci_cd_server\]" inventory.ini | grep -E "^[0-9]" | head -1)

if [ -n "$CI_CD_IP" ]; then
    echo "Connecting to CI/CD server ($CI_CD_IP) to check swarm status..."
    ssh -i keys/mykey.pem -o StrictHostKeyChecking=no admin@$CI_CD_IP "docker node ls" || echo "Could not retrieve node list"
else
    echo "Could not determine CI/CD server IP from inventory"
fi

echo ""
echo "========================================="
echo "Docker Swarm Setup Complete!"
echo "========================================="
echo "All worker nodes (dev, qa, prod) should now be part of the Docker Swarm cluster."
echo "You can verify the cluster status by connecting to the CI/CD server and running 'docker node ls'"
echo "========================================="
