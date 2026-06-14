#!/usr/bin/env bash
sudo /nix/store/a7sf90yc74dha1bcj2wx6hh3w10qf19z-nftables-1.1.6/bin/nft list table inet mullvad 2>&1
echo "=== TCP TEST ==="
curl -sS --connect-timeout 5 https://ifconfig.me 2>&1 || echo "CURL FAILED"
echo ""
echo "=== ICMP TEST ==="
ping -c 2 -W 3 1.1.1.1 2>&1
