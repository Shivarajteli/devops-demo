```groovy
pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
    }

    tools {
        jdk 'jdk21'
    }

    environment {
        SONAR_PROJECT_KEY = 'devops-demo'
        AWS_REGION        = 'ap-south-1'
        AWS_ACCOUNT_ID    = '825820235145'
        ECR_REPOSITORY    = 'devops-demo'
        GITOPS_VALUES_FILE = 'helm/devops-demo/values.yaml'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Check Commit Type') {
            steps {
                script {
                    env.SKIP_CI = sh(
                        script: '''
                            if git log -1 --pretty=%B | grep -Fq '[skip ci]'; then
                                echo true
                            else
                                echo false
                            fi
                        ''',
                        returnStdout: true
                    ).trim()

                    if (env.SKIP_CI == 'true') {
                        echo 'GitOps-only commit detected. Skipping build and deployment stages.'
                    }
                }
            }
        }

        stage('Build WAR with Maven') {
            when {
                expression { env.SKIP_CI != 'true' }
            }
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Archive WAR Artifact') {
            when {
                expression { env.SKIP_CI != 'true' }
            }
            steps {
                archiveArtifacts artifacts: 'target/devops-demo.war',
                                 fingerprint: true
            }
        }

        stage('SonarQube Analysis') {
            when {
                expression { env.SKIP_CI != 'true' }
            }
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
            when {
                expression { env.SKIP_CI != 'true' }
            }
            steps {
                sh '''
                    set -eu
                    docker build -t devops-demo:${BUILD_NUMBER} .
                    docker images devops-demo
                '''
            }
        }

        stage('Trivy Image Scan') {
            when {
                expression { env.SKIP_CI != 'true' }
            }
            steps {
                sh '''
                    set -eu
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
            when {
                expression { env.SKIP_CI != 'true' }
            }
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

        stage('Update Helm Image Tag in GitHub') {
            when {
                expression { env.SKIP_CI != 'true' }
            }
            steps {
                script {
                    withCredentials([
                        gitUsernamePassword(
                            credentialsId: 'github-gitops-token',
                            gitToolName: 'Default'
                        )
                    ]) {
                        sh '''
                            set -eu

                            VALUES_FILE="${GITOPS_VALUES_FILE}"

                            test -f "${VALUES_FILE}"

                            # Update only the image tag in the Helm values file.
                            sed -i \
                              "s/^  tag: .*/  tag: \\"${BUILD_NUMBER}\\"/" \
                              "${VALUES_FILE}"

                            # Fail rather than commit an incorrectly formatted chart.
                            grep -Eq '^  tag: "[^"]+"' "${VALUES_FILE}"

                            git config user.name "jenkins-bot"
                            git config user.email "jenkins-bot@example.com"

                            git add "${VALUES_FILE}"

                            if git diff --cached --quiet; then
                                echo "No Helm image tag changes to commit."
                            else
                                git commit -m "Update image tag to ${BUILD_NUMBER} [skip ci]"
                                git push origin HEAD:main
                            fi

                            echo "Helm image tag update completed."
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                if (env.SKIP_CI == 'true') {
                    echo 'GitOps-only commit processed; build stages were skipped.'
                } else {
                    echo 'WAR build, SonarQube analysis, Trivy scan, ECR push, and Helm GitOps update completed successfully.'
                }
            }
        }

        failure {
            echo 'Pipeline failed. Check the Console Output for details.'
        }
    }
}

