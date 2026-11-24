# Rust-Cache 100%: Four Freezes (#60-63), Cargo Gate, Usage-Triggered GC

**2026-11-24 ~21:58 CET · Crush agent (GLM-5.3) · trigger: owner ask "why does running Crush in printer-monitor crash my PC" → "make sure this never happens again"**

---

## Verdict

Four crash-class cuts in three days (Nov 22 20:48 → Nov 24 20:44). One is causally attributed end-to-end (#63 — cargo test writing into a 100%-full `/mnt/rust-cache` on the external USB SSD while compiling libduckdb-sys all-core); two had ZERO printer-monitor session activity (the box's documented ~1.1/day baseline); one (#60) ran a session in-window without full attribution. The disk-full condition was standing for days under an 85% Gatus alert that had been red since ~Nov 22 — alert fatigue, not missing telemetry. Demand (~265G) exceeds supply (224G); the Nov-18 owner clean (92%→31%) regrew at ~28G/day.

Fixes landed this session (in-tree, deploy pending): a `cargo` gate wrapper (entry-point refusal on full disk / IO storm / hot Tctl), usage-triggered fingerprint-aware GC, a distinct 95% CRITICAL alert tier, and 30G of headroom reclaimed live.

## a) FULLY DONE / VERIFIED

1. **Forensics** — journal-cut timestamps + reset registers for all four cuts pulled from retained boots (`0x02000800` WDT ×2, `0x00080800` software-CF9 ×2); #63's chain: 20:25:52 `cargo test -p monitor365-server` (parent `crush -y`, session `65814e2d`) → 20:34 session probe `/mnt/rust-cache` 96%/11G free → 20:36:36 session died of zai 429s, compile continued → 20:44:18 cut; disk 100%/2G free at next boot, `rust/monitor365` = 201G.
2. **cargo-gate** (`platforms/common/programs/cargo-gate.sh` → `~/.config/direnv/bin/cargo` via `direnv.nix`; PATH prepend in `direnv-smart-lib.sh`; re-prepend after `use flake` in monitor365 + printer-monitor `.envrc`). Gates compile-type subcommands only (metadata/fmt pass through — rust-analyzer safe); refuses on target-fs ≥92% or <10G free, io-PSI some avg10 ≥60, k10temp ≥90°C; `RUST_BUILD_GATE=0` escapes. **Live-tested with a fake cargo**: refusal rc=125 with actionable text at today's 100% disk, passthrough + escape + `+toolchain` forms verified; shellcheck clean both scripts.
3. **Usage-triggered GC** — `lib/cache-ssd.nix` metricsScript gains optional `criticalThreshold` metric + `reclaimFlagPath`/`reclaimThreshold` (flag touched/removed by the 5-min scrape); `systemd.paths.rust-cache-reclaim` (PathChanged on `/run/rust-cache-reclaim.flag`, `Unit = rust-cache-gc.service`, no RemainAfterExit — the class-11 deaf-trigger trap respected); GC script gains the busy-builder pgrep guard, a 6h `.gc-stamp` rate limit, and Leg 1.5: the fingerprint-orphan sweep ported from monitor365 `scripts/target-gc.sh` (pass 1 artifacts-without-fingerprint `-mmin +120`, pass 2 reverse orphans, pass 3 unreferenced build dirs).
4. **CRITICAL alert tier** — new "Rust Cache Critical" gatus check (95%, 5m interval, page-now wording); the 85% "Rust Cache Usage" alert reworded to standing-state advisory.
5. **Live headroom** — `target-gc.sh --apply` on monitor365 (dry-run first: 12,800 artifact orphans / 30,259MB): applied post-dry-run, cargo-idle-gated.
6. **Ledger** — freeze rows #59 (backfill from its report), #60-#63 appended to `docs/agents/stability.md`; #57/#58 flagged as pre-retention gap.

## b) PARTIALLY DONE

1. **Everything nix-side is IN-TREE, UNDEPLOYED** — gate script, direnv wiring, GC/path unit, gatus checks all need `nix run .#deploy` + HM activation; extend the standing deploy row (docs/todo/storage.md rust-cache waves) rather than racing the still-warm box (PSI 39-64% through this session; k10temp 87°C at boot).
2. **Eval not yet run** — the box never cooled below the no-heavy-eval line this session; targeted `nix eval` toplevel drvPath queued for the first calm window, full check rides the deploy.
3. **The wrapper only guards direnv-enabled shells** — monitor365 + printer-monitor covered via `.envrc`; the other ~12 linked Rust repos without `.envrc` are ungated (sweep row queued).

## c) NOT STARTED (queued as rows)

1. GC/provisioner counters + staleness checks (the Nov-18 arc's not-started item, still open).
2. monitor365 upstream shrink levers (feature-variant collapse, `incremental=false` for dev tests) — the actual capacity fix; owner verdict already chose this direction 2026-11-18.
3. Fixture/selftest for cargo-gate + the GC orphan leg (SystemNix fixture doctrine).
4. Samsung-placement prep (only if the [watch] regrowth row trips again post-fix).

## d) HONESTY LEDGER

- The first functional test of the gate PASSED THE BUILD THROUGH — the test harness prepended the wrong dir (the script must be NAMED `cargo` and executable to shadow; repo source is 644, HM sets executable). Caught by re-test with the correctly-named +x copy; the deployed path sets `executable = true`.
- #60 is attributed as "session ran in-window", NOT causally — no disk-state probe exists at its death minute; the row says so.
- Regrowth rate (~28G/day) is inferred from two points (11-18 clean at 31%, 11-24 at 100%), not a measured curve.

## e) References

- Ledger: `docs/agents/stability.md` freeze rows #59-#63 · Capacity arc: `docs/status/2026-11-18_07-04_rustcache-capacity-arc-storm-triage-upstream-gc.md` · target-gc: monitor365 `scripts/target-gc.sh`
