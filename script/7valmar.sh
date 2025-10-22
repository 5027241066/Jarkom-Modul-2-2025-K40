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
    type slave;
    masters { 192.231.3.2; };            // Tirion (ns1)
    file "/var/cache/bind/db.k40.com";   // salinan zona ditulis di sini
    allow-notify { 192.231.3.2; };       // terima NOTIFY dari ns1
};
EOF

# hapus salinan lama, start named, lalu cek
rm -f /var/cache/bind/db.k40.com* /var/cache/bind/k40.com*.jnl 2>/dev/null || true
named-checkconf || true
pkill named 2>/dev/null || true
named -4 -u bind -c /etc/bind/named.conf
sleep 2

echo "== File zona slave ==" && ls -l /var/cache/bind | grep db.k40.com || echo "(belum ada: cek allow-transfer/notify di ns1 & port 53/TCP+UDP)"

echo "== SOA ns1 vs ns2 =="
echo -n "ns1: " && dig +norecurse @192.231.3.2 k40.com SOA +short
echo -n "ns2: " && dig +norecurse @192.231.3.3 k40.com SOA +short

echo "== A & CNAME via ns2 (harus konsisten dengan ns1) =="
echo -n "apex:   " && dig +short @192.231.3.3 k40.com A
echo -n "sirion: " && dig +short @192.231.3.3 sirion.k40.com A
echo -n "lindon: " && dig +short @192.231.3.3 lindon.k40.com A
echo -n "vingilot: " && dig +short @192.231.3.3 vingilot.k40.com A
echo -n "www:    " && dig +short @192.231.3.3 www.k40.com A
echo -n "static: " && dig +short @192.231.3.3 static.k40.com A
echo -n "app:    " && dig +short @192.231.3.3 app.k40.com A
