# Boot Speed Deep Research — evo-x2 (2026-10-06)

**Session:** 2026-10-06 ~21:11 → ~21:35 — trigger: user asked "How can we make boot faster? DEEP research!" on boot 0 (started 21:09:52). READ → UNDERSTAND → RESEARCH → REFLECT loop, fixes shipped and verified one at a time.

**Sibling context:** the boot measured here IS the freeze-#19 recovery boot, and the sibling autopsy (`21-25`) documents that the rust-cache migration's 79 GB USB→USB rsync **re-fired 90 s into this boot** — my measurements are therefore WORST-CASE (IO PSI ~85 %, load 34 during part of the window). Every structural finding below holds on calm boots too (the 2026-08-31 "full 3 min in ExecStartPre at load 24" precedent had no migration storm), but the absolute seconds conflate storm amplification with structure. Post-deploy re-measure on a calm boot is queued (§f2).

## The question and the answer

Boot total was **3 min 8 s** (firmware 62.5 s + loader 2.7 s + kernel 1.9 s + initrd 5.8 s + **userspace 115.3 s**). The login screen (`graphical.target`) waits for `multi-user.target`, which was gated ~97 s by `hermes.service`'s **ExecStartPre** — a full-tree permissions walk + an unconditional SQLite `integrity_check` over a 1.4 GB db, both IO-heavy scans on the QLC root that ran before the gateway process was even allowed to fork. Two other boot-gated oneshots and a 50 s boot fsck on a cache SSD amplified the storm. All structural gates are now removed; userspace should land ~20-40 s (bounded next by bank-sync's notify-ready and home-manager activation, §d).

## Evidence (boot 0, 2026-10-06 21:09:52)

