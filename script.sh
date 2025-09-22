#!/bin/bash

# ========================================
# Script de instalação OnlyOffice Standalone (Nginx)
# ========================================

DOMAIN="officemafra.sc.gov.br"
DOCROOT="/var/www/onlyoffice-standalone"

echo "[1/5] Criando diretórios..."
mkdir -p $DOCROOT
chown -R www-data:www-data $DOCROOT

echo "[2/5] Criando arquivos PHP..."
cat <<EOF > $DOCROOT/index.php
<?php
echo "<h1>OnlyOffice Standalone</h1>";
echo "<p>Servidor disponível em: http://$DOMAIN/</p>";
?>
EOF

echo "[3/5] Instalando dependências..."
apt update -y
apt install -y nginx php-cli php-fpm

echo "[4/5] Criando configuração Nginx..."
cat <<EOF > /etc/nginx/sites-available/onlyoffice-standalone
server {
    listen 80;
    server_name $DOMAIN;

    root $DOCROOT;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

ln -sf /etc/nginx/sites-available/onlyoffice-standalone /etc/nginx/sites-enabled/

echo "[5/5] Testando configuração e reiniciando Nginx..."
nginx -t && systemctl restart nginx

echo "========================================================"
echo "Instalação concluída!"
echo "Acesse: http://$DOMAIN/"
echo "========================================================"
