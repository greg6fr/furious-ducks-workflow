#!/usr/bin/env node

/**
 * Setup Docker Swarm node labels for environment-specific deployments
 * This script configures the labels needed for the CI/CD pipeline
 */

const { execSync } = require('child_process');

const NODES = {
  'ip-10-0-1-107': 'cicd',    // CI/CD Server (Manager)
  'ip-10-0-1-158': 'prod',    // Production Server
  'ip-10-0-1-109': 'qa',      // QA Server  
  'ip-10-0-1-12': 'dev'       // Development Server
};

function executeCommand(command) {
  try {
    console.log(`🔧 Executing: ${command}`);
    const result = execSync(command, { encoding: 'utf8' });
    console.log(`✅ Success: ${result.trim()}`);
    return result;
  } catch (error) {
    console.error(`❌ Error executing command: ${command}`);
    console.error(error.message);
    throw error;
  }
}

function setupSwarmLabels() {
  console.log('🚀 Setting up Docker Swarm node labels...\n');
  
  try {
    // Get current nodes
    const nodesList = executeCommand('docker node ls --format "{{.Hostname}}"');
    const currentNodes = nodesList.split('\n').filter(node => node.trim());
    
    console.log('📋 Current Swarm nodes:', currentNodes);
    
    // Apply labels to each node
    Object.entries(NODES).forEach(([hostname, environment]) => {
      if (currentNodes.includes(hostname)) {
        console.log(`\n🏷️  Configuring ${hostname} as ${environment} environment...`);
        
        // Set environment label
        executeCommand(`docker node update --label-add environment=${environment} ${hostname}`);
        
        // Set role-specific labels
        if (environment === 'cicd') {
          executeCommand(`docker node update --label-add role=manager ${hostname}`);
          executeCommand(`docker node update --label-add services=jenkins,gitea ${hostname}`);
        } else {
          executeCommand(`docker node update --label-add role=worker ${hostname}`);
          executeCommand(`docker node update --label-add services=app ${hostname}`);
        }
        
        // Set resource constraints based on instance type
        if (environment === 'cicd') {
          executeCommand(`docker node update --label-add instance.type=t3.medium ${hostname}`);
          executeCommand(`docker node update --label-add resources=high ${hostname}`);
        } else {
          executeCommand(`docker node update --label-add instance.type=t2.micro ${hostname}`);
          executeCommand(`docker node update --label-add resources=limited ${hostname}`);
        }
        
        console.log(`✅ ${hostname} configured successfully`);
      } else {
        console.warn(`⚠️  Node ${hostname} not found in current swarm`);
      }
    });
    
    // Verify labels
    console.log('\n📊 Verifying node labels...');
    executeCommand('docker node ls --format "table {{.Hostname}}\\t{{.Status}}\\t{{.Availability}}"');
    
    // Show detailed labels
    currentNodes.forEach(hostname => {
      console.log(`\n🔍 Labels for ${hostname}:`);
      try {
        executeCommand(`docker node inspect ${hostname} --format "{{range .Spec.Labels}}{{.}}={{.}} {{end}}"`);
      } catch (error) {
        console.warn(`Could not inspect ${hostname}`);
      }
    });
    
    console.log('\n🎉 Docker Swarm labels setup completed successfully!');
    
  } catch (error) {
    console.error('\n💥 Failed to setup Swarm labels:', error.message);
    process.exit(1);
  }
}

// Run the setup
if (require.main === module) {
  setupSwarmLabels();
}

module.exports = { setupSwarmLabels };
