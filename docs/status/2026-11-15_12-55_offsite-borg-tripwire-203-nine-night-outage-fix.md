# Offsite-Borg Tripwire 203/EXEC: Nine-Night Outage, Root Fix + Class Guard

**Date:** 2026-11-15 ~12:55
**Trigger:** post-deploy §16 FAIL `Offsite Borg - tripwire binary not executable/missing (/nix/store/bvvc483…-borg-offsite-golive-check/bin/borg-offsite-golive-check)` (owner-pasted; same FAIL in the 10:13 foreign deploy's battery, log `/var/log/systemnix-deploys/2026-11-15_10-13-20.log:2549`)

## §a Evidence (all live-probed this session)

| Probe | Result |
| --- | --- |
| Deployed unit `/etc/systemd/system/borgbackup-job-hetzner.service:24` | `ExecStartPre=/nix/store/bvvc483…-borg-offsite-golive-check/bin/borg-offsite-golive-check` (the `/bin/` form) |
| `test -x` flat store path | YES (executable single 417-byte file at the drv root) |
| `test -x` `<file>/bin/borg-offsite-golive-check` | rc=1 (`Not a directory`) |
| Journal `borgbackup-job-hetzner` since go-live | **203/EXEC every nightly 06:30 fire Nov 07 → Nov 15 (9 consecutive)**: `Unable to locate executable …: Not a directory`, `Failed at step EXEC` |
| `/var/lib/borg-offsite/.last_success` | does not exist (never created) |
| `backups.prom` | `backup_ever_succeeded{backup="offsite-borg"} 0`, `backup_last_success_timestamp 0`, `backup_age_hours 999`, `backup_healthy 0` |
| Tree eval `systemd.services.borgbackup-job-hetzner.serviceConfig.ExecStartPre` (pre-fix) | renders the SAME `/bin/` form (current tree was broken too; next deploy would have re-rendered it) |
| Eval stderr (pre-fix) | `evaluation warning: getExe: Package borg-offsite-golive-check does not have the meta.mainProgram attribute … use getExe' to specify the name` |

## §b Root cause

`goliveCheck = pkgs.writeShellScript …` yields a **single-file derivation** (script at the drv root, no `bin/`). `lib.getExe'` AND `lib.getExe` BOTH render `<drv>/bin/<name>` (`getExe` falls back to the drv name when `meta.mainProgram` is absent — the same fallback that emitted the recurring `meta.mainProgram` eval warning the monitoring sessions kept seeing). The 2026-11-07 `getExe'` → `getExe` swap (docs/status/2026-11-07_07-17) was therefore a **no-op**: the unit has carried the dead path since its first enablement, and every nightly run died 203/EXEC before borg ever started.

Two downstream misdiagnoses corrected this session:

1. **docs/todo/pipeline.md tripwire row (2026-11-13): "false-FAIL — probe the manifest path itself with -x"** — INVERTED. The smoke's `-x` probe reads the path straight from the deployed unit; the unit genuinely referenced a nonexistent path, so the smoke was RIGHT. Their proposed fix would have passed the gate while the nightly job stayed dead (the exact silent-gate class the repo documents).
2. **"Three cheap eval-warning hygiene fixes" bundle (borg `meta.mainProgram` leg)** — the warning was not an independent hygiene item; it was `lib.getExe`'s fallback warning on this same call site. Removing `getExe` kills both the warning and the broken path.

Impact framing: the 203 was also **accidentally fail-closing the signed-off go-live seed** (owner triple-answer 2026-11-04: composition set, ~646 G raw seed, "auto-starting Persistent timer proceeds — no hold requested"). Fixing the path UNBLOCKS that seed at the next 06:30 fire (Nov 16).

## §c Fix surfaces (all landed; daemon commits 4f687f460 + e12b96fbb)

| Surface | Change |
| --- | --- |
| `platforms/nixos/system/backup.nix:316` | `ExecStartPre = "${goliveCheck}";` — interpolate the flat file path directly; comment documents the getExe/getExe' no-op history |
| `flake/parts/checks/selftests.nix` (`offsite-borg-positive-render`) | new assert: **no `/bin/` infix on ExecStartPre** — eval-time shape guard for the 203/EXEC class, fires on every flake check |
| `docs/services/offsite-borg.md` | TRIPWIRE PATH SHAPE paragraph in the go-live checklist |
| `TODO_LIST.md` tripwire row + `docs/todo/pipeline.md:1124` | ticked, premise corrected (smoke was right; unit was broken) |
| `TODO_LIST.md` hygiene bundle | borg leg marked RESOLVED (warning gone from eval); pipewire + caddy legs remain |
| Smoke (`scripts/lib/offsite-borg-smoke.sh`) | UNCHANGED — its `-x` probe was correct all along; fixture selftest re-run 21/21 |

## §d Verification

- Tree eval post-fix: `ExecStartPre = /nix/store/bvvc483…-borg-offsite-golive-check` (flat), `test -x` YES.
- `meta.mainProgram` warning gone from eval stderr.
- `nix build .#checks.x86_64-linux.offsite-borg-positive-render` green (forces the new assert).
- `scripts/test-offsite-borg-smoke.sh` 21/21 branches.
- `nix fmt --` on both .nix files: 0 changed; `statix` clean on both.

## §e Repo-wide class audit

Every other `lib.getExe`/`lib.getExe'` call site targets a `writeShellApplication` (bin/ layout — getExe correct) or a real package: monitor365 ×5, forgejo scripts (`_forgejo-scripts.nix`, all writeShellApplication), system-health ×2, memory-emergency-guard ×2, crm ×2, pim-sync, gatus-config (`mkSecretCheck` + oidc env), bank-sync, immich (`mkImmichApiKeyProvision`), snapshots (scrubGuard writeShellApplication + its `lib.getExe is REQUIRED` comment). **backup.nix was the only writeShellScript+getExe misuse.** The 2026-09-11 scrubGuard incident (bare `"${scrubGuard}"` on a writeShellApplication → "Is a directory") is the same family in the opposite direction; together the two incidents pin the rule: *writeShellScript → interpolate the flat path; writeShellApplication → getExe.*

## §f Deploy + follow-ups

- Deploy arc: the 10:13 foreign deploy aborted exit 3 (its battery carried the same tripwire FAIL among its NEW failures); the 12:08 re-run was pressure-gate refused (code 12, real IO storm, sdb 87%); this session's 45-min PSI watcher (12:52-13:36) never saw avg10 <20 (band 41-79%) and correctly did NOT force. A third deploy (13:06, foreign session) then aborted at flake check: their own fresh `storage-collector-prepared-source` FOD fails (`sed: Permission denied` in the prepared-source builder; their commit d1eed8cd9 "storage-collector 0.2 re-vendored" is the arc mid-repair). Per the sequencing-beats-re-firing discipline this session STOPPED re-firing: the tripwire fix is committed (4f687f460) and rides the next successful deploy from any session. Anchor pre-check: system-1012 → same store path as running system (already anchored). Live unit remains broken until that deploy lands (next 06:30 fires keep failing 203 until then).
- Amend of the footless fix commit 4f687f460 BLOCKED: a later daemon sweep (e12b96fbb) landed on top while another session is active — narrative lives here + in the queue rows instead.
- **[watch] First real seed: next 06:30 fire (Nov 16)** — expect `backup_ever_succeeded{backup="offsite-borg"} 1`, `.last_success` created, journal create+prune+compact, first-run `borg create --stats` = the irreplaceable-set measurement vs the ~800 G BX21 trigger. Queued to `docs/todo/storage.md` + TODO_LIST.
- The 10:13 battery's OTHER new FAILs (forgejo-runner INACTIVE ordering-cycle drop, tq pool inactive, Health Hub 503, CRM 303, crm-server 201% CPU) belong to the foreign session's arc — not harvested here.
- Restore drill real-mode ([watch], storage.md:333) stays open post-first-success.
