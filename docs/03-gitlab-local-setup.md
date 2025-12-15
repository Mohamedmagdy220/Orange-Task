# 📘 03 – Local GitLab Installation Using Docker Compose

## 1. Purpose

This document describes how to deploy a local GitLab instance using Docker Compose.

This GitLab instance will be used to:

- Host CI/CD pipelines.
- Manage GitLab CI runners.
- Orchestrate build and deployment workflows to Kubernetes (Minikube).

## 2. Architecture Diagram
```
+------------------------------------------------------+
|                    Local Machine                     |
|                                                      |
|  +-------------------+        +-------------------+  |
|  |   GitLab Server   |        |   GitLab Runner   |  |
|  |  (Docker Compose) | <----> |   (Docker)        |  |
|  +-------------------+        +-------------------+  |
|            |                                 |       |
|            | CI/CD Pipeline                  |       |
|            v                                 v       |
|      +-----------------------------------------------+
|      |               Minikube Cluster                |
|      |                                               |
|      |   build / dev / test namespaces               |
|      +-----------------------------------------------+
|                                                      |
+------------------------------------------------------+
```
## 3. Prerequisites

| Tool           | Requirement             |
| -------------- | ----------------------- |
| Docker         | Installed & Running     |
| Docker Compose | v2.x                    |
| Minikube       | Running                 |
| Free Disk      | ≥ 10 GB                 |

## 4. GitLab Docker Compose File

Create a docker-compose.yml file:
```bash
version: "3.8"

services:
  gitlab:
    image: gitlab/gitlab-ce:17.7.0-ce.0
    container_name: gitlab
    restart: always
    hostname: gitlab.local
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://192.168.1.7'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
    ports:
      - "80:80"
      - "443:443"
      - "2222:22"
    volumes:
      - ./config:/etc/gitlab
      - ./logs:/var/log/gitlab
      - ./data:/var/opt/gitlab
```

## 5. Start GitLab

```bash
docker compose up -d
```
![](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/3-gitlab/docker-compose%20up%20gitlab.png)
---

Check status:
```bash
docker ps
```
![gitlab container](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/3-gitlab/gitlab%20container.png)
---

## 6. Initial GitLab Configuration

Get Root Password
```bash
docker exec -it gitlab cat /etc/gitlab/initial_root_password
```

Login using:

- Username: root
- Password: from above command

![gitlab ui login](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/3-gitlab/gitlab%20login.png)
---

![gitlab ui](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/3-gitlab/gitlab%20ui.png)
---

## 7. Create GitLab Project

- Login as root
- Create new project
- Import repository from GitHub

```bash
https://github.com/ahmedmisbah-ole/Devops-Orange
```

## 8. Validation Checklist

✔ GitLab container is running
✔ Web UI accessible
✔ Able to login as root

##  Next Step
➡️ README #04 – Nexus Repository OSS Deployment on Minikube (Build Namespace)