| # | Finding | Evidence |
|---|---------|----------|
| 1 | `systemd-analyze time`: 1min 2.5s firmware + 2.7s loader + 1.9s kernel + 5.8s initrd + 1min 55.3s userspace = 3min 8.3s | live, 21:12 |
| 2 | Critical chain: `multi-user.target @115.3s ← hermes.service @18.3s +1min 37s` | `systemd-analyze critical-chain` |
| 3 | hermes ExecStartPre window: "Starting Hermes…" at 26.02 s monotonic, first script output (`hermes-migrate-state`) at 122.95 s — **96.9 s silent gap**; "Started" at 123.09 s | `journalctl -u hermes -b -o short-monotonic` |
| 4 | The gap is `fixPermissionsScript`'s fast-path probe (full-tree `find` ownership walk, prints nothing on a converged tree — no `hermes-perms:` line this boot) + the migrate script's `integrity_check` (1,428,819,328-byte state.db); aclRevoke is O(1) (one getfacl) | hermes.nix:127-198 + journal elimination |
| 5 | Boot -1 (freeze-#19 death boot) was far worse: hermes first attempt **timed out at the full 6 min**, restart-cooldown, second attempt 14.6 s → Started 534 s; `multi-user.target` at **584 s**; orphaned ExecStartPre PIDs from attempt 1 still emitted output at 533.8 s (D-state class) | `journalctl -b -1` |
| 6 | Boot-gated oneshots (wantedBy multi-user): `crush-hot-db-migrate` 37.5 s, `btrfs-rescue-snapshot` 36.2 s — they gate login even on a boot where hermes is fast | `systemd-analyze blame` + module grep |
| 7 | Boot fsck: `systemd-fsck@…ata-SanDisk_SDSSDA240G…-part1` 49.9 s — the buildcache ext4 cache SSD's fstab passno=2 (NixOS default for non-root fs) | blame + generated `/etc/fstab` |
| 8 | Storm oneshots: `discordsync-db-heal` (first fire boot+45 s, re-fires every 30 s), `system-health-metrics` (boot+30 s, 47.9 s first run), `pool-usb-recovery` (fires AT BOOT via udev SYSTEMD_WANTS on DAS enumeration — pool-recovery.nix:214 — plus the OnBootSec=2min catch-up timer; 93.9 s first run) — no IO-tier demotion | module grep (db-heal already had ioTier.background; the other two did not) |
| 9 | Next gates after hermes (same boot): `bank-sync.service` 55.1 s activation (14.3→69.4 s; Type=simple per eval — mechanism NOT yet diagnosed, see §d2), `home-manager-lars` 46.8 s, `clickhouse` 38.6 s, `miniflux`/`oauth2-proxy`/`gatus` ~30 s each (storm victims) | blame + journal |
| 10 | `boot.loader.timeout = 2` ≈ the 2.7 s loader leg; initrd 5.8 s is verbose-by-doctrine (freeze forensics, boot.nix comments) | boot.nix:33-44 |

## Changes shipped (each verified before the next)

| # | Change | File | Mechanism |
|---|--------|------|-----------|
| 1 | Perms walk → post-start heal unit | `modules/nixos/services/hermes.nix` | `fixPermissionsScript` (probe+heal UNCHANGED, cv-state-perms lesson preserved — they move together) now runs in `hermes-perms-heal.service`: `after = hermes.service`, pulled by `hermes.wants` on EVERY start (boot + every deploy restart — same convergence cadence, after the fork instead of before it). ioTier.build (BE/7+Nice10), TimeoutStartSec 10min, RequiresMountsFor stateDir, same caps as the old `+`-prefixed run. hermes ExecStartPre keeps only O(1)/cheap steps. hermes TimeoutStartSec 6min→3min. Script logs one completion marker per run (`hermes-perms: converged (fast/heal path)`) — a finished oneshot reads inactive, so tests/runbooks wait on the marker. |
| 2 | integrity_check now WAL-gated | same | sqlite deletes `state.db-wal` on the last clean close, so a present `-wal` IS the unclean-shutdown signal (freeze/crash class — exactly when the check matters). Clean boots skip the 1.4 GB scan entirely; journal_mode is persistent in the db header, no re-assert needed. Malformed handling unchanged. |
| 3 | `crush-hot-db-migrate` de-gated | `modules/nixos/services/crush-hot-db.nix` + `scripts/deploy.sh` | wantedBy multi-user → timer `OnBootSec=2min` (once-per-boot cadence preserved; RemainAfterExit semantics identical to the old boot-run). deploy.sh: removed from the is-enabled provisioner loop (static units return rc=1 — dead gate), added an explicit unconditional restart block (deploy-time convergence kept; name stays in deploy.sh → deploy-restart-audit green). `tests/test-crush-hot-db.nix` updated to pin the NEW shape (service static + timer enabled). |
| 4 | `btrfs-rescue-snapshot` de-gated | `platforms/nixos/system/btrfs-rescue.nix` | boot-run → timer `OnBootSec=2min` alongside the existing daily OnCalendar (Persistent). Every-boot convergence kept, login no longer waits 36 s on snapshot IO. Never was in deploy.sh; audit unaffected. |
| 5 | Boot fsck off on buildcache | `modules/nixos/services/buildcache.nix` | `noCheck = true` → fstab passno 0 (verified in generated fstab). A rebuildable cache SSD whose ext4 journal replays unclean shutdowns does not need a 50 s boot fsck. (Note: nixpkgs here has NO `fsckPass` option — `noCheck` is the knob.) |
| 6 | Storm oneshots demoted | `system-health.nix`, `pool-recovery.nix` | `ioTier.background` (BE/6) merged into both units (db-heal already had it). BFQ only reorders under contention — steady-state unaffected. |
| 7 | hermes VM test topology update | `tests/test-hermes.nix` | New `wait_perms_heal(machine, n)` helper waits for the Nth completion marker; perms/EROFS journal assertions retargeted to `hermes-perms-heal`; D1 test now also pins "the heal never crosses into the RO bind". Also fixed the pre-existing v2→v3 workspace-doc literal drift (the module ships `workspaceDocVersion = "3"`; the test still grepped v2 — likely why this test sat in the failing-6 list). |

**Verification per step:** unit/timer evals (`nix eval` spot checks incl. generated fstab passno 0), full toplevel eval (`nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` — throws on any failed assertion: shape/deploy-restart/mount-gating/stray-unit/port-registry audits all green), shellcheck on deploy.sh, `nix fmt` on touched files (0 diffs), and VM tests: **crush-hot-db PASS** (booted VM, new shape pinned); hermes VM test result: see §g (was still running at authoring).

## Projected impact + how to measure

- userspace 115.3 s → **~20-40 s** (chain floor is pocket-id's ~17.7 s + hermes ~1 s; stragglers = bank-sync 69 s / HM 60 s / clickhouse — see §d for whether to un-gate those too). Worst-case-storm boots improve the most (the 6-min-timeout class is structurally gone).
- Measure after the next deploy + reboot: `systemd-analyze time`, `systemd-analyze critical-chain`, `journalctl -u hermes-perms-heal -b` (must show one `hermes-perms: converged` line per hermes start), `systemctl is-enabled crush-hot-db-migrate.{service,timer}` (static/enabled).

## d) NOT FIXED — the next gates, ranked

1. **Firmware 62.5 s (the single biggest lever, owner-gated):** 128 GB soldered LPDDR5X POST/memory training on the GMKtec EVO-X2. BIOS candidates: Fast Boot, Memory Context Restore (MCR), reduced POST device init. Cannot be verified from Nix — needs a BIOS walk + reboot (queued [blocked:user], §f1). `systemd-analyze firmware` also unavailable (no firmware performance data).
2. **bank-sync.service activation 55 s — mechanism UNVERIFIED (corrected 21:55, same session):** the original draft claimed "Type=notify + event-store replay" — WRONG: the unit is Type=simple (verified via eval) and /mnt/pool mounted at 17.1 s, so neither notify-readiness nor pool-wait explains the 14.3→69.4 s activation. Diagnose the actual mechanism (ExecStartPre? restart cycle? blame semantics?) BEFORE deciding whether login should decouple from it. Queued as [decision] with the corrected framing (§f3).
3. **home-manager-lars 46.8 s** boot activation (HM internals; also had a cosmetic `mountpoint: command not found` in activate). Re-measure post-storm before acting (§f2 covers).
4. Loader 2.7 s: `boot.loader.timeout 2 → 1` saves ~1 s; left alone deliberately — the boot-mirror selection window is safety-relevant (boot-mirror doctrine).
5. initrd 5.8 s: verbose console is a deliberate freeze-forensics choice (boot.nix) — not touched.

## e) Deliberately NOT done

- No change to any service's Type/readiness semantics beyond hermes' own module.
- No `systemd-analyze blame`-chasing of the docker/oci fleet (clickhouse/miniflux/oauth2-proxy/gatus ~30 s each) — those are storm victims, not gates; re-measure on a calm boot first.
- The concurrent session's `tests/test-paperless-gpt.nix` + flake.nix wiring (committed 20:54/21:00, BEFORE this session) breaks `nix flake check` for the whole tree ("function called with unexpected argument 'pkgs'"); not mine to fix mid-flight — flagged here and in §f5.

## f) NEXT THINGS (self-harvested; routed per TODO rules)

1. `[blocked:user]` **BIOS boot-time walk on the GMKtec EVO-X2** — check Fast Boot / Memory Context Restore / POST init options against the 62.5 s firmware leg; each enabled option needs one reboot to measure. → docs/todo/stability.md (Source: this report §d1)
2. `[blocked:deploy]` **Re-measure boot on the first calm post-deploy boot** — `systemd-analyze time/critical-chain`, hermes-perms-heal journal (one converged line per hermes start), crush-hot-db timer static/enabled shape, buildcache fstab passno 0 live. Expect userspace ≤40 s; if bank-sync/HM still gate >50 s, promote §f3/§f4. → docs/todo/stability.md (Source: this report)
3. `[decision]` **bank-sync 55 s activation: diagnose the mechanism first, then decide decouple-vs-accept** — original framing (Type=notify) was wrong (Type=simple, eval-verified 21:55; pool mounts at 17 s); root-cause the 14.3→69.4 s activation before any wiring change. → docs/todo/services.md (Source: this report §d2/§f3, corrected)
4. `[watch]` **home-manager-lars activation time post-storm** — if still >30 s on a calm boot, investigate HM activation steps (journal shows cheap phases; suspect IO + nix store reads). → docs/todo/services.md (Source: this report §d3)
5. `[blocked:user]` **test-paperless-gpt flake wiring red for the whole tree** (another session's in-flight work, pre-dates this session): `nix flake check` aborts at eval; owner/owning-session should fix the `{ inputs }` vs `pkgs` call shape. NOT caused by this session's changes (verified: both files' commits 20:54/21:00:52 predate 21:11). → docs/todo/pipeline.md (Source: this report §e)

## g) Verification appendix

- crush-hot-db VM test: **PASS** (exit 0, booted VM, migrated fixtures + new static/timer shape asserted).
- hermes VM test: **PASS** (exit 0 — post-start heal topology, completion-marker waits, WAL-gated migrate, D1/6/6b perms regressions, v3 doc literals; both nodes booted).
- Full toplevel eval (all eval-time audits): PASS.
- Generated fstab buildcache line: `… 0 0` (fsck off) — verified.
- Daemon-race note: the auto-commit daemon swept most of these files into heuristic commits mid-session (verified via `git show --stat` per the amend policy); one intermediate commit briefly carried the invalid `fsckPass = 0` (option does not exist) — the working tree/next commit carries `noCheck = true`; toplevel eval green on the final tree.
