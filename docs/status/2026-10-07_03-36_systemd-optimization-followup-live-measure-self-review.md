# Systemd Optimization Follow-up — Live Measurement, New Critical-Chain Gate, Self-Review (2026-10-07)

**Session:** 2026-10-07 ~03:05 → 03:36 — trigger: user asked "How can we optimize systemd?" (advisory, exploration mode). READ-ONLY session: zero files changed before this report. Tree pinned at `ba553410`, clean.

**Scope:** this session only — what I measured, what I claimed, and where my own claims failed the repo's evidence doctrine. Extends the 2026-10-06 boot-speed deep research (`2026-10-06_21-31_*`) and its self-review (`21-58`).

## The question and the answer given

Live `systemd-analyze` on boot 0 (started 02:51:12): **2min 56.8s total** (firmware 1min 2.5s + loader 2.7s + kernel 1.9s + initrd 7.3s + **userspace 1min 42.3s**). Critical chain: `graphical.target ← display-manager ← systemd-user-sessions ← home-manager-lars.service @3.0s +1min 39.3s`. The 2026-10-06 hermes fix VERIFIED WORKING structurally: hermes is off the critical chain entirely, `hermes-perms-heal.service` exists and ran (15.1s, post-start — the reference pattern doing its job). The login gate moved to Home Manager activation, exactly where the 2026-10-06 report §d predicted ("next gate = bank-sync/HM").

