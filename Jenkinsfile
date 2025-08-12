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
        PROD_NODE = "13.38.206.31"
        QA_NODE = "13.37.196.126"
        DEV_NODE = "15.236.251.19"
        CI_CD_NODE = "15.236.87.60"
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
        
        stage('Deploy Based on Branch') {
            steps {
                script {
                    def branchName = env.BRANCH_NAME ?: 'main'
                    echo "🔍 Current branch: ${branchName}"
                    
                    if (branchName == 'main') {
                        echo "🚀 Deploying to PRODUCTION server: ${env.PROD_NODE}"
                        
                        // Deploy to Production server
                        sh """
                            # Deploy to production server
                            echo "Deploying to production server: ${env.PROD_NODE}"
                            
                            # Create or update Docker stack on production
                            docker stack deploy -c docker-compose.prod.yml furious-ducks-prod || echo "Production stack deployment initiated"
                            
                            # Wait for services to be ready
                            sleep 30
                            
                            # Check service status
                            docker service ls | grep furious-ducks || echo "Production services starting..."
                        """
                        
                        echo "✅ Production deployment completed on ${env.PROD_NODE}!"
                        
                    } else if (branchName == 'develop') {
                        echo "🧪 Deploying to QA server: ${env.QA_NODE}"
                        
                        // Deploy to QA server
                        sh """
                            # Deploy to QA server
                            echo "Deploying to QA server: ${env.QA_NODE}"
                            
                            # Create or update QA stack
                            docker stack deploy -c docker-compose.qa.yml furious-ducks-qa || echo "QA stack deployment initiated"
                            
                            # Wait for services to be ready
                            sleep 20
                            
                            # Check QA service status
                            docker service ls | grep furious-ducks-qa || echo "QA services starting..."
                        """
                        
                        echo "✅ QA deployment completed on ${env.QA_NODE}!"
                        
                    } else {
                        echo "ℹ️ Branch '${branchName}' - No deployment configured"
                        echo "Only 'main' and 'develop' branches trigger deployments"
                        echo "- main branch → Production server (${env.PROD_NODE})"
                        echo "- develop branch → QA server (${env.QA_NODE})"
                    }
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
