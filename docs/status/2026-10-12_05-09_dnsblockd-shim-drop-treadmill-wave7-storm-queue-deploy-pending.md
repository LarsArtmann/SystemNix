# Status: dnsblockd shim drop (treadmill wave 7) + storm-queued deploy

**Date:** 2026-10-12 05:09 CEST · **Session window:** 2026-10-11 ~19:11 → 2026-10-12 05:09
**Trigger:** owner ran `nix flake update dnsblockd && nh os switch` → go-modules FOD hash mismatch (specified `mpNspwwR…` ≠ got `0koFfQqs…`)
**Scope of this report:** THIS session's run only (shim drop → upstream repairs → deploy gating). Pre-existing backlog rows are cited, not re-inventoried.

**Headline:** The blocking FOD is fixed the RIGHT way (shim dropped per drop-protocol — upstream now owns the hash), three further upstream breaks were repaired or reconciled en route, the evo-x2 toplevel builds **EXIT 0** at locked rev `f39dc7d0`, and the switch itself is **correctly queued** behind the owner's I/O-pressure gate during a diagnosed-benign parallel-build storm. A calm-gated watcher will fire `nix run .#deploy` automatically (2h horizon).

---

## a) FULLY DONE

| # | Work | Evidence | Scope |
|---|------|----------|-------|
| A1 | **`dnsblockdVendorHashShim` DROPPED** — drop condition met: lock moved past 039ba0f to 8b8e594 whose `nix/vendor-hash.nix` bakes exactly the got hash `0koFfQqs…` (re-enumerated fresh from the clean local checkout at HEAD == locked rev, per the wave-6 rev-staleness lesson) | shim definition + list entry removed from `overlays/linux.nix`, class comment records the drop with evidence; daemon-committed | `overlays/linux.nix` |
| A2 | **Upstream art-dupl vendorHash refresh** — `dnsblockd-env` (and every `[env: nix-develop]` step) was broken by the art-dupl-src lock move; refreshed `nix/art-dupl-vendor-hash.nix` `Q1hNQoq…` → `q4yyw9Ji…` (first-hand FOD got), `nix build .#art-dupl` EXIT 0 | landed in dnsblockd `7677bbf9`, **pushed** (origin/master) | `~/projects/dnsblockd` |
| A3 | **Upstream UI CSS regen** — stale `app.min.css` + `styles.css` regenerated via the canonical `scripts/regen-ui.sh` (pinned templ 0.3.1020 / tailwindcss 4.3.3 toolchain) after the package build's freshness check failed | landed in dnsblockd `7677bbf9`, pushed; pre-commit UI gate "byte-fresh" PASS | `internal/server/views/` |
| A4 | **Toplevel verified at the FINAL locked rev** — `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` EXIT 0, 0 errors at lock `f39dc7d0` (the rev that actually matters, after two lock moves under the session) | `/tmp/tl-7677.log` | evo-x2 |
| A5 | **Storm diagnosis (the deploy abort was CORRECT and is understood)** — 2h+ PSI watch (avg10 23–96); writer attribution: no user proc >1.3 MB/5s; sdb `/mnt/buildcache` pegged (io_ticks 5000/5000 ms, in_flight 5→14 growing, 9826%/30s duty) mid-wave, then **proven healthy: 406 MB/s read, in_flight draining to 0** once the wave passed; fstrim ruled out (finished clean 01:19) → the 2026-10-05 buildcache-storm class (parallel golangci-lint/sccache builds), NOT the device wedge | this session's /proc + /sys field trials; watcher logs `/tmp/deploy-watch*.log` | host I/O subsystem (read-only) |
| A6 | **CHANGELOG entry** — full wave-7 narrative (shim drop, lock churn, upstream repairs, storm verdict) in house format | `CHANGELOG.md` under `[Unreleased] → Changed`, daemon-committed | `CHANGELOG.md` |
| A7 | **alejandra fix + standalone lint legs** — alejandra flagged my comment-block rewrite, formatted (scoped to the one file), re-check clean; deadnix clean. Per the daemon-race rule after the daemon swept the .nix commit | alejandra --check PASS post-format; deadnix rc=0 | `overlays/linux.nix` |
| A8 | **Deploy queued the doctrine-compliant way** — did NOT force; calm-gated watcher armed (pid 699158, log `/tmp/deploy-watch2.log`, fires `nix run .#deploy` after 4 consecutive PSI<20 samples ≈ 2 min sustained calm, 2h horizon; the deploy re-validates the gate at entry, so a mid-watch burst aborts cleanly) | watcher verified alive + logging at 05:01 | deploy orchestration |

