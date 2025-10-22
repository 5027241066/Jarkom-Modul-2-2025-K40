# Modul-2-2025-K40
## Anggota Kelompok

| No | Nama                   | NRP         |
|----|------------------------|-------------|
| 1  | Ahmad Yafi Ar Rizq | 5027241066  |
| 2  | Mohammad Abyan Ranuaji     | 5027241106  |

## Soal 1

<img width="691" height="566" alt="Screenshot 2025-10-12 232433" src="https://github.com/user-attachments/assets/2b9eeb85-a5bf-4fae-8dd8-202fbb3f7e3f" />

## Soal 2

Aktifkan IP forwarding, terapkan NAT/MASQUERADE pada eth0 (WAN), dan buka kebijakan FORWARD untuk trafik LAN→WAN dan return path.
Pada Eonwe masukkan code berikut untuk menyalakan IP forwarding dan menyalakan NAT
```
apt update
apt install iptables

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -t nat -F POSTROUTING
iptables -F FORWARD

iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth2 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth3 -o eth0 -j ACCEPT

iptables -A FORWARD -i eth1 -o eth2 -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -j ACCEPT
iptables -A FORWARD -i eth1 -o eth3 -j ACCEPT
iptables -A FORWARD -i eth3 -o eth1 -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -j ACCEPT
iptables -A FORWARD -i eth3 -o eth2 -j ACCEPT

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

cat >/etc/rc.local <<'EOF'
#!/bin/sh
echo 1 > /proc/sys/net/ipv4/ip_forward
[ -f /etc/iptables/rules.v4 ] && iptables-restore < /etc/iptables/rules.v4 || {
  iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
  iptables -A FORWARD -i eth2 -o eth0 -j ACCEPT
  iptables -A FORWARD -i eth3 -o eth0 -j ACCEPT
  iptables -A FORWARD -i eth1 -o eth2 -j ACCEPT
  iptables -A FORWARD -i eth2 -o eth1 -j ACCEPT
  iptables -A FORWARD -i eth1 -o eth3 -j ACCEPT
  iptables -A FORWARD -i eth3 -o eth1 -j ACCEPT
  iptables -A FORWARD -i eth2 -o eth3 -j ACCEPT
  iptables -A FORWARD -i eth3 -o eth2 -j ACCEPT
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
}
exit 0
EOF
```

Pada client lainnya masukkan code berikut untuk membuat mereka dapat mengakses internet luar
```
cat >/etc/resolv.conf << "DNS"
nameserver 192.231.3.2   # ns1 (Tirion)
nameserver 192.231.3.3   # ns2 (Valmar)
nameserver 192.168.122.1 # fallback
DNS

cat >/etc/rc.local << "EOF"
#!/bin/sh
cat >/etc/resolv.conf <<DNS
nameserver 192.231.3.2
nameserver 192.231.3.3
nameserver 192.168.122.1
DNS
exit 0
EOF
```

Tes ping keluar client

<img width="1052" height="570" alt="image" src="https://github.com/user-attachments/assets/cc87ac30-9454-473f-b0a0-d97042fe38cc" />

## Soal 3
Set default gateway klien sesuai segmen (192.231.1.1/2.1/3.1). Tulis /etc/resolv.conf awal ke 192.168.122.1 dan buat persisten saat boot.
Pada tiap client input command 

`
echo "nameserver 192.168.122.1" > /etc/resolv.conf
`

<img width="964" height="60" alt="image" src="https://github.com/user-attachments/assets/d871806d-823e-4c28-af34-f64fd030ed21" />

## Soal 4
ns1: Deklarasi zona master berisi SOA, NS, A apex (→ Sirion), A ns1 & A ns2, aktifkan notify/transfer, set forwarders.
ns2: Deklarasi zona slave yang menarik dari ns1 dan menyimpan salinan di cache.

Unruk mengonfigurasi server DNS di file /etc/resolv.conf pada client paste command
```
cat >/etc/resolv.conf <<'DNS'
nameserver 192.231.3.2   # ns1 (Tirion)
nameserver 192.231.3.3   # ns2 (Valmar)
nameserver 192.168.122.1 # fallback
DNS
cat >/etc/rc.local <<'EOF'
#!/bin/sh
cat >/etc/resolv.conf <<DNS
nameserver 192.231.3.2
nameserver 192.231.3.3
nameserver 192.168.122.1
DNS
exit 0
EOF
chmod +x /etc/rc.local && echo "resolv.conf & rc.local set"
```

Kemudian untuk mengaktifkan pada ns1/Tirion gunakan command berikut
```
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
        2025101301  ; serial (Ymdnn) — naikkan tiap edit
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
```

<img width="837" height="125" alt="image" src="https://github.com/user-attachments/assets/3c7d26e9-95be-4d73-8ea6-e5ed5e9bf126" />

Kemudian pada Velmar masukan code berikut untuk transfer
```
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
```

