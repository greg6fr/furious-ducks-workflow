# 🚀 Furious Ducks - Guide de Déploiement

## 📋 Aperçu du Déploiement Automatisé

Le pipeline Jenkins CI/CD déploie automatiquement sur différents environnements selon la branche Git utilisée.

## 🌿 Stratégie de Branches

### 🔴 Branche `main` → Serveur de Production
- **Serveur**: `13.38.206.31`
- **Environnement**: Production
- **Configuration**: `docker-compose.prod.yml`
- **Stack Docker**: `furious-ducks-prod`

### 🟡 Branche `develop` → Serveur QA
- **Serveur**: `13.37.196.126`
- **Environnement**: QA/Test
- **Configuration**: `docker-compose.qa.yml`
- **Stack Docker**: `furious-ducks-qa`

### ⚪ Autres Branches
- **Action**: Aucun déploiement automatique
- **Message**: Informations sur les branches configurées

## 🔄 Workflow de Déploiement

### 1. Push sur `main`
```bash
git checkout main
git add .
git commit -m "Production release"
git push origin main
```
**Résultat**: Déploiement automatique sur le serveur de production `13.38.206.31`

### 2. Push sur `develop`
```bash
git checkout develop
git add .
git commit -m "QA testing features"
git push origin develop
```
**Résultat**: Déploiement automatique sur le serveur QA `13.37.196.126`

## 🏗️ Pipeline Jenkins

### Étapes du Pipeline
1. **Checkout & Setup** - Vérification du code et outils
2. **Build with Docker** - Construction des images (parallèle)
3. **Push to Docker Hub** - Publication des images
4. **Deploy Based on Branch** - Déploiement conditionnel
5. **Verification** - Vérification du déploiement
6. **Post Actions** - Nettoyage et rapports

### Variables d'Environnement
```groovy
PROD_NODE = "13.38.206.31"    // Serveur de production
QA_NODE = "13.37.196.126"     // Serveur QA
DOCKERHUB_USERNAME = "dspgroupe3archi"
```

## 🐳 Configuration Docker Swarm

### Prérequis
Avant le premier déploiement, exécuter le script de labellisation des nœuds :

```bash
./scripts/setup-swarm-labels.sh
```

### Services Déployés

#### Production (`main` branch)
- **Frontend**: 2 répliques sur port 4000
- **Backend**: 2 répliques sur port 3000
- **MongoDB**: 1 réplique avec persistance
- **Nginx**: Load balancer sur ports 80/443

#### QA (`develop` branch)
- **Frontend**: 1 réplique avec mode debug
- **Backend**: 1 réplique avec logging étendu
- **MongoDB**: 1 réplique avec données de test
- **Configuration**: Variables d'environnement de test

## 📊 Monitoring et Vérification

### Commandes Utiles
```bash
# Vérifier les services Docker Swarm
docker service ls

# Voir les logs d'un service
docker service logs furious-ducks-prod_backend

# Vérifier l'état des nœuds
docker node ls

# Inspecter un stack
docker stack ps furious-ducks-prod
```

### Ports d'Accès
- **Production**: `http://13.38.206.31`
- **QA**: `http://13.37.196.126`

## 🔧 Dépannage

### Services ne démarrent pas (0/X replicas)
1. Vérifier les labels des nœuds :
   ```bash
   ./scripts/setup-swarm-labels.sh
   ```

2. Redéployer le stack :
   ```bash
   docker stack deploy -c docker-compose.prod.yml furious-ducks-prod
   ```

### Erreurs de configuration QA
Toutes les variables d'environnement booléennes ont été converties en chaînes de caractères.

### Accès aux logs Jenkins
- **URL**: `http://[CI_CD_SERVER]:8080`
- **Build History**: Voir tous les builds et leurs statuts

## 🎯 Bonnes Pratiques

1. **Tests locaux** avant push
2. **Commits atomiques** avec messages descriptifs
3. **Utilisation de `develop`** pour les fonctionnalités en cours
4. **Merge vers `main`** uniquement pour les releases stables
5. **Monitoring** des déploiements via Jenkins et Docker

## 📈 Métriques de Succès

- ✅ **Build #5**: Dernier build réussi
- ✅ **Configuration QA**: Toutes les erreurs résolues
- ✅ **Docker Images**: Versioning automatique
- ✅ **Multi-environnement**: Production et QA opérationnels

---

🦆 **Furious Ducks Workflow** - Pipeline CI/CD Enterprise-Ready
