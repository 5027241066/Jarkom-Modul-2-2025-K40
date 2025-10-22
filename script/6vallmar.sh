#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

# --- Auto install ---
if ! dpkg -s bind9 >/dev/null 2>&1; then
  apt-get update
  apt-get install -y bind9 bind9utils dnsutils
fi

DOMAIN="${1:-k40.com}"
SLAVEFILE="/var/cache/bind/db.${DOMAIN}"
NS1_IP="${NS1_IP:-192.231.3.2}"
NS2_IP="${NS2_IP:-192.231.3.3}"

named_bin="$(command -v named || true)"; [[ -z "$named_bin" ]] && named_bin="/usr/sbin/named"

echo "[ns2] Setup slave zone untuk ${DOMAIN}"

mkdir -p /etc/bind /var/cache/bind
chown -R bind:bind /var/cache/bind

# slave zone
cat >/etc/bind/named.conf.local <<EOF
zone "${DOMAIN}" {
    type slave;
    file "${SLAVEFILE}";
    masters { ${NS1_IP}; };
    allow-notify { ${NS1_IP}; };
};
EOF

# opsi basic
cat >/etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    listen-on { any; };
    listen-on-v6 { any; };
    dnssec-validation no;
    auth-nxdomain no;
};
EOF

# fresh pull
rm -f "${SLAVEFILE}"* 2>/dev/null || true
chown -R bind:bind /var/cache/bind

# checks (opsional)
if command -v named-checkconf >/dev/null 2>&1; then named-checkconf; fi

# reload/start
if command -v rndc >/dev/null 2>&1; then
  rndc reload || { pkill named 2>/dev/null || true; "$named_bin" -4 -u bind -c /etc/bind/named.conf; }
  rndc retransfer "${DOMAIN}" || true
else
  pkill named 2>/dev/null || true
  "$named_bin" -4 -u bind -c /etc/bind/named.conf
fi

if command -v dig >/dev/null 2>&1; then
  echo "[ns2] SOA (ns2):"; dig +norecurse @"${NS2_IP}" "${DOMAIN}" SOA +short || true
fi
