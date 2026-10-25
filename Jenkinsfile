pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
    }

    tools {
        jdk 'jdk21'
    }

    environment {
        SONAR_PROJECT_KEY = 'devops-demo'
        AWS_REGION       = 'ap-south-1'
        AWS_ACCOUNT_ID   = '825820235145'
        ECR_REPOSITORY   = 'devops-demo'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build WAR with Maven') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Archive WAR Artifact') {
            steps {
                archiveArtifacts artifacts: 'target/devops-demo.war',
                                 fingerprint: true
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'

                    withSonarQubeEnv('sonarqube') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                              -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                              -Dsonar.projectName='DevOps Demo' \
                              -Dsonar.sources=src/main/java \
                              -Dsonar.java.binaries=target/classes
                        """
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t devops-demo:${BUILD_NUMBER} .
                    docker images devops-demo
                '''
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                    TMPDIR=/var/tmp/trivy-tmp trivy --config /dev/null image \
                      --ignorefile /dev/null \
                      --scanners vuln \
                      --severity HIGH,CRITICAL \
                      --exit-code 1 \
                      --format table \
                      devops-demo:${BUILD_NUMBER}
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    set -eu

                    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    LOCAL_IMAGE="devops-demo:${BUILD_NUMBER}"
                    ECR_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${BUILD_NUMBER}"

                    aws ecr get-login-password \
                      --region "${AWS_REGION}" |
                      docker login \
                        --username AWS \
                        --password-stdin "${ECR_REGISTRY}"

                    docker tag "${LOCAL_IMAGE}" "${ECR_IMAGE}"
                    docker push "${ECR_IMAGE}"

                    echo "Successfully pushed ${ECR_IMAGE}"
                '''
            }
        }
    }

    post {
        success {
            echo 'WAR build, code analysis, Docker image scan, and ECR push completed successfully.'
        }

        failure {
            echo 'Pipeline failed. Check the Console Output for details.'
        }
    }
}
