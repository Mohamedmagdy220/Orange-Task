# ---------- Runtime stage only ----------

FROM eclipse-temurin:8-jre
WORKDIR /app
COPY target/*.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]




####################################################



# ---------- Build stage ----------
#FROM maven:3.9.9-eclipse-temurin-11 AS build
#WORKDIR /app

# Cache dependencies layer (speeds up CI builds)
#COPY pom.xml .
#RUN mvn -q -DskipTests dependency:go-offline

# Build app
#COPY src ./src
#RUN mvn -q -DskipTests clean package

# ---------- Runtime stage ----------
#FROM eclipse-temurin:11-jre
#WORKDIR /app

# Copy all jars then pick the real one (exclude *.original) and normalize name
#COPY --from=build /app/target/*.jar /app/
#RUN set -e; \
 #   ls -lah /app; \
  #  JAR="$(ls /app/*.jar | grep -v '\.original$' | head -n 1)"; \
   # test -n "$JAR"; \
   # mv "$JAR" /app/app.jar

#EXPOSE 8080
#ENTRYPOINT ["java","-jar","/app/app.jar"]