<img width="846" height="178" alt="image" src="https://github.com/user-attachments/assets/94bcf1de-cd08-47c3-9e0f-e4b226c684e5" />

## Soal 5
Set /etc/hostname di masing-masing host (eonwe, earendil, elwing, cirdan, elrond, maglor, lindon, vingilot, sirion). Pada ns1, tambahkan A record sesuai nama-nama tersebut. Node DNS direpresentasikan sebagai ns1.k40.com & ns2.k40.com (bukan tirion/valmar).

Pada client selain ns1 & ns2 masukkan code berikut
```
#!/usr/bin/env bash

# Write /etc/hosts with FQDN and shortname (plus localhost conventions)
cat >/etc/hosts <<'EOF'
127.0.0.1   localhost
127.0.1.1   [client].k40.com [client]
192.231.2.2 [client].k40.com [client]
EOF

# Preferred resolver order: ns1 -> ns2 -> NAT forwarder
cat >/etc/resolv.conf <<'DNS'
nameserver 192.231.3.2   # ns1.k40.com (Tirion)
nameserver 192.231.3.3   # ns2.k40.com (Valmar)
nameserver 192.168.122.1 # fallback
DNS

# Persist resolv.conf across reboots on minimal nodes
cat >/etc/rc.local <<'RC'
#!/bin/sh
cat >/etc/resolv.conf <<DNS
nameserver 192.231.3.2
nameserver 192.231.3.3
nameserver 192.168.122.1
DNS
exit 0
RC

# Quick verification
echo "Hostname now:"
hostname
echo "Hosts lookup for this node:"
getent hosts [client].k40.com || true
```

<img width="662" height="291" alt="image" src="https://github.com/user-attachments/assets/c2eda04f-7f1d-49d7-a76f-1f2eea096178" />

Kemudian pada ns1 (Tirion) masukkan sebagai berikut:
1. Setup
```
#!/usr/bin/env bash
# Write /etc/hosts with FQDN and shortname (plus localhost conventions)
cat >/etc/hosts <<'EOF'
127.0.0.1   localhost
127.0.1.1   ns1.k40.com tirion
192.231.3.2 ns1.k40.com tirion
EOF

# Preferred resolver order: ns1 -> ns2 -> NAT forwarder
cat >/etc/resolv.conf <<'DNS'
nameserver 192.231.3.2   # ns1.k40.com (Tirion)
nameserver 192.231.3.3   # ns2.k40.com (Valmar)
nameserver 192.168.122.1 # fallback
DNS

# Persist resolv.conf across reboots on minimal nodes
cat >/etc/rc.local <<'RC'
#!/bin/sh
cat >/etc/resolv.conf <<DNS
nameserver 192.231.3.2
nameserver 192.231.3.3
nameserver 192.168.122.1
DNS
exit 0
RC

# Quick verification
echo "Hostname now:"
hostname
echo "Hosts lookup for this node:"
getent hosts ns1.k40.com || true
```

2. Memperbarui file zona DNS pada server Tirion dengan menambahkan beberapa A records (hostname dan alamat IP). Script berikut ini juga membuat cadangan file zona sebelum melakukan perubahan, meminta pengguna untuk memperbarui serial SOA dalam file zona, dan memuat ulang server DNS (BIND) agar perubahan tersebut diterapkan. Append Zone.
```
#!/usr/bin/env bash
# Append A records to master zone on Tirion (ns1) and bump serial manually.
# Use only on Tirion where /etc/bind/db.k40.com exists.
set -euo pipefail
ZFILE="/etc/bind/db.k40.com"

cp -a "$ZFILE" "$ZFILE.bak.$(date +%s)"

cat <<'EOF' >> "$ZFILE"
; === Hostnames (A) glosarium ===
eonwe    IN  A  192.231.3.1
earendil IN  A  192.231.1.2
elwing   IN  A  192.231.1.3
cirdan   IN  A  192.231.2.2
elrond   IN  A  192.231.2.3
maglor   IN  A  192.231.2.4
sirion   IN  A  192.231.3.6
lindon   IN  A  192.231.3.4
vingilot IN  A  192.231.3.5
EOF

echo "Please bump the SOA serial in $ZFILE, then reload:"
echo "  named-checkzone k40.com $ZFILE && pkill named 2>/dev/null || true; named -4 -u bind -c /etc/bind/named.conf"
```

