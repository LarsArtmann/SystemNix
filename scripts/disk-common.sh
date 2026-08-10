#!/usr/bin/env bash
# Shared disk geometry constants for evo-x2.
# Source from BOTH disk-fix.sh and disk-diagnose.sh to prevent drift.
#
# Usage: source "$(dirname "$0")/disk-common.sh"

# shellcheck shell=bash
# Variables are consumed by sourcing scripts — disable "unused" warnings
# shellcheck disable=SC2034
DISK="/dev/nvme0n1"
P8_START_SECTOR=1097861120    # p8 start — hardcoded, never changes
BTRFS_SIZE_SECTORS=2147483648 # 1.00 TiB
BTRFS_END_SECTOR=$((P8_START_SECTOR + BTRFS_SIZE_SECTORS))
TARGET_P8_END_GIB=1560 # gives ~12.5 GiB margin past BTRFS
TARGET_P8_END_SECTOR=$((TARGET_P8_END_GIB * 1024 * 1024 * 1024 / 512))

sectors_to_gib() { awk -v sectors="$1" 'BEGIN { printf "%.1f", sectors * 512 / 1073741824 }'; }
sectors_to_tib() { awk -v sectors="$1" 'BEGIN { printf "%.2f", sectors * 512 / 1099511627776 }'; }
