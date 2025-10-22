#!/usr/bin/env bash
# Reverse zone slave: 3.231.192.in-addr.arpa
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y bind9 bind9utils dnsutils

REV_ZONE="3.231.192.in-addr.arpa"
NS1_IP="192.231.3.2"
SLAVE_DIR="/var/lib/bind"                         # Debian menyimpan slave di sini
SLAVE_FILE="${SLAVE_DIR}/${REV_ZONE}"

mkdir -p "${SLAVE_DIR}"
chown -R bind:bind "${SLAVE_DIR}"

# Tambah definisi zona slave (idempotent)
grep -q "${REV_ZONE}" /etc/bind/named.conf.local || cat >>/etc/bind/named.conf.local <<EOF

zone "${REV_ZONE}" {
    type slave;
    masters { ${NS1_IP}; };
    file "${SLAVE_FILE}";
    allow-notify { ${NS1_IP}; };
};
EOF

# Bersihkan salinan lama agar AXFR segar
rm -f "${SLAVE_FILE}"* 2>/dev/null || true
chown -R bind:bind "${SLAVE_DIR}"

named-checkconf

# Start/reload tanpa systemctl
pkill named 2>/dev/null || true
named -4 -u bind -c /etc/bind/named.conf
sleep 2

# Paksa retransfer jika tersedia
if command -v rndc >/dev/null 2>&1; then
  rndc retransfer "${REV_ZONE}" || true
  sleep 1
fi

# Verifikasi
echo "== Lokasi file slave (Debian) =="
ls -l "${SLAVE_DIR}" | grep "${REV_ZONE}" || echo "(Belum terlihat? Jika authoritative sudah aa, file bisa berada sebagai journal. Lanjut cek SOA/PTR.)"

echo "== SOA (ns2) =="
dig @127.0.0.1 ${REV_ZONE} SOA +cmd

echo "== PTR via ns2 =="
dig @127.0.0.1 -x 192.231.3.4 +short
dig @127.0.0.1 -x 192.231.3.5 +short
dig @127.0.0.1 -x 192.231.3.6 +short
