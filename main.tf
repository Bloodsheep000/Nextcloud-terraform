# ==================================================
# PROVIDER - On indique à Terraform qu'on utilise AWS
# ==================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==================================================
# DATA SOURCES - Récupère des infos existantes sur AWS
# ==================================================

# Récupère les zones de disponibilité de la région
data "aws_availability_zones" "available" {
  state = "available"
}

# ==================================================
# VPC - Réseau privé virtuel
# Isole notre infrastructure du reste d'AWS
# ==================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Permet la résolution DNS (important pour RDS)
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# ==================================================
# SUBNETS - Sous-réseaux
# ==================================================

# Sous-réseau PUBLIC : EC2 sera ici (accessible depuis Internet)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # L'EC2 reçoit une IP publique automatiquement

  tags = {
    Name    = "${var.project_name}-subnet-public"
    Project = var.project_name
  }
}

# Sous-réseau PRIVÉ 1 : RDS (pas d'accès Internet direct)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_1
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name    = "${var.project_name}-subnet-private-1"
    Project = var.project_name
  }
}

# Sous-réseau PRIVÉ 2 : RDS exige au minimum 2 sous-réseaux dans 2 AZ différentes
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_2
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name    = "${var.project_name}-subnet-private-2"
    Project = var.project_name
  }
}

# ==================================================
# INTERNET GATEWAY - Passerelle vers Internet
# Sans ça, le VPC est complètement isolé
# ==================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# ==================================================
# ROUTE TABLE - Table de routage
# Indique où envoyer le trafic réseau
# ==================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Tout le trafic externe (0.0.0.0/0) passe par l'Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-rt-public"
    Project = var.project_name
  }
}

# Association de la route table avec le subnet public
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ==================================================
# SECURITY GROUPS - Pare-feu au niveau instance
# Principe du moindre privilège : on ouvre uniquement ce qui est nécessaire
# ==================================================

# Security Group pour EC2 (Nextcloud)
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg-ec2"
  description = "Security Group pour le serveur Nextcloud"
  vpc_id      = aws_vpc.main.id

  # SSH - Administration du serveur
  ingress {
    description = "SSH depuis votre IP uniquement"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ⚠️ En prod : mettre votre IP uniquement !
  }

  # HTTP - Nextcloud (sera redirigé vers HTTPS en prod)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS - Nextcloud sécurisé
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tout le trafic sortant est autorisé (mises à jour, téléchargements)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-ec2"
    Project = var.project_name
  }
}

# Security Group pour RDS (MySQL)
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "Security Group pour la base de données MySQL"
  vpc_id      = aws_vpc.main.id

  # MySQL uniquement depuis le serveur EC2
  # On référence le SG de l'EC2, pas une IP (plus robuste)
  ingress {
    description     = "MySQL depuis EC2 uniquement"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-rds"
    Project = var.project_name
  }
}

# ==================================================
# S3 BUCKET - Stockage des fichiers Nextcloud
# Avantage : stockage quasi-illimité, découplé du serveur
# ==================================================
resource "aws_s3_bucket" "nextcloud_storage" {
  # Le nom doit être unique sur tout AWS
  bucket = "${var.project_name}-storage-${random_id.bucket_suffix.hex}"

  tags = {
    Name    = "${var.project_name}-storage"
    Project = var.project_name
  }
}

# Génère un suffixe aléatoire pour garantir l'unicité du nom S3
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Bloque tout accès public au bucket (les fichiers sont privés)
resource "aws_s3_bucket_public_access_block" "nextcloud_storage" {
  bucket = aws_s3_bucket.nextcloud_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Chiffrement du bucket S3
resource "aws_s3_bucket_server_side_encryption_configuration" "nextcloud_storage" {
  bucket = aws_s3_bucket.nextcloud_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ==================================================
# IAM - Permissions pour EC2 → S3
# L'EC2 a besoin d'une identité pour accéder au S3
# ==================================================

# Rôle IAM attaché à l'EC2
resource "aws_iam_role" "ec2_s3_role" {
  name = "${var.project_name}-ec2-role"

  # Politique de confiance : seul EC2 peut assumer ce rôle
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Politique S3 : l'EC2 peut lire/écrire dans notre bucket uniquement
resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "${var.project_name}-s3-policy"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.nextcloud_storage.arn,
          "${aws_s3_bucket.nextcloud_storage.arn}/*"
        ]
      }
    ]
  })
}

# Instance Profile : le "lien" entre le rôle IAM et l'EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# ==================================================
# RDS - Base de données MySQL managée
# Avantage vs MySQL sur EC2 : sauvegardes auto, patches, monitoring
# ==================================================

# Subnet Group : indique à RDS dans quels sous-réseaux se déployer
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
  }
}

resource "aws_db_instance" "nextcloud" {
  identifier        = "${var.project_name}-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = 20 # Go
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Sauvegardes automatiques (7 jours de rétention)
  backup_retention_period = 7
  backup_window           = "03:00-04:00" # Heure UTC

  # Mises à jour automatiques mineures
  auto_minor_version_upgrade = true
  maintenance_window         = "Mon:04:00-Mon:05:00"

  # ⚠️ En production : mettre à true et gérer la suppression manuellement
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name    = "${var.project_name}-db"
    Project = var.project_name
  }
}

# ==================================================
# EC2 - Serveur Nextcloud
# ==================================================
resource "aws_instance" "nextcloud" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Script exécuté au premier démarrage de l'instance
  # Installe et configure Nextcloud automatiquement
  user_data = templatefile("${path.module}/userdata.sh", {
    db_host     = aws_db_instance.nextcloud.address
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
    s3_bucket   = aws_s3_bucket.nextcloud_storage.bucket
    aws_region  = var.aws_region
  })

  root_block_device {
    volume_size = 20 # Go pour l'OS et Nextcloud
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "${var.project_name}-server"
    Project = var.project_name
  }

  # S'assure que la BDD est prête avant de lancer l'EC2
  depends_on = [aws_db_instance.nextcloud]
}
