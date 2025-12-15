# 🚀 DevOps Orange – End-to-End CI/CD Pipeline Project

## Project Summary
This project demonstrates a complete DevOps CI/CD workflow starting from source code management and ending with automated deployment to Kubernetes.

The solution is designed to reflect real-world DevOps practices, including:
- Infrastructure provisioning
- Artifact management
- Environment isolation
- Kubernetes-native deployments

The entire system runs locally using Minikube, GitLab, and Nexus, making it ideal for learning, demos, and technical assessments.

## High-Level Architecture

```
┌────────────────────────┐
│        Developer        │
│  (Git Push / Commit)   │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│        GitLab           │
│  Repository + CI/CD     │
│  (.gitlab-ci.yml)       │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────────────────────────┐
│            GitLab CI Pipeline               │
│                                            │
│  Stage 1: Build (Maven)                     │
│  - mvn clean package                        │
│  - produces JAR artifact                   │
│                                            │
│  Stage 2: Image (Kaniko)                    │
│  - build Docker image                      │
│  - tag with commit SHA                     │
│  - push to Nexus                           │
│                                            │
│  Stage 3: Deploy (Helm)                     │
│  - manual (dev / test)                     │
│  - uses IMAGE_TAG                          │
└───────────┬────────────────────────────────┘
            │
            ▼
┌────────────────────────────────────────────┐
│        GitLab Runner (Docker)               │
│                                            │
│  - Docker executor                          │
│  - network_mode: host                      │
│  - mounted docker.sock                     │
│  - reads CI variables                      │
│                                            │
│  Accesses:                                 │
│  ✔ Nexus NodePort                          │
│  ✔ Minikube API                            │
└───────────┬────────────────────────────────┘
            │
            ▼
┌────────────────────────────────────────────┐
│     Nexus Repository OSS (Docker Registry) │
│     Namespace: build                       │
│                                            │
│  - docker-hosted repository                │
│  - HTTP NodePort (30500)                   │
│  - Auth via CI variables                   │
└───────────┬────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────┐
│                Kubernetes Cluster (Minikube)                 │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │ build         │    │ dev           │    │ test          │   │
│  │ namespace     │    │ namespace     │    │ namespace     │   │
│  │               │    │               │    │               │   │
│  │ Nexus         │    │ ToyStore App  │    │ ToyStore App  │   │
│  │               │    │ Deployment    │    │ Deployment    │   │
│  │               │    │               │    │               │   │
│  │               │    │ MySQL         │    │ MySQL         │   │
│  │               │    │ StatefulSet   │    │ StatefulSet   │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```
---
## Technology Stack

| Category           | Tool                  |
| ------------------ | --------------------- |
| Source Control     | GitLab                |
| CI/CD              | GitLab CI             |
| Container Build    | Kaniko                |
| Artifact Registry  | Nexus Repository OSS  |
| Container Runtime  | Docker                |
| Orchestration      | Kubernetes (Minikube) |
| Packaging          | Helm                  |
| Infra as Code      | Terraform             |
| Configuration Mgmt | Ansible               |
| Database           | MySQL                 |
| Application        | Spring Boot           |

---

## Namespace Strategy

| Namespace | Purpose                      |
| --------- | ---------------------------- |
| `build`   | CI/CD tools (Nexus Registry) |
| `dev`     | Development environment      |
| `test`    | Testing environment          |

---
## Infrastructure Overview
1️⃣ Kubernetes (Minikube)
- Local Kubernetes cluster
- Acts as the runtime platform for all services

2️⃣ GitLab
- Self-hosted GitLab instance
- Manages source code and CI/CD pipelines

3️⃣ Nexus Repository OSS
- Deployed on Kubernetes (build namespace)
- Configured using:
   - Terraform (deployment & service)
   - Ansible (Docker hosted repo configuration)
- Used as private Docker registry


---
## CI/CD Pipeline Design

Pipeline Stages:
1. Build
   - Maven builds the Spring Boot JAR
2. Image
   - Kaniko builds Docker image
   - Image is pushed to Nexus
3. Deploy
   - Helm deploys the image to Kubernetes
   - Target environment: dev or test
  
---

## Verification Checklist

- ✔ Image exists in Nexus
- ✔ Pods running in dev/test

---

## Documentation Index

| Document                        | Description            |
| ------------------------------- | ---------------------- |
| `01-minikube-setup.md`          | Kubernetes setup       |
| `02-namespaces.md`              | Namespace design       |
| `03-gitlab-setup.md`            | GitLab installation    |
| `04-nexus-terraform-ansible.md` | Nexus deployment       |
| `05-mysql-helm.md`              | MySQL Helm chart       |
| `06-app-helm.md`                | Application Helm chart |
| `07-gitlab-ci-cd-complete.md`   | CI/CD full setup       |


## Author
Mohamed Magdy
DevOps Engineer





