# Status Report: browser-history vendorHash Mismatch — Upstream Fix + Re-lock

**Date:** 2026-09-30 04:33 CEST
**Session scope:** Single-task fix session. The user's `nix flake update browser-history && nh os switch` failed twice with go-modules FOD hash mismatches (both browser-history-agent and browser-history-server). Diagnosed, fixed upstream, re-locked, verified by toplevel build. Deploy NOT executed (human-owned).

---

## 0. Incident Timeline

| Time (approx) | Event |
| --- | --- |
| 02:39:57 | User SSH from Mac lands on evo-x2 (192.168.1.150) |
| ~02:45–03:23 | First `nix flake update browser-history && nh os switch` — SSH connection TIMED OUT mid-build after 38m24s (two go-modules FODs were downloading the full module graph serially) |
| 03:24:38 | Retry: both FODs fail `hash mismatch` after ~35s (module downloads now cached, failure is fast) |
| 03:25:05 | Second retry: identical failures after 17s |
| ~04:0x | This session starts: diagnosis → upstream fix → push → re-lock → green build |
| 04:33 | This report |

**Failure signature (both runs, deterministic — two different hashes, so NOT the NAR-hash/daemon-cache divergence class):**

```
browser-history-agent-go-modules:  specified sha256-ZEIg5xyYj0H3EmnGOpUJ/lcybRudbHxmox6Oqm1aWK4=
                                   got      sha256-W4n8fPmXQ03akExSgQMKiYBhAf0U0HrsZ61Ju75ynEo=
browser-history-server-go-modules: specified sha256-y5K2/UItJJy+oC82FUkmBOXDcu8O1yJGZPyW4ye2m2c=
                                   got      sha256-WhCjrAxY/eBt+gU/krBih6em6+dLbzVdadEMaLmnqrs=
```

