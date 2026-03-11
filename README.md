# 🚀 Déploiement Nextcloud sur AWS avec Terraform

> Projet réalisé dans le cadre du BTS SIO SISR  
> Infrastructure as Code (IaC) - Déploiement automatisé d'une solution de stockage cloud privé

---

## 📋 Sommaire

1. [Présentation du projet](#présentation-du-projet)
2. [Architecture](#architecture)
3. [Prérequis](#prérequis)
4. [Installation](#installation)
5. [Déploiement](#déploiement)
6. [Accès à Nextcloud](#accès-à-nextcloud)
7. [Sécurité](#sécurité)
8. [Coûts estimés](#coûts-estimés)
9. [Suppression de l'infrastructure](#suppression-de-linfrastructure)

---

## 📌 Présentation du projet

Ce projet déploie automatiquement une instance **Nextcloud** sur AWS grâce à **Terraform**.  
Il s'inscrit dans une démarche **Infrastructure as Code (IaC)** permettant de :

- ✅ Reproduire l'environnement en quelques minutes
- ✅ Versionner l'infrastructure dans Git
- ✅ Éviter les erreurs de configuration manuelle
- ✅ Détruire et recréer les ressources facilement

### Stack technique

| Composant | Technologie |
|---|---|
| **IaC** | Terraform >= 1.0 |
| **Cloud Provider** | Amazon Web Services (AWS) |
| **Région** | eu-west-3 (Paris) |
| **Serveur applicatif** | EC2 t3.small - Amazon Linux 2023 |
| **Base de données** | RDS MySQL 8.0 (managé) |
| **Stockage fichiers** | S3 Bucket |
| **Serveur web** | Apache + PHP 8.1 |
| **Application** | Nextcloud (dernière version) |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                  AWS Cloud - eu-west-3               │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │              VPC 10.0.0.0/16                 │   │
│  │                                              │   │
│  │  ┌──────────────────────────────────────┐   │   │
│  │  │     Subnet PUBLIC 10.0.1.0/24        │   │   │
│  │  │         [EC2 - Nextcloud]            │   │   │
│  │  └──────────────────────────────────────┘   │   │
│  │                    │                         │   │
│  │       ┌────────────┴────────────┐            │   │
│  │       ▼                         ▼            │   │
│  │  ┌──────────────┐  ┌──────────────────────┐ │   │
│  │  │Subnet PRIVÉ 1│  │   Subnet PRIVÉ 2     │ │   │
│  │  │ 10.0.2.0/24  │  │   10.0.3.0/24        │ │   │
│  │  │ [RDS MySQL]  │  │   (failover RDS)     │ │   │
│  │  └──────────────┘  └──────────────────────┘ │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │            S3 Bucket (fichiers)              │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### Principe de sécurité appliqué

```
Internet ──▶ EC2   ✅ Port 80, 443, 22
Internet ──▶ RDS   ❌ Bloqué
Internet ──▶ S3    ❌ Bloqué (accès via IAM Role uniquement)
EC2      ──▶ RDS   ✅ Port 3306 (interne VPC uniquement)
EC2      ──▶ S3    ✅ Via IAM Role (sans credentials stockés)
```

---

## ✅ Prérequis

### Outils à installer

```bash
# Terraform (>= 1.0)
https://developer.hashicorp.com/terraform/downloads

# AWS CLI
https://aws.amazon.com/fr/cli/

# Vérifier les installations
terraform --version
aws --version
```

### Compte AWS

- Un compte AWS actif (personnel, AWS Educate, ou compte école)
- Un utilisateur IAM avec les droits : `EC2`, `RDS`, `S3`, `VPC`, `IAM`

### Configuration AWS CLI

```bash
aws configure
# AWS Access Key ID     : [votre clé]
# AWS Secret Access Key : [votre clé secrète]
# Default region name   : eu-west-3
# Default output format : json
```

### Paire de clés SSH

```bash
# Créer une paire de clés sur AWS
aws ec2 create-key-pair \
  --key-name nextcloud-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/nextcloud-key.pem

# Sécuriser la clé privée (obligatoire sous Linux/Mac)
chmod 400 ~/.ssh/nextcloud-key.pem
```

---

## 📁 Structure du projet

```
nextcloud-aws/
├── main.tf          # Ressources AWS principales
├── variables.tf     # Variables configurables
├── outputs.tf       # Valeurs retournées après déploiement
├── userdata.sh      # Script d'installation automatique de Nextcloud
└── README.md        # Ce fichier
```

---

## 🚀 Déploiement

### Étape 1 - Cloner le projet

```bash
git clone https://github.com/votre-repo/nextcloud-aws.git
cd nextcloud-aws
```

### Étape 2 - Initialiser Terraform

```bash
terraform init
```

> 📌 Cette commande télécharge le **provider AWS** nécessaire à Terraform.

### Étape 3 - Vérifier le plan de déploiement

```bash
terraform plan
```

> 📌 Terraform affiche **ce qui va être créé** sans rien déployer.  
> Vérifiez qu'il n'y a pas d'erreurs avant de continuer.

### Étape 4 - Déployer l'infrastructure

```bash
terraform apply
```

Tapez `yes` pour confirmer.

> ⏱️ **Durée estimée : 10 à 15 minutes** (RDS est long à provisionner)

### Étape 5 - Récupérer les informations de connexion

```bash
terraform output
```

Exemple de sortie :

```
nextcloud_url    = "http://13.37.xx.xx"
ssh_command      = "ssh -i ~/.ssh/nextcloud-key.pem ec2-user@13.37.xx.xx"
rds_endpoint     = "nextcloud-bts.xxxxxx.eu-west-3.rds.amazonaws.com"
s3_bucket_name   = "nextcloud-bts-storage-xxxxxx"
```

---

## 🌐 Accès à Nextcloud

1. Ouvrez votre navigateur
2. Accédez à l'URL affichée par `terraform output`
3. Complétez l'installation via l'interface web

### Configuration initiale Nextcloud

| Champ | Valeur |
|---|---|
| **Dossier des données** | `/var/www/nextcloud/data` |
| **Type de base de données** | MySQL/MariaDB |
| **Hôte de la base** | *(valeur de `rds_endpoint`)* |
| **Nom de la base** | `nextcloud` |
| **Utilisateur BDD** | `nc_user` |
| **Mot de passe BDD** | *(valeur de `db_password` dans variables.tf)* |

---

## 🔒 Sécurité

### Mesures implémentées

| Mesure | Détail |
|---|---|
| **Subnet privé RDS** | La BDD n'est pas accessible depuis Internet |
| **Security Groups** | Pare-feu par ressource, moindre privilège |
| **IAM Role** | EC2 accède à S3 sans stocker de credentials |
| **Chiffrement RDS** | `storage_encrypted = true` |
| **Accès SSH restreint** | Port 22 ouvert (à restreindre à votre IP en production) |

### ⚠️ Recommandations pour la production

```hcl
# Restreindre le SSH à votre IP uniquement
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["VOTRE_IP/32"]  # Remplacer 0.0.0.0/0
}
```

---


## 🗑️ Suppression de l'infrastructure

```bash
# Détruit TOUTES les ressources créées par Terraform
terraform destroy
```

Tapez `yes` pour confirmer.

> ✅ Toutes les ressources AWS sont supprimées, **plus aucun frais** ne sera facturé.

---

## 🐛 Dépannage

### Nextcloud inaccessible après déploiement

```bash
# Se connecter en SSH à l'instance
ssh -i ~/.ssh/nextcloud-key.pem ec2-user@[IP_EC2]

# Vérifier les logs d'installation
sudo cat /var/log/cloud-init-output.log

# Vérifier qu'Apache tourne
sudo systemctl status httpd
```

### Erreur de connexion à RDS

```bash
# Tester la connexion MySQL depuis EC2
mysql -h [RDS_ENDPOINT] -u nc_user -p nextcloud
```

### Erreur Terraform "credentials not found"

```bash
# Reconfigurer AWS CLI
aws configure

# Vérifier la configuration
aws sts get-caller-identity
```

---

## 📚 Ressources utiles

- [Documentation Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Documentation Nextcloud](https://docs.nextcloud.com)
- [AWS Free Tier](https://aws.amazon.com/fr/free/)
- [Calculateur de coûts AWS](https://calculator.aws/pricing/2/homescreen)

---

## 👤 Auteur

**Hugo Léonardi**  
BTS SIO SISR - Aurlom
2024-2026

---

*Projet réalisé dans le cadre de l'épreuve E4/E5 du BTS SIO SISR*
