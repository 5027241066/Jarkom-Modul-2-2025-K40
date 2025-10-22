# === nomor 10: Vingilot (web dinamis PHP-FPM) ===
# Hostname: app.k40.com  | Home: / (index.php) | About: /about (rewrite -> about.php)
# Akses wajib via hostname (bukan IP)

set -euo pipefail

# Paksa APT IPv4 (kadang repo IPv6 bermasalah)
echo 'Acquire::ForceIPv4 "true";' >/etc/apt/apt.conf.d/99force-ipv4
apt-get clean; rm -rf /var/lib/apt/lists/*
apt-get update -o Acquire::ForceIPv4=true

# Install stack
apt-get install -y apache2 php php-fpm libapache2-mod-fcgid curl

# Aktifkan modul Apache
a2enmod proxy >/dev/null 2>&1 || true
a2enmod proxy_fcgi setenvif rewrite >/dev/null 2>&1 || true

# Aktifkan conf php-fpm bawaan Debian (jika ada)
a2enconf $(ls /etc/apache2/conf-available/ | grep -E '^php[0-9]+\.[0-9]+-fpm\.conf$' | head -n1) 2>/dev/null || true

# Pastikan PHP-FPM berjalan (tanpa systemctl)
PHP_SOCK="$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n1 || true)"
if [ -z "${PHP_SOCK}" ]; then
  # coba start via skrip init yang tersedia
  PHP_SVC="$(ls /etc/init.d/php*-fpm 2>/dev/null | head -n1 || true)"
  if [ -n "${PHP_SVC}" ]; then
    "${PHP_SVC}" restart || "${PHP_SVC}" start || true
    sleep 1
  else
    # fallback langsung ke binary
    PHP_BIN="$(command -v php-fpm8.3 || command -v php-fpm8.2 || command -v php-fpm8.1 || command -v php-fpm || true)"
    [ -n "${PHP_BIN}" ] && "${PHP_BIN}" -D || true
    sleep 1
  fi
  PHP_SOCK="$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n1 || true)"
fi
if [ -z "${PHP_SOCK}" ]; then
  echo "[ERR] PHP-FPM socket tidak ditemukan. Cek instalasi php-fpm."; exit 1
fi

# Dokumen
mkdir -p /var/www/app.k40.com
cat > /var/www/app.k40.com/index.php <<'EOF'
<!DOCTYPE html><html><head><title>Vingilot - Home</title></head>
<body>
<h1>Selamat datang di Vingilot!</h1>
<p>Ini adalah halaman beranda dari web dinamis.</p>
<p><a href="/about">Tentang Kami</a></p>
</body></html>
EOF
cat > /var/www/app.k40.com/about.php <<'EOF'
<!DOCTYPE html><html><head><title>Tentang Vingilot</title></head>
<body>
<h1>Halaman About</h1>
<p>Ini adalah halaman tentang Vingilot, kapal yang membawa cerita dinamis.</p>
<p><a href="/">Kembali ke beranda</a></p>
</body></html>
EOF

# Rewrite /about -> about.php
cat > /var/www/app.k40.com/.htaccess <<'EOF'
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^about$ about.php [L]
EOF

# VHost: PHP-FPM via socket + enforce hostname
cat > /etc/apache2/sites-available/app.k40.com.conf <<EOF
<VirtualHost *:80>
    ServerName app.k40.com
    DocumentRoot /var/www/app.k40.com

    <Directory /var/www/app.k40.com>
        Options +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Enforce akses via hostname (bukan IP)
    RewriteEngine On
    RewriteCond %{HTTP_HOST} !^app\.k40\.com$ [NC]
    RewriteRule ^ - [F]

    # Pastikan index.php menjadi default directory index
    DirectoryIndex index.php

    # PHP-FPM handler (unix socket)
    <FilesMatch \.php$>
        SetHandler "proxy:unix:${PHP_SOCK}|fcgi://localhost/"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/app_k40_error.log
    CustomLog \${APACHE_LOG_DIR}/app_k40_access.log combined
</VirtualHost>
EOF

a2ensite app.k40.com.conf >/dev/null 2>&1 || true
a2dissite 000-default.conf  >/dev/null 2>&1 || true

# Restart Apache (tanpa systemctl)
service apache2 restart 2>/dev/null || apachectl -k restart

# Tes lokal (pakai Host header, tanpa bergantung DNS)
echo "== Detected PHP-FPM socket: ${PHP_SOCK} =="
curl -I -H 'Host: app.k40.com' http://127.0.0.1/
curl -I -H 'Host: app.k40.com' http://127.0.0.1/about
