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
    file "/var/cache/bind/db.k40.com";   // salinan zona akan ditulis di sini
    allow-notify { 192.231.3.2; };
};
EOF
named-checkconf || true && \
pkill named 2>/dev/null || true && \
named -4 -u bind -c /etc/bind/named.conf && \
sleep 2 && \
echo "== Cek file zona slave ==" && ls -l /var/cache/bind | grep db.k40.com || echo "(belum ada: pastikan ns1 allow-transfer/notify & konektivitas TCP/UDP 53)" && \
echo "== SOA ns1 vs ns2 ==" && dig +norecurse @192.231.3.2 k40.com SOA +short && dig +norecurse @192.231.3.3 k40.com SOA +short
