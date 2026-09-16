# Full .sh Review — Footgun Neutralization, Gate Fixes, and the Remaining Backlog

**Session:** 2026-09-16 ~12:30–14:10 · **Scope:** every tracked `.sh` file (79 files, ~12.9k lines) · **Repo state at start:** clean @ `65e473a1`

---

## What was done (session narrative)

1. **Inventory:** `git ls-files '*.sh'` (79 files — a plain glob missed `legacy/.config/waybar/` because hidden dirs are skipped; `git ls-files` is the authoritative list).
2. **Mechanical baseline:** `bash -n` clean on all 79; shellcheck 0.11.0 (via store path, CI pins the same) at `-S warning` flagged only 5 files; all 8 fast selftests green (pre-deploy-metrics, shell-aliases, direnv-smart-lib, post-deploy-pressure, nullglob, textfile-tmp, serviceconfig-merge, templ-committed).
3. **Deep review:** 6 parallel read-only agents (deploy-critical / disk-migration / diagnostics / daemons / quality-gates / misc+legacy), each with a repo-specific checklist. Yield: **~5 CRITICAL, ~23 HIGH, ~55 MEDIUM/LOW** findings across ~40 files.
4. **Wiring research before edits:** which scripts are CI/pre-commit/flake-wired (scan-history-secrets, check-image-updates, the 3 audits, check-templ, fix-nixpkgs-lock are wired; pre/post-deploy-check are embedded via `builtins.readFile` + sibling-lib staging in flake.nix apps; zfs-vm is still a live `nixosConfigurations` attr → zfs scripts fixed in place, not moved).
5. **Fix execution:** footguns first, then live gates, verifying each edit (syntax + shellcheck -S error + functional stubs where possible). Batches C/D/E of the fix plan were NOT started (user interrupted for this report).

---

## a) FULLY DONE (fix applied + verified this session)

### Destructive footguns neutralized (Batch A — complete)

| File | Was | Now |
|---|---|---|
| `scripts/disk-create-p9.sh` | Would `sgdisk -d 9` + mkfs.ext4 the **live XFS ClickHouse p9** | Hard-refusing RETIRED tombstone (exit 1, explains why, points at migrate-clickhouse-xfs.sh) |
| `scripts/disk-fix.sh` | PHASE 1 deletes p9 = live ClickHouse data | Tombstone (executed 2026-06-26 emergency, superseded) |
| `scripts/disk-diagnose.sh` | Recommended running disk-fix.sh **even in the SAFE state** | Tombstone |
| `scripts/disk-common.sh` | Hardcoded `/dev/nvme0n1` constants for the above | Tombstone (fails loudly if sourced) |

All four verified: syntax ok + execution exits 1 with the explanation. This closes TODO_LIST "Pool + disk-domain quality" item (3) — tick still pending.

- **`bench-nix-fs.sh`** — destructive benchmark defaulted to `/dev/nvme0n1` with a header claiming it was "the blank Samsung" (kernel names FLIP; nvme0n1 is often the live root). Now: explicit device arg REQUIRED, swap-membership refusal (lsblk MOUNTPOINTS is blind to swap — compares against `/proc/swaps` col 1), dead `substr($0,0,0)` removed. Verified: no-arg refuses.
- **`bench-disk.sh`** — same: required-arg + swap refusal.
- **`buildcache-btrfs-convert.sh`** — mkfs.btrfs ran on `$DEVICE` after only a text prompt. Now: content gate (fstype must be ext4 AND label `buildcache`) + binary preflight BEFORE stopping/mutating anything.
- **`migrate-clickhouse-xfs.sh`** — `DISK="/dev/nvme0n1"` hardcoded in a partition+mKfs script. Now: by-id resolution (`nvme-Lexar_NQ790_*`) with live-root fallback + die if neither resolves.
- **`migrate-buildcache.sh`** — dropped the stale `/rust-cache/monitor365` migration (source gone; p9 is ClickHouse now); header "verifies byte-for-byte" corrected to the superset check it actually does.
- **`zfs-vm-backup.sh`** (6 bugs, all fixed):
  1. Mount phase masked every failure (`|| true` per mount, unconditional "All datasets mounted.") → now counts mounted datasets and exits 1 at zero.
  2. Empty manifest possible (nothing mounted → empty==empty "verified backup") → remote entry-count>0 assertion.
  3. **`rm -rf` of the previous verified backup BEFORE the new one verified** → move-aside (`$BACKUP_DIR.old-<ts>`), deleted only after verification passes, kept+reported on failure.
  4. Verification failure printed ❌ then "BACKUP COMPLETE" and **exited 0** → exits 1 now.
  5. `tar | grep -v '^$' || true` swallowed ssh-drop/tar errors → plain `tar xf` pipelines with explicit failure exits.
  6. Manifest normalization asymmetry (source stripped `legacy/`, dest kept it → every legacy file false-mismatched, contradicting its own comment) → identical normalization.

