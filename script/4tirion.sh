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

cat >/etc/bind/db.k40.com <<'EOF'
$TTL 3600
$ORIGIN k40.com.
@   IN  SOA ns1.k40.com. admin.k40.com. (
        2025102201  ; serial (Ymdnn) — naikkan tiap edit
        3600        ; refresh
        900         ; retry
        604800      ; expire
        300 )       ; negative TTL
@       IN  NS  ns1.k40.com.
@       IN  NS  ns2.k40.com.
ns1     IN  A   192.231.3.2       ; Tirion
ns2     IN  A   192.231.3.3       ; Valmar
@       IN  A   192.231.3.6       ; Sirion (apex/front door)

; host sesuai glosarium (boleh tambah/ubah sesuai kebutuhanmu)
eonwe    IN  A  192.231.3.1
earendil IN  A  192.231.1.2
elwing   IN  A  192.231.1.3
cirdan   IN  A  192.231.2.2
elrond   IN  A  192.231.2.3
maglor   IN  A  192.231.2.4
lindon   IN  A  192.231.3.4
vingilot IN  A  192.231.3.5
sirion   IN  A  192.231.3.6
EOF
named-checkconf && named-checkzone k40.com /etc/bind/db.k40.com || true && \
pkill named 2>/dev/null || true && \
named -4 -u bind -c /etc/bind/named.conf && \
echo "== SOA ns1 ==" && dig +norecurse @127.0.0.1 k40.com SOA +short || true
