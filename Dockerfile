FROM tomcat:10.1-jre21-temurin-noble

COPY target/devops-demo.war /usr/local/tomcat/webapps/ROOT.war