Kemudian pada ns2 (Valmar) masukkan code berikut:
```
#!/usr/bin/env bash

# Write /etc/hosts with FQDN and shortname (plus localhost conventions)
cat >/etc/hosts <<'EOF'
127.0.0.1   localhost
127.0.1.1   ns2.k40.com valmar
192.231.3.3 ns2.k40.com valmar
EOF

# Preferred resolver order: ns1 -> ns2 -> NAT forwarder
cat >/etc/resolv.conf <<'DNS'
nameserver 192.231.3.2   # ns1.k40.com (Tirion)
nameserver 192.231.3.3   # ns2.k40.com (Valmar)
nameserver 192.168.122.1 # fallback
DNS

# Persist resolv.conf across reboots on minimal nodes
cat >/etc/rc.local <<'RC'
#!/bin/sh
cat >/etc/resolv.conf <<DNS
nameserver 192.231.3.2
nameserver 192.231.3.3
nameserver 192.168.122.1
DNS
exit 0
RC

# Quick verification
echo "Hostname now:"
hostname
echo "Hosts lookup for this node:"
getent hosts ns2.k40.com || true

```
## Soal 6
Naikkan serial SOA di ns1 setiap perubahan dan paksa ns2 melakukan retransfer bila belum sinkron.

Pada tirion masukkan script berikut
```
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
```

<img width="910" height="183" alt="image" src="https://github.com/user-attachments/assets/312237a7-7d06-4426-8b86-aa9d165ec7fb" />

Kemudian pada velmar masukkan script berikut untuk menyiapkan server DNS slave (Valmar ns2), datanya disalin dari server master Tirion (ns1) dengan IP 192.231.3.2. DNS slave bertugas sebagai backup server DNS.
```
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
```

<img width="901" height="115" alt="image" src="https://github.com/user-attachments/assets/31ce16bd-8993-4597-9c6d-e2fc6241b95b" />

## Soal 7
Membuat zona utama untuk domain k40.com di server Tirion (ns1), kemudian membuat server slave di Valmar (ns2) agar data DNS tersinkronisasi secara otomatis. Zona ini berisi A record dan CNAME untuk host Sirion, Lindon, dan Vingilot.
- www.<xxxx>.com → sirion.<xxxx>.com 
- static.<xxxx>.com → lindon.<xxxx>.com 
- app.<xxxx>.com → vingilot.<xxxx>.com 

Tirion:
File `named.conf.options` mengatur agar DNS menerima query dari semua jaringan, menggunakan forwarder 192.168.122.1, dan mengaktifkan rekursi. File `named.conf.local` mendeklarasikan zona k40.com sebagai master zone dengan izin transfer ke server slave Valmar. File zona db.k40.com berisi catatan SOA, NS, A, dan CNAME untuk sirion, lindon, vingilot, serta alias www, static, dan app. Setelah validasi konfigurasi, layanan named dijalankan ulang, lalu dilakukan uji dig untuk memastikan semua hostname telah ter-resolve dengan benar.

```
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
```

<img width="761" height="259" alt="image" src="https://github.com/user-attachments/assets/982f70d3-50c9-4ce0-85c7-d52d444b4db4" />

Valmar:
Mengonfigurasi server DNS slave di Valmar (ns2) agar menyalin k40.com dari master Tirion. File `named.conf.options` diatur untuk menerima query dari semua jaringan dengan forwarder 192.168.122.1. Pada `named.conf.local`, zona k40.com dideklarasikan sebagai slave zone dengan master 192.231.3.2 dan lokasi penyimpanan salinan di `/var/cache/bind/db.k40.com`. Setelah layanan named dijalankan, skrip melakukan pengecekan SOA, serta memastikan seluruh A dan CNAME record di ns2 konsisten dengan data di ns1.

```
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
```

<img width="834" height="323" alt="image" src="https://github.com/user-attachments/assets/6ff0c0d9-bbef-45f0-a061-59c39c8b8ca5" />

Kemudian dilakukan pengujian dari klien lain dengan menjalankan perintah ping ke CNAME yang telah dikonfigurasi sebelumnya.

<img width="987" height="477" alt="image" src="https://github.com/user-attachments/assets/af8142ce-cb0a-4399-a212-f18c6cfd9199" />

## Soal 8
Membuat reverse zone agar setiap IP di segmen DMZ dapat dikonversi kembali ke hostname yang sesuai (PTR record).

Tirion:
Menambahkan reverse zone `3.231.192.in-addr.arpa` sebagai master zone di file konfigurasi `/etc/bind/named.conf.local`. Selanjutnya, dibuat file zona `/etc/bind/db.192.231.3` yang berisi PTR record untuk setiap host di jaringan DMZ, yaitu 4 yang mengarah ke lindon.k40.com, 5 ke vingilot.k40.com, dan 6 ke sirion.k40.com..

