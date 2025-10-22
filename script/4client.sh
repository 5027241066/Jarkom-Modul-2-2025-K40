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
