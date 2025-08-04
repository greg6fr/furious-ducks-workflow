
# Furious Ducks Workflow

## 🚀 Architecture Overview
This repository provides a complete CI/CD workflow for Furious Ducks agency based on open source technologies.
The setup includes:
- Jenkins (CI/CD)
- GitLab (SCM)
- Docker Swarm for container orchestration
- Monitoring stack (Prometheus, Grafana, ELK, Traefik)
- Automated backups with Restic/Borg
- Terraform + Ansible for provisioning

---

## 1️⃣ Provision Infrastructure with Terraform
Navigate to `infrastructure/terraform`:
```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```
This creates servers for:
- Workflow CI/CD
- Development
- QA
- Production

---

## 2️⃣ Configure Servers with Ansible
Once servers are created:
```bash
cd ../../ansible
ansible-playbook -i inventory.ini playbook.yml
```
This installs:
- Docker
- Jenkins
- GitLab CE
- Monitoring stack
- Backup tools

---

## 3️⃣ Initialize Docker Swarm
On the workflow server:
```bash
cd infrastructure
chmod +x docker-swarm-init.sh
./docker-swarm-init.sh
```
This sets up Docker Swarm to manage Dev, QA, and Prod environments.

---

## 4️⃣ Deploy Jenkins
Navigate to Jenkins folder:
```bash
cd ../../ci-cd/jenkins
docker-compose up -d
```
Access Jenkins via:
```
http://<workflow-server-ip>:8080
```

---

## 5️⃣ Deploy GitLab CE
Navigate to GitLab folder:
```bash
cd ../gitlab
docker-compose up -d
```
Access GitLab via:
```
http://<workflow-server-ip>
```

---

## 6️⃣ Setup Monitoring
Start Prometheus and Grafana:
```bash
cd ../../monitoring/prometheus
docker-compose up -d
cd ../grafana
docker-compose up -d
```
- Prometheus: `http://<workflow-server-ip>:9090`
- Grafana: `http://<workflow-server-ip>:3000`

Start Traefik:
```bash
cd ../traefik
docker-compose up -d
```

---

## 7️⃣ Configure Jenkins Pipelines
- Use templates in `ci-cd/templates` (PHP, NodeJS, Python)
- Each project includes a `Jenkinsfile`
- Jenkins builds Docker images, pushes to registry, and deploys to Swarm

---

## 8️⃣ Deploy Sample Apps
Examples available in `apps/`:
- HTML static site
- PHP app
- Node.js app

Deploy to Dev:
```bash
cd deployments/dev
docker-compose up -d
```

---

## 9️⃣ Automated Backups
Restic:
```bash
cd ../../backup/restic
chmod +x restic-backup.sh
./restic-backup.sh
```
Borg:
```bash
cd ../borg
chmod +x borg-backup.sh
./borg-backup.sh
```

---

## ✅ Summary
- **Fully containerized** CI/CD
- **Open source** solutions
- **Scalable** with Docker Swarm
- **Monitoring** & **Backup** included
- **Adaptable** to multi-tech projects

