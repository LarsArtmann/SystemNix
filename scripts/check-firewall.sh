#!/usr/bin/env bash

NFT=/nix/store/a7sf90yc74dha1bcj2wx6hh3w10qf19z-nftables-1.1.6/bin/nft

echo "=== NixOS firewall (inet nixos-fw) ==="
sudo $NFT list table inet nixos-fw 2>&1

echo ""
echo "=== Mullvad firewall (inet mullvad) ==="
sudo $NFT list table inet mullvad 2>&1

echo ""
echo "=== All nftables tables ==="
sudo $NFT list tables 2>&1

echo ""
echo "=== ip route ==="
ip route 2>&1 || true

echo ""
echo "=== ip addr (brief) ==="
ip -br addr 2>&1 || true

echo ""
echo "=== WireGuard interfaces ==="
ip link show type wireguard 2>&1 || true

echo ""
echo "=== resolv.conf ==="
cat /etc/resolv.conf

echo ""
echo "=== unbound listening sockets ==="
ss -tulnp 2>&1 | grep ':53 ' || true
