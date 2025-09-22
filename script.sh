#!/bin/bash

# ========================================
# Setup OnlyOffice Standalone (Nginx)
# Endereço padrão: 10.10.11.58
# ========================================

IP="10.10.11.58"
DOCROOT="/var/www/onlyoffice-standalone"
DOCS="$DOCROOT/arquivos"

echo "[1/6] Criando diretórios..."
mkdir -p "$DOCS"
chown -R www-data:www-data "$DOCROOT"
chmod -R 777 "$DOCS"

echo "[2/6] Criando arquivos PHP..."

# index.php
cat <<EOF > $DOCROOT/index.php
<?php
\$dir = __DIR__ . "/arquivos/";
\$files = scandir(\$dir);
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>ONLYOFFICE Standalone</title>
</head>
<body>
  <h2>Meus Documentos</h2>
  <ul>
    <?php foreach (\$files as \$f): ?>
      <?php if (\$f != "." && \$f != ".."): ?>
        <li>
          <a href="editor.php?file=<?php echo urlencode(\$f); ?>">
            <?php echo htmlspecialchars(\$f); ?>
          </a>
        </li>
      <?php endif; ?>
    <?php endforeach; ?>
  </ul>
  <form method="post" enctype="multipart/form-data" action="">
    <input type="file" name="upload">
    <button type="submit">Enviar</button>
  </form>
  <?php
  if (\$_FILES) {
      move_uploaded_file(\$_FILES["upload"]["tmp_name"], \$dir . basename(\$_FILES["upload"]["name"]));
      header("Refresh:0");
  }
  ?>
</body>
</html>
EOF

# editor.php
cat <<EOF > $DOCROOT/editor.php
<?php
\$file = \$_GET["file"] ?? "";
\$path = __DIR__ . "/arquivos/" . basename(\$file);
\$url = "http://$IP/onlyoffice-standalone/arquivos/" . rawurlencode(\$file);
\$key = md5(\$file . filemtime(\$path));

\$ext = pathinfo(\$file, PATHINFO_EXTENSION);
\$docType = "word";
if (in_array(\$ext, ["xls", "xlsx"])) \$docType = "cell";
if (in_array(\$ext, ["ppt", "pptx"])) \$docType = "slide";
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <script src="http://$IP/web-apps/apps/api/documents/api.js"></script>
</head>
<body>
  <div id="placeholder" style="width:100%; height:90vh;"></div>
  <script>
    var docEditor = new DocsAPI.DocEditor("placeholder", {
      document: {
        fileType: "<?php echo \$ext; ?>",
        key: "<?php echo \$key; ?>",
        title: "<?php echo \$file; ?>",
        url: "<?php echo \$url; ?>"
      },
      documentType: "<?php echo \$docType; ?>",
      editorConfig: {
        callbackUrl: "http://$IP/onlyoffice-standalone/save.php?file=<?php echo urlencode(\$file); ?>"
      }
    });
  </script>
</body>
</html>
EOF

# save.php
cat <<EOF > $DOCROOT/save.php
<?php
\$file = \$_GET["file"] ?? "";
\$path = __DIR__ . "/arquivos/" . basename(\$file);

\$data = json_decode(file_get_contents("php://input"), true);

if (\$data["status"] == 2) {
    \$url = \$data["url"];
    \$content = file_get_contents(\$url);
    file_put_contents(\$path, \$content);
}

echo json_encode(["error" => 0]);
EOF

echo "[3/6] Instalando dependências..."
apt update -y
apt install -y nginx php-cli php-fpm unzip curl

echo "[4/6] Criando configuração Nginx..."
cat <<EOF > /etc/nginx/sites-available/onlyoffice-standalone
server {
    listen 80;
    server_name $IP;

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

echo "[5/6] Testando configuração Nginx..."
nginx -t

echo "[6/6] Reiniciando Nginx..."
systemctl restart nginx
systemctl enable nginx

echo "========================================================"
echo "OnlyOffice Standalone instalado!"
echo "Acesse: http://$IP/onlyoffice-standalone/"
echo "========================================================"