```
#!/usr/bin/env bash
# Nomor 8 – Tirion (ns1/master)
# Tambah reverse zone 192.231.3.0/24 => 3.231.192.in-addr.arpa TANPA menimpa zona forward k40.com
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

NS2_IP="192.231.3.3"
REV_ZONE="3.231.192.in-addr.arpa"
REV_DIR="/etc/bind/rev"
REV_FILE="${REV_DIR}/${REV_ZONE}"
# Sesuaikan serial jika perlu (format YYYYMMDDns)
SERIAL="2025102205"

echo "[ns1] apt update & install bind tools"
apt update -y
apt install -y bind9 bind9utils dnsutils procps psmisc

echo "[ns1] Pastikan named.conf meng-include opsi & lokal (idempotent)"
# Ini aman—hanya memastikan include; tidak menyentuh named.conf.local (zona forward tetap)
cat >/etc/bind/named.conf <<'EOF'
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
EOF

echo "[ns1] Opsi dasar BIND (idempotent)"
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

echo "[ns1] Tambahkan blok zona REVERSE ke named.conf.local bila belum ada (tidak menimpa forward)"
mkdir -p "${REV_DIR}"
grep -q "zone \"${REV_ZONE}\"" /etc/bind/named.conf.local 2>/dev/null || cat >>/etc/bind/named.conf.local <<EOF

zone "${REV_ZONE}" {
    type master;
    file "${REV_FILE}";
    notify yes;
    also-notify { ${NS2_IP}; };
    allow-transfer { ${NS2_IP}; };
};
EOF

echo "[ns1] Tulis file zona reverse (PTR untuk Lindon/ Vingilot/ Sirion)"
cat >"${REV_FILE}" <<EOF
\$TTL 3600
@   IN  SOA ns1.k40.com. admin.k40.com. (
        ${SERIAL} ; SERIAL (YYYYMMDDnn) — naikkan tiap edit
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

# Bersihkan newline Windows jika ada
sed -i 's/\r$//' /etc/bind/named.conf /etc/bind/named.conf.options /etc/bind/named.conf.local "${REV_FILE}"

echo "[ns1] Validasi & jalankan named tanpa systemctl"
named-checkzone "${REV_ZONE}" "${REV_FILE}"
named-checkconf -z

# Stop, hapus jurnal, start
(ps -eo pid,comm | awk '$2=="named"{print $1}' | xargs -r kill) || true
rm -f "${REV_FILE}.jnl" /var/cache/bind/${REV_ZONE}*.jnl 2>/dev/null || true
named -4 -u bind -c /etc/bind/named.conf &
sleep 2

echo "== SOA reverse @ns1 =="
dig @127.0.0.1 ${REV_ZONE} SOA +short || true
echo "== PTR @ns1 =="
echo -n "192.231.3.4 -> "; dig +short @127.0.0.1 -x 192.231.3.4 || true
echo -n "192.231.3.5 -> "; dig +short @127.0.0.1 -x 192.231.3.5 || true
echo -n "192.231.3.6 -> "; dig +short @127.0.0.1 -x 192.231.3.6 || true

echo "[ns1] Selesai (reverse master aktif tanpa mengganggu zona forward)."
```

<img width="933" height="358" alt="image" src="https://github.com/user-attachments/assets/2482c8ae-5343-4434-8925-2a8cacd337c5" />

Valmar:

```
#!/usr/bin/env bash
# Nomor 8 – Valmar (ns2/slave)
# Tarik reverse zone 3.231.192.in-addr.arpa dari ns1 TANPA menimpa zona forward slave
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

NS1_IP="192.231.3.2"
REV_ZONE="3.231.192.in-addr.arpa"

echo "[ns2] apt update & install bind tools"
apt update -y
apt install -y bind9 bind9utils dnsutils procps psmisc

echo "[ns2] Pastikan named.conf meng-include opsi & lokal (idempotent)"
cat >/etc/bind/named.conf <<'EOF'
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
EOF

echo "[ns2] Opsi dasar BIND (idempotent)"
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

echo "[ns2] Tambahkan blok zona REVERSE SLAVE ke named.conf.local bila belum ada (tidak menimpa forward)"
grep -q "zone \"${REV_ZONE}\"" /etc/bind/named.conf.local 2>/dev/null || cat >>/etc/bind/named.conf.local <<EOF

zone "${REV_ZONE}" {
    type slave;
    masters { ${NS1_IP}; };
    file "${REV_ZONE}";   // relative => tersimpan di /var/cache/bind/
    allow-notify { ${NS1_IP}; };
};
EOF

# Rapikan newline
sed -i 's/\r$//' /etc/bind/named.conf /etc/bind/named.conf.options /etc/bind/named.conf.local

echo "[ns2] Siapkan direktori & izin cache"
mkdir -p /var/cache/bind
chown -R bind:bind /var/cache/bind

echo "[ns2] Validasi konfigurasi"
named-checkconf -z

echo "[ns2] Bersihkan salinan lama agar AXFR segar"
rm -f /var/cache/bind/${REV_ZONE}* /var/lib/bind/${REV_ZONE}* 2>/dev/null || true

echo "[ns2] Start named tanpa systemctl"
(ps -eo pid,comm | awk '$2=="named"{print $1}' | xargs -r kill) || true
named -4 -u bind -c /etc/bind/named.conf &
sleep 3

echo "== AXFR manual test dari ns1 =="
dig @${NS1_IP} ${REV_ZONE} AXFR +tcp | head || true

echo "== Cek file slave di cache =="
ls -l /var/cache/bind/${REV_ZONE}* || echo "!! file belum terlihat — cek allow-transfer/notify di ns1 & TCP/UDP 53"

echo "== SOA reverse @ns2 (harus sama dengan ns1) =="
dig @127.0.0.1 ${REV_ZONE} SOA +short || true

echo "== PTR @ns2 =="
echo -n "192.231.3.4 -> "; dig +short @127.0.0.1 -x 192.231.3.4 || true
echo -n "192.231.3.5 -> "; dig +short @127.0.0.1 -x 192.231.3.5 || true
echo -n "192.231.3.6 -> "; dig +short @127.0.0.1 -x 192.231.3.6 || true

echo "[ns2] Selesai (reverse slave aktif & tidak mengganggu forward slave)."
```

