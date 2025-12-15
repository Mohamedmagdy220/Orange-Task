# 📘 GitLab CI/CD Complete Setup
From Project Creation to Nexus Push and Minikube Deployment
---

## 1. Overview

##### This document describes the complete GitLab CI/CD setup for the DevOps Orange project.

By following this guide step-by-step, you will be able to:

- Create a GitLab project
- Configure CI/CD variables securely
- Create and register a GitLab Runner
- Allow the runner to access Nexus and Minikube
- Build Docker images in CI
- Push images to Nexus Docker Registry
- Deploy the application to Minikube using Helm

## 2. High-Level Architecture
```
Developer
   |
   v
GitLab Project
(.gitlab-ci.yml)
   |
   v
GitLab Runner (Docker Executor, host network)
   |
   |--- docker build / docker push
   |--- helm deploy
   |
   v
+-----------------------------+
| Nexus Docker Registry       |
| <MINIKUBE_IP>:30500         |
+-----------------------------+

+-----------------------------+
| Minikube Kubernetes Cluster |
| namespaces: build/dev/test  |
+-----------------------------+
```
---

## 3. Step 1 – Create GitLab Project

1. Create a new project.
2. push the project manually
3. Ensure the repository contains at least:
   - .gitlab-ci.yml
   - Dockerfile
   - helm/ directory

---
![](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/my%20project.png)
---
## 4. Step 2 – Review Project Files

### 4.1 Dockerfile

The Dockerfile is a runtime-only image used to run the Spring Boot JAR.

Key points:
- Uses a lightweight JRE image
- Copies the built JAR
- Exposes port 8080

Note: use in dockerfile image compatable with project (jdk-8)

```bash
# ---------- Runtime stage only ----------

FROM eclipse-temurin:8-jre
WORKDIR /app
COPY target/*.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
```

---

### 4.2 .gitlab-ci.yml
This file defines:
- Pipeline stages
- Build logic
- Docker image creation
- Deployment to Kubernetes

```bash
stages:
  - checkout
  - build
  - image
  - deploy

variables:
  APP_PATH: "Toy0Store"
  IMAGE_NAME: "toystore"
  HELM_CHART_PATH: "helm/toystore-app"

# 1) Checkout code from GitHub
checkout_code:
  stage: checkout
  image: alpine:3.20
  script:
    - apk add --no-cache git
    - git clone "$GITHUB_REPO" src
  artifacts:
    paths:
      - src/
    expire_in: 1 hour

# 2) Build spring boot project using Maven
maven_build:
  stage: build
  image: maven:3.9.9-eclipse-temurin-11
  script:
    - echo "Listing src directory:"
    - ls -lah src
    - cd src/$APP_PATH
    - mvn -DskipTests clean package
    - mkdir -p $CI_PROJECT_DIR/dist
    - cp target/*.jar $CI_PROJECT_DIR/dist/
    - echo "dist contents:"
    - ls -lah $CI_PROJECT_DIR/dist   
  artifacts:
    paths:
      - dist/*.jar
    expire_in: 1 hour

# 3) Create Docker image from JAR + Push to Nexus
build_and_push:
  stage: image
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    # Auth to Nexus
    - mkdir -p /kaniko/.docker
    - |
      cat > /kaniko/.docker/config.json <<EOF
      {
        "auths": {
          "${NEXUS_REGISTRY}": {
            "username": "${NEXUS_USER}",
            "password": "${NEXUS_PASS}"
          }
        }
      }
      EOF

    # Build context: بس target/ + Dockerfile.runtime
    - mkdir -p buildctx/target
    - cp dist/*.jar buildctx/target/
    - cp Dockerfile buildctx/Dockerfile

    # tag
    - echo "IMAGE_TAG=$CI_COMMIT_SHORT_SHA" > build.env

    # build + push
    - /kaniko/executor
      --context "$CI_PROJECT_DIR/buildctx"
      --dockerfile "$CI_PROJECT_DIR/buildctx/Dockerfile"
      --destination "${NEXUS_REGISTRY}/${NEXUS_DOCKER_REPO}/${IMAGE_NAME}:${CI_COMMIT_SHORT_SHA}"
      --insecure

  artifacts:
    reports:
      dotenv: build.env

# 4) Manual deploy: choose dev/test using TARGET_ENV
deploy_choose_env:
  stage: deploy
  image: 
    name: alpine/helm:3.16.3
    entrypoint: [""]
  when: manual
  script:
    - apk add --no-cache kubectl ca-certificates


    # kubeconfig
    - printf '%s' "$KUBECONFIG_RAW" > kubeconfig
    - sed -i 's/\r$//' kubeconfig   
    - sed -i 's#https://192\.168\.49\.2:8443#https://127.0.0.1:32771#g' kubeconfig
    - export KUBECONFIG="$CI_PROJECT_DIR/kubeconfig"
    - kubectl get ns
    
    # Debug: 
    - echo "TARGET_ENV=$TARGET_ENV"
    - echo "HELM_CHART_PATH=$HELM_CHART_PATH"
    - echo "IMAGE_TAG=$IMAGE_TAG"
    - echo "Listing repo root:"
    - ls -lah
    - echo "Listing helm folder:"
    - ls -lah helm || true
    - echo "Listing chart path:"
    - ls -lah "$HELM_CHART_PATH" || true
    

    # validate target env
    - |
      if [ -z "${TARGET_ENV}" ]; then
        echo "ERROR: set TARGET_ENV=dev or TARGET_ENV=test when running this job."
        exit 1
      fi
      case "${TARGET_ENV}" in dev|test) ;; *) echo "TARGET_ENV must be dev or test"; exit 1 ;; esac

    # helm deploy using image from nexus
    - helm upgrade --install toystore "$HELM_CHART_PATH" -n "$TARGET_ENV" --create-namespace --set image.repository="${NEXUS_REGISTRY}/${NEXUS_DOCKER_REPO}/${IMAGE_NAME}" --set image.tag="${IMAGE_TAG}" --set image.pullPolicy=IfNotPresent
    - kubectl -n "$TARGET_ENV" rollout status deploy/toystore
    - kubectl -n "$TARGET_ENV" get pods
```
---

