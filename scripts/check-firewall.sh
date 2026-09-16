#!/usr/bin/env bash
# NOTE (2026-09-16): Mullvad is REMOVED from this host — the `inet mullvad`
# table section below errors by design (kept to make the absence visible); the
# :53 listener section labels dnsblockd (sole resolver since unbound was
# retired).

NFT="$(command -v nft || echo nft)"

echo "=== NixOS firewall (inet nixos-fw) ==="
sudo "$NFT" list table inet nixos-fw 2>&1

echo ""
echo "=== Mullvad firewall (RETIRED — table absent means the stack is gone) ==="
sudo "$NFT" list table inet mullvad 2>&1

echo ""
echo "=== All nftables tables ==="
sudo "$NFT" list tables 2>&1

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
echo "=== dnsblockd (sole :53 resolver) listening sockets ==="
ss -tulnp 2>&1 | grep ':53 ' || true
