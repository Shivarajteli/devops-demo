FROM eclipse-temurin:21-jre-noble
WORKDIR /app
COPY src/Hello.class Hello.class
CMD ["java", "-cp", "/app", "Hello"]
