# ==================================================
# OUTPUTS - Informations affichées après le déploiement
# Utile pour savoir où se connecter sans chercher dans la console AWS
# ==================================================

output "nextcloud_url" {
  description = "URL d'accès à Nextcloud"
  value       = "http://${aws_instance.nextcloud.public_ip}"
}

output "nextcloud_public_ip" {
  description = "IP publique du serveur Nextcloud"
  value       = aws_instance.nextcloud.public_ip
}

output "ssh_connection" {
  description = "Commande SSH pour se connecter au serveur"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.nextcloud.public_ip}"
}

output "rds_endpoint" {
  description = "Endpoint de la base de données (interne uniquement)"
  value       = aws_db_instance.nextcloud.address
}

output "s3_bucket_name" {
  description = "Nom du bucket S3 utilisé pour le stockage"
  value       = aws_s3_bucket.nextcloud_storage.bucket
}

output "database_info" {
  description = "Informations de connexion à la BDD"
  value = {
    host     = aws_db_instance.nextcloud.address
    port     = aws_db_instance.nextcloud.port
    db_name  = var.db_name
    username = var.db_username
  }
}