**Root cause:** upstream `LarsArtmann/browser-history` master moved to `e2b6ff0` (the lock node the user's update pulled). Source-only churn since the last vendorHash refresh — `api/static/styles.css` (e2b6ff0), `go.work.sum` + `cmd/browser-history-agent/main.go` (420e2df), `api/build-css.sh` (baf2e66) — shifted the FODs' resolved module sets (FOD module set is resolved from actual imports, not from go.mod claims; the 2026-08-31 CV lesson, third recurrence of the class). The baked vendorHashes in upstream `flake.nix:343,400` were stale for its own HEAD. The upstream daemon auto-commits (all "chore: auto-commit (heuristic)") keep producing exactly this churn with no CI signal.

---

## a) FULLY DONE

1. **Diagnosis.** Confirmed both stale hashes were baked in upstream `browser-history/flake.nix` (lines 343 server / 400 agent), byte-identical to the "specified" side of the failures. Confirmed the local sibling checkout was clean at exactly the lock rev `e2b6ff0` (content-pin before edit). Confirmed determinism (identical got-hashes across two build attempts → genuine staleness, not fetch nondeterminism).
2. **Upstream fix (probe→paste→push protocol, DiscordSync 2026-09-17 / CV 2026-09-03 precedent).** Pasted the observed got-hashes into `browser-history/flake.nix` (server: `sha256-WhCjrAxY/…mnqrs=`, agent: `sha256-W4n8fPmXQ03ak…ynEo=`). Pathspec commit `5f04c79` ("fix: refresh go-modules vendorHashes after source churn"), pushed to origin/master (`e2b6ff0..5f04c79`).
3. **SystemNix re-lock.** `nix flake lock --update-input browser-history --refresh` (`--refresh` load-bearing per the daemon-fetch-cache doctrine). Lock node: `e2b6ff0 → 5f04c7994cea9aac249f780f244f64e1e4a7510b`.
4. **Build verification.** `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --no-link --keep-going` → GREEN. Both go-modules FODs and both packages (`browser-history-{server,agent}-5f04c79`) built; full toplevel realized: `770mr3anhp0jsdzqf0lcyklv9ib0mbxn-nixos-system-evo-x2-26.11.20260928.7a0f122`.
5. **flake.lock landed in git.** The auto-commit daemon already committed it (working tree clean at session end).

## b) PARTIALLY DONE

1. **The deploy itself.** The tree builds green but evo-x2 still runs the OLD generation; the new toplevel (`770mr3an…`) is built-but-unactivated. `nh os switch` / `nix run .#deploy` is deliberately user-owned — the user must re-run it. Until then the old (potentially crash-loop-era) browser-history binary keeps running.
2. **Post-deploy verification.** Nothing verified against the RUNNING system (post-deploy smoke, unit liveness, agent ingest, ownership-heal journal evidence) — impossible before the switch.
3. **Binary-jump risk assessment.** The user's update moved the lock from (per AGENTS.md, the 2026-09-22 rollback rev) `1c8f967` to `e2b6ff0` = **36 upstream commits**, spanning the 2026-09-17 `SQLITE_READONLY` crash-loop era (`f3561fd8`) and the 09-22 uid-drift era. I did NOT verify whether the checkpoint-path regression was actually fixed upstream within those 36 commits — the deploy carries an unassessed binary jump. (Mitigations live SystemNix-side: ownership-heal ExecStartPre + 09-22 "treat READONLY as uid drift FIRST" doctrine, independent of the lock.)

## c) NOT STARTED

1. `nix flake check --no-build` belt run after the re-lock (the toplevel build is the stronger signal — `nix eval`/`check` is NOT required for this fix — but it was skipped, not consciously deferred).
2. Deployment + all post-deploy checks (see b).
3. `nvd` diff of old-vs-new browser-history binaries (jump-size evidence).
4. Sweep of OTHER LarsArtmann flake inputs for latent vendorHash staleness at their locked revs (this class has now recurred on CV 3×, DiscordSync, PMA, browser-history — a batch lock-free `goModules` probe of every LarsArtmann input would catch the next one BEFORE a deploy night).
5. Upstream hardening of the class (CI FOD build on push, or a scheduled vendorHash auto-refresh bot in browser-history).
6. Memory updates — deliberately none: every lesson applied this session is already durably recorded in AGENTS.md (source-only-churn vendorHash class, probe→paste→push protocol, `--refresh` flag, pathspec commits, `edit`-after-`View`). Nothing new was learned that generalizes.

## d) TOTALLY FUCKED UP

Nothing destroyed, nothing reverted, no data loss. Honest defect list (all minor):

1. **Wasted tool call:** attempted `edit` on `browser-history/flake.nix` before reading it — both edits rejected with the read-first guard. Re-did with `View` first. Cost: one round trip.
2. **Jump-size blind spot:** fixed the build without asking "how far does this deploy jump, and does it cross a known-bad range?" The 36-commit `1c8f967..e2b6ff0` span (incl. the 09-17 crash-loop era) was only quantified while writing this report. A one-line `git log 1c8f967..e2b6ff0 --oneline | wc -l` during diagnosis would have surfaced it immediately.
3. **Did not verify the regression is dead upstream.** AGENTS.md holds the 09-17 era as "crash-loops the server at first start". Whether `1c8f967..e2b6ff0` contains the fix is unverified — flagged, not researched (scope discipline), but it should gate the deploy go/no-go.
4. **First-build timeout not acted on.** The user's first attempt died to an SSH timeout after 38 minutes because two FODs downloaded the module graph serially over a slow path; the retry pattern (which produced clean deterministic hashes) only happened because the user retried manually. Nothing here was fixable by me in-session, but a `--max-jobs`/keep-going note belongs in the runbook.

## e) WHAT WE SHOULD IMPROVE

1. **Kill the class at the source.** Every vendorHash mismatch of this era traces to LarsArtmann Go repos whose daemon auto-commits move master with zero CI signal. A single upstream CI job that builds `.#default.goModules` per push (or a nightly bot that probes got-hash vs baked and auto-PRs) would have prevented tonight entirely. CV CI is already documented dead (hosted-minutes) — browser-history CI status is UNKNOWN and should be checked.
2. **Pre-deploy jump assessment.** Before re-locking any input, diff the old→new lock rev range and check it against known-bad eras (the AGENTS.md holds regression holds for a reason). One command, worth codifying in the flake-update runbook.
3. **Batch staleness sweep.** Probe every LarsArtmann input's `goModules` FOD at its locked rev (lock-free `nix build --impure --expr '… getFlake … .goModules'`) on a schedule or before deploy batches — converts "deploy-night hash mismatch" into "known stale list" during quiet hours.
4. **SSH-timeout resilience for long FOD downloads.** Long module downloads + `nh` over interactive SSH = 38-minute dead runs. Prefer `mosh`/tmux for deploy nights, or run the build under `nohup`/`systemd-run` so a dropped SSH doesn't kill it mid-FOD.
5. **Edit-tool discipline:** always `View` before `edit`, even when `sed -n` output is already in context — the guard is enforced and the failed batch wasted a turn.

## Session observations (from the build logs, not actioned — FYI only)

- Eval warning: **catalog migration (ADR-008) still incomplete** — 23 integration subdomains lack catalog entries (`catalog, cache, banksync, history, daily, discordsync, logs, renamer, status, immich, inbox, manifest, mr-sync, overview, dash, paperless, search, signoz, graph, timers, tq, crm`); hardening into an assertion is planned (T05/T06).
- `programs.zsh.initExtra` deprecation (darwin-side HM) — migration pending.
- `stdenv.isDarwin/isLinux` + `'system' has been renamed` deprecations — cosmetic, repo-wide grep candidate.
- python3-3.13.15 vs python3-3.14.7-env double presence in system-path (colliding bin subpaths) — one python owner decision pending.
- fastflowlm-1.0.2 vs xrt lib collisions, xwayland vs xorg-server, postfix vs bcc man-page collisions — known/benign.
- `go-standard.proxyVendor = true is ignored when deps are set` trace warning (browser-history uses prepared-source + `_local_deps` replaces) — expected upstream design, benign.
- llama-vlm soak-test reminder warning — still pending from its module.

---

## f) Next work queue (ordered, session-scoped)

**Deploy & verify (blocks everything else):**
1. `nh os switch` (or `nix run .#deploy`) — user-gated, builds are warm so it should be fast.
2. After switch: `readlink /run/current-system` vs `/nix/var/nix/profiles/system` — anchor MUST match (rc=14/exit-4 class).
3. `nix run .#post-deploy-check` (browser-history vHost + smoke blocks).
4. Verify `browser-history.service` and `browser-history-agent` active, journals clean of `SQLITE_READONLY(8)`.
5. If READONLY appears: treat as uid drift FIRST (read the ownership-heal ExecStartPre's journaled `ls -lan`), per 2026-09-22 doctrine — do NOT roll the lock back (go-modules FOD rollback trap).
6. Verify one real agent ingest post-deploy (AGENT_FRESHNESS: server may 503-degrade until first ingest — the gate accepts any status, expect recovery).
7. Gatus "Browser History" + "Browser History Agent Data" green; agent-metrics textfile fresh.
8. OIDC login works (client secret bridge unchanged, but the server binary jumped).
9. `nvd diff` old vs new generation — quantify the browser-history binary jump for the record.
10. 24h soak watch (system-health, restart churn) before considering the jump settled.

**Verify/assess (quiet-hours work):**
11. Verify upstream `1c8f967..e2b6ff0` actually contains the 09-17 checkpoint-regression fix (`git log upstream -- server.save_event_checkpoint`-adjacent) — documents whether the era is closed.
12. `nix flake check --no-build` belt run (also covers pre-commit for the next commit).
13. Batch lock-free `goModules` probe of all LarsArtmann inputs at locked revs; produce a stale-vendorHash list BEFORE the next deploy night.
14. Check whether browser-history upstream CI is alive (private-repo Actions minutes class); if dead, decide a local guard.
15. Sweep the deprecation warnings (zsh initExtra, stdenv.isDarwin/isLinux) into the pipeline todo.

**Upstream hardening (browser-history repo):**
16. Add CI check: build both `goModules` FODs on every push to master (would have caught e2b6ff0).
17. Or/and: scheduled bot that probes got-hash vs baked vendorHash and auto-opens a refresh PR.
18. Investigate why `go.work.sum` churned with `cmd/browser-history-agent/main.go` in 420e2df (real dep change vs tidy noise) — determines whether FOD drift was go.sum-driven or import-driven.
19. Record `5f04c79` in browser-history CHANGELOG (docs-health pass there).
20. Consider upstream `checks.vendor-hash` self-test convention so every LarsArtmann Go flake carries it (matches the "verification layer owns the failure mode" house doctrine).

**SystemNix process:**
21. Codify "jump-size + known-bad-era check" into the flake-update runbook (docs/services or CONTRIBUTING eval-guard section).
22. Decide owner-side: the weekly flake-update bot is still BLOCKED on `NIX_GITHUB_RO_TOKEN` — without it, bot PRs (which would carry exactly this broken lock) can't even run CI; revisit creating the PAT.
23. Consider a pre-deploy-check probe that WARNS when a LarsArtmann input's lock is newer than its last verified-good build (bookkeeping only — FOD truth still needs a build).
24. ADR-008 catalog completion (23 subdomains) — existing plan T05/T06, now with a fresh warning list in this report.
25. Empty-store cleanup: the failed-build era left partial FOD outputs; harmless (GC-eligible), no action needed — noted for completeness.

*(25 items — the honest queue; padding to 50 would be noise.)*

---

## g) Questions I cannot answer myself

1. **Deploy go/no-go + timing:** The fix is built and verified at build level, but the deploy carries a 36-commit browser-history binary jump across the 09-17 crash-loop era. Do you want me to consider it safe to switch NOW (with the READONLY-watch playbook in g-item 5 armed), or should I first verify upstream `1c8f967..e2b6ff0` contains the checkpoint fix before you deploy?
2. **Batch staleness sweep:** Should I run the lock-free `goModules` FOD probe across ALL LarsArtmann flake inputs at their locked revs now (catches the next vendorHash mismatch during quiet hours; some FODs will download module graphs, so ~10–30 min of IO on the box), or leave it as a scheduled item?
3. **Upstream investment:** Do you want a vendorHash-drift guard IN browser-history upstream (CI FOD build on push, and/or an auto-refresh bot), or is the manual probe→paste→push protocol acceptable given CI minutes are scarce on private repos?

---

**Awaiting instructions.**
