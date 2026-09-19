# 2026-09-15 ~19:30 — TODO-harvest execution sweep: Zone 6 closeout, CI triage, second-scanner guard

> **[docs-health 2026-09-19] RESOLVED + ARCHIVED:** interim companion superseded by the fuller 19:27 closeout + self-review of the same sweep (docs/status/2026-09-15_19-27_*).


**Session type:** verification + fix execution over the 2026-09-15 TODO_LIST harvest (five window-closeout sections). ~~interim OPEN carrier~~ superseded by the fuller 19:27 closeout (docs/status/2026-09-15_19-27_*).
**Tree state at start:** clean at `20695f8a`; parallel session ACTIVE throughout (paperless/nix-email/sops WIP — 833 insertions, full-config evals poisoned by their mid-flight "Saved views" error; all shared-surface evals deferred or targeted).

## a. Zone 6 / memory-emergency-guard closeout (14 rows)

- **Deployed-state (3-step probe, step 3):** deployed guard script carries the full Zone 6 implementation (16 zone6/io_psi/ioChurnUnits hits); profile system-779 anchored; rendered Gatus TRIPPED check correct. **Verified mid-storm:** live prom `io_psi_some_avg60_percent 82.22`, `io_disk_busy_percent_max 100.0`, `zone6_trips_total 99`, trips_last_hour 6, restore_capped 1 — the box was tripping WHILE being verified.
- **Counter-reset tolerance:** none needed — counters persist in `/var/lib/memory-emergency-guard/zone-counts` (StateDirectory; live `13 35 0 2 0 99`) and no Gatus condition reads counters.
- **Notify tier:** sev1 bridge classifies guard-trip as `notify` (never overlays) — Zone 6 rides the same path.
- **Backup safety during guard-stopped btrbk:** dump backups are NOT churn units — live evidence during the active trip window showed all backup ages fresh (13-17h); btrbk snapshot aging is covered by the Snapshot Canary (>3d) + incremental-resume semantics.
- **NEW CODE (deploy-pending):**
  - guard emits `memory_emergency_guard_churn_units_stopped{unit="…"}` + `churn_stopped_timestamp_seconds` (renamed from the TODO's zone6_ prefix — churn units stop on ANY zone's trip; a zone6_ prefix would lie about when it fires). State: `${stateDir}/churn-stopped` (epoch + units ACTIVE pre-stop only), emitted during the io-drain window, cleared on the first run under the trip threshold (clear-before-read: no stale final emission — the VM test caught that ordering bug on its first run).
  - guard emits `memory_emergency_guard_last_run_timestamp_seconds` (freshness stamp).
  - guard textfile write converted fixed-`$OUT.tmp` → mktemp+trap (the allowlisted-instance cleanup AGENTS asked for on touch).
  - system-health emits `system_memory_guard_metrics_fresh` (guard .prom mtime vs 300s) + new gated Gatus check **"Memory Guard Collector Fresh"** — closes the guard-death phantom-green: the old check's "absent metrics" premise is WRONG for textfile collectors (node_exporter serves frozen content forever).
  - btrfs-health emits `btrfs_scrub_deferred_by_guard` / `btrfs_scrub_errors_present` / `btrfs_scrub_incomplete_unexplained`; old "BTRFS Scrub Health" check split into "BTRFS Scrub Errors" + "BTRFS Scrub Incomplete" (the error_free composite red on every RUNNING scrub and on guard-deferred interruptions).
- **Calibration (item §c.2):** verdict UNCHANGED. 99 real trips in ~1.5d all corroborate genuine danger; forensics bundle 2026-09-15T16:01Z (avg60 79.87%, load 84): `usb-storage` wedged in `usb_sg_wait`, D-state `blk_mq_get_tag` on the DAS flush thread, user-session crush processes dominating cgroup io.stat — the DRIVERS are crush-DB QLC churn + the stalling single USB DAS link, not the churn units the guard stops. Evidence + thresholds: `docs/services/memory-emergency-guard.md` (new runbook).
- **VM test (fresh evidence):** `heavy-job nix build .#checks.x86_64-linux.memory-emergency-guard` exit 0 with EXTENDED assertions (trip records stopped units, drain clears them, phantom trip reports nothing, timestamp always present). gatus-pattern-lint + gatus-patterns also green.

## b. Post-push verification (10:45 section)

