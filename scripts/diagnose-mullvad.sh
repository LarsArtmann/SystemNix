#!/usr/bin/env bash
# Diagnose Mullvad VPN traffic routing issues

echo "=== Mullvad status ==="
mullvad status 2>&1

echo ""
echo "=== WireGuard / tunnel interfaces ==="
ip link show 2>&1

echo ""
echo "=== ip route ==="
ip route show 2>&1
echo "--- table main ---"
ip route show table main 2>&1
echo "--- table all ---"
ip route show table all 2>&1 | head -30
echo "--- rule list ---"
ip rule show 2>&1

echo ""
echo "=== rp_filter settings ==="
sysctl net.ipv4.conf.all.rp_filter 2>&1
sysctl net.ipv4.conf.default.rp_filter 2>&1
for iface in $(ls /proc/sys/net/ipv4/conf/); do
  echo -n "$iface: "
  sysctl "net.ipv4.conf.$iface.rp_filter" 2>&1
done

echo ""
echo "=== ip_forward ==="
sysctl net.ipv4.ip_forward 2>&1

echo ""
echo "=== iptables filter INPUT (first 30 rules) ==="
sudo iptables -L INPUT -n -v --line-numbers 2>&1 | head -30

echo ""
echo "=== iptables filter FORWARD (first 20 rules) ==="
sudo iptables -L FORWARD -n -v --line-numbers 2>&1 | head -20

echo ""
echo "=== iptables nat (first 20 rules) ==="
sudo iptables -t nat -L -n -v --line-numbers 2>&1 | head -20

echo ""
echo "=== iptables mangle (first 20 rules) ==="
sudo iptables -t mangle -L -n -v --line-numbers 2>&1 | head -20

echo ""
echo "=== nftables ruleset (if any) ==="
sudo /nix/store/a7sf90yc74dha1bcj2wx6hh3w10qf19z-nftables-1.1.6/bin/nft list ruleset 2>&1 | head -80

echo ""
echo "=== conntrack stats ==="
sudo conntrack -C 2>&1 || true
sudo conntrack -L 2>&1 | head -20 || true