<img width="1055" height="566" alt="image" src="https://github.com/user-attachments/assets/c4609690-befc-4768-aa54-c6751ec3e949" />

## Soal 9
Modul Apache seperti autoindex dan rewrite diaktifkan untuk memungkinkan untuk menampilkan daftar file dan pembatasan akses. File VirtualHost static.k40.com.conf dibuat agar hanya mengizinkan akses melalui hostname static.k40.com atau lindon.k40.com, serta menampilkan listing direktori /annals. Setelah itu, situs baru diaktifkan dan Apache direstart agar konfigurasi berlaku.

```
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
curl    http://static.k40.com/annals/
```
Ketika curl terlampir list file annals dan ketika masuk file kita bisa melihat isi file

<img width="1055" height="618" alt="image" src="https://github.com/user-attachments/assets/7a9accfa-73c2-41a2-a5e6-af642580b05b" />

## Soal 10
Membuat web berbasis PHP-FPM dengan hostname app.k40.com. Apache dan PHP-FPM diinstal, modul proxy serta rewrite diaktifkan untuk menangani file PHP melalui socket FPM. Dua halaman dibuat `index.php` sebagai home dan `about.php` untuk halaman About, lalu `.htaccess` menambahkan aturan rewrite agar `/about` bisa diakses tanpa akhiran .php. VirtualHost dikonfigurasi agar hanya bisa diakses lewat hostname app.k40.com, bukan IP, dan menetapkan `index.php` sebagai halaman utama. Setelah konfigurasi diaktifkan dan Apache direstart, script menguji akses untuk memastikan kedua halaman berjalan dengan benar.

```
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
```

Ketika curl akan muncul status 200 yang berarti sudah berhasil di deploy

<img width="720" height="266" alt="image" src="https://github.com/user-attachments/assets/173526d5-fd52-4dbe-95d6-8f4ef164b7de" />

## Soal 11
Langkah-langkah di Sirion: Install Nginx dan buat file konfigurasi /etc/nginx/sites-available/reverse_proxy dengan isi berikut, lalu aktifkan konfigurasi tersebut.
```
# Di Sirion
echo "nameserver 192.168.122.1" > /etc/resolv.conf
apt-get update
apt-get install nginx -y

cat > /etc/nginx/sites-available/reverse_proxy <<EOF
server {
    listen 80;
    server_name www.k40.com sirion.k40.com;

    location /static/ {
        proxy_pass http://192.231.3.4/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /app/ {
        proxy_pass http://192.231.3.5/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -s /etc/nginx/sites-available/reverse_proxy /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
nginx -t
service nginx restart
```
Langkah-langkah di Vingilot: Edit file konfigurasi /etc/apache2/sites-available/app.k40.com.conf untuk menambahkan ServerAlias dan menghapus aturan redirect.
```
# Di Vingilot (/etc/apache2/sites-available/app.k40.com.conf)
<VirtualHost *:80>
    ServerName app.k40.com
    ServerAlias www.k40.com

    DocumentRoot /var/www/app.k40.com

    <Directory /var/www/app.k40.com>
        Options +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.4-fpm.sock|fcgi://localhost/"
    </FilesMatch>

    ErrorLog ${APACHE_LOG_DIR}/app_k40_error.log
    CustomLog ${APACHE_LOG_DIR}/app_k40_access.log combined
</VirtualHost>
```
Di Vingilot (lanjutan)
```
service apache2 restart
service php8.4-fpm start # Memastikan PHP-FPM berjalan setelah restart Apache
```
Verifikasi menggunakan curl "http://www.k40.com/static/annals/" dan "curl http://www.k40.com/app/" di terminal yang langsung terhubung dengan eonwe seperti foto berikut:

<img width="915" height="294" alt="image" src="https://github.com/user-attachments/assets/879f59ce-6bf7-4ee8-b840-cf058657ac83" />