## 5. Step 3 – Configure CI/CD Variables (Critical)
CI/CD variables allow us to:
- Avoid hardcoding secrets
- Keep the pipeline portable
- Change environments without editing code

Navigate to:
#### Project → Settings → CI/CD → Variables

![enter variables](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/enter%20the%20variables%20for%20gitlab.png)
---

### 5.1 Required Group Variables 

| Variable Name       | Type   | Description                                     |
| ------------------- | ------ | ------------------------------------------------|
| `NEXUS_USER`        | Text   | Nexus username                                  |
| `NEXUS_PASS`        | Masked | Nexus password                                  |
| `NEXUS_DOCKER_REPO` | Text   | Docker hosted repo name                         |
| `GITHUB_REPO`       | Text   | Source repository (optional use)                |
| `NEXUS_REGISTRY`    | Text   | Nexus Docker registry endpoint (`IP:NodePort`)  |
| `KUBECONFIG_RAW`    | Masked | Kubernetes config used by CI to access Minikube |

Note:GitLab CI jobs run outside your local shell, so they do not have access to ~/.kube/config. -->  Store kubeconfig as a CI/CD variable

![variables](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/variables.png)
---

## 6. Step 4 – Create GitLab Runner (Docker Executor)

The pipeline needs to:
- Run Docker commands
- Reach Nexus on Minikube NodePort
- Reach Kubernetes API server
---
### 6.2 Why --network host Is Mandatory in create gitlab runner container

Both:
- Nexus
- Minikube API / NodePorts

are exposed on the host network.


If the runner runs on Docker bridge network:
- It may not reach NodePorts
- Docker push/pull may fail
✅ Solution: run the runner on host network 


---
### 6.3 Start GitLab Runner Container

```bash
docker run -d --name gitlab-runner --restart always \
  --network host \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

Explanation:
- --network host: allows access to Minikube & Nexus

verify:

![gitlab container](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/gitlab%20runner%20container.png)
---

### 6.4 Register the Runner
1. In GitLab:
   - Project → Settings → CI/CD → Runners
   - Copy the registration token

2. Register:
   ```bash
   docker exec -it gitlab-runner gitlab-runner register
   ```
Recommended options:
- Executor: `docker`
- Default image: alpine:latest
- token : registration token

After this step, the runner should appear as online:

![gitlab runner](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/gitlab%20runner%20in%20gitlab%20ui.png)
---

## 7. step 5 - Now we run pipline

![after run pipline](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/after%20run%20pipline.png)
---


## 8. step 6 - the first stage in pipline (checkout)

in this stage we clone the repo of the code 
and after this job successed you will see:
![first job](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/first%20job%20successed.png)
---

## 9. step 7 - the second job in pipline (build)
in this stage we build the app.jar as a package for Dockerfile
and after this job successed you will see:
![second job](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/first%20and%20second%20one%20successed.png)
---

## 10. Step 8 – Docker Image Build and Push to Nexus Using Kaniko

### 10.1 Authentication to Nexus (Kaniko)
During pipeline execution:
```bash
/kaniko/.docker/config.json
```
this file is dynamically created using GitLab CI variables

#### CI Variables Used
- NEXUS_REGISTRY
- NEXUS_USER
- NEXUS_PASS


Authentication Setup (inside CI job):
```bash
mkdir -p /kaniko/.docker

