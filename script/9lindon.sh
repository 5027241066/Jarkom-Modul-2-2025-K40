# setup_lindon_static_k40.sh — Web statis di Lindon (192.231.3.4) untuk nomor 9
apt update && apt install -y apache2 curl >/dev/null

# Siapkan dokumen
mkdir -p /var/www/static.k40.com/annals
# contoh berkas isi (bukan index.html) agar listing tampil
echo "Catatan kuno pertama" > /var/www/static.k40.com/annals/catatan1.txt
echo "Catatan kuno kedua"   > /var/www/static.k40.com/annals/catatan2.txt
# JANGAN bikin index.html di /annals kalau mau autoindex muncul
rm -f /var/www/static.k40.com/annals/index.html 2>/dev/null || true

chown -R www-data:www-data /var/www/static.k40.com

# Aktifkan modul yang dibutuhkan
a2enmod autoindex >/dev/null 2>&1 || true
a2enmod rewrite   >/dev/null 2>&1 || true

# Vhost
cat >/etc/apache2/sites-available/static.k40.com.conf <<'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@static.k40.com
    ServerName  static.k40.com
    ServerAlias lindon.k40.com
    DocumentRoot /var/www/static.k40.com

    # Wajib: /annals menampilkan listing direktori
    <Directory /var/www/static.k40.com/annals>
        Options +Indexes
        AllowOverride None
        Require all granted
        # (opsional) tampilkan listing yg lebih rapi
        IndexOptions FancyIndexing FoldersFirst NameWidth=* SuppressDescription
    </Directory>

    # Wajib: akses hanya via hostname (bukan IP / host lain)
    RewriteEngine On
    RewriteCond %{HTTP_HOST} !^static\.k40\.com$ [NC]
    RewriteCond %{HTTP_HOST} !^lindon\.k40\.com$ [NC]
    RewriteRule ^ - [F]   # 403 Forbidden jika bukan host yg diizinkan

    ErrorLog ${APACHE_LOG_DIR}/static_k40_error.log
    CustomLog ${APACHE_LOG_DIR}/static_k40_access.log combined
</VirtualHost>
EOF

a2ensite static.k40.com.conf >/dev/null 2>&1 || true
a2dissite 000-default.conf   >/dev/null 2>&1 || true

# Restart Apache (tanpa systemctl)
service apache2 restart 2>/dev/null || apachectl -k restart

# (Opsional) set resolver di host ini agar nama host lab resolve via ns1/ns2
cat >/etc/resolv.conf <<'DNS'
nameserver 192.231.3.2
nameserver 192.231.3.3
nameserver 192.168.122.1
DNS

# Tes: harus 200 OK dan menampilkan autoindex (Bukan 404/403)
echo "== HTTP HEAD static.k40.com/annals/ =="
curl -I http://static.k40.com/annals/ || true

#Tes lain
curl -I http://static.k40.com/annals/
curl    http://static.k40.com/annals/   # harus tampil listing file
