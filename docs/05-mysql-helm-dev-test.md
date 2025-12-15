# 📘 05 – MySQL Helm Chart + Auto DB Initialization (Dev & Test)

## 1. Purpose

This document describes how to deploy MySQL on Minikube using a custom Helm chart (not Bitnami), and automatically initialize the database by importing an SQL script on first startup.

We deploy the same Helm chart into two environments:

- `dev` namespace
- `test` namespace
---
## 2. Prerequisites

- Minikube running
- Namespaces created: `dev`, `test`
- Helm installed

---
## 3. Helm Chart Setup

### 3.1 Create Helm chart directory
```bash
mkdir -p ~/devops-orange/helm
cd ~/devops-orange/helm
helm create mysql-chart
```
---
### 3.2 Clean default templates
```bash
rm -f mysql-chart/templates/*
mkdir -p mysql-chart/files
```
---
### Add SQL Init Script into the Chart
We package the SQL file inside the Helm chart, so Helm can render it into a ConfigMap.

```bash
cp ~/devops-orange/Devops-Orange/Database/toystore-test.sql \
   ~/devops-orange/helm/mysql-chart/files/init.sql
```
---
### 5. secrets for mysql DB
create secret in ns dev :
```bash
kubectl -n dev create secret generic mysql-secret \
  --from-literal=mysql-root-password='RootPass_dev!' \
  --from-literal=mysql-password='AppPass_dev' \
  --from-literal=mysql-user='appuser' \
  --from-literal=mysql-database='toystore'
```
---
create secret in ns test :

```bash
kubectl -n test create secret generic mysql-secret \
  --from-literal=mysql-root-password='RootPass_test' \
  --from-literal=mysql-password='AppPass_test' \
  --from-literal=mysql-user='appuser' \
  --from-literal=mysql-database='toystore'
```

![secrets](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/5-mysql/get%20secrets.png)
---

### 6. Helm Values

values.yaml:
```bash
image:
  repository: mysql
  tag: "8.0"
  pullPolicy: IfNotPresent

service:
  port: 3306

persistence:
  size: 5Gi

existingSecret: mysql-secret
secretKeys:
  rootPassword: mysql-root-password
  database: mysql-database
  user: mysql-user
  password: mysql-password
```

create  ~/devops-orange/helm/mysql-chart/values-dev.yaml :

inside values-dev.yaml
```bash
existingSecret: mysql-secret
```

create ~/devops-orange/helm/mysql-chart/values-test.yaml :

inside values-test.yaml
```bash
existingSecret: mysql-secret
```

Since the Secret name is the same in both namespaces, these values files remain minimal.
Any difference between dev and test comes from the Secret content in each namespace.
---
## 7. Helm Templates

### 7.1 ConfigMap for init.sql

create ~/devops-orange/helm/mysql-chart/templates/configmap-initdb.yaml :

```bash
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-initdb
data:
  init.sql: |-
{{ .Files.Get "files/init.sql" | indent 4 }}
```
---
### 7.2 Service
cretae ~/devops-orange/helm/mysql-chart/templates/service.yaml :

```bash
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-mysql
spec:
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 3306
      name: mysql
  selector:
    app: {{ .Release.Name }}-mysql
```
---
### 7.3 StatefulSet (Mount initdb + PVC)

create ~/devops-orange/helm/mysql-chart/templates/statefulset.yaml :

```bash
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ .Release.Name }}-mysql
spec:
  serviceName: {{ .Release.Name }}-mysql
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Release.Name }}-mysql
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-mysql
    spec:
      containers:
        - name: mysql
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 3306
              name: mysql
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.existingSecret }}
                  key: {{ .Values.secretKeys.rootPassword }}
            - name: MYSQL_DATABASE
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.existingSecret }}
                  key: {{ .Values.secretKeys.database }}
            - name: MYSQL_USER
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.existingSecret }}
                  key: {{ .Values.secretKeys.user }}
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.existingSecret }}
                  key: {{ .Values.secretKeys.password }}
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
            - name: initdb
              mountPath: /docker-entrypoint-initdb.d
              readOnly: true
      volumes:
        - name: initdb
          configMap:
            name: {{ .Release.Name }}-initdb
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: {{ .Values.persistence.size }}
```

---
## 8. Deploy to Dev and Test

### 8.1 Install/Upgrade (dev)

```bash
helm upgrade --install mysql ~/devops-orange/helm/mysql-chart \
  -n dev \
  -f ~/devops-orange/helm/mysql-chart/values-dev.yaml
```
---
### 8.2 Install/Upgrade (test)

```bash
helm upgrade --install mysql ~/devops-orange/helm/mysql-chart \
  -n test \
  -f ~/devops-orange/helm/mysql-chart/values-test.yaml
```
---

## 9. Verify Deployment
### Rollout status

```bash
kubectl -n dev  rollout status statefulset/mysql-mysql
kubectl -n test rollout status statefulset/mysql-mysql
```
![db-pods created](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/5-mysql/statfulset%20status.png)
---

### Pods

```bash
kubectl -n dev  get pods
kubectl -n test get pods
```

![db-pods created](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/5-mysql/get%20pods%20-n%20dev.png)
---


![db-pods created](https://github.com/Mohamedmagdy220/first/blob/main/docs/images/5-mysql/get%20pods%20-n%20test.png)
---

  