## b) PARTIALLY DONE

| # | Work | What works | What remains | Blocker | Effort |
|---|------|-----------|--------------|---------|--------|
| B1 | **The switch itself (the owner's original command)** | build green, pre-deploy suite passed 72/12/0 on attempt 1, deploy machinery healthy | `nh os switch` has NOT run — aborted at the pressure gate, now queued behind the watcher | owner policy: io PSI gate + freeze-#4/#5 precedent (never enter activation mid-storm) | S (automatic if the storm drains; watcher covers 2h) |
| B2 | **dnsblockd local checkout convergence** | origin/master (`f39dc7d0`) is green and locked; my redundant commit dissolved | local master sits at `4e1af5d0` (daemon-committed 56-file `views.fresh/` DELETION, unpushed) directly against the session's upstream re-add — diverged, mid tug-of-war | NOT mine to resolve while the parallel session is live; converging under them risks sabotage | S (once ownership is clear) |
| B3 | **statix verification** | alejandra + deadnix explicitly verified on the shim-drop commit | statix output was swallowed by my pipeline grep (`tail -8` cut) — never explicitly confirmed clean on `overlays/linux.nix` | none — one command | S |
| B4 | **Zone-6 guard trip evidence** | journal shows clean 30s guard cycles, no trip-action lines in the visible tail | the guard's authoritative textfile proms are root-only (agent `sudo` blocked), so "no trips" rests on journal absence which may be permission-masked; the freeze-5 "queue, don't race dips" decision therefore ran on incomplete evidence | root-readable proms or a probe script | S |
| B5 | **CHANGELOG/todo sync for the wave-7 drop** | CHANGELOG done (A6); 2 direct follow-ups harvested to `docs/todo/{monitoring,pipeline}.md` + `TODO_LIST.md` twins | `docs/todo/upstream.md` wave-6 narrative not annotated with the wave-7 drop (deliberately deferred — see Harvest note) | none | S |

## c) NOT STARTED

| # | Work | Why not started | Priority |
|---|------|-----------------|----------|
| C1 | **Post-deploy verification legs** — dnsblockd unit running the `f39dc7d0` binary, spans reporting, §17 memory-throttle sweep, full `post-deploy-check.sh` (also closes the standing `[blocked:deploy]` row from the 2026-10-07 wave) | strictly blocked on B1 (the switch) | Critical, the moment the switch lands |
| C2 | **FOLLOWERS un-follow** (wave-6 §f.2: dnsblockd/erraudit/crush-daily/discordsync/go-health-dashboard/crm off `?ref=master`) | owner-gated `[decision]` — explicitly "I cannot decide it" in the wave-6 report; this session's treadmill recurrence (3rd lock move in 24h) is more fuel | High — it is the structural exit from this entire class |
| C3 | **§11 tree-mutation tripwire + shim-drop lock-rev stamp** (queued from the cqrs-lint session) | queued, not built; would have mechanically caught my rev-stale toplevel claim (see E2) | Medium |
| C4 | **dnsblockd upstream CI: FOD-realization freshness check** (CSS/_templ.go staleness currently reaches master and only explodes in SystemNix's deploy build; the vendor-hash FOD check exists, the artifact-freshness one doesn't) | upstream work, not started | Medium |
| C5 | **ROADMAP triage of this report's §f brainstorm** (items beyond the harvested two) | awaiting owner instructions per "then wait" | Low |

## d) TOTALLY FUCKED UP

No data loss, no broken deploy, nothing destroyed. But radical honesty — four items, worst first:

1. **The dnsblockd local checkout is a live landmine** (`~/projects/dnsblockd`): local master `4e1af5d0` = an UNPUSHED daemon commit deleting all 56 `views.fresh/` files, while upstream `f39dc7d0` (which SystemNix locks) RE-ADDED them. If anything pushes `4e1af5d0`, the build re-breaks and the treadmill gains another lap. Severity: blocks nothing today (SystemNix builds from locked origin revs), but it's a loaded gun on master. Root cause: the daemon swept a parallel session's in-flight worktree deletions into a commit while I was mid-investigation; I disengaged instead of fighting it. Mitigation: owner/session converges it (drop `4e1af5d0`, reset to origin) — needs Q2 answered first.
2. **Mixed-attribution commit `7677bbf9`**: the daemon swept my 3 repair files together with 13 files of the parallel session's `views.fresh/` work under a heuristic message. My slow regen cycle created the window. No code harm (content correct), but the history now misattributes both parties' work — the exact class of pipeline.md's open `[decision]` row on daemon commit-message quality.
3. **Wasted cycles (honest accounting)**: (a) I attempted the deploy while a heavy build wave was running and only measured PSI after the abort — one 1-second `/proc/pressure/io` read beforehand would have saved a full pre-deploy suite run; (b) I hand-ran `gen-library-classes.sh` + `tailwindcss` and hit the `styles.css` staleness at the pre-commit gate, even though the first failure output literally said "One command fixes all of it: scripts/regen-ui.sh"; (c) my templ-regen commit `a2bda973` duplicated the parallel session's `f39dc7d0` and dissolved in a rebase conflict — ~10 minutes of avoidable work, plus a `git pull --rebase` in an actively-contended repo (predictably messy; abort → soft-reset needed).
4. **My "toplevel green" at 8b8e594 was rev-scoped and I reported it before the churn settled** — the lock then moved twice and the green claim went stale within the hour (the qmd entry's "rides the next quiet window" trap, replayed on me). The final EXIT 0 (A4) is at the rev that matters, but the intermediate claim cost credibility and a rebuild cycle. The wave-6 lesson ("got-hashes are rev-scoped") generalizes to WHOLE toplevel-green claims on this box, and I under-applied it.

## e) WHAT WE SHOULD IMPROVE

1. **PSI pre-check before the pre-deploy suite** (harvested → pipeline.md): gate reads PSI at ENTRY today, but entry is after ~2 min of checks; move a 1s read to deploy.sh line ~1.
2. **Freeze-5 doctrine → mechanism** (harvested → pipeline.md): "Zone-6 tripped within 1h ⇒ queue the deploy" lives in prose; wire the guard trip timestamp into the gate.
3. **Guard textfile proms unreadable to agents** (B4): group-read the prom dir or ship a read-only probe script — this session's Zone-6 evidence was incomplete because of it.
4. **Pre-commit UI gate vs FOD check is a split brain**: the local gate passed ("byte-fresh") at `b931f81a` while the FOD failed at `7677bbf9` — the gate checks worktree state, the FOD checks committed-tree state, and any commit landing between gate-pass and build reopens the gap. Fix upstream: gate should validate the POST-commit tree (or CI should run the FOD freshness check — C4).
5. **Commit fast, commit pathspec, when daemons and sessions share a repo**: my regen-to-commit gap let the daemon sweep my files into a mixed commit. The pathspec-commit rule works — use it FIRST, not as a retry.
6. **In contended repos, don't rebase — converge or drop**: when origin's commit message already names the same fix, dropping my local commit is strictly better than a rebase dance.
7. **Whole-toplevel-green claims on this box need a rev stamp**: "green at rev X, tree Y" or it's not a claim (feeds the queued §11 tripwire, C3).
8. **sdb `/mnt/buildcache` is the storm epicenter** (2nd storm in a week traced to it): the Go/Rust cache write-hot-path on a USB SSD makes every parallel lint/build wave a box-wide PSI event; the Samsung hot-tier doctrine (2026-08-31 plan) already has the playbook — evaluate moving the hottest cache subtrees.

## f) NEXT — up to 50 (brainstorm, Impact/Effort/Category; sorted roughly by impact)

> Harvest status: items F1–F2 harvested to the todo system; **F3–F50 deliberately NOT harvested pending your instructions** (brainstorm per the skill; most are ROADMAP fuel, owner-gated, or blocked — say the word and I run docs-health HARVEST on the subset you pick).

| # | Item | Impact | Effort | Category |
|---|------|--------|--------|----------|
| F1 | Verify the storm-night btrbk sends ran (root journal/state + guard `backup_starved` proms + Gatus starved check) — harvested | Critical | S | Bug-verify |
| F2 | Deploy gate: PSI pre-check before the suite + freeze-5 queue rule as mechanism — harvested | High | S | Quality |
| F3 | Let the watcher fire / confirm the switch landed; read `/tmp/deploy-watch2.log` tail | Critical | S | Ops |
| F4 | If still storming at watcher timeout: force (`DEPLOY_FORCE_PRESSURE=1`) vs keep queueing — needs Q3 | Critical | S | Decision |
| F5 | Post-deploy: assert dnsblockd binary == `f39dc7d0` (`readlink /proc/$(pgrep -f dnsblockd)/exe`), health + spans flowing | Critical | S | Bug-verify |
| F6 | Run full `post-deploy-check.sh` — closes the standing `[blocked:deploy]` row from the 2026-10-07 wave | High | S | Quality |
| F7 | Post-deploy §17 memory-throttle sweep + triage the 10 actively-throttling units (pre-existing queue row) | High | M | Bug |
| F8 | Converge the dnsblockd local checkout (drop `4e1af5d0`, reset to origin) once Q2 answered | High | S | Cleanup |
| F9 | Ratify the FOLLOWERS un-follow (C2) — dnsblockd is on its 3rd lock move in 24h | High | M | Decision |
| F10 | Re-run `nix flake check --no-build` at a quiet moment (this session only built the evo-x2 toplevel; darwin/rpi3/zfs-vm + checks unexercised) | High | S | Quality |
| F11 | Annotate `docs/todo/upstream.md` wave-6 narrative with the wave-7 drop (queue/library sync) | Medium | S | Docs |
| F12 | Pre-commit UI gate: validate the POST-commit tree (or CI FOD freshness) — closes the E4 split brain | High | M | Bug |
| F13 | dnsblockd upstream CI: add artifact-freshness FOD check (C4) | Medium | M | Quality |
| F14 | art-dupl lockstep check (rev vs vendor hash) upstream — the misalignment class recurred 2026-09-29 AND today | Medium | M | Quality |
| F15 | Root-cause WHY `views.fresh/*.templ` additions changed canonical `views/` regen output (shared import? layout coupling?) | Medium | M | Bug |
| F16 | Root-readability for guard textfile proms (probe script or group) — unlocks Zone-6 evidence (B4) | Medium | S | Quality |
| F17 | §11 tree-mutation tripwire + shim-drop lock-rev stamp (C3) | Medium | M | Quality |
| F18 | crush-daily: the uncommitted `vendorHash.nix` fix (xo4ePVg0…) sits in `~/projects/crush-daily` — push + re-lock + drop its shim (noted in the linux.nix comment) | Medium | S | Cleanup |
| F19 | discordsync shim: probe upstream re-pin → drop when lock moves | Medium | S | Cleanup |
| F20 | Watch `overlays/linux.nix` for a stale parallel-session re-add of the dropped dnsblockd shim | Low | S | Watch |
| F21 | After switch: open new terminal + verify the ~9 restarted units (dnsblockd, dbus, polkit, signoz-provision, pocket-id-provision, memory-emergency-guard, …) | Medium | S | Ops |
| F22 | Gatus/SigNoz alert-history review for the 23:00–05:00 storm window (false pages? guard trips invisible to me?) | Medium | S | Ops |
| F23 | Session-gating for fleet lint/build waves (the open `[decision]` row) — 23 concurrent golangci-lint procs drove tonight's storm | High | L | Decision |
| F24 | Evaluate moving hot build-cache subtrees off sdb/USB to the Samsung (E8) | Medium | L | Feature |
| F25 | Inventory the stray `openseo` vite preview (port 3002) + other dev servers — which session owns them? | Low | S | Cleanup |
| F26 | sccache still writing to buildcache (6.7 GB lifetime in tonight's census) — confirm rust-cache placement vs the /mnt/rust-cache migration | Medium | S | Cleanup |
| F27 | Deploy-abort evidence hygiene: confirm `journalctl -t systemnix-deploy` recorded tonight's exit-12 abort cleanly | Low | S | Ops |
| F28 | Convert tonight's storm forensics into a stability.md appendix (sdb pegged-vs-healthy field trial numbers) | Low | S | Docs |
| F29 | Fleet CI vendor-hash checks gap (PMA/erraudit/crush-daily … documented 2026-08-08, still open) | Medium | M | Quality |
| F30 | buildEnv collision triage (fastflowlm vs xrt `libxrt*`, python3.13 vs 3.14 — visible in every deploy's system-path warnings) | Low | M | Cleanup |
| F31 | Catalog eval warning (36 integration subdomains vanish if `dns-local.nix` is deleted) — act or suppress with rationale | Low | S | Decision |
| F32 | `stdenv.isLinux` deprecation warnings — sweep when nixpkgs batch lands | Low | S | Cleanup |
| F33 | llama-vlm SOAK-TEST warning — schedule the real-unit soak before any decommission decision | Low | M | Decision |
| F34 | emeet-pixyd textfile collector broken (pre-deploy warnings again tonight) — deploy the collector fix | Low | S | Bug |
| F35 | §12 advisory: `network-local-commands` ExecStart "not built yet" — verify layout post-build or teach §11 the case | Low | S | Quality |
| F36 | Purge my scratch files `/tmp/io-snap{1,2}` `/tmp/s{1,2}` `/tmp/d{1,2}` `/tmp/r{1,2}` | Low | S | Cleanup |
| F37 | Consider a flake.lock update cooldown convention for deploy windows (3 lock moves in one session = churn tax) | Medium | M | Decision |
| F38 | The unattributed `du` walker on /mnt/buildcache (ext4_read_bh D-state) — attribute via crush.db or drop | Low | S | Ops |
| F39 | Add "measure PSI before deploying" to the deploy runbook text (AGENTS.md Build & Deploy block) — doctrine echo of F2 | Low | S | Docs |
| F40 | Re-check that the `dnsblockd` FOD cache is warm post-switch so the NEXT bump's §11 preview is fast | Low | S | Ops |
| F41 | Consider landing the drop-protocol as `scripts/check-vendor-hash.sh`-equivalent consumer-side probe (the wave-6 report's "make it a script" item — still tribal) | Medium | M | Quality |
| F42 | Sweep `docs/status/` for reports claiming "toplevel green" without a rev stamp and annotate the convention | Low | S | Docs |
| F43 | Re-verify `scripts/test-pre-deploy-vendor.sh` fixtures still match post-drop (it references a dnsblockd prepared-source drv) | Low | S | Quality |
| F44 | SigNoz: confirm `signoz_traces_reporting{service="dnsblockd"}` post-switch (the registry wiring=enforced invariant) | Medium | S | Bug-verify |
| F45 | Update the linux.nix class comment if discordsync's upstream re-pins (its drop condition will fire like dnsblockd's did) | Low | S | Watch |
| F46 | Post-switch: confirm the memory-emergency-guard restored any units it stopped during the storm window (churn re-arm) | Medium | S | Ops |
| F47 | Fleet: measure how often `?ref=master` FOLLOWER inputs moved under an active session in the last 30 days (data for the un-follow decision, F9) | Medium | M | Docs |
| F48 | Add the wave-7 recurrence to `references/lessons.md` in crush-config (cross-project: whole-green claims are rev-scoped) — by commit there, not in-session | Low | S | Docs |
| F49 | The `[decision]` daemon commit-message quality row (pipeline.md) — tonight produced exhibit A (`7677bbf9`); attach it | Medium | S | Docs |
| F50 | ROADMAP: "deploy-window lock freeze" exploration (inputs that moved <N hours before a deploy get held back) | Low | M | Decision |

## g) Questions I can NOT answer myself

1. **Do you ratify the FOLLOWERS un-follow (C2/F9)?** dnsblockd moved 3 times under this one session; every shim is a treadmill lap. The wave-6 report left this owner-gated ("I cannot decide it") — it is the only structural exit, and I can implement it in ~an hour once decided.
2. **Is the parallel session still live in `~/projects/dnsblockd`, and what is the INTENT of the `views.fresh/` deletions?** I can see the commits but not the plan: was deleting `views.fresh` an abandoned intermediate (then I converge the checkout per F8) or an in-flight rename that their next push completes (then hands off)? Converging under a live session would sabotage it.
3. **Deploy risk appetite if the storm persists past the watcher's 2h horizon:** keep queueing until naturally calm, or use the documented `DEPLOY_FORCE_PRESSURE=1` override (precedent: the 2026-10-11 01:57 Forgejo deploy landed under a storm and survived)? I will not choose this alone — freezes #4/#5 died entering activation mid-storm, but the build is fully cached and activation is short.

---

## Harvest record (AGENTS.md TODO-system obligation)

- **Harvested at authoring time:** F1 → `docs/todo/monitoring.md` + `TODO_LIST.md` twin; F2 → `docs/todo/pipeline.md` + `TODO_LIST.md` twin.
- **Deliberately NOT harvested:** F3–F50 — brainstorm per the skill's >25 rule; blocked-on-deploy items (C1/F5–F7/F21/F40/F44/F46) are gated on B1, not the queue; decision items (F4/F9/F23/F31/F33/F37/F50) are owner-gated; the rest await your pick (C5). Say "harvest" + item numbers and I route them.

## Evidence index

- Shim drop: `overlays/linux.nix` class comment (daemon commit), this report A1
- Toplevel green: `/tmp/tl-7677.log` (EXIT 0 at `f39dc7d0`)
- Deploy abort: `/var/log/systemnix-deploys/` entry + exit-record, gate output in-session
- Storm watch: `/tmp/deploy-watch.log` (40-min timeout run), `/tmp/deploy-watch2.log` (armed watcher)
- dnsblockd upstream: `7677bbf9` (my repairs, daemon-swept), `f39dc7d0` (session's templ fix — the landing fix), `4e1af5d0` (divergent local deletion commit)
- CHANGELOG: `[Unreleased] → Changed` wave-7 entry
