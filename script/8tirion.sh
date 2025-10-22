#!/usr/bin/env bash
# Nomor 8 – Tirion (ns1/master)
# Deklarasi reverse zone 192.231.3.0/24 => 3.231.192.in-addr.arpa
# PTR: 3.4 -> lindon.k40.com., 3.5 -> vingilot.k40.com., 3.6 -> sirion.k40.com.
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

NS2_IP="192.231.3.3"
REV_ZONE="3.231.192.in-addr.arpa"
REV_DIR="/etc/bind/rev"
REV_FILE="${REV_DIR}/${REV_ZONE}"
SERIAL="2025102205"   # GANTI jika perlu bump (format: YYYYMMDDnn)

echo "[ns1] Update & install BIND"
apt update -y
apt install -y bind9 bind9utils dnsutils procps psmisc

echo "[ns1] Minimal include"
cat >/etc/bind/named.conf <<'EOF'
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
EOF

echo "[ns1] Options"
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

echo "[ns1] Zone master reverse (idempotent)"
mkdir -p "${REV_DIR}"
# Tulis block zona (overwrite biar bersih)
cat >/etc/bind/named.conf.local <<EOF
zone "${REV_ZONE}" {
    type master;
    file "${REV_FILE}";
    notify yes;
    also-notify { ${NS2_IP}; };
    allow-transfer { ${NS2_IP}; };
};
EOF

echo "[ns1] File zona reverse"
cat >"${REV_FILE}" <<EOF
\$TTL 3600
@   IN  SOA ns1.k40.com. admin.k40.com. (
        ${SERIAL} ; SERIAL (YYYYMMDDnn) – bump tiap edit
        3600      ; refresh
        900       ; retry
        1209600   ; expire
        300 )     ; negative TTL

@   IN  NS  ns1.k40.com.
@   IN  NS  ns2.k40.com.

; PTR untuk DMZ
4   IN  PTR lindon.k40.com.
5   IN  PTR vingilot.k40.com.
6   IN  PTR sirion.k40.com.
EOF

# Bersihkan CRLF jika ada
sed -i 's/\r$//' /etc/bind/named.conf /etc/bind/named.conf.options /etc/bind/named.conf.local "${REV_FILE}"

echo "[ns1] Validasi & start named (tanpa systemctl)"
named-checkzone "${REV_ZONE}" "${REV_FILE}"
named-checkconf -z

# Stop, bersihkan jurnal, start
pkill named 2>/dev/null || true
rm -f "${REV_FILE}.jnl" /var/cache/bind/${REV_ZONE}*.jnl 2>/dev/null || true
named -4 -u bind -c /etc/bind/named.conf &
sleep 2

echo "== SOA ns1 (reverse) =="
dig @127.0.0.1 ${REV_ZONE} SOA +short

echo "== PTR via ns1 =="
echo -n "3.4 -> "; dig +short @127.0.0.1 -x 192.231.3.4
echo -n "3.5 -> "; dig +short @127.0.0.1 -x 192.231.3.5
echo -n "3.6 -> "; dig +short @127.0.0.1 -x 192.231.3.6

echo "[ns1] Selesai. Pastikan Valmar (ns2) bisa AXFR & SOA sama."