## Soal 12
Langkah-langkah di Sirion: Install apache2-utils untuk perintah htpasswd, buat file password /etc/nginx/.htpasswd dengan user admin (password diatur saat perintah dijalankan), lalu modifikasi konfigurasi Nginx untuk menambahkan blok location /admin yang menerapkan Basic Auth.
```
# Di Sirion
apt-get update
apt-get install apache2-utils -y

# Buat file password, Anda akan diminta memasukkan password untuk 'admin'
htpasswd -c /etc/nginx/.htpasswd admin

# Edit konfigurasi Nginx
# nano /etc/nginx/sites-available/reverse_proxy
# Tambahkan blok location /admin { ... } seperti di bawah

cat > /etc/nginx/sites-available/reverse_proxy <<EOF
server {
    listen 80;
    server_name www.k40.com sirion.k40.com;

    location /admin {
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://192.231.3.5/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        proxy_pass http://192.231.3.4/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /app/ {
        proxy_pass http://192.231.3.5/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

nginx -t
service nginx restart
```
Verifikasi dari Klien (misalnya Elrond): Gunakan curl untuk menguji akses ke /admin dalam tiga skenario: tanpa kredensial, dengan kredensial salah, dan dengan kredensial benar.
```
# Di Elrond
curl -I http://www.k40.com/admin
curl -I --user admin:oadijaijdaodajd http://www.k40.com/admin

# 3. Dengan kredensial benar (Harus 200 OK)
# Ganti 'password-benar' dengan password yang Anda buat
curl -I --user admin:admin http://www.k40.com/admin
```
Dengan output seperti berikut:

<img width="971" height="680" alt="image" src="https://github.com/user-attachments/assets/3925c417-b5c6-4777-b695-e1810860aeaa" />

## Soal 13
Langkah-langkah di Sirion: Modifikasi konfigurasi Nginx (/etc/nginx/sites-available/reverse_proxy) menjadi dua blok server. Blok pertama ditandai sebagai default_server untuk menangani akses via IP dan juga menangani nama sirion.k40.com, tugasnya hanya melakukan redirect 301. Blok kedua secara spesifik melayani nama domain kanonik www.k40.com dan berisi semua konfigurasi reverse proxy sebelumnya.
```
# Di Sirion
# Edit file /etc/nginx/sites-available/reverse_proxy
# Ganti isinya menjadi seperti di bawah

cat > /etc/nginx/sites-available/reverse_proxy <<EOF
# Blok 1: Redirect IP & sirion.k40.com
server {
    listen 80 default_server;
    server_name sirion.k40.com;
    return 301 http://www.k40.com\$request_uri;
}

# Blok 2: Melayani www.k40.com
server {
    listen 80;
    server_name www.k40.com;

    location /admin {
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://192.231.3.5/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        proxy_pass http://192.231.3.4/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /app/ {
        proxy_pass http://192.231.3.5/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

nginx -t
service nginx restart
```
Verifikasi di Elrond atau client yang nyambung dengan eonwe
```
curl -I http://192.231.3.6/app/
curl -I http://sirion.k40.com/static/
curl -I http://www.k40.com/app/
```

<img width="742" height="690" alt="image" src="https://github.com/user-attachments/assets/d83f6a4e-2c59-40f3-8201-0e51d6647f4d" />

## Soal 14
Pertama, definisikan format log baru bernama proxy di /etc/apache2/apache2.conf yang menggunakan header X-Forwarded-For sebagai IP klien. Kedua, ubah direktif CustomLog di /etc/apache2/sites-available/app.k40.com.conf agar menggunakan format proxy tersebut.
```
# Di Vingilot

echo '' >> /etc/apache2/apache2.conf
echo '# Custom log format for reverse proxy' >> /etc/apache2/apache2.conf
echo 'LogFormat "%{X-Forwarded-For}i %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" proxy' >> /etc/apache2/apache2.conf

# Menggunakan sed untuk mengganti 'combined' menjadi 'proxy'
sed -i 's/CustomLog \${APACHE_LOG_DIR}\/app_k40_access.log combined/CustomLog \${APACHE_LOG_DIR}\/app_k40_access.log proxy/' /etc/apache2/sites-available/app.k40.com.conf

service apache2 restart
```
Lalu kita dapat melakukan verifikasi
```
# Di Elrond
curl http://www.k40.com/app/

# Di Vingilot
tail -n 5 /var/log/apache2/app_k40_access.log
```
Output di terminal Elrond:

<img width="912" height="199" alt="image" src="https://github.com/user-attachments/assets/e124538c-9e0c-4985-abe5-e2263db69864" />

Output di terminal Vingilot:

<img width="1126" height="357" alt="image" src="https://github.com/user-attachments/assets/c3b67ea0-6c3a-42bb-b0aa-254c69e56e04" />


## Soal 15
Langkah-langkah di Elrond: Install apache2-utils (yang berisi ab), lalu jalankan perintah ab untuk kedua endpoint.
```
# Di Elrond
apt-get update
apt-get install apache2-utils -y

# Uji endpoint dinamis (/app/)
ab -n 500 -c 10 http://www.k40.com/app/

# Uji endpoint statis (/static/)
ab -n 500 -c 10 http://www.k40.com/static/
```
Setelah merangkum output, tabelnya akan menjadi sebagai berikut:

