# 📘 02 – Kubernetes Namespaces Setup (Build, Dev, Test)

## 1. Purpose
This document explains how to create and manage Kubernetes namespaces used in the DevOps Orange project.

Namespaces are used to logically isolate:

- CI/CD build tools.
- Application environments (Dev & Test).

## 2. Architecture Diagram
```
+--------------------------------------------------+
|                  Minikube Cluster                |
|                                                  |
|  +----------------+   +------------------------+ |
|  |  build         |   |  dev                   | |
|  |  Namespace     |   |  Namespace             | |
|  |                |   |                        | |
|  |  - Nexus OSS   |   |  - MySQL (Helm)        | |
|  |                |   |  - Spring Boot App     | |
|  +----------------+   +------------------------+ |
|                                                  |
|  +----------------------------------------------+|
|  |  test                                        ||
|  |  Namespace                                   ||
|  |                                              ||
|  |  - MySQL (Helm)                              ||
|  |  - Spring Boot App                           ||
|  +----------------------------------------------+|
|                                                  |
+--------------------------------------------------+
```
## 3. Namespaces Overview

| Namespace | Purpose                            |
| --------- | ---------------------------------- |
| build     | CI/CD tools (Nexus Repository OSS) |
| dev       | Development environment            |
| test      | Testing environment                |

## 4. Create Namespaces

```bash
kubectl create namespace build
kubectl create namespace dev
kubectl create namespace test
```

## 5. Verify Namespaces
```bash
kubectl get namespaces
```

Expected output:

![ns](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/2-ns/namespaces.png)
---

## 6. Next Step
➡️ README #03 – Local GitLab Installation Using Docker Compose