cat > /kaniko/.docker/config.json <<EOF
{
  "auths": {
    "${NEXUS_REGISTRY}": {
      "username": "${NEXUS_USER}",
      "password": "${NEXUS_PASS}"
    }
  }
}
EOF
```

This allows Kaniko to authenticate securely to Nexus without exposing credentials in logs.
---
### 10.2 Build Context Preparation
Steps Performed in CI:
```bash
mkdir -p buildctx/target
cp dist/*.jar buildctx/target/
cp Dockerfile buildctx/Dockerfile
```
---
### 10.3 Image Tagging Strategy
The image is tagged using the Git commit short SHA:
```bash
IMAGE_TAG=$CI_COMMIT_SHORT_SHA
```

The tag is stored as a dotenv artifact:
```bash
echo "IMAGE_TAG=$CI_COMMIT_SHORT_SHA" > build.env
```
---
### 10.4 Build and Push Using Kaniko
The actual image build and push is executed by the Kaniko executor:
```bash
/kaniko/executor \
  --context "$CI_PROJECT_DIR/buildctx" \
  --dockerfile "$CI_PROJECT_DIR/buildctx/Dockerfile" \
  --destination "$NEXUS_REGISTRY/$NEXUS_DOCKER_REPO/$IMAGE_NAME:$CI_COMMIT_SHORT_SHA" \
  --insecure
```
---
### 10.5 Result of This Step

After this job completes successfully:
1. The Docker image is available in Nexus Docker Registry
2. Image is tagged with the commit SHA
3. The tag is exported for use in deployment stages
4. Kubernetes can later pull this image for Dev or Test deployments

and you will see:
![third job](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/3%20jobs%20successed.png)
---


#### 10.6 Verification

From Nexus UI:
![image tag](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/image%20tag.png)
---


## 11. Step 7 – Stage 4 

### 11.1 - Kubernetes Access from CI (Minikube)
Inside the deploy job:
1. Recreate kubeconfig from variable
2. Export `KUBECONFIG`
3. Use `kubectl` and `helm`

From `.gitlab-ci.yml`:

```bash
mkdir -p ~/.kube
echo "$KUBECONFIG_RAW" > ~/.kube/config
export KUBECONFIG=~/.kube/config
kubectl get namespaces
```
In this step CI has full access to Minikube.

---
### 11.2 Environment Selection (Dev or Test)

The target environment is controlled by a pipeline variable:
```bash
TARGET_ENV=dev   or   TARGET_ENV=test
```
From `.gitlab-ci.yml`:
```bash
- |
      if [ -z "${TARGET_ENV}" ]; then
        echo "ERROR: set TARGET_ENV=dev or TARGET_ENV=test when running this job."
        exit 1
      fi
      case "${TARGET_ENV}" in dev|test) ;; *) echo "TARGET_ENV must be dev or test"; exit 1 ;; esac
```

![](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/choose%20environment%20to%20deploy%20.png)
---


### 11.3 Helm Deployment Command

The deployment job uses helm upgrade --install to ensure idempotency.
```bash
- helm upgrade --install toystore "$HELM_CHART_PATH" -n "$TARGET_ENV" --create-namespace --set image.repository="${NEXUS_REGISTRY}/${NEXUS_DOCKER_REPO}/${IMAGE_NAME}" --set image.tag="${IMAGE_TAG}" --set image.pullPolicy=IfNotPresent
- kubectl -n "$TARGET_ENV" rollout status deploy/toystore
- kubectl -n "$TARGET_ENV" get pods
```
after success you will see:
![deploy job](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/deploy%20job%20successed.png)
---

### 8.7 Verification After Deployment

Check pods, service -n test:
![](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/cicd/the%20deployment%20in%20the%20vm.png)
---















