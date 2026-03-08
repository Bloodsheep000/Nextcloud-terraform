#!/bin/bash
# ==================================================
# USER DATA - Script d'installation automatique
# Execute une seule fois au premier demarrage de l'EC2
# Les variables $${...} sont injectees par Terraform (templatefile)
# ==================================================

exec > /var/log/userdata.log 2>&1
set -e

echo "=== Debut de l'installation Nextcloud ==="

# --- Mise a jour du systeme ---
dnf update -y

# --- Installation des dependances ---
dnf install -y \
  httpd \
  php8.4 \
  php8.4-mysqlnd \
  php8.4-gd \
  php8.4-xml \
  php8.4-mbstring \
  php8.4-zip \
  php8.4-intl \
  php8.4-bcmath \
  php8.4-gmp \
  php8.4-opcache \
  mariadb105 \
  wget \
  unzip

# --- Téléchargement de Nextcloud ---
echo "=== Telechargement de Nextcloud ==="
wget -q https://download.nextcloud.com/server/releases/latest.zip -O /tmp/nextcloud.zip
unzip -q /tmp/nextcloud.zip -d /var/www/html/
chown -R apache:apache /var/www/html/nextcloud
chmod -R 755 /var/www/html/nextcloud

# --- Configuration Apache ---
cat > /etc/httpd/conf.d/nextcloud.conf << 'EOF'
<VirtualHost *:80>
    DocumentRoot /var/www/html/nextcloud
    ServerName localhost

    <Directory /var/www/html/nextcloud>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted

        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>

    ErrorLog /var/log/httpd/nextcloud_error.log
    CustomLog /var/log/httpd/nextcloud_access.log combined
</VirtualHost>
EOF

# --- Configuration PHP optimisee pour Nextcloud ---
cat > /etc/php.d/nextcloud.ini << 'EOF'
memory_limit = 512M
upload_max_filesize = 512M
post_max_size = 512M
max_execution_time = 300
date.timezone = Europe/Paris
opcache.enable = 1
opcache.memory_consumption = 128
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 1
EOF

# --- Installation automatique de Nextcloud ---
echo "=== Installation de Nextcloud ==="
cd /var/www/html/nextcloud

sudo -u apache php occ maintenance:install \
  --database      "mysql" \
  --database-host "${db_host}" \
  --database-name "${db_name}" \
  --database-user "${db_user}" \
  --database-pass "${db_password}" \
  --admin-user    "admin" \
  --admin-pass    "NextcloudAdmin123!" \
  --data-dir      "/var/www/html/nextcloud/data"

# --- Configuration du stockage S3 ---
echo "=== Configuration du stockage S3 ==="
sudo -u apache php occ config:system:set \
  objectstore class \
  --value='\OC\Files\ObjectStore\S3'

sudo -u apache php occ config:system:set \
  objectstore arguments bucket \
  --value="${s3_bucket}"

sudo -u apache php occ config:system:set \
  objectstore arguments region \
  --value="${aws_region}"

sudo -u apache php occ config:system:set \
  objectstore arguments use_ssl \
  --value=true \
  --type=boolean

sudo -u apache php occ config:system:set \
  objectstore arguments use_path_style \
  --value=false \
  --type=boolean

# Utilise le role IAM de l'instance (pas besoin de cles AWS en dur !)
sudo -u apache php occ config:system:set \
  objectstore arguments use_instance_credentials \
  --value=true \
  --type=boolean

# --- Demarrage et activation des services ---
systemctl enable httpd
systemctl start httpd

echo "=== Installation terminee ! ==="
echo "Nextcloud accessible sur http://$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

# --- Configuration des trusted_domains ---
sudo -u apache php /var/www/nextcloud/occ config:system:set \
  trusted_domains 0 \
  --value="localhost"

sudo -u apache php /var/www/nextcloud/occ config:system:set \
  trusted_domains 1 \
  --value="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

sudo -u apache php /var/www/nextcloud/occ config:system:set \
  trusted_domains 2 \
  --value="$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)"