<img width="584" height="540" alt="image" src="https://github.com/user-attachments/assets/c172a2b8-40b9-46e7-a0b7-ae0082bf8a6c" />


## Soal 16
Verifikasi Kondisi Awal (di Elrond) Periksa resolusi DNS untuk static.k40.com sebelum ada perubahan.
```
dig static.k40.com +short
```
Dengan output sebagai berikut:

<img width="573" height="120" alt="image" src="https://github.com/user-attachments/assets/3318e215-2d23-4823-b7f0-d05ff12bd885" />

Edit file zona /etc/bind/jarkom/db.k40.com untuk menaikkan serial SOA menjadi 3, mengubah IP lindon menjadi 192.231.3.40, dan menambahkan TTL 30 pada record lindon dan static.
```
# Di Tirion
# nano /etc/bind/jarkom/db.k40.com
# Ganti isinya menjadi:
cat > /etc/bind/jarkom/db.k40.com <<EOF
\$TTL    604800
@       IN      SOA     ns1.k40.com. root.k40.com. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.k40.com.
@       IN      NS      ns2.k40.com.

k40.com.        IN      A       192.231.3.6
ns1             IN      A       192.231.3.2
ns2             IN      A       192.231.3.3
sirion          IN      A       192.231.3.6
lindon      30  IN      A       192.231.3.40
vingilot        IN      A       192.231.3.5

www             IN      CNAME   sirion.k40.com.
static      30  IN      CNAME   lindon.k40.com.
app             IN      CNAME   vingilot.k40.com.
EOF

service named restart
```
Verifikasi lagi:
```
# Di Valmar
dig k40.com @localhost SOA
```
Dengan output sebagai berikut:

<img width="1140" height="642" alt="image" src="https://github.com/user-attachments/assets/4e90f593-eff7-4734-92b3-5f7dcc1104c9" />

Kalau kita cek kembali dengan command
```
# Di Elrond
dig static.k40.com +short
```
Outputnya akan menjadi sebagai berikut (setelah 30 detik)

<img width="586" height="88" alt="image" src="https://github.com/user-attachments/assets/37071198-d152-4e4d-b3dc-ffc28f17503b" />

## Soal 17
Pada setiap node yang relevan, jalankan perintah update-rc.d <nama_layanan> defaults untuk mengaktifkan autostart.
```
# Di Tirion
update-rc.d named defaults

# Di Valmar
update-rc.d named defaults

# Di Sirion
update-rc.d nginx defaults

# Di Lindon
update-rc.d apache2 defaults

# Di Vingilot
update-rc.d php8.4-fpm defaults
update-rc.d apache2 defaults
```
Semua node (Tirion, Valmar, Sirion, Lindon, Vingilot) dihentikan (Stop) lalu dinyalakan kembali (Start) melalui GNS3 dan nyalakan kembali service yang dibutuhkan.
```
# Di Tirion
service named start

# Di Valmar
service named start

# Di Vingilot
service apache2 start
service php8.4-fpm start

# Di Sirion
service nginx start
```
Lalu verifikasi kembali apakah berhasil atau tidak
```
# Di Elrond
curl http://www.k40.com/app/
```
Dengan output sebagai berikut:

<img width="910" height="233" alt="image" src="https://github.com/user-attachments/assets/c4053a8c-180f-4a2e-a5b2-8d2c0d737f7d" />

## Soal 18
Edit file zona /etc/bind/jarkom/db.k40.com untuk menambahkan record TXT dan CNAME, serta menaikkan nomor serial SOA menjadi 4.
```
# Di Tirion
# nano /etc/bind/jarkom/db.k40.com
# Ganti isinya menjadi:
cat > /etc/bind/jarkom/db.k40.com <<EOF
\$TTL    604800
@       IN      SOA     ns1.k40.com. root.k40.com. (
                              4         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.k40.com.
@       IN      NS      ns2.k40.com.

k40.com.        IN      A       192.231.3.6
ns1             IN      A       192.231.3.2
ns2             IN      A       192.231.3.3
sirion          IN      A       192.231.3.6
lindon      30  IN      A       192.231.3.40
vingilot        IN      A       192.231.3.5

www             IN      CNAME   sirion.k40.com.
static      30  IN      CNAME   lindon.k40.com.
app             IN      CNAME   vingilot.k40.com.

melkor          IN      TXT     "Morgoth (Melkor)"
morgoth         IN      CNAME   melkor.k40.com.
EOF

service named restart
```
Verifikasi kembali di terminal elrond:
```
# Di Elrond
# 1. Verifikasi TXT record
dig melkor.k40.com TXT

# 2. Verifikasi CNAME (alias)
dig morgoth.k40.com
```
Dengan output seperti berikut:

<img width="1126" height="635" alt="image" src="https://github.com/user-attachments/assets/15d60d9d-46dd-4c76-8b8a-673d44a0754e" />

