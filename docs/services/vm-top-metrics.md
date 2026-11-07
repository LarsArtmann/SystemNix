# vm-top-metrics

**Runbook owner surface:** `modules/nixos/services/vm-top-metrics.nix` (module) + `scripts/vm-top-metrics.sh` (single source of truth, shellcheck'd, `selftest` mode) — enabled on evo-x2 from `platforms/nixos/system/configuration.nix`.

## What it does

Top-N (default 5) processes by **total-vm (`VmSize`)**, emitted as a node_exporter textfile collector every 5 min into `/var/lib/prometheus-node-exporter/textfile_collectors/vm-top.prom` (atomic rename):

- `node_vm_top_vmsize_bytes{pid,comm}` — per-process VmSize in bytes
- `node_vm_top_vmsize_hwm_bytes` — max of the top set (single trending line)

**VmSize is RESERVED address space, not RSS.** The metric tracks *reservation pressure* — the exact currency of the oom-kill cascade class (the 2026-11-02 b0d70d73 chromium reservation cascade: balloons grew silently until the swap-exhausted kill pass). First live run on evo-x2 (2026-11-07): three helium tabs + one electron at ~1.45 TiB VmSize each — normal for Chromium-family reservation, but now *visible and trendable*.

## Traps

- **comm label sanitization**: quotes/backslashes stripped, 64-char cap (Prometheus label hygiene) — pinned by the selftest.
- **Kernel threads have no `VmSize:` line** and are skipped by construction (selftest fixture pins it).
- **The ExecStartPost start-contract** fails the unit when `vm-top.prom` is missing/empty after a collect — stale metrics are never silently served.
- **Fixture env note** (script-internal): `PROC_DIR`/`TOP_N` bind at script start; a call-site env prefix does NOT rebind them — the selftest assigns the globals directly. This bit the first selftest draft (function env-prefix ≠ variable rebinding).

## Verification

- `bash scripts/vm-top-metrics.sh selftest` — fixture assertions (top-N order, kernel-thread skip, TOP_N bound, hwm, label sanitization).
- Post-deploy: `systemctl status vm-top-metrics.service` + `cat /var/lib/prometheus-node-exporter/textfile_collectors/vm-top.prom`.
- SigNoz/dashboarding of `node_vm_top_vmsize_bytes` is follow-up work (the monitoring library owns the panel row).
