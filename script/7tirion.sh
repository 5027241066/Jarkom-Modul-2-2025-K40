apt update && apt install -y bind9 bind9utils dnsutils && \
mkdir -p /etc/bind /var/cache/bind && chown -R bind:bind /var/cache/bind && \

cat >/etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { any; };
    allow-query { any; };

    forwarders { 192.168.122.1; };
    recursion yes;
    dnssec-validation no;
};
EOF

cat >/etc/bind/named.conf.local <<'EOF'
zone "k40.com" {
    type master;
    file "/etc/bind/db.k40.com";
    notify yes;
    also-notify { 192.231.3.3; };     // Valmar (ns2)
    allow-transfer { 192.231.3.3; };  // izinkan ns2 tarik zona
};
EOF

cat >/etc/bind/db.k40.com <<'ZONE'
$TTL 3600
$ORIGIN k40.com.
@   IN  SOA ns1.k40.com. admin.k40.com. (
        2025102204  ; serial (Ymdnn) — naikkan setiap edit!
        3600        ; refresh
        900         ; retry
        604800      ; expire
        300 )       ; negative TTL

; NS authoritative
@       IN  NS  ns1.k40.com.
@       IN  NS  ns2.k40.com.

; Glue A untuk NS
ns1     IN  A   192.231.3.2
ns2     IN  A   192.231.3.3

; Apex (front door)
@       IN  A   192.231.3.6    ; Sirion

; Host layanan
sirion   IN  A  192.231.3.6
lindon   IN  A  192.231.3.4
vingilot IN  A  192.231.3.5

; CNAME
www      IN  CNAME  sirion.k40.com.
static   IN  CNAME  lindon.k40.com.
app      IN  CNAME  vingilot.k40.com.
ZONE

# bersihkan CRLF/BOM jika ada, validasi & jalankan named
sed -i "s/\r$//" /etc/bind/db.k40.com 2>/dev/null || true
sed -i "1s/^\xEF\xBB\xBF//" /etc/bind/db.k40.com 2>/dev/null || true
named-checkconf && named-checkzone k40.com /etc/bind/db.k40.com && \
pkill named 2>/dev/null || true && named -4 -u bind -c /etc/bind/named.conf && \
sleep 1 && \
echo "== SOA ns1 ==" && dig +norecurse @127.0.0.1 k40.com SOA +short && \
echo "== A & CNAME (harus resolve ke IP target) ==" && \
echo -n "apex:   " && dig +short @127.0.0.1 k40.com A && \
echo -n "sirion: " && dig +short @127.0.0.1 sirion.k40.com A && \
echo -n "lindon: " && dig +short @127.0.0.1 lindon.k40.com A && \
echo -n "vingilot: " && dig +short @127.0.0.1 vingilot.k40.com A && \
echo -n "www:    " && dig +short @127.0.0.1 www.k40.com A && \
echo -n "static: " && dig +short @127.0.0.1 static.k40.com A && \
echo -n "app:    " && dig +short @127.0.0.1 app.k40.com A
