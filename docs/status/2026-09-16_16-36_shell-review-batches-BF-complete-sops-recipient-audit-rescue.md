# Shell-Script Review: Batches B–F Executed, Born-Broken sops-recipient-audit Check Rescued, Repo Eval Green Again

**Session:** 2026-09-16 ~14:30–16:36 · **Scope:** completion of the 79-script review (handoff from `2026-09-16_14-04_*`) — Batches B/C/D/E fixes + Batch F verification + an unplanned root-cause rescue of a parallel session's eval-breaking check · **Repo at start:** clean @ `65e473a1` (all prior edits verified surviving)

---

## a) FULLY DONE (this session)

### Batch B — live gates/daemons (completed, was ~60%)

- **`scripts/post-deploy-check.sh`** — (1) `journalctl|wc -l || echo 0` double-output (`"0\n0"` under pipefail — journalctl exits 1 on zero matches while wc already printed 0) → `|| true` + `timeout 30`; (2) same class on the PapDashboard ingest curl (`-w %{http_code}` ALWAYS prints 000 on failure → `|| echo 000` double-emitted) → `|| true`; (3) `monitor.$DOMAIN` vHost probe enable-gated on `monitor365-server.service` existing (was a permanent 000-SKIP since monitor365's 2026-08-12 disable).
- **`scripts/pre-reboot-check.sh`** — (1) `env PATH="$PATH"` on the sudo re-exec (secure_path was stripping the wrapper's runtimeInputs → downstream btrfs/nix probes dying into `2>/dev/null` = phantom-green); (2) numeric `loader.conf` `default N` treated as a menu INDEX (warn + in-range check + strict §3 audit) instead of a false "entry file missing" REBOOT BLOCKED — fixture-tested both branches (index 2 of 3 → warn; index 9 of 1 → FAIL); (3) XDG_STATE baseline-path contract documented (writer default == reader glob today; latent only).
- **`scripts/verify-deployment.sh`** — (1) boot-time extraction now takes the duration after the LAST `=` and handles `Xmin Y.YYYs` (old code reported the FIRMWARE leg as "boot time"; live-verified: `12min 3.662s` → `723.7s`); (2) `--max-time` on all 7 curls; (3) both `wc -l || echo "0"` double-output sites → `|| true`; (4) `/mnt/btrfs-root/@snapshots` → `.snapshots` (the audit path NEVER existed — snapshot staleness was never checked).
- **`scripts/lib/pressure-report.sh`** — `# shellcheck shell=bash` directive (completes the lib/ pair).

### Batch C — diagnostics (16 scripts)

- **`scripts/health-check.sh`** — failed-unit `grep -c || echo "0"` double-output (every CLEAN run previously false-failed with an integer-expression abort); `head -5 | while` SIGPIPE guard; **HM age check re-rooted**: `/nix/var/nix/profiles/per-user/$USER/home-manager` does not exist on this box at all, AND any store-path stat reads mtime=1 (deterministic builds) → the "20706d old" permanent WARN mechanism; now lstat's the `/etc/profiles/per-user/$USER` symlink (recreated every activation — live: `0d old`); platform-aware toplevel eval (Darwin attr on Darwin). Full live run: clean exit, no false findings.
- **`scripts/internet-diagnostic.sh`** — summary now reuses the §4-parsed gateway (the `GATEWAY` var was NEVER set — always pinged hardcoded 192.168.1.1, wrong on hotspot failover, this box's actual failure mode); retired dual-WAN stack (route-health-monitor/mptcp/unbound) replaced with the LIVE architecture (wifi-failover + dnsblockd); ECMP check → wlan0-standby detection; emergency commands rewritten (deprecated `just wan-status` removed). **Live run: 10/10 checks pass on a healthy box — the script was permanently red before.**
- **`scripts/nixos-diagnostic.sh`** — `nixos-rebuild check` (nonexistent subcommand → ❌ on every healthy system) → `dry-build`; `nix flake check --quiet` → `--no-build`; 3 raw `nixos-rebuild switch` advice lines → `nix run .#deploy` (repo doctrine).
- **`scripts/das-link-recovery-check.sh`** — `scan_boot "-b -1"` single-argv → two-arg call. ⚠ CORRECTION: the original finding was OVERSTATED — systemd 261's journalctl accepts the single-string form (verified both select the previous boot identically); fix kept as the unambiguous idiom.
- **`scripts/usb-diagnostic.sh`** — explicit device arg REQUIRED (was defaulting `/dev/sda`); partition suffix probes `p1` for nvme; `timeout` on fuser/lsof/smartctl (this script runs DURING wedges — an unbounded probe hangs the diagnostic itself); `journalctl -k -b` (was unbounded cross-boot scan); anchored `-w` greps.
- **`scripts/dns-diagnostics.sh`** — blocking test now VERDICTS instead of accepting any answer: private/sinkhole IP = blocked (dnsblockd answers 192.168.1.200 live), PUBLIC IP = "blocking is OFF or blocklist failed to load" (the old check called ANY answer "blocked" = phantom green); via-less default-route parse guard (was extracting the DEVICE name as gateway); `--max-time` on the :9090 stats curl (the documented wedge class); FAILS counter + exit contract (was always exit 0).
- **`scripts/hermes-state-audit.sh`** — 3 `du|sort|head` SIGPIPE guards (under pipefail the audit died before sections 2–4 ever ran).
- **`scripts/hdd-vibration-check.sh`** — `smart()` wrapper gained `timeout 30` (covers every call site).
- **Retired-stack banners (non-destructive, per handoff decision):** `route-health-monitor.sh`, `mptcp-endpoint-manager.sh`, `diagnose-mullvad.sh`, `check-mullvad-nft.sh` + `check-firewall.sh` mullvad section relabeled + "unbound listening sockets" → dnsblockd.
- **`scripts/display-watchdog.sh`** — DESIGN fix: the 3-strike ladder reset itself at threshold → infinite niri/display-manager restart loop on a permanently dead display; new `state_exhausted` guard stops interventions after exhaustion (only a genuinely recovered display clears the counter); corrupt state file sanitizes to 0 (was a set -e arithmetic crash → unit start-limit); `timeout` on loginctl×3/systemctl×2. State machine stub-tested (garbage/empty/3/2 cases).
- **`scripts/niri-drm-healthcheck.sh`** — same once-only semantics (restart EXACTLY once at threshold, counter persists — was restart-every-~2-min on persistent wedge); `read_count` sanitize; journalctl/loginctl timeouts. Stub-tested.
- **`scripts/dnsblockd-goroutine-dump.sh`** — NEW dump-capture verification step: greps the journal for Go's `SIGQUIT: quit` signature after the kill (journald rate-limiting can silently drop multi-MB stack bursts — without this the runbook reported success while the forensic sample, its entire purpose, was lost); exit 1 on lost dump; fixed its own `curl || echo 000` / `wc || echo` double-output sites.
- **`scripts/io-psi-forensics.sh`** — the one unbounded `find /sys/fs/cgroup` now `timeout 30` (runs during IO storms).

### Batch D — quality gates (7 core, all CI-relevant)

- **`scripts/scan-history-secrets.sh`** (CI-wired) — added `github_pat_` fine-grained PAT (hermes consumes exactly this class; gitleaks' `gh[pousr]_` misses it), `glpat-`, `sk_live_` patterns — each pattern-tested (detect-real ✓, no-placeholder-FP ✓) and **history re-scanned: zero new hits** (CI noise unchanged; the scan is red-by-design until the held purge push); oversized-blob skip now prints a WARN (1 blob visible).
- **`scripts/test-home-manager.sh`** (CRITICAL phantom-green) — all 18 ⚠️-only assertions now increment a `TESTS_WARN` counter (mirrored-indent mechanical transform) and the exit contract fails on ANY warn; **negative-tested: empty-HOME run now exits 1 (was 0 with HM entirely un-deployed)**.
- **`scripts/test-shell-aliases.sh`** — anchored `^[[:space:]]*alias([[:space:]]+--)?[[:space:]]+name=` matching (the old `alias.*l` substring matched ANY line whose name/command contains an "l" — nearly vacuous; discovered the deployed configs use HM's `alias -- ga=` form and extended the anchor). Suite honestly green 33/33; regex negative-proven (alias hello ≠ alias l).
- **`scripts/validate-gomemlimit.sh`** — all-SKIP run now FAILS (typo'd service list was indistinguishable from "no limit needed"); unit-not-found detected via LoadState (list drift WARNs instead of silently SKIPping). All three paths exit-tested.
- **`scripts/check-image-updates.sh`** (CI-wired) — `checked==0` now FAILS (parser drift was green); Docker Hub tag pagination (5×100 pages — tags sort by last_updated, not version, so page 1 could make a stale tag look "latest"). **Live run found REAL drift: twenty v2.32.0 → 2.40.2** (correctly reported; DB-backed app = migration-gated, not auto-bumped).
- **`scripts/check-flake-inputs.sh`** — hard-fails outside the repo (the `|| echo .` fallback made every grep `|| true`-green in any directory); ref=master section reworded to INFORMATIONAL per the ratified 2026-09-16 pin policy (branch-refs are the sanctioned default); excluded the fish session-guard `set -gx GOTOOLCHAIN auto` from the purity check (pre-existing false positive on master, live-verified cleared).
- **`scripts/check-doc-links.sh`** — %20 handling direction FIXED (was ENCODING spaces → tested for files literally named `my%20doc.md` → false BROKEN on every valid spaced link; now DECODES); zero-files-scanned fails. Proven: valid-%20-link → 0, broken-link → 1, real repo → green.

### Batch E — misc

- **`scripts/update-vendor-hash.sh`** — project loop is while-read (spaced keys no longer word-split into set -u crashes). Stub-tested with spaced keys.
- **`scripts/status-report.sh`** — `is-active || echo unknown` double-output ×2 (is-active PRINTS its verdict and exits nonzero — assignments now keep its own output); generations `wc -l || echo` same; platform-aware toplevel eval; retired `unbound` dropped from the service table.
- **`scripts/samsung-nix-sync.sh`** — `lsblk` added to the binary preflight — **it is load-bearing**: under sudo's secure PATH a missing lsblk yields EMPTY disk names, the 5s deltas compute `0-0=0`, and the pressure gate passes "disks-idle" with NO measurement taken (phantom-green on a safety gate); `--final` failure paths now re-start `nix-gc.timer` in the EXIT cleanup (a mid-sync `die` previously left GC silently dead forever).
- **`scripts/samsung-prepare.sh`** — `die` uses `%b` (callers embed `\n`; `%s` printed literal backslash-n).
- **`scripts/data-corruption-repair.sh`** — `/dev/nvme0n1p8` fallback → by-uuid-or-DIE (nvme enumeration flips; the fallback could btrfs-check the WRONG partition); the 3 `dd count=100000` caps removed (~400 GiB/file silent verification cap — a repair tool must read whole files); scrub wait loop bounded at 8h with `timeout 30` status probes (the kernel ioctl-wedge class looped forever); `|| true` on the status capture.
- **`scripts/pocket-id-login-code.sh`** — transport failure now distinct from "no admin found" (the old `|| true` conflated API outage with absent data) + `--max-time 10`.
- **`scripts/verify-io-tiers.sh`** — scheduler check derives the ROOT disk via findmnt+lsblk (was hardcoded nvme0n1 — enumeration flips); boolean exit contract (was `exit $FAIL` — a count is not a status code). Live: resolves nvme0n1, BFQ ✓.
- **`platforms/common/programs/direnv-smart-lib.sh`** — shellcheck directive.

### Batch F — verification (GREEN)

- `bash -n`: **80 tracked .sh files, 0 failures**.
- shellcheck `-S error`: CI-parity glob (scripts/*.sh + .githooks/*) **PASS**, `scripts/lib/` **PASS**.
- **8/8 fast selftests green** (pre-deploy-metrics, shell-aliases, direnv-smart-lib, post-deploy-pressure, nullglob, textfile-tmp, serviceconfig-merge ×2 phases, templ-committed).
- `nix flake check --no-build`: **ALL CHECKS PASSED** — but only after the unplanned rescue below.

### Unplanned: rescued the born-broken `sops-recipient-audit` check (see §d)

`modules/nixos/services/sops-recipient-audit.nix` (new module + test landed 2026-09-16 via parallel-session commit `4a4eeb73`) hard-broke EVERY `nix flake check`/eval touching `config.assertions`. Root-caused and fixed (3 stacked bugs, details in §d); the check's 5 test cases now all pass and the full flake check is green. Base commit `65e473a1` verified clean in a worktree first (proving the breakage was new, not mine).

### Also

- **TODO_LIST item (3) ticked** — p8/p9-era disk-script tombstones marked DONE inline (with rationale + status-doc pointer).

---

## b) PARTIALLY DONE

- **Batch D tail (lower-priority gate hardening — reviewed, fixes NOT applied):** `audit-go-deps.sh` (timeouts + zero-audited fail + skipped-input WARN), `negative-test-lints.sh` (per-case timeout + rsync preflight), `report-goexperiment-gaps.sh` (test-only importer misclassification), LOW audit refinements (nullglob trailing-space class-A, textfile-tmp substring allowlist, serviceconfig-merge URL-strip, doc-freshness over-count), `crush-rc-test.sh` timeout + `--probe` guard, `validate.sh` absolute flake ref + timeout, `test-post-deploy-pressure.sh` fail-path fixture.
- **Wifi-failover daemon fix:** functionally stub-tested (previous session); the VM test (`tests/test-wifi-failover.nix`) still not run.
- **`docs/status/2026-09-16_14-04_*` backlog items 41–50** (systemic improvements — see §e/§f).

---

## c) NOT STARTED

- `scripts/negative-test-lints.sh` full pass (heavy nix builds).
- `tests/test-wifi-failover.nix` VM test run.
- CI shellcheck severity bump to `-S warning` with ignorelist (item 41).
- New static audit for the `cmd || echo "0"` double-output class (item 42 — 6+ live instances fixed by hand this session; nothing prevents regressions).
- Kernel-device-name (sdX/nvmeXnY) audit rule for scripts/ (item 43 — 5 sites fixed by hand).
- AGENTS.md gotcha entries for the two NEW trap classes discovered this session (see §e.1/§e.2) — deliberately deferred to this report + next steps per "report and wait".
- Retire-or-fix decision sweep for `platforms/nixos/scripts/service-health-check` (item 46); `legacy/` policy (item 47).
- twenty Docker image drift v2.32.0 → 2.40.2 (found live by the repaired checker; migration-gated per DB-backed-app doctrine).

---

## d) TOTALLY FUCKED UP (found-and-fixed, incl. my own)

1. **The parallel session's `sops-recipient-audit` check was BORN BROKEN — three stacked bugs, never green once:**
   - **(a) Nix 2.34.8 list-literal parse quirk (the eval killer):** `refs = … ++ [ builtins.head (ruleRef l) ]` — an UNparenthesized application inside a list literal parses as TWO list elements, so `refs` contained the primop `head` ITSELF. Forcing it died `cannot coerce the built-in function 'head' to a string`, breaking every flake check/eval (deploy-blocking class). Isolated with minimal probes (`[ builtins.head [ "x" ] ]` → two elements; attrset-value context → fine; paren'd → fine). Fixed with parens + explanatory comment; repo-wide sweep found exactly ONE instance of the pattern.
   - **(b) key_groups structural noise:** the line-based rule parser captured `- age:` (from the nested `key_groups: - age:` YAML shape) as a recipient ref → EVERY real secrets file flagged "MISSING recipients age:". Fixed with an `isRecipientRef` filter (only `*anchor` refs and literal `age1…` keys count).
   - **(c) Fixture bug:** `shared-ok.yaml`'s second recipient key was 68 chars vs the anchor's 64 → "conforming-file-falsely-flagged" could never pass. Fixture corrected to the exact anchor key.
   - Meta-lesson: the check's test cases were authored by reasoning and NEVER executed (the eval crash prevented any run). Landed via a daemon sweep; blocked every `nix flake check` from `4a4eeb73` until this session.
2. **My multiedit partial failure on display-watchdog.sh** (box-drawing chars in old_string) — 5 of 6 applied, leaving inconsistent state; caught by grep-verify, re-applied. Same class as the zfs-vm incident in the previous session — box-drawing lines in old_string remain my #1 multiedit failure mode.
3. **Inverted counter in my first dns-diagnostics edit** — the FAILS increment landed on `ok()` with a stray `;;`; caught on immediate re-read of the edit and fixed before any test ran.
4. **My own test harness bugs:** python bytes-pattern vs str-string TypeError; a first swap-check regex that couldn't match multi-column lines (previous session); repeated `$?`-after-pipe masking (tail/head/`ls` exit codes read as the script's) — bit me ~4 times before I switched to direct no-pipe exit checks. 
5. **Two throwaway repro .nix files had their own bugs** (out-of-bounds `elemAt`, toString-on-list) — cost debug rounds before I simplified the probes.
6. **One report finding was WRONG:** the das-link `"-b -1"` quoting bug doesn't actually fire on systemd 261 (both forms select the previous boot identically — proven live). Fix kept as the unambiguous idiom; the original HIGH rating was overstated.

---

## e) WHAT WE SHOULD IMPROVE (systemic, this session's evidence)

1. **Record the Nix 2.34 list-literal application parse quirk in AGENTS.md** — `[ f (args) ]` inside a list literal = TWO elements (the function itself becomes a list element); attrset-value context is unaffected. It is silent at parse time, detonates at force time, and produced a deploy-blocking eval crash from a plausible-looking line. Candidate: an eval-time/CI grep for `++ [ *.` unparenthesized-application shapes, or at least the gotcha entry.
2. **The `X=$(cmd || echo 0)` double-output class deserves a static audit** (like `audit-shell-nullglob`): grep -c / wc -l / curl -w / systemctl is-active ALL print their own zero/failure value before exiting nonzero — found in ≥6 scripts this session alone (post-deploy-check ×2, verify-deployment ×2, health-check ×2, status-report ×3, dnsblockd-goroutine-dump ×3, pap_ingest). Nothing prevents recurrence.
3. **Born-broken checks must be executed before landing** — the sops-recipient-audit test was authored but never run (its own throw never reached). The negative-test-lints meta-pattern exists for exactly this; new checks should be run through `nix flake check --no-build` IN THE SESSION THAT ADDS THEM. A pre-commit/CI quick `nix eval .#checks.<new-check>.drvPath` would have caught it at commit time.
4. **Fix application bugs in the owning session when possible, but eval-breakers block everyone** — a broken eval in shared surface (config.assertions) took down every parallel session's verification loop. Escalation rule: when a parallel-session commit breaks a shared gate, fix-forward immediately + flag loudly (done here).
5. **Exit codes after pipes lie** (recurring, bit me 4×): any `script | tail` verification reads tail's exit. The repo convention "verify raw summaries" should extend to "verify exit codes WITHOUT a pipe".
6. **Incident-time tools need timeouts more than happy-path ones** (recurring theme confirmed): smartctl/fuser/lsof/journalctl/systemctl/loginctl/find/curl without timeouts clustered exactly in the scripts you run DURING a wedge — all wrapped this session.
7. **Fixture keys must be byte-derived from the fixture anchors** (the 64-vs-68 char age key): fixtures should reference a single `let` constant or be generated, not hand-typed.

---

## f) NEXT (priority order)

1. AGENTS.md gotcha entry: Nix 2.34 list-literal application parse quirk (with the minimal repro).
2. AGENTS.md gotcha entry: `X=$(cmd || echo "0")` when cmd already prints its own zero → `"0\n0"` (grep -c, wc -l, curl -w, is-active).
3. New audit script `audit-shell-double-output.sh` (pre-commit + CI) for the §e.2 class.
4. CI: run `nix eval` smoke on every `checks.*` attr name in CI even when `--no-build` is used elsewhere (born-broken-check guard).
5. `audit-go-deps.sh`: timeouts on nix eval + git ls-remote; FAIL when zero inputs audited; WARN on skipped inputs.
6. `negative-test-lints.sh`: per-case timeout + rsync preflight; then RUN the full pass (not yet done).
7. Run `tests/test-wifi-failover.nix` (daemon fix still only stub-tested).
8. CI shellcheck `-S warning` with a small ignorelist (would have caught several of this session's classes pre-merge); include `scripts/lib/` and `platforms/**/programs/*.sh` in the lint glob.
9. Kernel-device-name audit rule for scripts/ (no sdX/nvmeXnY as defaults) — 5 sites were hand-fixed; guard the class.
10. `report-goexperiment-gaps.sh`: classify test-only importers correctly.
11. LOW audit refinements: nullglob trailing-space class-A, textfile-tmp exact allowlist, serviceconfig-merge URL-strip-not-drop, doc-freshness scoped `name =` count.
12. `crush-rc-test.sh`: timeout + `--probe` without model guard; `validate.sh`: absolute flake ref + timeouts.
13. `test-post-deploy-pressure.sh`: add a fail-path fixture.
14. twenty Docker image drift v2.32.0 → 2.40.2: migration review + bump (DB-backed app doctrine; found live by the repaired checker).
15. Retire-or-fix `platforms/nixos/scripts/service-health-check` (dead unwired file, stale unit refs).
16. `legacy/` directory policy: leave-as-history vs prune.
17. zfs-vm trio decision (attr stays in flake.nix?) — drives whether zfs-vm scripts stay maintained runbooks.
18. wifi-failover eviction → state-based reconcile (documented 2026-09-06 follow-up; needs VM-test update).
19. Consider extending the sops-recipient-audit parser to full YAML key_groups semantics (currently line-based with the isRecipientRef filter — adequate, but a future nested-only shape could need it).
20. Update `docs/services/*` runbooks touched by script behavior changes (internet-diagnostic emergency commands, dnsblockd-goroutine-dump new verification step + exit contract, display/niri watchdog once-only semantics).
21. Sweep remaining `curl` sites in scripts/ for `--max-time` (convention item 45; ~15 sites fixed ad hoc this session, a handful remain in LOW-priority scripts).
22. Post-deploy-check §12/§13-style smoke for the sops-recipient-audit guard? (eval-time only today — decide if it needs runtime teeth.)
23. Re-verify the 3 selftest scripts I modified still hold after any future formatter pass (`nix fmt` reflow could break the mirrored-indent warn transform in test-home-manager.sh — the transform is a one-shot, the RESULT is stable, but re-check after fmt).
24. Record in TODO_LIST: the sops-recipient-audit rescue (this session) so the owning session's docs cross-reference it.

---

## g) Questions (cannot resolve myself)

1. **Retired-stack scripts — delete or keep?** The mullvad pair, `route-health-monitor.sh`, `mptcp-endpoint-manager.sh` now carry RETIRED banners (non-destructive, per the interim decision). Delete them outright (git history preserves everything), or keep as standby tooling? Related: is the `zfs-vm` nixosConfiguration still wanted in flake.nix — it decides whether the zfs-vm scripts stay maintained runbooks? (Also still open from the prior session: tombstone vs delete for the p8/p9 disk quartet.)
2. **`data-corruption-repair.sh` IO gate:** its `io PSI ≥20%` block is effectively permanently engaged on this box (corpse-inflated 60-80% at idle disks). Adopt the samsung-nix-sync diskstats real-activity bypass (changes a safety gate's semantics), or keep the manual `I_OVERALL_OK=1` escape as the sanctioned path?
3. **CI shellcheck severity:** bump CI from `-S error` to `-S warning` with a small ignorelist (and add `scripts/lib/` to the glob)? It would have caught several of this session's bug classes pre-merge, at the cost of a one-time ignorelist-tuning pass over existing warnings.

---

**Verification state at report time:** 80/80 scripts `bash -n` clean; CI-parity shellcheck green incl. `scripts/lib/`; 8/8 selftests green; `nix flake check --no-build` ALL CHECKS PASSED (incl. the rescued sops-recipient-audit check — 5/5 cases); wifi-failover stub-tested (VM test pending); negative-test-lints full pass pending. All changes daemon-committed (mine appear as `b2d1bc7a` + sweeps; the sops rescue + fixture fix ride the next sweep).
