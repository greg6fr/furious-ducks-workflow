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
        MONGO_IMAGE = "mongo:7.0"
        
        // Docker Swarm nodes
        PROD_NODE = "15.236.142.213"
        QA_NODE = "15.237.255.213"
        DEV_NODE = "13.38.79.229"
    }
    
    stages {
        stage('Checkout & Setup') {
            steps {
                script {
                    echo "🚀 Starting CI/CD Pipeline for ${env.BRANCH_NAME}"
                    echo "📦 Build #${env.BUILD_NUMBER} - Commit: ${GIT_COMMIT_SHORT}"
                }
                
                // Clean workspace
                cleanWs()
                checkout scm
                
                // Setup Node.js environment
                sh '''
                    node --version
                    npm --version
                '''
            }
        }
        
        stage('Install Dependencies') {
            parallel {
                stage('Frontend Dependencies') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "📦 Installing Angular dependencies..."
                                npm ci --only=production
                                npm install -g @angular/cli
                            '''
                        }
                    }
                }
                stage('Backend Dependencies') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "📦 Installing Node.js dependencies..."
                                npm ci --only=production
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Code Quality & Tests') {
            parallel {
                stage('Frontend Tests') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "🧪 Running Angular tests..."
                                npm run test:ci
                                npm run lint
                                npm run e2e:headless
                            '''
                        }
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'frontend/test-results.xml'
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'frontend/coverage',
                                reportFiles: 'index.html',
                                reportName: 'Frontend Coverage Report'
                            ])
                        }
                    }
                }
                stage('Backend Tests') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "🧪 Running Node.js tests..."
                                npm run test:coverage
                                npm run lint
                            '''
                        }
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'backend/test-results.xml'
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'backend/coverage',
                                reportFiles: 'index.html',
                                reportName: 'Backend Coverage Report'
                            ])
                        }
                    }
                }
            }
        }
        
        stage('Build Docker Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        script {
                            echo "🏗️ Building Angular application..."
                            dir('frontend') {
                                sh '''
                                    npm run build:prod
                                    docker build -t ${ANGULAR_IMAGE}:${APP_VERSION} -t ${ANGULAR_IMAGE}:latest .
                                '''
                            }
                        }
                    }
                }
                stage('Build Backend') {
                    steps {
                        script {
                            echo "🏗️ Building Node.js application..."
                            dir('backend') {
                                sh '''
                                    docker build -t ${NODEJS_IMAGE}:${APP_VERSION} -t ${NODEJS_IMAGE}:latest .
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Security Scan') {
            parallel {
                stage('Frontend Security') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "🔒 Running security audit..."
                                npm audit --audit-level=high
                                # Optional: Trivy scan
                                # trivy image ${ANGULAR_IMAGE}:${APP_VERSION}
                            '''
                        }
                    }
                }
                stage('Backend Security') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "🔒 Running security audit..."
                                npm audit --audit-level=high
                                # Optional: Trivy scan
                                # trivy image ${NODEJS_IMAGE}:${APP_VERSION}
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                script {
                    echo "📤 Pushing images to Docker Hub..."
                    sh '''
                        echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin
                        
                        # Push Frontend
                        docker push ${ANGULAR_IMAGE}:${APP_VERSION}
                        docker push ${ANGULAR_IMAGE}:latest
                        
                        # Push Backend
                        docker push ${NODEJS_IMAGE}:${APP_VERSION}
                        docker push ${NODEJS_IMAGE}:latest
                        
                        docker logout
                    '''
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🚀 Deploying to Production..."
                    sh '''
                        # Create Docker Compose for production
                        envsubst < docker-compose.prod.yml > docker-compose.prod.generated.yml
                        
                        # Deploy to Docker Swarm on Prod node
                        docker stack deploy -c docker-compose.prod.generated.yml furious-ducks-prod
                        
                        # Wait for deployment
                        sleep 30
                        
                        # Health check
                        curl -f http://${PROD_NODE}:4200/health || exit 1
                    '''
                }
            }
        }
        
        stage('QA Testing & Deployment') {
            when {
                branch 'main'
            }
            parallel {
                stage('Deploy to QA') {
                    steps {
                        script {
                            echo "🧪 Deploying to QA environment..."
                            sh '''
                                # Deploy to QA node
                                envsubst < docker-compose.qa.yml > docker-compose.qa.generated.yml
                                docker stack deploy -c docker-compose.qa.generated.yml furious-ducks-qa
                                
                                # Wait for QA deployment
                                sleep 30
                            '''
                        }
                    }
                }
                stage('Integration Tests') {
                    steps {
                        script {
                            echo "🔍 Running integration tests on QA..."
                            sh '''
                                # Wait for QA to be ready
                                timeout 300 bash -c 'until curl -f http://${QA_NODE}:4200/health; do sleep 10; done'
                                
                                # Run integration tests
                                npm run test:integration -- --baseUrl=http://${QA_NODE}:4200
                                
                                # Run API tests
                                npm run test:api -- --baseUrl=http://${QA_NODE}:3000
                                
                                # Performance tests
                                npm run test:performance -- --url=http://${QA_NODE}:4200
                            '''
                        }
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'integration-test-results.xml'
                        }
                    }
                }
            }
        }
        
        stage('Notification & Cleanup') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'main') {
                        echo "✅ Production deployment completed successfully!"
                    } else {
                        echo "✅ Development build completed successfully!"
                    }
                    
                    // Clean up old images
                    sh '''
                        docker image prune -f
                        docker system prune -f --volumes
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Archive artifacts if they exist
                if (fileExists('frontend/dist')) {
                    archiveArtifacts artifacts: 'frontend/dist/**', allowEmptyArchive: true
                }
                if (fileExists('backend/dist')) {
                    archiveArtifacts artifacts: 'backend/dist/**', allowEmptyArchive: true
                }
                
                echo "🧹 Pipeline completed - cleaning workspace"
            }
            
            // Clean workspace
            cleanWs()
        }
        success {
            script {
                if (env.BRANCH_NAME == 'main') {
                    echo "✅ Production deployment successful! Build #${env.BUILD_NUMBER} - ${env.GIT_COMMIT_SHORT}"
                    echo "🚀 Services deployed to production and QA environments"
                } else {
                    echo "✅ Build and tests successful! Build #${env.BUILD_NUMBER} - ${env.GIT_COMMIT_SHORT}"
                }
            }
        }
        failure {
            script {
                echo "❌ Pipeline failed! Branch: ${env.BRANCH_NAME}, Build #${env.BUILD_NUMBER}"
                echo "📋 Check the logs above for detailed error information"
                echo "🔧 Common issues: missing credentials, network connectivity, Docker daemon"
            }
        }
    }
}