The HM journal pinpoints a **96-second gap** (02:51:25 → 02:53:01) between `Starting units: activitywatch-theme.service, activitywatch-watcher-*.service, activitywatch.service` (HM's `reloadSystemd` step) and the next activation step (`signal-theme`). That gap is ~96% of the HM activation and ~57% of total userspace time.

## Evidence (boot 0, all live)

| # | Finding                                                                                                                                                                                                                                                                      | Evidence                                                                                |
| - | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| 1 | `systemd-analyze time`: 62.5s firmware + 2.7s loader + 1.9s kernel + 7.3s initrd + 1min 42.3s userspace = 2min 56.8s                                                                                                                                                         | live 03:0x                                                                              |
| 2 | Critical chain gates on `home-manager-lars.service @3.000s +1min 39.262s` → `systemd-user-sessions` → `display-manager`                                                                                                                                                      | `systemd-analyze critical-chain`                                                        |
| 3 | HM activation: steps complete 02:51:25, `Starting units: activitywatch*` at 02:51:25, next step (`signal-theme`) at **02:53:01** — 96s inside `reloadSystemd`'s user-unit start window                                                                                       | `journalctl -b -u home-manager-lars.service`                                            |
| 4 | `mountpoint: command not found` ×4 (activate script lines 277/280/283×2) inside `migrate-buildcache-fallback-caches` — the hook's mountpoint probes cannot run                                                                                                               | same journal; hook defined in `platforms/nixos/users/home.nix` (our code, not upstream) |
| 5 | Blame top: clickhouse-db-backup 2min 58.6s, home-manager-lars 1min 39.3s, buildcache-usb-recovery 1min 31.2s, hermes 1min 9.3s, pool-usb-recovery 1min 9.2s, discordsync-db-heal 1min 8.8s, bank-sync 47.7s — the full post-crash catch-up fleet in one window               | `systemd-analyze blame`                                                                 |
| 6 | Boot 0 is a **recovery boot**: boots -3/-2/-1 span 00:02→02:49 (3 short-lived boots in 2h47m — the freeze #21/#22 overnight sequence), boot -1's journal cuts mid-traffic at 02:49:28, and the SEV1 bridge started this boot with conditions live, clearing only at 02:52:10 | `journalctl --list-boots`, `-b -1 -n 2`, boot-0 SEV1 grep                               |
| 7 | The 2026-10-06 restructure IS deployed: hermes off the chain, hermes-perms-heal unit live (15.1s), no buildcache fsck in blame                                                                                                                                               | critical-chain + blame                                                                  |
| 8 | Queued backlog mapped (agent sweep): stampede control, tmpfiles-cycle tripwire (in-tree, undeployed), verify sweep, boot-duration collector, stray-unit lint, BIOS walk, loader timeout — all already in TODO_LIST/docs/todo                                                 | agent report, spot-checked                                                              |

## a) FULLY DONE

1. Live-state capture of boot 0 (time/critical-chain/blame/HM journal) — the first post-deploy measurement of the 2026-10-06 restructure, delivered as an advisory answer.
2. **Structural verification of the 2026-10-06 boot-speed work**: hermes no longer gates login; perms-heal runs post-start; the predicted "next gate" (HM) confirmed as the new chain owner.
3. Backlog mapping via agent sweep (brainstorming/planning/status/todo) — no duplicate proposals; answer routed to the two genuinely new findings.
4. Localized the HM 96s blockage to the journal-second level (the `Starting units: activitywatch*` window).

## b) PARTIALLY DONE

1. **HM blockage root-cause**: gap localized, mechanism NOT verified — I never probed `journalctl --user -b -u activitywatch.service` (why are those units slow?) nor distinguished the three candidates: blocking `systemctl --user start` waiting on a slow unit vs `daemon-reload` cost vs user-bus contention. I asserted "HM activation waits for those four user units to fully start" from a journal GAP — correlation presented as mechanism.
2. **`mountpoint` bug**: found live, located the owning file (`platforms/nixos/users/home.nix`), but did not read the hook — "delete (parked-relocation remnant) vs fix (PATH)" is untriaged, and I did not reconcile my "phantom-green class" framing against the 2026-10-06 report §d3 which had already logged it as "cosmetic".
3. **Calm-boot re-measure** (stability.md:169, `[blocked:deploy]`): accidentally half-performed — data captured, but on an invalid window (see §d1). Item stays open.

## c) NOT STARTED

1. Any fix: activitywatch start-policy decoupling, HM hook PATH fix/deletion, stampede admission control, the actual calm-boot re-measure, boot-duration collector, BIOS walk.
2. `systemd-analyze critical-chain multi-user.target` (SSH availability chain — only graphical measured).
3. `systemctl --failed` health sweep (5-second check that belongs in any systemd answer; already a queued gap from `2026-10-07_03-02_*` §28).

## d) TOTALLY FUCKED UP

1. **I declared the ≤~40s userspace expectation "falsified" on a boot that the repo's own doctrine forbids measuring.** The very first file I read this session (docs/agents/systemd.md:67) says: measure on a CALM boot — a storm boot "conflates structure with storm amplification". Boot 0 is a post-freeze-22 recovery boot: 3 prior boots in 2h47m, journal cut mid-traffic at 02:49:28, SEV1 conditions live at boot start (cleared 02:52:10), and the entire catch-up stampede in blame (Evidence 5). My flat sentence "this boot falsifies the ≤~40s expectation" was an evidence-strength overclaim — the 2026-09-18 rule ("a result observed once is 'happened', never 'can'"; assert WHICH question your evidence answers) extends here to: **assert WHICH BOOT WINDOW your evidence comes from**. Retraction as stated: this boot is a storm data point; what it VALIDATES is structure (chain shape, fix effectiveness), not absolute seconds. The re-measure row's expectation is untested, not falsified.
2. **Presented the `mountpoint` finding as a fresh "phantom-green class" bug without checking the prior session's verdict on the same log line** — the 2026-10-06 report §d3 had already logged it (as "cosmetic"). Two sessions, same log line, two unreconciled severity claims, zero reads of the generating hook. That is a split-brain-in-formation on a finding, and my version was the LESS verified of the two (I never opened the hook).
3. Minor: cited TODO_LIST line numbers (:106, :161-163, :174, :493) straight from the agent's report without spot-verification — the queue's own rule (spot-verify premises at queueing time) applies to citing them in a report too. Spot-check during harvest caught one drift risk (re-measure row greps under different wording than the agent quoted).

## e) WHAT WE SHOULD IMPROVE

1. **Preflight any `systemd-analyze` claim with a window-classification check**: `journalctl --list-boots | tail -3` + SEV1/zone-6 grep + blame catch-up-fleet scan BEFORE quoting numbers. 30 seconds; this session's §d1 would not exist otherwise. (The boot-duration collector queued at monitoring.md:87 should record this context too — a bare seconds metric without storm classification will mislead trend checks.)
2. **Read the sibling report for the same log line before minting a "new" finding** — grep `docs/status/` for the exact journal string first. The repo's report series is one conversation; I treated it as unknown territory.
3. **Probe the user-manager directly before asserting an HM mechanism** — `journalctl --user -b -u activitywatch*` costs nothing and converts my gap-inference into a mechanism claim (or kills it).
4. Evidence-rule extension worth internalizing: every quantitative claim carries its window's validity class (calm / storm / recovery-boot). Labels, not vibes.

## f) NEXT THINGS (session-derived; routed per TODO rules at authoring time)

1. **Diagnose the 96s HM `reloadSystemd` blockage** — `journalctl --user -b -u 'activitywatch*'` + hm-activate timestamps; distinguish blocking unit-start vs daemon-reload vs user-bus wait; then decide the decoupling (defer activitywatch starts off the login path, or fix the slow unit). NEW row, stability.md. (§f.1)
2. **Calm-boot re-measure stays open** — extend stability.md:169 with this boot's data point: restructure VERIFIED structurally (hermes off chain, perms-heal live), userspace 1min42.3s measured on a recovery boot = invalid for the ≤40s verdict; re-measure window must have no SEV1 carryover and no catch-up fleet in blame. (§f.2)
3. **Triage `migrate-buildcache-fallback-caches`** (`platforms/nixos/users/home.nix`): read the hook — if it guards the PARKED go-build hot-cache relocation (systemd.md:21 HM-symlink/automount trap), delete the remnant; if live, fix `mountpoint` resolution (util-linux on the activation PATH) and reconcile the cosmetic-vs-phantom-green severity question with 2026-10-06 §d3. NEW row, stability.md. (§f.3)
4. **Stampede row extension** — stability.md:25 gains boot-0 evidence: clickhouse-db-backup first-fire 2min58.6s + buildcache/pool USB recoveries + discordsync-db-heal all inside the login window of a recovery boot; the HM gate itself may be storm-amplified, making admission control a boot-speed lever too, not just a stability one. (§f.4)
5. Boot-duration textfile collector (already queued, monitoring.md:87 / TODO_LIST:174): add window-classification context (SEV1/catch-up flags) to the metric — this session is the proof it's needed.
6. `systemd-analyze critical-chain multi-user.target` — measure the SSH chain; never captured.
7. `systemctl --failed` + `systemd-analyze verify` sweep — already queued (TODO_LIST:493); this session skipped the cheap half.
8. bank-sync activation mechanism ([decision], 2026-10-06 §f3) — still undiagnosed; blame shows 47.7s on boot 0.
9. BIOS firmware walk (62.5s, the single biggest leg) — owner-gated, pairs with the reboot window below.
10. Loader timeout 2→1 decision — owner-gated, standing row.
11. If HM decoupling lands: pin the new chain floor (expected pocket-id ~17.7s per 2026-10-06 §d) in the re-measure row so the next session has a target.
12. Consider an hm-activate step-timing breadcrumb convention (one journal line per activation step with elapsed) — the 96s gap was only findable because HM logs step names; step timings would have made it automatic.

## g) QUESTIONS (cannot figure these out myself)

1. **activitywatch stack: is it still daily-used, and may its start be deferred off the login-blocking path?** It is (probably) what login now waits ~96s on; whether it must be "active before greeter" or can start post-login is a value call, not a grep.
2. **Can we schedule ONE deliberate reboot window** to bundle: the calm-boot re-measure (needs a fresh quiet boot), the boot-mirror PartUUID/BootCurrent decode verify (open since 2026-09-30), and optionally the first BIOS-walk option? The box has had 5 boots since midnight — owner picks the quiet moment.
3. **The parked buildcache go-build relocation (home.nix hook): delete the remnant, or is the fallback relocation still wanted?** Its mountpoint probes are dead code today; intent decides delete-vs-fix before anyone spends a dispatch on it.

_Annotation (2026-10-07 03:59, execution self-review `2026-10-07_03-59_login-gate-fix-execution-self-review.md`):_ Q1 is MOOT — the fix deferred activitywatch-theme off the login path entirely (OnBootSec timer), so no start-policy decision is needed. Q3 is ANSWERED — triage found the hook is the LIVE 2026-09-22 cache-fallback convergence (not the parked relocation); fixed via absolute `${pkgs.util-linux}/bin/mountpoint`, deploy queued [ready]. Q2 (reboot window) remains open and now pairs with that deploy row.

---
*Self-harvested at authoring time per the TODO System rule: §f.1, §f.3 → new rows in docs/todo/stability.md + TODO_LIST.md; §f.2, §f.4 → extensions of existing rows in both surfaces (queue + library kept in sync). §f.5-§f.10 land on already-queued rows — no duplicates minted. Deliberately NOT harvested: §f.11-§f.12 (speculative, contingent on §f.1's outcome — they become actionable only after the HM mechanism is known).*
---

## ADDENDUM — re-dispatch executed (2026-10-07 ~04:15, same session)

User directive: "DO MORE RESEARCH AND IMPROVE THINGS FOR REAL." §f.1 and §f.3 executed end-to-end; both closed on all surfaces.

### Mechanism VERIFIED (closes §b.1)

The 96 s blockage is **`activitywatch-theme.service` ALONE** — the server and both watchers started in ~1 ms; the theme oneshot ran 02:51:25.596 → 02:53:01.743 (96.1 s). Chain: HM activation blocks on `systemctl --user start` for every enabled oneshot → theme's curl POST (`--retry 5 --retry-delay 2 --retry-connrefused`, **NO `--max-time`**) connected to aw-server but waited on its response — aw-server's 13 GB sqlite sits behind the /mnt/pool data-to-pool symlink and only answered once the boot storm drained. My earlier alternative candidates (daemon-reload cost / user-bus contention) were wrong; it was an unbounded response wait on a cosmetic POST.

### Hook triage resolved (corrects §f.3's hypothesis AND 2026-10-06 §d3's "cosmetic" verdict)

The hook is NOT the parked go-build relocation remnant — it is the **live 2026-09-22 cache-fallback convergence** (reaps real dirs before HM's checkLinkTargets aborts; pre-creates mount targets). It has been a **silent no-op since it landed**: the generated activate script's PATH contains no util-linux (verified: bash/coreutils/diffutils/findutils/gettext/gnugrep/gnused/jq/ncurses/nix), so every `mountpoint -q` exits 127 → all guards false → pre-creates AND reaps never ran. Landmine, not cosmetic: any real dir reappearing in the fallback set would abort HM activation → home-manager-lars fails → exit-4 activation class + login-gate damage. Correction surfaces: this addendum, the stability.md row, the CHANGELOG Fixed entry.

### Fixes landed (in-tree, daemon commit `cf8aa52e`; UNDEPLOYED by design)

1. `platforms/common/programs/activitywatch.nix` — theme de-gated from HM activation (`Install.WantedBy` removed) → `systemd.user.timers.activitywatch-theme` (OnBootSec=2min, Persistent=false, timers.target); curl bounded (`--connect-timeout 3 --max-time 30`). The 2026-10-06 boot-critical-path doctrine applied at the user-manager layer. Theme persists in aw-server's DB → PartOf-driven stops need no re-apply before the next boot's fire.
2. `platforms/nixos/users/home.nix` — all four `mountpoint` call sites → absolute `${pkgs.util-linux}/bin/mountpoint`.

### Verification

- Targeted eval: hook text renders the store path (all sites); ExecStart carries the bounds; service `Install` gone; timer shape correct (OnBootSec 2min / Persistent false / timers.target).
- Full `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` **GREEN** — every eval-time assertion battery (systemd-shape, deploy-restart, mount-gating, stray-unit, port-registry, gatus-coverage, pool-recovery converge-coverage) passes with the changes.
- `nix fmt`: 0 diffs (alejandra-verified standalone — the daemon committed the files, so the daemon-race lint-skip doctrine applied).
- **NOT deployed**: IO PSI held 40-60 % avg10 through the session (post-freeze-22 storm residue; a deploy's validation battery is the freeze-22 death class). Post-deploy verification checklist lives in the CHANGELOG Fixed entry.

### Expected effect

HM activation now completes at its non-theme cost (this boot's remaining activation steps ran in ~3 s) → the userspace login floor drops from 1 min 42 s toward the ≤~40 s re-measure expectation. stability.md:169 stays open pending a CALM boot — this boot's reading carried the 96 s theme block plus stampede amplification, so it never falsified the expectation in the first place (§d1 stands).

### Queue state

Both [ready] rows closed on both surfaces: TODO_LIST rows pruned (prune-wins contract), stability.md rows flipped [x] with evidence, CHANGELOG `### Fixed` entry added under [Unreleased].
