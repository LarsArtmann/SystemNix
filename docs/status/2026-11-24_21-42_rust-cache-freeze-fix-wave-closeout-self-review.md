# Rust-Cache Freeze-Fix Wave: Close-Out + Self-Review

**2026-11-24 21:42 CET · Crush agent (GLM-5.3) · closes the session opened by "why does Crush in printer-monitor crash my PC" → "make sure this never happens again"**

Supersedes the §b "eval not yet run" state of `2026-11-24_21-58_rust-cache-full-four-freezes-cargo-gate-usage-triggered-gc.md` — the module eval + rendered-script shellcheck COMPLETED (details in §a.7).

---

## a) FULLY DONE (verified this session)

1. **Forensics** — freezes #60-#63 attributed (reset registers from retained next-boots: WDT ×2, software-CF9 ×2); #63 end-to-end (cargo test → full USB disk → cut 8 min later); #61/#62 zero printer-monitor activity (baseline pathology); ledger rows #59-#63 landed in `docs/agents/stability.md` (the table had ended at #56 — #57/#58 flagged as pre-retention gaps).
2. **cargo-gate** (`platforms/common/programs/cargo-gate.sh`) — deployed to `~/.config/direnv/bin/cargo` via `direnv.nix` (`executable = true`, pattern already proven at home.nix:546); PATH-prepend in `direnv-smart-lib.sh`; re-prepend after `use flake` in monitor365 + printer-monitor `.envrc` (both committed by the daemon). **All three legs live-tested with a fake cargo**: disk (refused rc=125 at 100%), PSI (refused, correct storm text), thermal (refused at 98 °C); passthrough (metadata), escape (`RUST_BUILD_GATE=0`), and `+toolchain` forms verified; shellcheck clean.
3. **Usage-triggered GC** — `lib/cache-ssd.nix` metricsScript (optional `criticalThreshold`/`reclaimFlagPath`/`reclaimThreshold`, null-safe for buildcache); `rust-cache.nix`: `criticalThresholdPercent` option (95), busy-builder guard, 6h `.gc-stamp`, Leg 1.5 fingerprint-orphan sweep (pass 1 `-mmin +120` race floor), `rust-cache-reclaim.path` (PathChanged → `rust-cache-gc.service`, no RemainAfterExit), gatus "Rust Cache Critical" + de-fanged 85% advisory.
4. **Live headroom** — target-gc dry-run (12,800 orphans / 30,259MB) then `--apply`: disk 100%/2G → **90%/25G**.
5. **Docs/TODOs** — status report (21-58), storage.md rust-cache contract bullet, CHANGELOG entry, TODO rows synced both surfaces (deploy row extended with 11-24 verify legs; port row ticked [x]; envrc-coverage-gap row added), AGENTS.md freeze rules in monitor365 + printer-monitor.
6. **Commits** — everything landed (daemon commits `ff907e037`/`6d95b97e4`/`8c6d2f4f2` + explicit `47421770d`); trees clean in all three repos; foreign commits on top identified, untouched.
7. **Module eval + rendered-script proof (21:3x-21:4x)** — throwaway `--impure` getFlake eval (never touched the tree): module merges, `pathUnit.Unit = rust-cache-gc.service`, trigger `/run/rust-cache-reclaim.flag`, wantedBy multi-user, GC User=lars, **RemainAfterExit unset** (class-11 rule), `criticalThresholdPercent = 95`; rendered script bodies extracted (GC 6,794 chars, metrics 2,620) — **shellcheck clean both**, with orphan pass-1 ×2, busy-guard, stamp, flag ×2, `usage_critical` ×3 all present in RENDERED text. Harness needed a `services.integration` stub (the module's `options ?` guard assumes the sibling — fine in the real tree, which passed flake check twice on Nov-18).

## b) PARTIALLY DONE

1. **The whole nix wave is IN-TREE, UNDEPLOYED** — gate/trigger/CRITICAL-check live only after `nix run .#deploy` + HM activation. Blocked by: (a) the box (Tctl 75-99 °C, PSI 34-64% through the session — no deploy windows taken); (b) the FOREIGN modloc wave (CHANGELOG 11-24: evo-x2 eval red-by-design until the nixos-modules lock float — lock still at `1bb7c82e`, float target d1980f3+ unverifiable without fetching). Deploy checklist lives in the extended TODO row.
2. **Full `nix flake check` not run** — the minimal module eval + rendered shellcheck substitute for MY surfaces; the fleet audits (systemd-shape, gatus-coverage, tile) still need the real check at the deploy.

## c) NOT STARTED (rows exist)

Fixture tests for gate + orphan leg (storage.md row) · `.envrc` sweep for the other ~12 Rust repos (row) · GC/provisioner counters + staleness check (Nov-18 row) · `docs/services/rust-cache.md` runbook (Nov-18 row) · monitor365 shrink levers (owner direction, unimplemented) · freeze #60-62 evidence pulls (NEW row, §f) · idle-99°C thermal escalation watch (NEW row, §f).

## d) TOTALLY FUCKED UP (honesty ledger)

1. **Two false-green gate tests in a row**: first test prepended the wrong dir (script not named `cargo` → fake cargo won); second forgot `chmod +x` (PATH skips non-executables). A passthrough "pass" proved nothing — caught only because I re-ran with the correct name+mode and asserted the REFUSAL path. Rule going forward: a wrapper test must assert both directions in the same harness.
2. **Hand-mangled glob escaping** in Leg 1.5 pass 3 (`'"'"'*"'"'` garbage written into the nix string) — the Nov-18 report documents this exact `''`-trap class; caught by edit-anchor mismatch + fixed immediately, but it shouldn't have been written at all (write the bash first, then interpolate).
3. **`rg -r` trap hit twice** (hook-blocked both times) — the repo documents this as a repeated-session killer; still typed it.
4. **First eval attempt forgot `--impure`** for `getFlake path:` — burned a cycle on a flag.
5. **Second eval attempt lacked the `services.integration` sibling stub** — burned another cycle; the `options ?` guard is minimal-eval-blind (worth a one-line note in the safe-verification recipe doc).
6. **Extracted `serviceConfig.ExecStart` (the 100-char wrapper) instead of `.script`** — grep counts of 0 looked like missing legs; re-extracted before drawing conclusions. Adjacent to the house rule "assert WHICH entity served it".
7. **Turn-1 phrasing overstated** "the rust-cache-full condition is invisible to the prevention layers" — the 85% alert EXISTED and fired; the real gap was alert fatigue + no automated action. Corrected mid-session after reading the checks.
8. Minor: typed `mount` (yolo-guard blocked, v0.101.0 behavior), monitor365 `.envrc` write before View-tool read, ledger edit anchored on a view-truncated line — each burned one cycle.

## e) WHAT WE SHOULD IMPROVE

- **Render-then-write for embedded scripts**: extract a rendered skeleton (or keep the logic in a standalone .sh like monitor365's target-gc) instead of hand-writing `''`-escaped bash inside nix — the Nov-18 lesson, now repeated by me.
- **Standing-red alerts need a distinct escalation tier by design** — the 85% alert masked the cliff for days; generalized rule worth adopting for every long-lived advisory check.
- **Entry-point gating beats post-hoc cleanup** — the wrapper is the only layer that acted at the moment of the freeze trigger; the same pattern could wrap other foot-guns (but deploy gates + BuildFlow EnvGuard already own nix/go).
- **Wrapper test harness recipe**: name+chmod in one step, assert refusal AND passthrough, keep it in ~/.cache for reuse until the fixture row lands.

## f) NEXT (session-harvested where actionable)

1. Deploy the wave at the first calm window (row, extended with verify legs) — after the modloc lock float clears.
2. Full `nix flake check --no-build --all-systems` (rides the deploy row).
3. Post-deploy: `~/.config/direnv/bin/cargo` exec-bit + live refusal in monitor365 + `direnv allow` in both repos.
4. Post-deploy: `rust-cache-reclaim.path` SubState `waiting`; touch the flag → GC fires → `.gc-stamp` written.
5. Post-deploy: gatus "Rust Cache Critical" evaluating (endpoint count 321 per foreign commit).
6. Fixture tests: cargo-gate (subcommand classify, 3 refusals, escape, PATH-skip) + GC Leg 1.5 branches (row).
7. `.envrc` sweep for the remaining ~12 linked Rust repos (row).
8. GC/provisioner counters → `.prom` + staleness check (row).
9. monitor365 shrink levers: libduckdb-sys feature-variant collapse (owner direction 11-18).
10. monitor365: `incremental = false` dev-test profile lever.
11. `docs/services/rust-cache.md` runbook (row).
12. Freeze #60-62 evidence pulls before journal vacuum ages the boots out (NEW row).
13. Idle-Tctl escalation watch: 99.25 °C measured with NO builds running (NEW row — beyond the documented load~20 shape).
14. BIOS fan-curve walk (owner-gated residue of the waived-cooling verdict).
15. `target.migrated-*` reaping policy (Nov-18 item).
16. Samsung-placement prep only if the regrowth [watch] row trips post-fix.
17. Add the `services.integration` stub + `--impure` note to the safe-verification recipe in docs/agents/nix-flakes.md.
18. Consider a tiny selftest harness committed under scripts/ for wrapper two-direction tests (fold into item 6).

## g) OWNER QUESTIONS (cannot be answered from here)

1. **Deploy bundling**: fire this wave at the next calm window on its own, or hold it behind the modloc lock-float wave (foreign, currently red-by-design)?
2. **Capacity endgame**: implement the monitor365 shrink levers now (feature-variant collapse + incremental=false — your 11-18 direction), or revisit placement (Samsung ~490G) given demand ~265G vs 224G?
3. **Thermal**: idle Tctl hit 99.25 °C with no builds this session — is the BIOS fan-curve walk (one setting per boot, the waived-verdict's remaining lever) worth scheduling?

## References

Incident report: `2026-11-24_21-58_…` · Capacity arc: `2026-11-18_07-04_…` · Ledger: `docs/agents/stability.md` #59-#63 · Contract: `docs/agents/storage.md` rust-cache section.
