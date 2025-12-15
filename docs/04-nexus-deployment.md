# 📘 04 – Nexus Repository OSS on Minikube Using Terraform + Ansible

## 1. Purpose

This document describes how to deploy and configure Sonatype Nexus Repository OSS on Minikube using:
- Terraform for Kubernetes resources (Namespace, Deployment, Service)
- Ansible for post-deployment configuration (create `docker-hosted` repository)

Nexus will be used as:
- Docker Image Registry
- Artifact repository for CI/CD pipelines
- Central image source for Kubernetes deployments
---
## 2. Architecture Diagram
```
+-------------------------------------------------------------+
|                       Minikube Cluster                      |
|                                                             |
|  +-----------------------------+                            |
|  | build namespace             |                            |
|  |                             |                            |
|  |  [Terraform]                |                            |
|  |   - nexus Deployment         |                           |
|  |   - nexus Service (NodePort) |                           |
|  |        UI : 30081            |                           |
|  |        REG: 30500            |                           |
|  +--------------+--------------+                            |
|                 |                                           |
|                 |  HTTP API (8081)                          |
|                 v                                           |
|           [Ansible Configuration]                           |
|           - Create docker-hosted repo (port 5000)           |
|                                                             |
|                                                             |
+-------------------------------------------------------------+
```
---
## 3. Prerequisites

- Minikube running
- `build` namespace created
- Terraform installed
- Ansible installed

---
## 4. Terraform – Deploy Nexus to Kubernetes

### 4.1 Provider Configuration
providers.tf:
```bash
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
```
---
### 4.2 Variables
variables.tf:
```bash
variable "namespace" { default = "build" }
variable "nexus_image" { default = "sonatype/nexus3:latest" }
variable "storage_size" { default = "10Gi" }
```
---
### 4.3 Namespace + Deployment + Service
main.tf:

```bash
data "kubernetes_namespace" "build" {
  metadata { name = var.namespace }
}

resource "kubernetes_persistent_volume_claim" "nexus_data" {
  metadata {
    name      = "nexus-data"
    namespace = data.kubernetes_namespace.build.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

resource "kubernetes_deployment" "nexus" {
  metadata {
    name      = "nexus"
    namespace = data.kubernetes_namespace.build.metadata[0].name
    labels    = { app = "nexus" }
  }

  spec {
    replicas = 1

    selector { match_labels = { app = "nexus" } }

    template {
      metadata { labels = { app = "nexus" } }

      spec {
        container {
          name  = "nexus"
          image = var.nexus_image

          port { container_port = 8081 } # Nexus UI
          port { container_port = 5000 } # Docker hosted (هنفعّله بعدين)

          resources {
            requests = { cpu = "500m", memory = "1Gi" }
            limits   = { cpu = "1", memory = "2Gi" }
          }

          volume_mount {
            name       = "nexus-data"
            mount_path = "/nexus-data"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8081
            }
            initial_delay_seconds = 120
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8081
            }
            initial_delay_seconds = 60
            period_seconds        = 10
          }

        }

        volume {
          name = "nexus-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.nexus_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nexus" {
  metadata {
    name      = "nexus"
    namespace = data.kubernetes_namespace.build.metadata[0].name
  }
  spec {
    selector = { app = "nexus" }

    port {
      name        = "http"
      port        = 8081
      target_port = 8081
      node_port   = 30081
    }

    port {
      name        = "docker"
      port        = 5000
      target_port = 5000
      node_port   = 30500
    }

    type = "NodePort"
  }
}
```
---
## 4.4 Apply Terraform

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

![terraform init](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/4-terraform%20and%20ansible/terraform%20init.png)
---

![terraform plan](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/4-terraform%20and%20ansible/terraform%20plan.png)
---

![terraform apply](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/4-terraform%20and%20ansible/after%20terraform%20apply.png)
---

### Verify:

```bash
kubectl get deploy,svc -n build
kubectl get pods -n build
```
![get all](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/4-terraform%20and%20ansible/resources%20in%20namespace%20build.png)
---

