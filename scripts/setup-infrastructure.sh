#!/bin/bash

# Furious Ducks Workflow - Infrastructure Setup Script
# This script configures the Docker Swarm cluster for CI/CD automation

set -e

echo "🚀 Setting up Furious Ducks Workflow Infrastructure..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Docker Swarm manager
check_swarm_manager() {
    print_status "Checking Docker Swarm status..."
    if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
        print_error "This script must be run on a Docker Swarm manager node"
        exit 1
    fi
    
    local role=$(docker info --format '{{.Swarm.ControlAvailable}}')
    if [ "$role" != "true" ]; then
        print_error "This node is not a Swarm manager"
        exit 1
    fi
    
    print_success "Running on Docker Swarm manager"
}

# Setup node labels
setup_node_labels() {
    print_status "Setting up Docker Swarm node labels..."
    
    # Run the Node.js script to setup labels
    if [ -f "scripts/setup-swarm-labels.js" ]; then
        node scripts/setup-swarm-labels.js
        print_success "Node labels configured successfully"
    else
        print_warning "Node labels script not found, setting up manually..."
        
        # Manual label setup as fallback
        docker node update --label-add environment=cicd ip-10-0-1-107 2>/dev/null || true
        docker node update --label-add environment=prod ip-10-0-1-158 2>/dev/null || true
        docker node update --label-add environment=qa ip-10-0-1-109 2>/dev/null || true
        docker node update --label-add environment=dev ip-10-0-1-12 2>/dev/null || true
        
        print_success "Basic node labels set"
    fi
}

# Create Docker networks
setup_networks() {
    print_status "Creating Docker overlay networks..."
    
    # Production network
    if ! docker network ls | grep -q "furious-ducks-network"; then
        docker network create --driver overlay --attachable furious-ducks-network
        print_success "Created production network"
    else
        print_warning "Production network already exists"
    fi
    
    # QA network
    if ! docker network ls | grep -q "furious-ducks-qa-network"; then
        docker network create --driver overlay --attachable furious-ducks-qa-network
        print_success "Created QA network"
    else
        print_warning "QA network already exists"
    fi
}

# Create required directories
setup_directories() {
    print_status "Creating required directories..."
    
    mkdir -p logs
    mkdir -p data/mongodb
    mkdir -p data/mongodb-qa
    mkdir -p backups
    mkdir -p ssl
    
    print_success "Directories created"
}

# Setup environment files
setup_environment() {
    print_status "Setting up environment configuration..."
    
    # Production environment
    if [ ! -f ".env.prod" ]; then
        cat > .env.prod << EOF
# Production Environment Variables
MONGO_ROOT_PASSWORD=furious-ducks-prod-$(openssl rand -hex 16)
JWT_SECRET=jwt-secret-prod-$(openssl rand -hex 32)
DOCKERHUB_USERNAME=your-dockerhub-username
APP_VERSION=latest
PROD_NODE=52.47.133.246
QA_NODE=51.44.86.0
DEV_NODE=51.44.220.111
EOF
        print_success "Created .env.prod"
    else
        print_warning ".env.prod already exists"
    fi
    
    # QA environment
    if [ ! -f ".env.qa" ]; then
        cat > .env.qa << EOF
# QA Environment Variables
MONGO_ROOT_PASSWORD=furious-ducks-qa-$(openssl rand -hex 16)
JWT_SECRET=jwt-secret-qa-$(openssl rand -hex 32)
DOCKERHUB_USERNAME=your-dockerhub-username
APP_VERSION=latest
PROD_NODE=52.47.133.246
QA_NODE=51.44.86.0
DEV_NODE=51.44.220.111
EOF
        print_success "Created .env.qa"
    else
        print_warning ".env.qa already exists"
    fi
}

# Setup Jenkins credentials
setup_jenkins_credentials() {
    print_status "Setting up Jenkins credentials helper..."
    
    cat > scripts/setup-jenkins-credentials.sh << 'EOF'
#!/bin/bash
# Jenkins Credentials Setup Helper

echo "🔐 Jenkins Credentials Setup"
echo "Please configure the following credentials in Jenkins:"
echo ""
echo "1. Docker Hub Credentials:"
echo "   - ID: dockerhub-credentials"
echo "   - Type: Username with password"
echo "   - Username: your-dockerhub-username"
echo "   - Password: your-dockerhub-token"
echo ""
echo "2. SSH Keys for Deployment:"
echo "   - ID: swarm-ssh-key"
echo "   - Type: SSH Username with private key"
echo "   - Username: admin"
echo "   - Private Key: $(cat infrastructure/ansible/keys/mykey.pem)"
echo ""
echo "3. Environment Variables:"
echo "   - MONGO_ROOT_PASSWORD"
echo "   - JWT_SECRET"
echo ""
echo "Access Jenkins at: http://15.237.192.218:8080"
echo "Initial password: 44c256c865834a1ab9cd657ef9d6a4f2"
EOF
    
    chmod +x scripts/setup-jenkins-credentials.sh
    print_success "Jenkins credentials helper created"
}

# Validate setup
validate_setup() {
    print_status "Validating infrastructure setup..."
    
    # Check Docker Swarm nodes
    local node_count=$(docker node ls --format '{{.Hostname}}' | wc -l)
    if [ "$node_count" -ge 4 ]; then
        print_success "Docker Swarm has $node_count nodes"
    else
        print_warning "Expected 4 nodes, found $node_count"
    fi
    
    # Check networks
    if docker network ls | grep -q "furious-ducks"; then
        print_success "Docker networks configured"
    else
        print_error "Docker networks missing"
    fi
    
    # Check environment files
    if [ -f ".env.prod" ] && [ -f ".env.qa" ]; then
        print_success "Environment files configured"
    else
        print_error "Environment files missing"
    fi
}

# Main execution
main() {
    echo "🦆 Furious Ducks Workflow Infrastructure Setup"
    echo "=============================================="
    
    check_swarm_manager
    setup_node_labels
    setup_networks
    setup_directories
    setup_environment
    setup_jenkins_credentials
    validate_setup
    
    echo ""
    print_success "Infrastructure setup completed successfully!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Configure Jenkins credentials: ./scripts/setup-jenkins-credentials.sh"
    echo "2. Update .env.prod and .env.qa with your Docker Hub username"
    echo "3. Create your Angular/Node.js application structure"
    echo "4. Push to develop/main branches to trigger CI/CD"
    echo ""
    echo "🔗 Access Points:"
    echo "   Jenkins: http://15.237.192.218:8080"
    echo "   Gitea: http://15.237.192.218:3000"
    echo ""
}

# Run main function
main "$@"
