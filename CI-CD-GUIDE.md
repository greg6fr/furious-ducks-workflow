# 🦆 Furious Ducks Workflow - Guide CI/CD Complet

## 🎯 Vue d'Ensemble

Cette automatisation CI/CD optimisée gère le déploiement d'une stack **Angular + Node.js + MongoDB** sur votre infrastructure Docker Swarm 4-nœuds.

### 📋 Workflow par Branche

| Branche | Actions | Déploiement |
|---------|---------|-------------|
| `develop` | ✅ Build + Test + Push Docker Hub | ❌ Pas de déploiement |
| `main` | ✅ Build + Test + Push Docker Hub<br/>✅ Déploiement Production<br/>✅ Tests QA + Déploiement QA | ✅ Prod + QA |

## 🏗️ Architecture Infrastructure

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CI/CD Server  │    │   Dev Server    │    │   QA Server     │    │  Prod Server    │
│  (Manager)      │    │   (Worker)      │    │   (Worker)      │    │   (Worker)      │
│                 │    │                 │    │                 │    │                 │
│ • Jenkins       │    │ • Dev Apps      │    │ • QA Testing    │    │ • Production    │
│ • Gitea         │    │ • Development   │    │ • Integration   │    │ • Live Apps     │
│ • Docker Swarm  │    │                 │    │ • Validation    │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Configuration Initiale

### 1. Préparer l'Infrastructure

```bash
# Exécuter le script de configuration
chmod +x scripts/setup-infrastructure.sh
./scripts/setup-infrastructure.sh

# Configurer les labels Docker Swarm
npm run setup:swarm-labels
```

### 2. Configurer Jenkins

```bash
# Afficher les instructions de configuration Jenkins
./scripts/setup-jenkins-credentials.sh
```

**Credentials à configurer dans Jenkins :**

1. **Docker Hub** (`dockerhub-credentials`)
   - Type: Username with password
   - Username: votre-username-dockerhub
   - Password: votre-token-dockerhub

2. **SSH Swarm** (`swarm-ssh-key`)
   - Type: SSH Username with private key
   - Username: admin
   - Private Key: contenu de `infrastructure/ansible/keys/mykey.pem`

### 3. Structure de Projet Recommandée

```
furious-ducks-workflow/
├── frontend/                 # Application Angular
│   ├── src/
│   ├── Dockerfile
│   ├── package.json
│   └── angular.json
├── backend/                  # API Node.js
│   ├── src/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── Jenkinsfile              # Pipeline CI/CD
├── docker-compose.prod.yml  # Configuration Production
├── docker-compose.qa.yml    # Configuration QA
└── scripts/                 # Scripts d'automatisation
```

## 📦 Dockerfiles Recommandés

### Frontend (Angular)

```dockerfile
# frontend/Dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build:prod

FROM nginx:alpine
COPY --from=builder /app/dist/* /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1
```

### Backend (Node.js)

```dockerfile
# backend/Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
USER node
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
CMD ["npm", "start"]
```

## 🔧 Optimisations Implémentées

### ⚡ Performance
- **Builds parallèles** : Frontend et Backend en simultané
- **Tests parallèles** : Exécution simultanée des suites de tests
- **Cache Docker** : Réutilisation des layers pour accélérer les builds
- **Multi-stage builds** : Images optimisées et légères

### 🛡️ Sécurité
- **Audit de sécurité** : `npm audit` automatique
- **Scan d'images** : Trivy (optionnel)
- **Credentials sécurisés** : Gestion via Jenkins Credentials
- **Headers de sécurité** : Configuration Nginx optimisée

### 📊 Monitoring
- **Health checks** : Vérification automatique de l'état des services
- **Tests de couverture** : Rapports HTML intégrés
- **Logs centralisés** : Collecte et archivage
- **Notifications Slack** : Alertes de déploiement

### 🔄 Déploiement
- **Rolling updates** : Déploiement sans interruption
- **Rollback automatique** : En cas d'échec de déploiement
- **Placement intelligent** : Services déployés sur les bons nœuds
- **Resource limits** : Gestion optimisée des ressources

## 📋 Scripts package.json Recommandés

### Frontend (package.json)
```json
{
  "scripts": {
    "build:prod": "ng build --configuration production",
    "test:ci": "ng test --watch=false --browsers=ChromeHeadless --code-coverage",
    "test:e2e": "ng e2e --headless",
    "lint": "ng lint"
  }
}
```

### Backend (package.json)
```json
{
  "scripts": {
    "start": "node server.js",
    "test:coverage": "jest --coverage --ci",
    "test": "jest",
    "lint": "eslint src/",
    "seed:qa": "node scripts/seed-qa-data.js"
  }
}
```

## 🎮 Utilisation

### Déploiement Develop
```bash
git checkout develop
git add .
git commit -m "feat: nouvelle fonctionnalité"
git push origin develop
```
**Résultat :** Build + Test + Push vers Docker Hub

### Déploiement Production
```bash
git checkout main
git merge develop
git push origin main
```
**Résultat :** Build + Test + Push + Déploiement Prod + Tests QA

## 📊 Monitoring et Logs

### Accès aux Services
- **Jenkins :** http://15.237.192.218:8080
- **Gitea :** http://15.237.192.218:3000
- **Production :** http://52.47.133.246:4200
- **QA :** http://51.44.86.0:4200

### Commandes de Monitoring
```bash
# Statut du cluster
docker node ls

# Services déployés
docker service ls

# Logs d'un service
docker service logs furious-ducks-prod_frontend

# Métriques de performance
docker stats
```

## 🔧 Dépannage

### Problèmes Courants

1. **Build qui échoue**
   ```bash
   # Vérifier les logs Jenkins
   # Nettoyer le cache Docker
   docker system prune -f
   ```

2. **Déploiement qui échoue**
   ```bash
   # Vérifier l'état des nœuds
   docker node ls
   
   # Vérifier les services
   docker service ps furious-ducks-prod_frontend
   ```

3. **Tests qui échouent**
   ```bash
   # Exécuter les tests localement
   npm run test:ci
   npm run test:e2e
   ```

## 🚀 Prochaines Étapes

1. **Créer votre structure d'application** (frontend/ et backend/)
2. **Configurer vos Dockerfiles**
3. **Mettre à jour les variables d'environnement** (.env.prod, .env.qa)
4. **Pousser sur develop pour tester** le pipeline
5. **Déployer en production** via main

## 📞 Support

Pour toute question ou problème :
1. Vérifiez les logs Jenkins
2. Consultez les métriques Docker Swarm
3. Examinez les logs des services

---

🎉 **Votre pipeline CI/CD optimisé est prêt !** Profitez d'un déploiement automatisé, sécurisé et performant pour votre stack Angular + Node.js + MongoDB.
