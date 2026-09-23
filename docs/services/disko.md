# disko — Reinstall/Rescue Runbook (evo-x2, Samsung `tlc`)

Status: **document-only.** disko is a provisioning-time tool; destructive modes are RESCUE-ONLY and never run on disks with data (house doctrine, AGENTS.md + the Phase-2 plan). This page is the T24 rescue-path decision one-pager from `docs/planning/2026-09-14_13-27_SAMSUNG-PHASE2-HOT-DB-NATIVE-PARETO-PLAN.md`.

## What exists

| Surface | Where |
| --- | --- |
| Geometry spec (executable, eval-checked) | `disko/samsung-tlc.nix` |
| Flake output | `flake.diskoConfigurations.samsung-tlc` |
| Eval guard (geometry + discovery-trap) | `checks.x86_64-linux.disko-samsung-tlc` |
| Blank-vdisk VM rehearsal | `tests/test-disko-layout.nix` → `checks.x86_64-linux.disko-layout` |
| Live-geometry source of truth | `/etc/fstab` (subvol=nix, hot toplevel) + `platforms/nixos/system/boot-mirror.nix` (SAMSUNG-EFI) |

The spec covers ONLY the Samsung 970 EVO Plus 1TB (`/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V`): p1 = 4G FAT32 `SAMSUNG-EFI` (no mountpoint — the QLC primary's fstab mounts it as the boot mirror), p2 = btrfs `-L tlc` with toplevel at `/mnt/hot` (subvolid=5 — `hot/<name>` service subvols are created THROUGH it by `modules/nixos/services/hot-db.nix`, so it must never become a named subvolume) plus named subvols `/nix` and `/users/lars/cache/nix`. The QLC root disk and `/data` are NOT modeled — they carry live data and are hand-managed (`hardware-configuration.nix`).

## THE DISCOVERY TRAP (never violate)

The disko config is deliberately NOT imported by any `nixosConfigurations` entry. An imported disko module makes `disko --flake .#evo-x2` find an applicable config and apply DESTRUCTIVE modes to the named disk. The eval guard (`flake.nix` `disko-samsung-tlc`) asserts `!(evoConfigOptions ? disko)` so a future "harmless" import fails `nix flake check` immediately. Keep it that way.

Flag-level facts (verified against disko docs 2026-09-14): `--dry-run` prints the generated script without executing; `destroy` prompts unless `--yes-wipe-all-disks`; `mount` mode targets `--root-mountpoint` (installer context). ALWAYS `--dry-run` first and read the script.

## Rescue-path decision (T24)

**Decision: manual rescue rebuild is the default path; nixos-anywhere stays deferred** until an actual reinstall is scheduled and someone is at the console.

- **Why not nixos-anywhere today:** it wants the disko config wired into a nixosConfigurations entry (exactly the discovery trap), plus console access and one-shot SSH provisioning. This flake's private git+ssh inputs and per-host sops age identity make a from-scratch `nixos-anywhere` bootstrap a separate project, not a rescue tool. A rescue rebuild starts from the stock NixOS installer ISO.
- **Why disko still earns its keep:** it is the executable, CI-guarded record of the Samsung geometry — the same class of stuck-boot/geometry-drift gap `scripts/pre-reboot-check.sh` and `boot-mirror.nix` close elsewhere. `disko mount` (installer/rescue context) reproduces the mount layout without hand-remembering subvol/option details.

### Reinstall/rescue recipe (Samsung disk blank or being replaced)

1. Boot the NixOS installer ISO; get the repo (clone via SSH or `nix copy` from evo-x2).
2. Dry-run the script and READ it: `nix build github:nix-community/disko#disko` (or use the repo's locked input) → `disko --dry-run` against `disko/samsung-tlc.nix` with the target disk passed by-id. **Never** `disko --flake .#evo-x2` — nothing is applicable by design.
3. Apply only against a BLANK/by-id-verified disk: `disko -m destroy,format,mount <spec>` (interactive `destroy` prompt is the last guard).
4. Continue with the standard manual rebuild: `nixos-install --flake <repo>#evo-x2`-style bootstrapping from the mounted layout, restore the sops age key from the SSH host key, redeploy via `nix run .#deploy` from a full checkout.
5. Re-verify with `checks.disko-samsung-tlc` (geometry guard re-runs against the live config) and `bash scripts/pre-reboot-check.sh` before first reboot.

### What stays OUT of scope

- Never run disko against the QLC NVMe or `/data` — both carry live data with no disko spec, deliberately.
- Destructive disko inside VM tests only (`tests/test-disko-layout.nix` applies to an `emptyDiskImages` blank vdisk).
- Autoinstaller ISO (disko + ISO target) remains a ROADMAP idea, not implemented.
