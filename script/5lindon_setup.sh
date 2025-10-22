#!/usr/bin/env bash

# Write /etc/hosts with FQDN and shortname (plus localhost conventions)
cat >/etc/hosts <<'EOF'
127.0.0.1   localhost
127.0.1.1   lindon.k40.com lindon
192.231.3.4 lindon.k40.com lindon
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
getent hosts lindon.k40.com || true