<img width="1023" height="599" alt="image" src="https://github.com/user-attachments/assets/9ce211e8-ed3b-47fe-b106-b77a907a8a4c" />

## Soal 19
Edit file zona /etc/bind/jarkom/db.k40.com untuk menambahkan CNAME record havens dan menaikkan nomor serial SOA menjadi 5.
```
# Di Tirion
# nano /etc/bind/jarkom/db.k40.com
# Ganti isinya menjadi:
cat > /etc/bind/jarkom/db.k40.com <<EOF
\$TTL    604800
@       IN      SOA     ns1.k40.com. root.k40.com. (
                              5         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.k40.com.
@       IN      NS      ns2.k40.com.

k40.com.        IN      A       192.231.3.6
ns1             IN      A       192.231.3.2
ns2             IN      A       192.231.3.3
sirion          IN      A       192.231.3.6
lindon      30  IN      A       192.231.3.40
vingilot        IN      A       192.231.3.5

www             IN      CNAME   sirion.k40.com.
static      30  IN      CNAME   lindon.k40.com.
app             IN      CNAME   vingilot.k40.com.

melkor          IN      TXT     "Morgoth (Melkor)"
morgoth         IN      CNAME   melkor.k40.com.

havens          IN      CNAME   www.k40.com.
EOF

service named restart
```
Edit file konfigurasi Nginx /etc/nginx/sites-available/reverse_proxy untuk menambahkan havens.k40.com ke direktif server_name dan memperbarui kondisi if agar tidak mengalihkan hostname baru ini.
```
# Di Sirion
# nano /etc/nginx/sites-available/reverse_proxy
# Ganti isinya menjadi:
cat > /etc/nginx/sites-available/reverse_proxy <<EOF
server {
    listen 80 default_server;
    server_name www.k40.com sirion.k40.com havens.k40.com;

    if (\$host !~* ^(www|havens)\.k40\.com$) {
        return 301 http://www.k40.com\$request_uri;
    }

    location /admin {
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://192.231.3.5/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        proxy_pass http://192.231.3.4/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /app/ {
        proxy_pass http://192.231.3.5/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

service nginx restart
```
Verifikasi di 2 terminal berbeda misal elrond dan cirdan:
```
# Di Elrond
dig havens.k40.com
curl http://havens.k40.com/app/

# Di elwing
dig havens.k40.com
curl http://havens.k40.com/static/annals/
```
Dengan output sebagai berikut:

<img width="1005" height="666" alt="image" src="https://github.com/user-attachments/assets/ae0debce-9e30-41e8-ae4e-d75db3aee3d6" />

<img width="907" height="203" alt="image" src="https://github.com/user-attachments/assets/ae03be44-45cb-4705-a4d2-d712cc8b0e20" />

<img width="1014" height="767" alt="image" src="https://github.com/user-attachments/assets/1d500a36-f34a-4dea-9898-db30a3f26a5e" />

## Soal 20
Di sirion, membuat direktori /var/www/html dan file index.html dengan konten yang ditentukan. Kemudian, memodifikasi konfigurasi Nginx (/etc/nginx/sites-available/reverse_proxy) untuk menambahkan blok location / yang menyajikan file index.html dari direktori tersebut.
```
# Di Sirion
mkdir -p /var/www/html

# Buat file index.html
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>War of Wrath</title>
</head>
<body>
    <h1>War of Wrath: Lindon bertahan</h1>
    <p>Silakan telusuri tautan di bawah ini:</p>
    <ul>
        <li><a href="/static/annals/">Arsip di Lindon (/static)</a></li>
        <li><a href="/app/">Kisah di Vingilot (/app)</a></li>
    </ul>
</body>
</html>
EOF

# Edit konfigurasi Nginx
# nano /etc/nginx/sites-available/reverse_proxy
# Tambahkan blok location / { ... }
cat > /etc/nginx/sites-available/reverse_proxy <<EOF
server {
    listen 80 default_server;
    server_name www.k40.com sirion.k40.com havens.k40.com;

    if (\$host !~* ^(www|havens)\.k40\.com$) {
        return 301 http://www.k40.com\$request_uri;
    }

    # Lokasi untuk root (halaman depan)
    location / {
        root /var/www/html;
        index index.html;
    }

    location /admin {
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://192.231.3.5/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        proxy_pass http://192.231.3.4/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /app/ {
        proxy_pass http://192.231.3.5/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

nginx -t
service nginx restart
```
Lalu verifikasi misal di elrond dan maglor:
```
# Di Elrond
curl http://www.k40.com/

# Di maglor
curl http://www.k40.com/
```
Dengan output sebagai berikut:

<img width="1030" height="493" alt="image" src="https://github.com/user-attachments/assets/482a6b56-91fb-49a1-9a71-bb992ee63d89" />

<img width="1027" height="487" alt="image" src="https://github.com/user-attachments/assets/08ec3d11-bc2d-4a01-a20d-0837332d0b62" />
