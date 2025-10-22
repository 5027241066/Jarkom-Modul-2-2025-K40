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
