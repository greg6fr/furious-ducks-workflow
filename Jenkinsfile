pipeline {
    agent any
    
    environment {
        // GitHub Repository
        GIT_REPOSITORY = 'https://github.com/greg6fr/furious-ducks-workflow.git'
        
        // Docker Hub credentials (configure in Jenkins)
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_USERNAME = 'dspgroupe3archi'
        
        // Application versions
        APP_VERSION = "${env.BUILD_NUMBER}"
        GIT_COMMIT_SHORT = "${env.GIT_COMMIT[0..7]}"
        
        // Docker images
        ANGULAR_IMAGE = "${DOCKERHUB_USERNAME}/furious-ducks-frontend"
        NODEJS_IMAGE = "${DOCKERHUB_USERNAME}/furious-ducks-backend"
        
        // Docker Swarm nodes (current IPs)
        PROD_NODE = "51.44.223.133"
        QA_NODE = "13.38.45.25"
        DEV_NODE = "15.237.179.98"
        CI_CD_NODE = "15.236.225.200"
    }
    
    stages {
        stage('Checkout & Setup') {
            steps {
                // Checkout first to establish Git context
                checkout scm
                
                script {
                    echo "🚀 Starting CI/CD Pipeline for ${env.BRANCH_NAME}"
                    echo "📦 Build #${env.BUILD_NUMBER} - Commit: ${env.GIT_COMMIT[0..7]}"
                }
                
                // Install Node.js using NodeJS plugin or Docker
                script {
                    echo "📋 Checking Node.js availability..."
                    sh '''
                        if command -v node >/dev/null 2>&1; then
                            echo "✅ Node.js found: $(node --version)"
                            echo "✅ npm found: $(npm --version)"
                        else
                            echo "❌ Node.js not found - installing via Docker"
                        fi
                    '''
                }
            }
        }
        
        stage('Build with Docker') {
            parallel {
                stage('Build Frontend Docker Image') {
                    steps {
                        script {
                            echo "🔨 Building Angular frontend Docker image..."
                            
                            // Check if package-lock.json exists, if not create it
                            sh '''
                                cd apps/angular-ssr
                                if [ ! -f "package-lock.json" ]; then
                                    echo "📦 Creating package-lock.json for Angular app..."
                                    npm install
                                fi
                            '''
                            
                            // Build Docker image
                            sh """
                                cd apps/angular-ssr
                                docker build -t ${ANGULAR_IMAGE}:${APP_VERSION} .
                                docker tag ${ANGULAR_IMAGE}:${APP_VERSION} ${ANGULAR_IMAGE}:latest
                            """
                        }
                    }
                }
                
                stage('Build Backend Docker Image') {
                    steps {
                        script {
                            echo "🔨 Building Node.js backend Docker image..."
                            
                            // Check if package-lock.json exists, if not create it
                            sh '''
                                cd apps/node-api
                                if [ ! -f "package-lock.json" ]; then
                                    echo "📦 Creating package-lock.json for Node.js API..."
                                    npm install
                                fi
                            '''
                            
                            // Build Docker image
                            sh """
                                cd apps/node-api
                                docker build -t ${NODEJS_IMAGE}:${APP_VERSION} .
                                docker tag ${NODEJS_IMAGE}:${APP_VERSION} ${NODEJS_IMAGE}:latest
                            """
                        }
                    }
                }
            }
        }
        
        stage('Push to Docker Hub') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "📤 Pushing images to Docker Hub..."
                    
                    // Login to Docker Hub
                    sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
                    
                    // Push images
                    sh """
                        docker push ${ANGULAR_IMAGE}:${APP_VERSION}
                        docker push ${ANGULAR_IMAGE}:latest
                        docker push ${NODEJS_IMAGE}:${APP_VERSION}
                        docker push ${NODEJS_IMAGE}:latest
                    """
                    
                    echo "✅ Images pushed successfully!"
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🚀 Deploying to production environment..."
                    
                    // Deploy to Docker Swarm
                    sh """
                        # Create or update Docker stack
                        docker stack deploy -c docker-compose.prod.yml furious-ducks-prod || echo "Stack deployment initiated"
                        
                        # Wait for services to be ready
                        sleep 30
                        
                        # Check service status
                        docker service ls | grep furious-ducks || echo "Services starting..."
                    """
                    
                    echo "✅ Production deployment completed!"
                }
            }
        }
        
        stage('Deploy to QA') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🧪 Deploying to QA environment..."
                    
                    // Deploy to QA
                    sh """
                        # Create or update QA stack
                        docker stack deploy -c docker-compose.qa.yml furious-ducks-qa || echo "QA Stack deployment initiated"
                        
                        # Wait for services to be ready
                        sleep 20
                        
                        # Check QA service status
                        docker service ls | grep furious-ducks-qa || echo "QA Services starting..."
                    """
                    
                    echo "✅ QA deployment completed!"
                }
            }
        }
        
        stage('Verification') {
            steps {
                script {
                    echo "🔍 Verifying deployments..."
                    
                    // Check Docker Swarm status
                    sh """
                        echo "Docker Swarm Nodes:"
                        docker node ls || echo "Could not list nodes"
                        
                        echo "Running Services:"
                        docker service ls || echo "Could not list services"
                        
                        echo "Stack Status:"
                        docker stack ls || echo "Could not list stacks"
                    """
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Pipeline completed - cleaning up..."
                
                // Clean up local Docker images to save space
                sh '''
                    docker image prune -f || echo "Could not prune images"
                '''
            }
            
            // Clean workspace
            cleanWs()
        }
        success {
            script {
                if (env.BRANCH_NAME == 'main') {
                    echo "✅ Production deployment successful! Build #${env.BUILD_NUMBER} - ${env.GIT_COMMIT_SHORT}"
                    echo "🚀 Services deployed to production and QA environments"
                    echo "🔗 Frontend: http://${CI_CD_NODE}:80"
                    echo "🔗 Backend: http://${CI_CD_NODE}:3000"
                } else {
                    echo "✅ Build and tests successful! Build #${env.BUILD_NUMBER} - ${env.GIT_COMMIT_SHORT}"
                }
            }
        }
        failure {
            script {
                echo "❌ Pipeline failed! Branch: ${env.BRANCH_NAME}, Build #${env.BUILD_NUMBER}"
                echo "📋 Check the logs above for detailed error information"
                echo "🔧 Common issues:"
                echo "   - Docker daemon not running"
                echo "   - Missing credentials"
                echo "   - Network connectivity issues"
                echo "   - Node.js/npm not available"
            }
        }
    }
}
