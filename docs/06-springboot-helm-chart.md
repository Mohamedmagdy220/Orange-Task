# 📘 06 – Deploy ToyStore App on Dev Using Helm + Connect to MySQL Secret

## 1. Purpose

This document describes how to deploy the ToyStore Spring Boot application on the dev namespace using a lightweight custom Helm chart, and connect it to the MySQL database using:
- MySQL Service inside the cluster `(mysql-mysql)`
- Kubernetes Secret (mysql-secret) containing DB credentials
- ConfigMap providing `SPRING_DATASOURCE_URL` 
---
## 2. Architecture Diagram
```
+-------------------------------------------------------------------+
|                         Minikube Cluster                           |
|                                                                    |
|  dev namespace                                                     |
|  +-------------------+         +-------------------------------+   |
|  | MySQL StatefulSet |         | ToyStore Deployment           |   |
|  | (mysql Helm chart)|         |                               |   |
|  | Service: mysql-mysql <------| SPRING_DATASOURCE_URL         |   |
|  +---------+---------+         | SPRING_DATASOURCE_USERNAME    |   |
|            ^                   | SPRING_DATASOURCE_PASSWORD    |   |
|            |                   +---------------+---------------+   |
|            |                                   |                   |
|    Secret: mysql-secret                        | Service: toystore |
|    - mysql-user                                | (ClusterIP)       |
|    - mysql-password                            +-------------------+
+--------------------------------------------------------------------+
```
---
## 3. Prerequisites

- Minikube running
- MySQL deployed in `dev` namespace (from README #05)
- mysql-secret exists in dev namespace with keys:
    - mysql-database
    - mysql-user
    - mysql-password

Verify:
```bash
kubectl -n dev get secret mysql-secret
```

![secret](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/6-spring/get%20secret.png)
---

## 4. Build Application Image Inside Minikube

After clonning this github repo (https://github.com/ahmedmisbah-ole/Devops-Orange) to my project :
- get into the directory of the project
- create Dockerfile to create docker image

```bash
cd ~/devops-orange/Devops-Orange/ToyOStore
nano Dockerfile
```

We nead runtime stage only because in ci pipline we build the app.jar with maven before docker , if we nead test it local we can make multistage docker file :
#### Dockerfile:

```bash
# ---------- Runtime stage only ----------

FROM eclipse-temurin:8-jre
WORKDIR /app
COPY target/*.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
```
### (Bouns) if we nead test it local we can make multistage docker file :
```bash
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
```
Then:

```bash
eval $(minikube docker-env)
docker build -t toystore:dev .
```

Validate image exists:

```bash
docker images | grep toystore
```

![image local](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/6-spring/test%20image%20local.png)
---


## 5. Create Helm Chart for the Application

### 5.1 Create chart structure

```bash
cd ~/devops-orange/helm
helm create toystore-app
rm -f toystore-app/templates/*
```
---
## 6. Helm Values

values.yaml
```bash
image:
  repository: toystore
  tag: dev
  pullPolicy: IfNotPresent

mysql:
  serviceName: mysql-mysql
  port: 3306

secretName: mysql-secret

service:
  port: 80
```
---
## 7. Helm Templates

### 7.1 ConfigMap (Datasource URL)

Creates `SPRING_DATASOURCE_URL` pointing to MySQL service inside the cluster.

```bash
apiVersion: v1
kind: ConfigMap
metadata:
  name: toystore-config
data:
  SPRING_DATASOURCE_URL: "jdbc:mysql://{{ .Values.mysql.serviceName }}:{{ .Values.mysql.port }}/toystore"
```
Note: Database name is fixed to toystore because it already exists (validated during MySQL init in README #05).
---
### 7.2 Deployment (inject ConfigMap + Secret)

Inject:
- URL from ConfigMap
- Username/password from Secret keys: mysql-user, mysql-password

helm/toystore-app/templates/deployment.yaml
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: toystore
spec:
  replicas: 1
  selector:
    matchLabels:
      app: toystore
  template:
    metadata:
      labels:
        app: toystore
    spec:
      containers:
        - name: toystore
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: toystore-config
          env:
            - name: SPRING_DATASOURCE_USERNAME
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.secretName }}
                  key: mysql-user
            - name: SPRING_DATASOURCE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.secretName }}
                  key: mysql-password
```
---
### 7.3 Service (ClusterIP)
Expose application internally using ClusterIP:

helm/toystore-app/templates/service.yaml
```bash
apiVersion: v1
kind: Service
metadata:
  name: toystore
spec:
  type: ClusterIP
  selector:
    app: toystore
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
```

---
## 8. Deploy on Dev Namespace

if you nead to test it local before you get into the pipline :

```bash
helm upgrade --install toystore ~/devops-orange/helm/toystore-app -n dev
```
---
## 9. Verification

Check all resourses in `dev` namespace :
```bash
kubectl -n dev get all
```

![check all resources -n dev](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/6-spring/all%20resourses%20.png)
---











