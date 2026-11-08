# dnsblockd Unit-Identity Decision Card (D2)

**Created:** 2026-11-08 23:40 (SUPERB phase-2 close-out) · **Owner question — answer to unblock the last big delegation**

## What is being decided

Migrating `modules/nixos/services/dns-blocker.nix` onto the upstream
dnsblockd NixOS module (locked rev `f9bb6477`, both formerly-missing
options `csrf_enabled` + `blocklist_files` verified present there) has
exactly ONE open gate: which OS identity the daemon runs as after the
migration.

- **Option A — adopt upstream's unprivileged `dnsblockd` user** (the
  module default). Requires a one-time ownership heal of the live state
  dir: `/var/lib/dnsblockd` is the **hot-tier subvol** (`hot/dnsblockd`,
  Samsung, `+C`, wave-2 cutover 2026-10-14, deliberately EXCLUDED from
  btrbk — snapshot coverage must NOT change). Heal = stop window +
  `chown -R dnsblockd:dnslbockd`-class fix on the mounted subvol
  (cv-state-perms pattern: `+`ExecStartPre chown at first start, not a
  manual sudo step). Restore paths are untouched: the QLC rollback
  shadow under the mount keeps its old ownership and is reclaim-eligible
  afterwards (storage.md soak-end row); the allowlist backup reads only.
  Wins: privilege drop on the resolver daemon (root today), upstream
  VM tests apply as-is, no permanent override to track.
- **Option B — override `user = "root"`** to preserve current ownership.
  Zero migration window, zero risk to the hot subvol; costs: keeps a
  root resolver (weakest privilege posture on the box), carries a
  permanent consumer-side divergence from the upstream contract, and the
  wrapper stays half-adopted (~65 of ~110 upstream keys reachable; the
  unreachable set `cluster_*`, `dns_doq_*`, `dns_doh3_*`, `retention_*`,
  `tracking_batch_*`, `dashboard_sse_*`, `dhcp_lease_file`,
  `gateway_decrypt_*`, `allow_sibling_domains` only opens via full
  adoption either way).

## Recommendation

**A** — the heal is one bounded stop window on a service that already
tolerates restarts (5s RestartSec), the pattern is proven, and B pays a
permanent privilege + divergence tax for a one-time convenience.

## What the answer unblocks

The M19–M21 wrapper→module migration in the same wave: re-point
`dns-blocker.nix` at `inputs.dnsblockd.nixosModules.default`, keep the
hot-tier mount gating + registry entry + allowlist backup consumer-side,
per-unit parity against the current render, upstream's two VM tests
(`nixos-vm-test`, `nixos-vm-test-gateway`) join the battery.

**Owner row:** docs/todo/services.md:87 (`[blocked:user]`, the only open
gate). Evidence: docs/architecture-understanding/2026-10-28_10-18_dnsblockd-integration.html §E3/§E7.