### Live gates + daemons (Batch B — ~60% done)

- **`scripts/lib/metrics-gate.sh`** — the §10 classifier's presence regex `^${metric}(|[{[:space:]])` had an **empty-first alternation = bare prefix match**: a longer sibling metric (`foo_total` present) classified `foo` as PRESENT — the exact phantom-green class the gate exists to block. Fixed to `^${metric}([^a-zA-Z0-9_:]|$)`. **Negative-proven**: old regex phantom-matches, new one absent-on-sibling/present-on-exact/present-on-labeled. Added `# shellcheck shell=bash` directive.
- **`scripts/test-pre-deploy-metrics.sh`** — new Fixture C2 (prefix collision must FAIL); whole suite green.
- **`scripts/deploy.sh`** —
  - `echo "$nh_output" | grep -q "Exited(4)"` → **herestring**: grep -q closes early; a >64KB nh output SIGPIPEs echo under pipefail and would misdiagnose an exit-4 activation as "config NOT activated. Aborting." (the repo's own documented trap, not applied at this call site).
  - 3 journalctl calls in the deploy critical path wrapped in `timeout 15`.
  - D-state diagnostic pipeline `| head -8 | sed` guarded with `|| true` (SIGPIPE under pipefail could abort the deploy mid-gate-print).
- **`scripts/wifi-failover-watch.sh`** (live daemon, 2 HIGHs) —
  - **v6 eviction never worked**: `del_route_line` always ran v4 `ip route del`, so `ip -6 route show` lines died "inet address expected" → WARN+break. Now `del_route_line -6`.
  - **set -e/pipefail death paths**: `grep | head -1` assignment SIGPIPEs with ≥2 pinned routes (the exact case the loop exists for) and a vanished-route race would kill the daemon mid-failover → restart → start-limit → the blackhole returns. Now `grep -m1 + || true + empty-check` in both loops.
  - **Functionally verified** with a stubbed `ip`: multi-route v4 eviction, v6 eviction, `linkdown` token stripping all PASS (after fixing two bugs in my own test stub).
- **`scripts/pre-deploy-check.sh`** —
  - **Repo-anchoring**: all repo-relative reads (`modules/nixos/services/gatus-config.nix`, `lib/ports.nix`, `flake.lock`) made phantom-green when run from any other cwd (flake app wrapper never cds). Now: anchors to the checkout via BASH_SOURCE; from a store wrapper requires a repo-looking cwd and exits 2 LOUD. Verified from /tmp: anchors and runs the real gate.
  - `find "$BUILDS_DIR" … | wc -l` unguarded (pipefail could kill the whole gate with no summary) → `|| echo 0`.
  - §10b `TOBE_GATUS_CFG` mktemp leak on interrupt → pre-registered in the EXIT trap.
  - ⚠ Two of these edits were **silently reverted by a parallel-session/daemon race** and re-applied during this status audit (see §d).

---

## b) PARTIALLY DONE

- **Batch B remainder (verified findings, fixes NOT applied):**
  - `post-deploy-check.sh`: `"0\n0"` double-output at `journalctl|wc -l || echo 0` (~2 sites incl. :1285); `monitor.$DOMAIN` vHost probe not enable-gated (monitor365 disabled → permanent WARN).
  - `pre-reboot-check.sh`: sudo re-exec drops the wrapper's runtimeInputs PATH (`env BOOT_DIR=…` without PATH → btrfs/nix calls fail into 2>/dev/null = phantom-green); numeric loader default (`default 2`) misdiagnosed as missing entry → false REBOOT BLOCKED; baseline path `~/.local/state` vs `XDG_STATE_HOME` mismatch with post-deploy-check's writer.
  - `verify-deployment.sh`: zero `--max-time` on ~7 curls; boot-time check greps the FIRST duration (= firmware/kernel) not the total after `=`; `[ -d /mnt/btrfs-root/@snapshots ]` is a nonexistent path (real: `.snapshots`) → snapshot staleness never audited; `wc -l || echo "0"` double-output.
  - `lib/pressure-report.sh`: clean per agent, only needs the `shellcheck shell=bash` directive.
- **Review itself:** 100% done (all 79 files read by agents; wiring mapped). Fixes: ~15 of ~40 files-with-findings done.

## c) NOT STARTED (triaged backlog from the review — priority order)

**Batch C (diagnostics):**
1. `health-check.sh` — HIGH: `grep -c "failed" || echo "0"` double-output makes EVERY clean run false-fail (`0\n0` arithmetic error); MEDIUM: `readlink` (not `-f`) → permanent "HM generation is 20706d old" WARN; hardcoded evo-x2 vs "cross-platform" claim; SIGPIPE `systemctl | head -5 | while` under set -e.
2. `internet-diagnostic.sh` — HIGH ×2: `GATEWAY` var never set (captured as `GW`) → always pings hardcoded 192.168.1.1 (wrong on hotspot failover, this box's actual failure mode); retired units (`route-health-monitor`, `mptcp-endpoint-manager`, `unbound`) fail() every run → script permanently red on a healthy machine.
3. `nixos-diagnostic.sh` — HIGH: `nixos-rebuild check` is not a subcommand → ❌+exit 1 on healthy systems; `nix flake check --quiet` (not a flag) → `--no-build`.
4. `das-link-recovery-check.sh` — HIGH: `scan_boot "-b -1"` passes one argv with a leading space → journalctl errors, stderr eaten → false-clean green for the previous boot (the exact false-clean the script exists to prevent). Fix: two-arg call.
5. `usb-diagnostic.sh` — HIGH: unbounded `smartctl` on possibly-wedged disk (the script you run DURING the wedge); smartctl|head pipe lie; `journalctl -k` without `-b`; `/dev/sda` default + `${DEV}1` partition derivation; unanchored greps.
6. `dns-diagnostics.sh` — curl without max-time (the documented :9090 wedge class); blocking test accepts ANY answer (phantom green); always exits 0; `via`-less default route parsing.
7. `hermes-state-audit.sh` — SIGPIPE abort (`du|sort|head` under set -euo pipefail) before sections 2–4 ever run.
8. `hdd-vibration-check.sh` — unbounded smartctl (same wedge class).
9. `check-firewall.sh` — mullvad section stale (table gone); "unbound" label stale.
10. `diagnose-mullvad.sh` + `check-mullvad-nft.sh` — entire scripts target a retired stack.
11. `route-health-monitor.sh` — retired but header claims to be live architecture; latent bugs if revived (needs RETIRED banner or deletion).
12. `mptcp-endpoint-manager.sh` — substring `grep -q "$addr"` false-matches .15 vs .150; multi-endpoint awk breaks delete (dead code via dual-wan, but fix is cheap).
13. `display-watchdog.sh` — threshold exhaustion resets its own counter → restart loop forever on a dead display; no timeouts on loginctl/systemctl; corrupt state file = crash under set -e.
14. `niri-drm-healthcheck.sh` — same count-file sanitize + journalctl/loginctl timeouts; reset_count before verification → restart every ~2 min on persistent wedge.
15. `dnsblockd-goroutine-dump.sh` — no confirmation the dump reached the journal (journald rate-limiting can drop multi-MB stack bursts) — the exact lost-sample it exists to prevent.
16. `io-psi-forensics.sh` — one unbounded `find /sys/fs/cgroup` walk (everything else timeout-wrapped).

**Batch D (quality gates):**
17. `scan-history-secrets.sh` — HIGH: `github_pat_` fine-grained PATs NOT matched (`gh[pousr]_` misses them; hermes literally uses github_pat_ tokens) → add pattern (+ consider glpat-/sk_live-); MEDIUM: >50MB blobs silently skipped; gzip-only decompression (zip/xz/bz2/zstd opaque); `rev-list --all` misses reflog/dangling objects.
18. `test-home-manager.sh` — CRITICAL phantom-green: nearly every assertion is a non-failing ⚠️; HM entirely un-deployed still exits 0.
19. `test-shell-aliases.sh` — HIGH: substring alias match (`alias l` matches any line containing "l") = nearly vacuous.
20. `validate-gomemlimit.sh` — HIGH: all-SKIP run exits 0 (typo'd service name indistinguishable from "no limit"); list never cross-checked against modules.
21. `check-image-updates.sh` — HIGH: `checked=0, failures=0` exits 0 (parser drift = checked nothing); MEDIUM: Docker Hub pagination (first 100 tags only → wrong verdicts).
22. `check-flake-inputs.sh` — HIGH: green outside the repo (wrong-dir fallback + `|| true` greps).
23. `check-doc-links.sh` — zero-files-scanned is green; space→%20 encoding is BACKWARDS (decodes nothing, false BROKEN on valid links with spaces).
24. `audit-go-deps.sh` — inputs silently vanish from the audit (no WARN, zero-audited exit 0); nix eval + git ls-remote without timeout.
25. `negative-test-lints.sh` — nix build per case without timeout; rsync dependency unpreannounced.
26. `report-goexperiment-gaps.sh` — test-only importers misclassified OK.
27. LOW refinements: audit-shell-nullglob trailing-space class-A; audit-textfile-tmp substring allowlist; audit-serviceconfig-merge `grep -v '://'` line-dropping (strip URLs instead); doc-freshness `name =` over-count; crush-rc-test timeout + `--probe` without model; validate.sh path-relative flake ref + timeout; test-post-deploy-pressure missing fail-fixture; test-shell-aliases fish -i timeout.

**Batch E (misc):**
28. `update-vendor-hash.sh` — HIGH: project keys with spaces word-split → set -u crash on default run; while-read fix.
29. `gather-status.sh` + `status-report.sh` — `is-active || echo` output-concatenation class (`inactive\nnot-found`); status-report: generations line same; hardcoded evo-x2 eval.
30. `samsung-prepare.sh` — `\n` literals in die (printf %s); `samsung-nix-sync.sh` — lsblk missing from preflight; nix-gc.timer never restarted on failure paths.
31. `data-corruption-repair.sh` — kernel-name fallback `/dev/nvme0n1p8` (die instead); dd `count=100000` silently caps verification at ~400 GiB/file; scrub wait loop without timeout; docker left stopped on remount failure; `--map-user` phase undocumented.
32. `pocket-id-login-code.sh` — silent exit on transport failure; `versions.sh` — darwin attr path wrong; `verify-io-tiers.sh` — exit-code-is-count, class-blind tier compare, nvme0n1 hardcode; `dns-update.sh` — grep -F + timeouts; `twenty-fix-collation.sh` — blind REFRESH COLLATION VERSION (mask real index corruption); `fix-nixpkgs-lock.sh` — hardcodes ref branch in `original`; `direnv-smart-lib.sh` — shellcheck directive + exclude-dirs gaps; `zfs-vm-survey.sh`/`zfs-vm-deepdive.sh` LOWs.
33. Heavy verifications NOT run: `nix flake check --no-build` (pre/post-deploy-check are embedded via readFile → writeShellApplication re-shellchecks them), the wifi-failover VM test, `negative-test-lints.sh` (nix builds).

## d) TOTALLY FUCKED UP (own mistakes, all caught + corrected in-session)

1. **Parallel-session race ate my edits:** between applying the pre-deploy-check.sh fixes and verifying them, a concurrent session/daemon commit reverted the repo-anchor block and the `find || echo 0` guard (verification tool call was also interrupted mid-run, masking it). Caught during this status audit by re-grepping every claimed fix; re-applied and re-verified. Lesson: after ANY daemon-visible edit window, re-verify fix-survival immediately — "applied" ≠ "still there".
2. **Introduced-then-fixed bug in zfs-vm-backup.sh:** my 7-edit multiedit had 1 silently-failed edit, leaving the verify branch referencing `$OLD_BACKUP` that my (also-failed) move-aside edit was supposed to define → would have been a set -u crash at verification time. Caught by checking which edit failed; both applied and grep-verified consistent (8 refs).
3. **Two bugs in my own wifi-failover test stub** (family-blind output clearing; a metric filter that caused an infinite loop → background kill). Harness bugs, not script bugs; final run PASSes all three assertions.
4. **First swap-check regex was wrong** (`grep -qxFf /proc/swaps` can't match multi-column lines) — corrected before verification.
5. **Half-formed preflight** briefly written into buildcache-btrfs-convert.sh (pointless sudo true loop) — replaced with the clean version in the same step.

## e) WHAT WE SHOULD IMPROVE (systemic, from this review)

1. **Tombstones > TODO items for footguns:** the p9 trio was a known live-data destroyer since 2026-08-22 (AGENTS.md warns "NEVER run sgdisk -d 9") and a TODO item since 2026-08-28 — it stayed runnable for a month. A documented warning does not neutralize a script; a refusing tombstone does.
2. **CI shellcheck runs at `--severity=error` only** — warning-severity catches (SC2034 unused-var classes aside: the lib-shell directives, unquoted expansions) never run in CI. Bump to `-S warning` with a small ignore list, or at least lint `scripts/lib/`.
3. **The `cmd || echo "0"` + already-prints-0 pattern** (grep -c, wc -l, systemctl is-active) double-emits `"0\n0"` and breaks arithmetic/branches — found in ≥6 scripts. The repo gotcha list covers echo|grep -q SIGPIPE but not this sibling. Candidate for an audit script (like audit-shell-nullglob) + a gotcha entry.
4. **"Never /dev/nvme0n1|sdX" is a config rule, not a script rule** — 5 manual scripts still default to kernel names. Could extend an eval-time/script audit to flag kernel-name device references in scripts/*.sh.
5. **Incident-time scripts need timeouts more than happy-path ones:** smartctl/journalctl/curl without timeouts live mostly in the scripts you run DURING a wedge — exactly when things hang.
6. **Retired stacks leave script corpses:** mullvad (2 scripts), dual-wan (2), unbound refs, waybar legacy — a "retire the service, retire its scripts" checklist item would prevent the next internet-diagnostic that fails forever on a healthy box.
7. **Diagnostic exit-code contract:** several diagnostics always exit 0 (or fail on healthy machines) — worth a convention: "diagnostics exit non-zero when they could NOT diagnose, distinguish from findings".
8. **Phantom-green gates keep recurring in test scripts** (test-home-manager, test-shell-aliases, validate-gomemlimit, check-image-updates, check-flake-inputs, check-doc-links): the negative-test-lints/audit-selftest meta-pattern exists in this repo — new gates should ship with a "zero-work-done must fail" assertion by convention.

## f) NEXT (up to 50, priority order)

1. Tick TODO_LIST item (3) "trash/mark-RETIRED the p8/p9-era disk scripts" — DONE this session, tick it.
2. Fix `health-check.sh` grep -c double-output (HIGH, false-fail every clean run).
3. Fix `internet-diagnostic.sh` GW/GATEWAY var + retired units → wifi-failover/dnsblockd (HIGH ×2).
4. Fix `nixos-diagnostic.sh` nonexistent `nixos-rebuild check` → dry-build (HIGH).
5. Fix `das-link-recovery-check.sh` scan_boot "-b -1" quoting (HIGH phantom-clean).
6. Add `github_pat_` pattern to scan-history-secrets.sh (+ CI-wired, HIGH).
7. Fix `update-vendor-hash.sh` word-split crash (HIGH).
8. `test-home-manager.sh`: make warnings count toward exit (CRITICAL phantom-green).
9. `test-shell-aliases.sh`: anchored alias matching.
10. `validate-gomemlimit.sh`: fail on all-SKIP + unit-not-found detection.
11. `check-image-updates.sh`: assert checked>0; add Docker Hub pagination.
12. `check-flake-inputs.sh`: hard-fail outside repo / missing flake.nix.
13. `check-doc-links.sh`: fail on zero files; fix %20 decode direction.
14. `verify-deployment.sh`: curl --max-time ×7; boot-time total-after-`=`; `.snapshots` path fix.
15. `post-deploy-check.sh`: `"0\n0"` sites + monitor365 enable-gating.
16. `pre-reboot-check.sh`: preserve PATH through sudo re-exec; numeric loader default; XDG_STATE baseline path.
17. `usb-diagnostic.sh`: smartctl timeout + pipe fix + `-b` + explicit-device requirement.
18. `dns-diagnostics.sh`: curl max-time; blocked-test vs sinkhole IP; exit-code contract.
19. `hermes-state-audit.sh` + `hdd-vibration-check.sh`: SIGPIPE/timeout fixes.
20. `display-watchdog.sh` + `niri-drm-healthcheck.sh`: state-file sanitize; command timeouts; stop-reset-at-threshold (backoff) design fix.
21. `dnsblockd-goroutine-dump.sh`: journal-capture confirmation after SIGQUIT.
22. `io-psi-forensics.sh`: timeout the cgroup find.
23. `gather-status.sh` / `status-report.sh`: || echo concat class.
24. `samsung-nix-sync.sh`: lsblk preflight; restart nix-gc.timer in failure paths. `samsung-prepare.sh`: %b.
25. `data-corruption-repair.sh`: by-UUID-or-die; dd count cap; scrub wait timeout; docker restart on die.
26. `pocket-id-login-code.sh`, `versions.sh`, `verify-io-tiers.sh`, `dns-update.sh`, `twenty-fix-collation.sh`, `fix-nixpkgs-lock.sh` small fixes (Batch E list).
27. `direnv-smart-lib.sh`: shellcheck directive + exclude-dirs (target/.venv/bin/dist).
28. Decide + execute retirement for mullvad/dual-wan script corpses (route-health-monitor, mptcp-endpoint-manager, diagnose-mullvad, check-mullvad-nft, check-firewall section).
29. `route-health-monitor.sh`/`mptcp-endpoint-manager.sh`: if kept, fix substring grep + while-read + nmcli timeouts.
30. `zfs-vm-survey.sh`/`zfs-vm-deepdive.sh` LOWs (POOL default, import-branch split, vfio verify).
31. `audit-go-deps.sh`: timeouts + zero-audited fail + skipped-input WARN.
32. `negative-test-lints.sh`: timeout + rsync preflight.
33. `report-goexperiment-gaps.sh`: test-only importer class.
34. LOW audit refinements (nullglob trailing-space, textfile-tmp exact allowlist, serviceconfig-merge URL-strip, doc-freshness scoped count).
35. `crush-rc-test.sh` timeout + `--probe` guard; `validate.sh` absolute flake ref + timeout.
36. `test-post-deploy-pressure.sh`: add a fail-path fixture.
37. Run `nix flake check --no-build` (validates the readFile-embedded pre/post-deploy-check still build as writeShellApplications).
38. Run the wifi-failover VM test (`tests/test-wifi-failover.nix`) against the daemon fix.
39. Run `scripts/negative-test-lints.sh` full pass.
40. Add `# shellcheck shell=bash` to `lib/pressure-report.sh` (+ CI: lint scripts/lib/*).
41. Consider CI shellcheck at `-S warning` with ignorelist.
42. New audit script: reject `| wc -l || echo` / `grep -c … || echo` double-output class in scripts/.
43. New audit rule/convention: no kernel device names (sdX/nvmeXnY) as defaults in scripts/.
44. Gotcha entry: "`X=$(cmd || echo 0)` when cmd already prints 0 → '0\n0'".
45. Convention + sweep: every curl in scripts/ carries --max-time (audit-able).
46. Retire-or-fix decision + sweep for `platforms/nixos/scripts/service-health-check` (dead unwired file with stale unit refs, found by review).
47. `legacy/` policy: leave untouched as history, or prune (several legacy scripts have real bugs but are inert).
48. zfs-vm trio: decide whether the `zfs-vm` nixosConfiguration stays in flake.nix at all (drives whether the scripts stay runbooks).
49. Consider migrating wifi-failover eviction to state-based reconcile (documented 2026-09-06 follow-up; needs VM-test update).
50. Re-run the full 8-script selftest suite + pre-commit hooks after remaining batches land.

## g) Questions (cannot resolve myself)

1. **Tombstone vs delete:** the p8/p9 trio + disk-common are now hard-refusing tombstones. TODO allowed "trash/mark-RETIRED" — do you want them deleted outright (git history keeps everything), or are tombstones the right weight?
2. **Retired-stack scripts:** `route-health-monitor.sh`, `mptcp-endpoint-manager.sh`, `diagnose-mullvad.sh`, `check-mullvad-nft.sh` target disabled/removed stacks (dual-wan, mullvad) — retire them, or fix-in-place as standby tooling? Related: is the `zfs-vm` nixosConfiguration in flake.nix still wanted (it decides whether the zfs-vm scripts stay maintained runbooks)?
3. **data-corruption-repair.sh's IO gate:** its `io PSI ≥20%` block is effectively permanently engaged on this box (corpse-inflated 60-80% at idle disks) — adopt the samsung-nix-sync diskstats real-activity bypass (changes a safety gate), or keep the manual `I_OVERALL_OK=1` escape as the sanctioned path?

---

**Verification state at report time:** all 79 scripts `bash -n` clean; changed files pass `shellcheck -S error` (CI parity); 8/8 fast selftests green; metrics-gate regex fix negative-proven; wifi-failover eviction functionally stub-tested; tombstones execute-refuse; pre-deploy-check anchors from foreign cwd. Heavy gates (flake check, VM test, negative-test-lints) not yet run this session.
