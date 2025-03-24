# 🧱 Plan de travail – Projet DevOps Azure

🎯 Objectif : Concevoir et mettre en œuvre le déploiement d’une application FastAPI conteneurisée sur Azure, en assurant un cycle complet incluant le déploiement manuel initial, l’automatisation CI/CD, la sécurisation des secrets, et l’infrastructure as code. Le projet comprend également le déploiement de deux instances de l’application accessibles via une URL unique, avec une logique de routage dynamique basée sur la parité de la minute.

---

## 📘 Synthèse des activités

La première partie du projet consiste à mettre en place les bases techniques et à réaliser un déploiement manuel fonctionnel de l’application. Cela comprend l’organisation du dépôt, la connexion à la base de données PostgreSQL hébergée sur Azure, la conteneurisation de l’application avec Docker, le push de l’image vers Azure Container Registry, puis le déploiement manuel dans App Service Linux. La configuration de l’application (variables d’environnement, logs) est finalisée pour assurer un fonctionnement stable, traçable, et reproductible.

La deuxième partie est dédiée à l’automatisation, la qualité et la sécurisation. Un pipeline GitHub Actions est mis en place pour builder, publier et déployer automatiquement l’image. Des tests unitaires (`pytest`) et des outils de linting (`ruff`, `flake8`) sont intégrés au pipeline. Les secrets sont externalisés dans Azure Key Vault et accédés via une identité managée. La supervision est renforcée à l’aide de logs et d’outils comme Application Insights. Des restrictions d’accès sont également configurées pour renforcer la sécurité de l’application.

La dernière phase introduit la gestion de l’infrastructure à l’aide de Terraform, permettant un déploiement entièrement automatisé et versionné des ressources Azure nécessaires au projet. Deux instances distinctes de l’application sont déployées, chacune sur un App Service séparé, et exposées derrière une URL unique. Une logique de routage est mise en œuvre pour rediriger les requêtes vers l’une ou l’autre instance en fonction de la parité de la minute courante. Cette étape permet de valider une approche multi-instances et de tester un comportement de répartition de charge basé sur des règles simples côté application.

---

## ✅ Résultat attendu

| Élément                                        | Statut |
|------------------------------------------------|--------|
| Application FastAPI conteneurisée              | ✅     |
| Déploiement manuel via script Azure CLI        | ✅     |
| Build et push dans Azure Container Registry    | ✅     |
| Hébergement dans Azure App Service             | ✅     |
| Automatisation du déploiement via CI/CD        | ✅     |
| Tests automatisés et lint intégrés             | ✅     |
| Sécurisation des secrets via Key Vault         | ✅     |
| Supervision avec logs et métriques             | ✅     |
| Déploiement via Terraform                      | ✅     |
| Deux instances déployées et accessibles        | ✅     |
| Routage logique entre instances via URL unique | ✅     |


---

## 🔧 Dockerisation & Déploiement

- Organiser le dépôt GitHub et la structure du projet
- Vérifier la connexion à PostgreSQL sur Azure
- Créer un Dockerfile fonctionnel et tester localement
- Préparer les variables d’environnement (env vars)
- Créer un Azure Container Registry (ACR)
- Builder l’image avec `az acr build`
- Déployer manuellement dans App Service Linux (F1)
- Générer un nom unique automatiquement dans le script
- Ajouter la configuration de l’app (ENV, logs)
- Activer les logs App Service (`az webapp log tail`)

---

## 🔁 CI/CD, Tests & Sécurité

- Créer un workflow GitHub Actions (`deploy.yml`)
- Intégrer les secrets dans GitHub
- Automatiser : build, push ACR, déploiement App Service
- Ajouter `pytest` + `ruff` ou `flake8` pour les tests et le lint
- Ajouter les tests dans le pipeline GitHub Actions
- Créer un Azure Key Vault et y stocker les secrets sensibles
- Activer Managed Identity sur l’App Service
- Lier l’App Service au Key Vault (via les app settings)
- Supprimer les secrets du code et des secrets GitHub
- Intégrer Application Insights (optionnel)
- Mettre en place des restrictions d’accès (IP, auth simple)
- Activer l’audit des accès Key Vault
- Évaluer la couverture des pratiques DevOps cibles

---

## ⚙️ Infrastructure as code &  & FinOps avancés

Cette troisième phase vise à industrialiser l’infrastructure de l’application à l’aide de Terraform, tout en intégrant une approche de maîtrise des coûts à travers un scénario FinOps simulé. L’objectif est de déployer deux instances distinctes de l’application FastAPI sur Azure App Service, chacune dans un plan tarifaire différent : l’une sur un plan standard, l’autre sur un plan optimisé (par exemple, un plan spot ou basse priorité). Une logique applicative est introduite pour router les requêtes vers l’une ou l’autre instance selon la parité de la minute courante.

Toute l’infrastructure — registre, App Services, Key Vault, plans — est définie et déployée via Terraform pour garantir la reproductibilité. Cette phase permet de valider une stratégie multi-environnements, de tester des mécanismes de routage interne, et d’analyser l’impact des choix d’infrastructure sur les coûts. C’est aussi l’occasion de monitorer plus finement le comportement de l’application selon les instances utilisées, et de compléter la démarche DevOps par une dimension d’optimisation économique.

---

### 🔧 Infrastructure as code & LoadBalancing


- Définir toute l’infrastructure avec Terraform : ACR, App Service Plans, App Services, Key Vault
- Déployer deux instances indépendantes de l'application avec des noms distincts
- Créer une URL unique (via un proxy, une route d’entrée, ou un composant d’orchestration)
- Implémenter une logique de routage basée sur la parité de la minute (`minute % 2`)
- Rediriger les requêtes de l’utilisateur vers l’une ou l’autre instance selon la logique définie
- Superviser les appels pour confirmer le comportement attendu


## 🎓 Compétences DevOps couvertes

| Domaine                                      | Couvert ? | Détails clés                                                       |
|----------------------------------------------|-----------|---------------------------------------------------------------------|
| Intégration continue (CI)                    | ✅        | Build/test automatique via GitHub Actions                           |
| Livraison continue (CD)                      | ✅        | Déploiement auto sur App Service après build                        |
| Conteneurisation & Cloud native              | ✅        | Docker, ACR, App Service Linux                                      |
| Sécurisation des secrets & accès             | ✅        | Azure Key Vault + Managed Identity                                  |
| Supervision & observabilité                  | ✅        | Logs Azure, routage vérifiable par minute                          |
| Infrastructure as Code                       | ✅        | Déploiement complet via Terraform                                   |
| Architecture multi-instance & routage logique| ✅        | 2 instances déployées, routage selon minute                         |
| Gestion de la qualité du code                | ✅        | Linting (`ruff`, `flake8`) + tests unitaires (`pytest`)             |
| Structuration et automatisation de projet    | ✅        | Repo organisé, script de déploiement, workflows CI/CD               |




