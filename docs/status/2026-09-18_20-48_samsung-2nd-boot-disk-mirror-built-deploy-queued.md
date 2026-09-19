# Samsung 2nd Boot Disk — Mirror Built, Deploy Queue-Gated (2026-09-18 20:48)

Session ask: **"I feel very strongly of making my Samsung a 2nd boot disk and switching asap — MAKE A PLAN!"**

## TL;DR

Everything code-side is BUILT, evaluated, shellcheck-clean, logic-fixture-tested, and committed (daemon-batched). The deploy is QUEUED behind the IO-pressure gate (correctly refusing to race a live storm — freeze #5 doctrine). After it lands: one command activates the NVRAM switch, one audit gates the reboot. The only remaining QLC dependency after the switch is the root `@` subvolume.

## (a) CURRENT STATE — exact live state of everything

| Piece | State (verified 20:47) |
| --- | --- |
| `platforms/nixos/system/boot-mirror.nix` | WRITTEN + committed. Mount `/boot-mirror` (Samsung p1 `SAMSUNG-EFI`, by-uuid `4F53-C156`, nofail) + `boot-mirror-sync.service` (bootctl install `--variables=no --make-entry-directory=no` → rsync `--delete` (FAT flags, per-ESP random-seed excluded) → `diff -r` parity gate that FAILS on drift) |
| `scripts/boot-mirror-activate.sh` + flake app | WRITTEN + committed + shellcheck-green (drv realized). Idempotent: creates `Linux Boot Manager (Samsung)` EFI entry, orders it first, verifies NVRAM after. Parsing logic fixture-tested (4 scenarios, incl. the 0x000B auto-entry non-match) |
| `scripts/pre-reboot-check.sh` §11 | WRITTEN + committed. Mirror audit: EFI entry presence, bootctl is-installed, tree parity; severity FAIL once mirror is first in BootOrder, WARN before |
| deploy.sh | `boot-mirror-sync` added to provisioner restart loop (+ rationale comment) |
| AGENTS.md | Build & Deploy section carries the full boot-mirror runbook + rollback |
| Static gates | `nix flake check --no-build` PASS; evo-x2 eval PASS (re-run after every fix); ExecStart/mount/Condition eval-probed |
| Deploy | NOT RUN — queued. Background job (`/tmp/boot-mirror-poll-deploy2.sh`, shell 038) polls IO PSI avg10, fires `nix run .#deploy` on 2 consecutive <20% readings, retries on gate exit-12, deadline 22:55 (before the 23:00 btrbk window). **(SUPERSEDED 2026-09-19: the tmp-cleaner ate both /tmp files overnight — the >4h-staleness rule; queue re-established INLINE with persistent log `~/.local/state/boot-mirror-deploy.log`, see `docs/status/2026-09-19_09-48_samsung-boot-mirror-queue-recovery-llama-vlm-fix-parallel-deploy.md`)** |
| IO storm (blocker) | avg10 21-54% oscillating, avg60 ~55%. **Driver identified: `sdb` (buildcache USB SSD) 100% busy; BOTH NVMe idle (QLC 4%, Samsung 0%)**. Producers: 8× golangci-lint (~1h old), rustc ×5, qemu-aarch64 ×2, cc1 — parallel sessions' builds, not this session |
| Memory dimensions | clear: zram ~0%, MemAvailable 81G |
| Git tree | clean — daemon batch-committed everything (HEAD `260f86ef`) |

## (b) FULLY and COMPLETELY DONE (verified)

1. Research: disk layout, EFI entries (QLC `Linux Boot Manager` 0x0001 current; auto `UEFI OS` 0x000B on Samsung p1 pointing at a nonexistent BOOTX64.EFI), nixpkgs `mirroredBoots` is grub/extlinux-ONLY (mirror unit is the only path), pre-reboot-check internals, deploy-restart-audit, evo-x2/rpi3 import graph (module is evo-x2-only).
2. Pareto plan: `docs/planning/2026-09-18_19-53_SAMSUNG-2ND-BOOT-DISK-PARETO-PLAN.md` (tiers, design decisions, rollback, hazards honored, mid-flight catches).
3. boot-mirror module + configuration.nix import + deploy.sh wiring + flake app.
4. Activate script + §11 audit, both parse/logic-tested; all three touched scripts `bash -n` clean; both wrapped derivations shellcheck-green via pre-build.
5. AGENTS.md runbook.

## (c) PARTIALLY DONE / in flight

- **Deploy** — queued (see above). The swap window replaces the stale Sep-9 partial asset copy on Samsung p1 with a full verified mirror (first sync ~250MB, seconds).
- Mirror live-verification (journal, `bootctl is-installed`, tree diff, df) — blocked on the deploy.

## (d) NOT STARTED

- `nix run .#boot-mirror-activate` (NVRAM switch; after deploy + verification).
- Second `nix run .#pre-reboot-check` (post-activation — §11 becomes FAIL-grade once mirror is first).
- Reboot + post-reboot verification (`BootCurrent` = Samsung entry, `bootctl status` partition `023f66c0-…`, three-way anchor, services green).
- CHANGELOG.md entry (deliberately deferred until the switch is verified live).

## (e) TOTALLY FUCKED UP — honest mistakes (all caught pre-deploy, none deployed)

1. **flake.nix edit-tool races ×3** against the daemon — wasted a cycle each time; fixed by switching to an atomic read-assert-replace python edit. Lesson: on hot files during parallel sessions, scripted atomic edits beat the freshness check.
2. **Plan-doc edit clobbered the `## Rollback` header** (old_string was the header itself) — caught and restored in the next edit.
3. **`after = ["boot-mirror.mount"]` named a nonexistent unit** — systemd escapes the dash (`boot\x2dmirror.mount`, verified). Never deployed; replaced by `RequiresMountsFor` (implies Requires=+After=).
4. **`bootctl install` default `--make-entry-directory=auto`** would have created a mirror-only `<token>/` dir → permanent false-FAIL of the diff gate. Caught by reflection; fixed with `--make-entry-directory=no`.
5. **SC2012 (`ls | wc -l`)** — would have failed the deploy MID-BUILD under writeShellApplication's shellcheck. Caught by pre-building the script drvs (now a keepable practice).
6. **`sed` missing from the activate app runtimeInputs** (would exit-127 in the wrapper). Caught by a manual binary audit of the script.
7. **Queue-job swap gap**: killed the first poll job before starting its replacement — for ~3 min NOTHING was queued. Noticed, replacement now running (shell 038).

## (f) IMPROVEMENTS

- Pre-build `writeShellApplication` drvs (`nix build` the app + unit ExecStart) BEFORE pressure-gated deploy windows — turns build-time shellcheck failures into zero-cost catches.
- Atomic scripted edits for daemon-hot files (flake.nix class).
- The §11 severity escalation pattern (gate grades by who boots first) is reusable for any future redundant-path audit.
- Future (structural): mirror freshness could join system-health as an age metric; §11 could get a VM-testable fixture (needs a mounted MIRROR_DIR).

## (g) NEXT 50-ish (this feature's ladder, impact-ordered)

1. Deploy when the gate opens (queued job does this) — watch activation for the new mount+unit start
2. `journalctl -u boot-mirror-sync` — must show `OK — N entries` (or fail loudly)
3. `findmnt /boot-mirror` + `df -h` + `bootctl --esp-path=/boot-mirror is-installed` (via §11)
4. `nix run .#pre-reboot-check` — §11 WARN-grade green (pre-activation)
5. `nix run .#boot-mirror-activate` — verify printed BootOrder: Samsung entry first
6. `nix run .#pre-reboot-check` again — §11 FAIL-grade green
7. REBOOT (user decision — kills sessions)
8. Post-reboot: `bootctl status` Current Boot Loader partition = `023f66c0-…`; `efibootmgr | BootCurrent`; three-way anchor; failed-unit sweep; gatus/system-health green
9. CHANGELOG.md entry + plan-doc checkboxes closed
10. Watch first nightly: sync re-run at boot/deploy only — confirm no drift alerts
11. Confirm QLC fallback still boots (optional: one deliberate firmware-menu boot test)
12. ESP growth watch: configurationLimit 50 × ~2 ESPs of kernels — revisit limit if usage climbs
13. Consider post-deploy-check §15 (mirror freshness assert) — optional, sync unit already fail-loud
14. Consider system-health mirror-age metric (only if skipped-sync class ever observed)
15. Structural follow-up (separate task): migrate root `@` off QLC → Samsung becomes a COMPLETE boot disk surviving QLC death; until then "2nd boot disk" = boot-chain redundancy, not QLC-death survival
16. If storm never drains tonight: rerun `/tmp/boot-mirror-poll-deploy2.sh` (or reschedule after the 23:00 btrbk window) — **DEAD 2026-09-19: tmp-cleaner ate that script; the inline queue v3 pattern (retry rc=12/13, gate-aware, `~/.local/state/boot-mirror-deploy.log`) replaced it**

## Questions I could NOT figure out myself (up to 3)

1. **Reboot timing** — once gates are green, reboot immediately (kills your desktop + all sessions, ~21:00 tonight) or you pick the moment (before the 23:00 btrbk window / tomorrow)? Only you know what's running.
2. **Force the deploy through the USB storm?** Data says the storm is 100% buildcache-USB (NVMe idle, activation risk low) but the freeze doctrine says queue — `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` exists for exactly this owner call. Default: I keep queueing.
3. **Scope of "2nd boot disk"** — is ESP+`/nix` offload (today's state after the switch) the intended end state, or do you want root `@` migrated off the QLC next (Samsung then survives full QLC death; a bigger, riskier migration)?

## Attribution note

The IO storm's producers (8× golangci-lint ~1h, rustc ×5, qemu-aarch64 ×2) belong to parallel sessions; the llama-rag re-enable doc in the same commit window (`260f86ef`) is another session's work. This session touched only the files listed in (b).
