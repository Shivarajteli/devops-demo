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
                              -Dsonar.sources=src \
                              -Dsonar.java.binaries=src
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
    }

    post {
        success {
            echo 'Build, analysis, Docker image creation, and security scan completed.'
        }

        failure {
            echo 'Pipeline failed. Check the console output.'
        }
    }
}

