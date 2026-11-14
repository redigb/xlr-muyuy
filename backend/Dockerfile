# Compila y corre con Java 25 (LTS), igual que el pom.xml (release 25).
# Imágenes multiarquitectura -> funciona en Oracle A1 (ARM64).
FROM maven:3.9-eclipse-temurin-25 AS build
WORKDIR /src
COPY pom.xml .
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -q package -DskipTests

FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /src/target/quarkus-app/ ./
# Perfil prod por defecto (application-prod.yml): data en /app/data
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseCompactObjectHeaders --enable-native-access=ALL-UNNAMED"
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar quarkus-run.jar"]