## 5. Nexus Access Details

### 5.1 Get Minikube IP
```bash
minikube ip
```
### 5.2 Nexus UI
```bash
http://192.168.49.2:30081
```

Get Initial Admin Password
```bash
kubectl exec -n build deploy/nexus -- cat /nexus-data/admin.password
```

### verify:
![access nexus](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/3-gitlab/access%20nexus%20ui%20.png)
---


## 6. Ansible – Configure Nexus (Create docker-hosted Repo)

### 6.1 Variables

vars.yml:
```bash

namespace: build
nexus_ui_nodeport: 30081

docker_repo_name: docker-hosted
docker_repo_port: 5000

change_admin_password: true
```
### 6.2 vault (Sensitive variables)
vault.yml
```bash
new_admin_password="..............."
```
Encrypt it:
```bash
ansible-vault encrypt ansible/vault.yml
```
---
### 6.3 Playbook
This playbook will:

- Detect Nexus Pod
- Read initial admin password
- Wait until Nexus is ready (/service/rest/v1/status)
- Change admin password
- Verify admin login with new password
- Create docker hosted repo


playbook.yml:
```bash
- name: Nexus bootstrap via Ansible (Vault-secured)
  hosts: localhost
  gather_facts: false

  vars_files:
    - vars.yml
    - vault.yml   # 🔒 encrypted secrets

  vars:
    admin_user: admin
    minikube_ip: "{{ lookup('pipe', 'minikube ip') }}"
    nexus_ui: "http://{{ minikube_ip }}:{{ nexus_ui_nodeport }}"

  tasks:
    - name: Get Nexus pod name
      shell: >
        kubectl -n {{ namespace }} get pod -l app=nexus
        -o jsonpath='{.items[0].metadata.name}'
      register: nexus_pod
      changed_when: false

    - name: Read initial admin password (if exists)
      shell: >
        kubectl -n {{ namespace }} exec -i {{ nexus_pod.stdout }}
        -- sh -lc "test -f /nexus-data/admin.password && cat /nexus-data/admin.password || true"
      register: admin_pass
      changed_when: false

    - name: Wait for Nexus UI
      uri:
        url: "{{ nexus_ui }}/"
        method: GET
        status_code: 200
      register: nexus_ready
      retries: 40
      delay: 10
      until: nexus_ready.status == 200

    - name: Change admin password
      uri:
        url: "{{ nexus_ui }}/service/rest/v1/security/users/{{ admin_user }}/change-password"
        method: PUT
        user: "{{ admin_user }}"
        password: "{{ admin_pass.stdout | trim }}"
        force_basic_auth: true
        headers:
          Content-Type: "text/plain"
        body: "{{ new_admin_password }}"
        status_code: [204, 404, 405]
      when: change_admin_password

    - name: Verify admin login with new password
      uri:
        url: "{{ nexus_ui }}/service/rest/v1/status"
        method: GET
        user: "{{ admin_user }}"
        password: "{{ new_admin_password }}"
        force_basic_auth: true
        status_code: 200

    - name: Create docker hosted repo
      uri:
        url: "{{ nexus_ui }}/service/rest/v1/repositories/docker/hosted"
        method: POST
        user: "{{ admin_user }}"
        password: "{{ new_admin_password }}"
        force_basic_auth: true
        status_code: [201, 400]
        headers:
          Content-Type: "application/json"
        body_format: json
        body:
          name: "{{ docker_repo_name }}"
          online: true
          storage:
            blobStoreName: "default"
            strictContentTypeValidation: true
            writePolicy: "ALLOW"
          docker:
            httpPort: "{{ docker_repo_port }}"
            forceBasicAuth: true
            v1Enabled: false
          cleanup:
            policyNames: []
```

### Run the Playbook

```bash
ansible-playbook -i ansible/playbook.yml.yml --ask-vault-pass
```

### Validation from nexus ui repo

You should see docker-hosted in the list:

![docker-hosted](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/3-gitlab/docker-hosted%20in%20nexus%20repo.png)
---



