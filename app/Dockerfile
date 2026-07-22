# ============================================
# STAGE 1 : BUILD - Construction de l'application
# ============================================
FROM maven:3.8.4-openjdk-17-slim AS build
WORKDIR /app

# Copier les fichiers de dépendances d'abord (optimisation du cache)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copier le code source et construire
COPY src ./src
RUN mvn package -DskipTests -B

# ============================================
# STAGE 2 : RUNTIME - Image légère pour l'exécution
# ============================================
FROM amazoncorretto:17-alpine
WORKDIR /app

# Copier le JAR depuis le stage de build
COPY --from=build /app/target/spring-petclinic-*.jar app.jar

# Exposer le port
EXPOSE 8080

# Lancer l'application avec le profil PostgreSQL
ENTRYPOINT ["java", "-jar", "app.jar"]
CMD ["--spring.profiles.active=postgresql"]
