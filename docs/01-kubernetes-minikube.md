# 📘 01 – Kubernetes Local Setup Using Minikube

## 1. Purpose
✅ This document describes how to set up a local Kubernetes cluster using Minikube, which will be used as the base infrastructure for the DevOps Orange project.

Minikube provides a lightweight Kubernetes environment suitable for:

- Local development.
- CI/CD testing.
- Running services such as GitLab, Nexus, and application workloads.

## 2. 🔧 Prerequisites
Before starting, ensure the following tools are installed on your machine:

| Tool     | Version (Recommended)   |
| -------- | ----------------------- |
| OS       | Linux                   |
| Docker   | ≥ 20.x                  |
| CPU      | 4 cores minimum         |
| RAM      | 8 GB minimum            |
| Disk     | 40 GB minimum           |

## 3. 📌 Verification Steps &  Result:

### ✅ Step 1: install Docker
#### 1.1 install Docker engine 

```bash
sudo dnf config-manager --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```
#### 1.2 enable Docker
```bash
sudo systemctl enable docker --now
```
#### 1.3 enable Dockcer without sudo 
```bash
sudo usermod -aG docker $USER
newgrp docker
```


### ✅ Step 2: install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s \
https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl
sudo mv kubectl /usr/local/bin/

kubectl version --client
```

### ✅ Step 3: Minikube (Driver = Docker)

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube-linux-amd64
sudo mv minikube-linux-amd64 /usr/local/bin/minikube

minikube version
```

### ✅ Step 4: start minikube on CentOS 9

```bash
minikube start \
  --driver=docker \
  --cpus=4 \
  --memory=8192
```

##### make sure 

```bash
minikube status
kubectl get nodes
```
Expected output:

![status](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/1-minikube/minikube%20status.png)
---

![](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/1-minikube/nodes%20in%20mini-kube%20.png)
### ✅ Step 5: Addons
```bash
minikube addons enable ingress
minikube addons enable metrics-server
```


##  Validation Checklist

✔ Minikube is running
✔ kubectl is connected to minikube context
✔ Node status is Ready
✔ Addons enabled successfully

##  Next Step
➡️ README #02 – Kubernetes Namespaces Setup (Build, Dev, Test)