- **CI is NOT green — three root causes, two fixed:**
  1. `art-dupl` input was `git+file:///home/lars/projects/art-dupl?rev=…` — broke EVERY CI eval (`Git repository … does not exist`: flake-check VM tests AND go-deps-audit input evals, `FATAL: nix eval of input outPaths failed`). **Fixed:** flipped to `git+https://github.com/LarsArtmann/art-dupl?ref=refs/heads/fork&rev=9c370324…` — the flip condition in the old comment is satisfied (origin/fork contains the rev); locked narHash is byte-identical (`2+XqErGW…`) so zero consumer churn. Trap found en route: a bare `github:<owner>/<repo>/<rev>` URL fails to LOCK (nix's tarball→git-tree import dies with a libgit2 tree-builder error on this repo) while `nix flake prefetch` of the same ref succeeds — the real git+https clone path is the working form.
  2. shellcheck SC2218 `scripts/migrate-clickhouse-xfs.sh` (`die` used at line 42, defined at ~60) — fixed by moving the color/helper definitions above the disk-resolution block; shellcheck + bash -n pass.
  3. Secret history scan red = KNOWN history blobs (Context7 key in old AGENTS.md versions). **New discovery:** the purge runbook itself carried the FULL literal of all three keys IN-TREE (`printf 'ctx7sk-a5b19……'`) — the repo's own forbidden pattern, re-exposing the still-live Context7 key in a public tree. Runbook redacted to interactive placeholders; history hits remain purge-owned (documented nag).
- **Secret-scanning alerts:** Sourcegraph alert already `resolved`; the 1 open Resend alert is the KNOWN 2026-07-18 key, revoked 2026-08-18 — closing it is a one-click owner action (not agent-executed: account-gated).
- **Post-hoc scan:** `scan-history-secrets.sh` over 16389 blobs — FAIL is the expected nag state; hits are all KNOWN dead/rotated-pending keys; NO new material.
- **`.tq-verify` rails:** committed in both CV (`a680b25d`, `12853428`) and go-taskqueue (`57b6a75`); both trees clean.
- **Git corruption:** `git fsck --full` clean; the formerly-wedging `4f0b9081` is a valid commit — recovery confirmed LIVE. `core.fsync` IS in `platforms/common/programs/git.nix:33` but NOT in the deployed `~/.gitconfig` — needs the next HM deploy (owner-gated).
- **Closeout reports on origin:** 10:45 + 11:05 reports both ls-tree-verified on fresh origin; `17acfe3d` itself dangles (content carried up by a later rebase).

## c. Conventions (06:10/07:32 sections)

`docs/CONTRIBUTING.md` gained a "Verification conventions" section: the **3-step probe** (code-exists → regression-test-executed → deployed-parity; eval-cache hit ≠ execution), the **git-transcript rule** (git-state claims carry command+output evidence at write time), and **citation hygiene** (reachable SHAs; dangling citations annotated with counterparts). AGENTS.md module-location: guard/sev1/system-health/workload-admission explicitly under `modules/nixos/services/`.

## d. Second-scanner guard (item 28)

`scripts/audit-push-protection-literals.sh` shipped: rejects tracked `sgp_`/`sq0atp-` + 40-char literals (GitHub pattern-matches raw blobs, ignores gitleaks allowlists). Selftest composes its negative-case tokens at RUNTIME so the scanner cannot flag itself (first draft flagged its own fixtures — the runtime-composition fix is itself the pattern for future selftest authors); asserts Files>0 fail-closed (gosec lesson). Wired into `.githooks/pre-commit` + `nix-check.yml` (selftest + scan). Both remaining literal fixtures templated to `@HEX40@`; mutation harness updated; both mutation semantics verified live (drift → "no leaks found", corrupt → 1 leak); `gitleaks-coverage-selftest` rebuilt GREEN.

## e. Not done / honest gaps

- **Full `nix flake check` re-verify:** blocked ALL session by the parallel session's mid-flight WIP (their eval error, not ours). Targeted checks all green; the toplevel eval must be re-run at quiescence BEFORE the next deploy.
- **Zone 6 metrics deploy-parity:** everything in §a's NEW CODE is step-2 evidence only — deploy is owner-gated (BLOCKED row).
- **Upstream go-taskqueue items** (queue-level claiming/dedup, stderr-to-file hygiene, corrupted-repo requeue lane, enqueue-time reachable-SHA check): NOT started — upstream repo work, several rows self-describe as needing design decisions.
- **footer-commit / empty-footer-commit contract rows:** BLOCKED (owner decisions) — untouched.
- **nix-email settled check:** the owning session was ACTIVELY editing those files during this session — left untouched per shared-tree doctrine.
- Stale textfile tmp leftovers observed in `/var/lib/prometheus-node-exporter/textfile_collectors/` (`niri.prom.tmp`, `*.prom.XXXXXX` orphans from SIGKILLed runs) — cosmetic (node_exporter ignores non-.prom), noted for a future sweep.
