#!/bin/bash
# Script para configurar ambiente standalone do ONLYOFFICE + PHP
# Servidor: 10.10.11.58

BASE_DIR="/var/www/onlyoffice-standalone"
DOC_DIR="$BASE_DIR/arquivos"

echo "[1/5] Criando diretórios..."
sudo mkdir -p "$DOC_DIR"

echo "[2/5] Criando arquivos PHP..."
# index.php
sudo tee "$BASE_DIR/index.php" > /dev/null <<'EOF'
<?php
$dir = __DIR__ . "/arquivos/";
$files = scandir($dir);
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
    <?php foreach ($files as $f): ?>
      <?php if ($f != "." && $f != ".."): ?>
        <li>
          <a href="editor.php?file=<?php echo urlencode($f); ?>">
            <?php echo htmlspecialchars($f); ?>
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
  if ($_FILES) {
      move_uploaded_file($_FILES["upload"]["tmp_name"], $dir . basename($_FILES["upload"]["name"]));
      header("Refresh:0");
  }
  ?>
</body>
</html>
EOF

# editor.php
sudo tee "$BASE_DIR/editor.php" > /dev/null <<'EOF'
<?php
$file = $_GET["file"] ?? "";
$path = __DIR__ . "/arquivos/" . basename($file);
$url = "http://10.10.11.58/onlyoffice-standalone/arquivos/" . rawurlencode($file);
$key = md5($file . filemtime($path));

$ext = pathinfo($file, PATHINFO_EXTENSION);
$docType = "word";
if (in_array($ext, ["xls", "xlsx"])) $docType = "cell";
if (in_array($ext, ["ppt", "pptx"])) $docType = "slide";
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <script src="http://10.10.11.58/web-apps/apps/api/documents/api.js"></script>
</head>
<body>
  <div id="placeholder" style="width:100%; height:90vh;"></div>
  <script>
    var docEditor = new DocsAPI.DocEditor("placeholder", {
      document: {
        fileType: "<?php echo $ext; ?>",
        key: "<?php echo $key; ?>",
        title: "<?php echo $file; ?>",
        url: "<?php echo $url; ?>"
      },
      documentType: "<?php echo $docType; ?>",
      editorConfig: {
        callbackUrl: "http://10.10.11.58/onlyoffice-standalone/save.php?file=<?php echo urlencode($file); ?>"
      }
    });
  </script>
</body>
</html>
EOF

# save.php
sudo tee "$BASE_DIR/save.php" > /dev/null <<'EOF'
<?php
$file = $_GET["file"] ?? "";
$path = __DIR__ . "/arquivos/" . basename($file);

$data = json_decode(file_get_contents("php://input"), true);

if ($data["status"] == 2) {
    $url = $data["url"];
    $content = file_get_contents($url);
    file_put_contents($path, $content);
}

echo json_encode(["error" => 0]);
EOF

echo "[3/5] Ajustando permissões..."
sudo chown -R www-data:www-data "$BASE_DIR"
sudo chmod -R 777 "$DOC_DIR"

echo "[4/5] Criando alias Apache..."
CONF_FILE="/etc/apache2/sites-available/onlyoffice-standalone.conf"
sudo tee "$CONF_FILE" > /dev/null <<EOF
Alias /onlyoffice-standalone $BASE_DIR

<Directory $BASE_DIR>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF

echo "[5/5] Ativando site no Apache..."
sudo a2ensite onlyoffice-standalone.conf
sudo systemctl reload apache2

echo "========================================================"
echo "Instalação concluída!"
echo "Acesse: http://10.10.11.58/onlyoffice-standalone/"
echo "========================================================"
