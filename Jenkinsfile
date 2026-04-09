// ============================================================
//  ShopNow Premium Store — Jenkins CI/CD Pipeline
//  Flow:
//    1. Checkout Code
//    2. Verify Project Structure
//    3. Build Docker Image
//    4. Push Image to DockerHub
//    5. Deploy to Kubernetes
//    6. Verify Deployment
// ============================================================

pipeline {

    agent any

    // ── Pipeline-level Environment Variables ─────────────────
    environment {
        DOCKERHUB_USERNAME    = "setu3011"
        IMAGE_NAME            = "shopnow-app"
        IMAGE_TAG             = "${BUILD_NUMBER}"                        // unique tag per build
        FULL_IMAGE            = "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"
        LATEST_IMAGE          = "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"

        DOCKERHUB_CREDENTIAL  = "dockerhub-creds"                       // Jenkins credential ID
        KUBECONFIG_CREDENTIAL = "kubeconfig-creds"                      // Jenkins credential ID

        K8S_NAMESPACE         = "shopnow"
        K8S_DEPLOYMENT        = "shopnow-deployment"
        K8S_CONTAINER         = "shopnow-container"

        DOCKERFILE_PATH       = "Dockerfile"                            // Dockerfile at project root
        DOCKER_CONTEXT        = "."                                     // build context = project root
    }

    // ── Triggers ─────────────────────────────────────────────
    triggers {
        githubPush()            // auto-trigger on GitHub push
        // pollSCM('H/5 * * * *') // or poll every 5 min (uncomment if preferred)
    }

    // ── Global Options ────────────────────────────────────────
    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
    }

    // ===================================================================
    //  STAGES
    // ===================================================================
    stages {

        // ── STAGE 1: Checkout ──────────────────────────────────
        stage('Checkout Code') {
            steps {
                echo '📥 Cloning repository...'
                checkout scm
                sh 'ls -la'
            }
        }

        // ── STAGE 2: Verify Files ─────────────────────────────
        stage('Verify Project Structure') {
            steps {
                echo '🔍 Verifying required files exist...'
                sh '''
                    echo "---- Project Root ----"
                    ls -la

                    echo "---- app/frontend ----"
                    ls -la app/frontend/

                    echo "---- Dockerfile check ----"
                    if [ ! -f Dockerfile ]; then
                        echo "ERROR: Dockerfile not found at project root!"
                        exit 1
                    fi

                    if [ ! -f app/frontend/index.html ]; then
                        echo "ERROR: index.html not found at app/frontend!"
                        exit 1
                    fi

                    echo "✅ All required files found."
                '''
            }
        }

        // ── STAGE 3: Build Docker Image ───────────────────────
        stage('Build Docker Image') {
            steps {
                echo "🐳 Building Docker image: ${FULL_IMAGE}"
                sh '''
                    docker build \
                        -f ${DOCKERFILE_PATH} \
                        -t ${FULL_IMAGE} \
                        -t ${LATEST_IMAGE} \
                        ${DOCKER_CONTEXT}

                    echo "✅ Docker image built successfully."
                    docker images | grep ${IMAGE_NAME}
                '''
            }
        }

        // ── STAGE 4: Push to DockerHub ────────────────────────
        stage('Push to DockerHub') {
            steps {
                echo "📤 Pushing image to DockerHub: ${FULL_IMAGE}"
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKERHUB_CREDENTIAL}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin

                        docker push ${FULL_IMAGE}
                        docker push ${LATEST_IMAGE}

                        echo "✅ Both tags pushed to DockerHub."
                        docker logout
                    '''
                }
            }
        }

        // ── STAGE 5: Deploy to Kubernetes ─────────────────────
        stage('Deploy to Kubernetes') {
            steps {
                echo "☸️  Deploying ${FULL_IMAGE} to Kubernetes..."
                withCredentials([file(
                    credentialsId: "${KUBECONFIG_CREDENTIAL}",
                    variable: 'KUBECONFIG'
                )]) {
                    sh '''
                        # Ensure namespace exists
                        kubectl get namespace ${K8S_NAMESPACE} || \
                            kubectl create namespace ${K8S_NAMESPACE}

                        # Apply full manifest (Namespace, Deployment, Service, Ingress)
                        kubectl apply -f k8s/shopnow-k8s.yaml

                        # Hot-swap container image to the new build-tagged image
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                            ${K8S_CONTAINER}=${FULL_IMAGE} \
                            --namespace=${K8S_NAMESPACE}

                        # Restart pods to force pull of fresh image
                        kubectl rollout restart deployment/${K8S_DEPLOYMENT} \
                            --namespace=${K8S_NAMESPACE}

                        # Block pipeline until rollout finishes (max 2 min)
                        kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                            --namespace=${K8S_NAMESPACE} \
                            --timeout=120s

                        echo "✅ Deployment rollout complete."
                    '''
                }
            }
        }

        // ── STAGE 6: Verify Deployment ────────────────────────
        stage('Verify Deployment') {
            steps {
                echo '🔎 Verifying running pods and resources...'
                withCredentials([file(
                    credentialsId: "${KUBECONFIG_CREDENTIAL}",
                    variable: 'KUBECONFIG'
                )]) {
                    sh '''
                        echo "---- Pods ----"
                        kubectl get pods -n ${K8S_NAMESPACE} -o wide

                        echo "---- Service ----"
                        kubectl get service -n ${K8S_NAMESPACE}

                        echo "---- Ingress ----"
                        kubectl get ingress -n ${K8S_NAMESPACE}

                        echo "---- Active Image in Deployment ----"
                        kubectl get deployment ${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE} \
                            -o=jsonpath='{.spec.template.spec.containers[0].image}'
                        echo ""

                        echo "✅ Verification complete."
                    '''
                }
            }
        }

    }
    // ===================================================================
    //  END STAGES
    // ===================================================================

    // ── Post Actions ──────────────────────────────────────────
    post {

        success {
            echo """
            ╔══════════════════════════════════════════════╗
            ║   ✅  PIPELINE SUCCEEDED                     ║
            ║   Image : ${FULL_IMAGE}
            ║   Build : #${BUILD_NUMBER}                   ║
            ╚══════════════════════════════════════════════╝
            """
        }

        failure {
            echo """
            ╔══════════════════════════════════════════════╗
            ║   ❌  PIPELINE FAILED                        ║
            ║   Build : #${BUILD_NUMBER}                   ║
            ║   Logs  : ${BUILD_URL}console                ║
            ╚══════════════════════════════════════════════╝
            """
        }

        always {
            echo '🧹 Cleaning up local Docker images to free disk space...'
            sh '''
                docker rmi ${FULL_IMAGE}   || true
                docker rmi ${LATEST_IMAGE} || true
                docker image prune -f      || true
            '''
        }

    }

}
