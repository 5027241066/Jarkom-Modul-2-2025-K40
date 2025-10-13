# Laporan Resmi Jarkom-Modul-2-2025-K40
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

## Soal 6
Naikkan serial SOA di ns1 setiap perubahan dan paksa ns2 melakukan retransfer bila belum sinkron.

Pada tirion masukkan script berikut
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
        2025101302  ; serial (Ymdnn) — naikkan tiap edit
        3600        ; refresh
        900         ; retry
        604800      ; expire
        300 )       ; negative TTL

; authoritative nameservers
@       IN  NS  ns1.k40.com.
@       IN  NS  ns2.k40.com.

; glue (A) untuk NS
ns1     IN  A   192.231.3.2    ; Tirion
ns2     IN  A   192.231.3.3    ; Valmar

; apex (front door)
@       IN  A   192.231.3.6    ; Sirion

; (opsional) host lain sesuai glosarium
eonwe    IN  A  192.231.3.1
earendil IN  A  192.231.1.2
elwing   IN  A  192.231.1.3
cirdan   IN  A  192.231.2.2
elrond   IN  A  192.231.2.3
maglor   IN  A  192.231.2.4
lindon   IN  A  192.231.3.4
vingilot IN  A  192.231.3.5
sirion   IN  A  192.231.3.6
ZONE
named-checkconf && named-checkzone k40.com /etc/bind/db.k40.com && \
pkill named 2>/dev/null || true && \
named -4 -u bind -c /etc/bind/named.conf && \
echo "== SOA ns1 ==" && dig +norecurse @127.0.0.1 k40.com SOA +short
```

<img width="861" height="143" alt="image" src="https://github.com/user-attachments/assets/3e37f8ad-359f-4584-af49-dbf230dbd3ee" />

Kemudian pada velmar masukkan script berikut untuk menyiapkan server DNS slave (Valmar ns2), datanya disalin dari server master Tirion (ns1) dengan IP 192.231.3.2. DNS slave bertugas sebagai backup server DNS.
```
#!/usr/bin/env bash
echo "[+] Setup DNS Slave (Valmar - ns2) untuk k40.com"

# 1) Install paket
apt update
apt install -y bind9 bind9utils dnsutils

# 2) Siapkan direktori & ownership yang benar untuk slave zone
mkdir -p /etc/bind /var/cache/bind
chown -R bind:bind /var/cache/bind

# 3) Konfigurasi opsi global (forwarders sesuai soal sebelumnya bisa 192.168.122.1)
cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { any; };
    allow-query { any; };

    forwarders { 192.168.122.1; };  // bisa diganti/ditambah jika perlu
    recursion yes;
    dnssec-validation no;
};
EOF

# 4) Daftarkan zona SLAVE (tarik dari ns1 = 192.231.3.2)
cat > /etc/bind/named.conf.local <<'EOF'
zone "k40.com" {
    type slave;
    masters { 192.231.3.2; };            // Tirion (ns1)
    file "/var/cache/bind/db.k40.com";   // salinan zona ditulis di sini
    allow-notify { 192.231.3.2; };       // terima NOTIFY dari ns1
};
EOF

# 5) Validasi konfigurasi
named-checkconf

# 6) (opsional) Buka port DNS kalau ada iptables
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -A INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
iptables -C INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true

# 7) Bersihkan salinan lama & jalankan named (tanpa systemd)
rm -f /var/cache/bind/db.k40.com* /var/cache/bind/k40.com*.jnl 2>/dev/null || true
pkill named 2>/dev/null || true
named -4 -u bind -c /etc/bind/named.conf

# 8) Tunggu sebentar & verifikasi
sleep 2
echo "[+] Mengecek file zona slave..."
ls -l /var/cache/bind | grep db.k40.com || echo "[!] Belum ada salinan: cek allow-transfer/notify di ns1 dan konektivitas 53/TCP+UDP"

echo "[+] Mengecek serial SOA ns1 & ns2..."
echo -n "ns1: " && dig +norecurse @192.231.3.2 k40.com SOA +short
echo -n "ns2: " && dig +norecurse @192.231.3.3 k40.com SOA +short

echo "[DONE] DNS Slave Valmar siap. Pastikan serial ns1 ==7 ns2 (sama)."
```

<img width="908" height="176" alt="image" src="https://github.com/user-attachments/assets/840594d5-7757-46e0-911c-cd5aee2a81f2" />

## Soal 7
Tambahkan A/CNAME di ns1, naikkan serial, dan pastikan ns2 menarik perubahan.
