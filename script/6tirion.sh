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
ZONEFILE="/etc/bind/db.${DOMAIN}"
NS1_HOST="${NS1_HOST:-ns1}"
NS2_HOST="${NS2_HOST:-ns2}"
NS1_IP="${NS1_IP:-192.231.3.2}"
NS2_IP="${NS2_IP:-192.231.3.3}"
FORWARDER="${FORWARDER:-192.168.122.1}"

TODAY="$(date +%Y%m%d)"
SERIAL="${TODAY}03"   # paksa …03

named_bin="$(command -v named || true)"; [[ -z "$named_bin" ]] && named_bin="/usr/sbin/named"

echo "[ns1] Setup master zone untuk ${DOMAIN} (serial ${SERIAL})"

mkdir -p /etc/bind /var/cache/bind

# options
cat >/etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    listen-on { any; };
    listen-on-v6 { any; };
    dnssec-validation no;
    forwarders { ${FORWARDER}; };
    auth-nxdomain no;
};
EOF

# master zone
cat >/etc/bind/named.conf.local <<EOF
zone "${DOMAIN}" {
    type master;
    file "${ZONEFILE}";
    notify yes;
    also-notify { ${NS2_IP}; };
    allow-transfer { ${NS2_IP}; };
};
EOF

# zone file (buat jika belum ada)
if [[ ! -f "${ZONEFILE}" ]]; then
cat >"${ZONEFILE}" <<ZONE
\$TTL 3600
\$ORIGIN ${DOMAIN}.
@   IN  SOA ${NS1_HOST}.${DOMAIN}. admin.${DOMAIN}. (
        ${SERIAL} ; SERIAL
        3600      ; refresh
        900       ; retry
        1209600   ; expire
        300 )     ; minimum
    IN  NS  ${NS1_HOST}.${DOMAIN}.
    IN  NS  ${NS2_HOST}.${DOMAIN}.

${NS1_HOST} IN  A   ${NS1_IP}
${NS2_HOST} IN  A   ${NS2_IP}
ZONE
else
  # bump SERIAL jadi YYYYMMDD02 (tanpa perl)
  awk -v serial="$SERIAL" '
    BEGIN{done=0; sawSOA=0}
    /IN[ \t]+SOA/ {sawSOA=1}
    {
      if (sawSOA && !done) {
        if (sub(/[0-9]{10}/, serial)) { done=1; sawSOA=0 }
      }
      print
    }
  ' "$ZONEFILE" > "${ZONEFILE}.tmp" && mv "${ZONEFILE}.tmp" "$ZONEFILE"
fi

# checks (opsional)
if command -v named-checkconf >/dev/null 2>&1; then named-checkconf; fi
if command -v named-checkzone >/dev/null 2>&1; then named-checkzone "${DOMAIN}" "${ZONEFILE}"; fi

# reload/start
if command -v rndc >/dev/null 2>&1; then
  rndc reload || true
else
  pkill named 2>/dev/null || true
  "$named_bin" -4 -u bind -c /etc/bind/named.conf
fi

if command -v dig >/dev/null 2>&1; then
  echo "[ns1] SOA (ns1):"; dig +norecurse @"${NS1_IP}" "${DOMAIN}" SOA +short || true
fi
