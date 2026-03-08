variable "aws_region" {
  description = "Région AWS utilisée"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Nom du projet (utilisé pour nommer les ressources)"
  type        = string
  default     = "nextcloud-bts"
}

# --- Réseau ---
variable "vpc_cidr" {
  description = "Plage d'adresses IP du réseau privé virtuel"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Sous-réseau public (EC2 accessible depuis Internet)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr_1" {
  description = "Sous-réseau privé 1 (RDS - pas accessible depuis Internet)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr_2" {
  description = "Sous-réseau privé 2 (RDS exige 2 AZ minimum)"
  type        = string
  default     = "10.0.3.0/24"
}

# --- EC2 ---
variable "instance_type" {
  description = "Type d'instance EC2 (taille/puissance du serveur)"
  type        = string
  default     = "t3.small" # 2 vCPU, 2Go RAM
}

variable "ami_id" {
  description = "Image système (Amazon Linux 2023)"
  type        = string
  default     = "ami-00575c0cbc20caf50" # Amazon Linux 2023 - eu-west-3
}

variable "key_pair_name" {
  description = "Nom de la clé SSH (à créer dans la console AWS)"
  type        = string
  default     = "nextcloud-key"
}

# --- RDS ---
variable "db_name" {
  description = "Nom de la base de données Nextcloud"
  type        = string
  default     = "nextcloud"
}

variable "db_username" {
  description = "Utilisateur de la base de données"
  type        = string
  default     = "nextcloud_user"
}

variable "db_password" {
  description = "Mot de passe BDD - NE PAS mettre en dur en production !"
  type        = string
  sensitive   = true # Pour masquer le mot de passe dans les logs et outputs
  default     = "ChangeMe123!" 
}

variable "db_instance_class" {
  description = "Type d'instance RDS"
  type        = string
  default     = "db.t3.micro"
}
