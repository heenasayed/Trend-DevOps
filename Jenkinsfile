pipeline {
    agent any

    environment {
        IMAGE   = "heenadocker5866/trend-app"
        CLUSTER = "trend-cluster"
        REGION  = "us-east-1"
    }

    triggers {
        githubPush()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh '''
                    docker build \
                      -t $IMAGE:$BUILD_NUMBER \
                      -t $IMAGE:latest \
                      .
                '''
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_PASS'
                    )
                ]) {
                    sh '''
                        echo "$DH_PASS" | docker login \
                          -u "$DH_USER" \
                          --password-stdin

                        docker push $IMAGE:$BUILD_NUMBER
                        docker push $IMAGE:latest
                    '''
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                    aws eks update-kubeconfig \
                      --name $CLUSTER \
                      --region $REGION

                    kubectl apply -f k8s/

                    kubectl set image deployment/trend-app \
                      trend-app=$IMAGE:$BUILD_NUMBER

                    kubectl rollout status deployment/trend-app
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
    }
}

