# Monitor365 Re-Enable — Full Session Status + Brutal Self-Review

**Date:** 2026-10-18 01:33 CEST
**Session scope:** "Reenable Monitor365!" — recon, enable flip, eval-audit fixes, build verification, doc/queue close-out. Nothing else was researched (per instruction); everything below is from this session's run and what it noticed in passing.
**One-line verdict:** Monitor365 (agent + server) is re-enabled, all eval gates green, toplevel **build green** (`BUILD_EXIT=0`), `nix flake check --no-build` all checks passed — **NOT deployed** (deliberate; see b/c). The blocker that justified the 66-day disable died at the source before I touched anything.

**Attribution note (shared-tree discipline):** the auto-commit daemon swept this session's changes into heuristic commits `bbb0f7965` (42 files) and `8293f719a` (4 files). Still dirty at report time: `AGENTS.md` (+1), `docs/CONTRIBUTING.md` (+28) — a PARALLEL session's docs edits, not mine — plus my last two todo-file edits (`docs/todo/pipeline.md` checklist append, `docs/todo/upstream.md` renamer row). All four remaining dirty files are docs-only: they cannot affect an eval/build. My earlier "deploy would ship the parallel session's half-done nix work" statement from the closing message is now OUTDATED — their nix-module edits (`tq-agent-pool.nix`, `systemd-shape-audit.nix`, `projects-management-automation.nix`) were swept into daemon commits mid-session. Corrected here.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **Root-cause discovery: the 2026-08-12 blocker is obsolete.** Upstream monitor365 restructured to the preparedSrc pattern — collector-utils family (wireguard-collector, clipboard-monitor, mic-monitor, ssh-key-monitor, collector-utils, hardware-identity) fetched as flake inputs via `git+ssh` OUTSIDE the sandbox, path deps rewritten in-tree, crane build with `--features otel`. SystemNix's flake.lock already held that world: `d2c77df8c`, locked 2026-10-16 08:30, all six family nodes present in OUR lock file. | `~/projects/monitor365/flake.nix` (919 lines, `makePreparedSrc`, Cargo.lock rewrite at :271-319); SystemNix `flake.lock` nodes verified programmatically |
| a2 | **Enable flip** — `monitor365.enable = true` + `monitor365-server.enable = true` in `platforms/nixos/system/configuration.nix`, stale DISABLED comments replaced with accurate re-enable rationale; storage-collector comment no longer claims to be "the data source that works while monitor365 is disabled". | configuration.nix:1429, 1471 |
| a3 | **All eval-gate findings fixed** (5 findings across 5 audits — see d5 for my miscount): upstream's `StartLimitBurst/IntervalSec` baked into serviceConfig (systemd 261+ ignores them there) → nulled per-key, values ride the wrapper's typed top-level options (5/600s); `monitor365-schema-migrate` unbounded TimeoutStartSec → 5min; schema-migrate → `ioTier.maintenance`; monitor365-server registered in the signoz-coverage census (wiring env, 26h budget; upstream build flag `--features otel` verified first-hand at upstream flake.nix:343); schema-migrate got an explicit 5min boot bound. | `modules/nixos/services/monitor365.nix`; eval exit 0 after fixes (`/tmp/m365-eval3.log`) |
| a4 | **pool-recovery roster** gained `monitor365.service` (pool-bound agent buffer, RequiresMountsFor-gated) at the CENTRAL default list with a trap-note comment (see e2 for why central). | `modules/nixos/services/pool-recovery.nix:136-140` |
| a5 | **Toplevel build GREEN** — `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going --no-link` → `BUILD_EXIT=0` (`/tmp/m365-build2.log`); monitor365 cargo-deps FOD, agent, ui, server all realized. | `nix build .#monitor365` → `/nix/store/xrzk4q8jfm91c3fp3rq08660spxzcpg8-monitor365-0.1.0` |
| a6 | **`nix flake check --no-build` → "all checks passed!"** (the aarch64-darwin omit warning is the documented expected one). NOTE the honest caveat: `--no-build` evaluates checks, it does not EXECUTE build-time lint legs (statix/deadnix/alejandra) — see b4. | flake check output |
| a7 | **packages surface restored** — `monitor365` re-added to the Linux packages block; 2026-09-15 removal note corrected (premise obsolete); quick-go exclusion kept with an HONEST new reason (master-tracking heavy Rust = freeze-class build load in the pre-deploy batch; the toplevel build surfaces its FODs anyway). | `flake/parts/packages.nix` |
| a8 | **file-and-image-renamer vendorHash shim re-added with first-hand nix-hash-fix evidence** — got-hash `sha256-4fF/8VOwhVSm+gOMRiVVlmF5ZPeVqWustlMidHijfEU=` from a real FOD mismatch at drv `5pbh840dkyvi88yqzmm6mf9ly3gk04zn-…-40176d0-go-modules.drv`, overriding a parallel session's same-day drop whose "bit-neutral" premise was invalidated by the 00:39 lock float. | `overlays/linux.nix` fleetVendorHashShims |
| a9 | **Docs closed out, no drift left in living documents:** runbook banner `docs/services/monitor365.md` rewritten (RE-ENABLED + post-deploy residue list); CHANGELOG top entry; FEATURES.md ×3 rows (§service table, §10 inputs table, §disabled-decisions table); README service row; G7 owner-decision row RESOLVED in `docs/todo/services.md`; next-deploy verify checklist appended in `docs/todo/pipeline.md`. | files cited; all swept into daemon commits |
| a10 | **Ghost-probe queue row closed in BOTH surfaces with live verification** — the §11 `monitor365.goModules` hygiene probe exists NOWHERE anymore (`goModules` absent from `.github/` and `scripts/` entirely; current hygiene step at nix-check.yml:179 only greps GOTOOLCHAIN/ref=master). TODO_LIST.md + docs/todo/pipeline.md closed in one pass (no-drift rule honored). | `rg -rn goModules .github/ scripts/` → empty |

## b) PARTIALLY DONE

| # | Item | Works now | Open | Blocker | Effort |
|---|------|-----------|------|---------|--------|
| b1 | **The re-enable itself** | Config, build, check all green | NOT DEPLOYED — no unit exists on evo-x2 yet | Owner deploy call (window, PSI history); tree is docs-dirty only now, so the nix surface is deployable | S (the deploy) + M (post-deploy battery) |
| b2 | **signoz-coverage registration** | Eval-consistent, reverse assertion satisfied | `serviceName = "monitor365-server"` is an EDUCATED GUESS — the actual OTLP serviceName the binary emits is unverified; if upstream emits something else, `signoz_traces_missing` false-pages within 26h | Needs a running server (post-deploy ClickHouse lookup) | S |
| b3 | **Docs/queue state** | Living docs updated | Historical reports (monitoring.md:82 resolution text "re-enable gated on crates.io publication…") now carry a false premise in their resolution narrative — left untouched as immutable snapshots; a docs-health ANNOTATE pass would fix | Owner instruction (annotate-vs-leave policy) | S |
| b4 | **Lint/format conformance of my .nix edits** | `nix flake check --no-build` green (eval-level) | The build-time lint legs (statix/deadnix/alejandra) did NOT execute this session; daemon commits bypass the pre-commit filetype legs (documented repo trap) — my swept .nix files are formatter-unverified | One `nix fmt` pass at a quiescent moment (walks the whole tree — the documented caveat) or wait for next interactive commit's pre-commit | S |
| b5 | **Agent desktop collectors** | `settings.collectors` enables screenshots/camera/keystrokes/etc. | The wrapper's `displayUser` block (monitor365.nix:574) — I never verified whether `displayUser` is set in configuration.nix, i.e. whether the desktop half actually rides the system agent or a user unit. Unexamined. | Config grep at deploy verification | S |

## c) NOT STARTED

| # | Item | Why not started | Still wanted? |
|---|------|-----------------|---------------|
| c1 | Post-deploy verification battery: units active (monitor365, monitor365-server, schema-migrate, both watchdogs), :9191/metrics, :3001/health, agent↔server realtime device count, gatus checks green | No deploy yet | Yes — queued in the pipeline.md next-deploy checklist |
| c2 | uid re-chown `/mnt/pool/services/monitor365` (stale 966:956 from pre-disable user) if the recreated user differs | Root-only; runtime step | Yes — documented in runbook + CHANGELOG + checklist |
| c3 | monitor365-backup.prom refresh check after first 03:00 backup fire (file is stale since Aug 2, `monitor365_backup_age_hours 999`) | Timer hasn't fired | Yes |
| c4 | Upstream file-and-image-renamer vendorHash re-pin at tip `40176d0`+ | Queued in docs/todo/upstream.md; parallel session was actively in that repo today — tip must be re-verified first | Yes |
| c5 | Push monitor365 upstream master (local HEAD `027596e69` is 2 unpushed daemon commits ahead of origin `d2c77df8c` = the locked rev) — until pushed, SystemNix lock CANNOT advance to local tip; lock-vs-tip divergence is standing | Agents never push; owner-gated | Owner call |
| c6 | The Caddy `@noCache` drop chain (services.md:368): monitor365 upstream's cache-policy fix is local-only at `72efa84b4+` → push → relock → deploy → verify headers → delete override | Same push-gate | Yes, pre-existing row |
| c7 | monitor365 input pin-policy decision: every overnight lock float now triggers a full Rust workspace rebuild inside the next deploy's toplevel — monitor365 cargo was a NAMED freeze-20 suspect, so this is a standing freeze-exposure decision, not a cosmetic one | Owner risk/cost call (question g3) | Yes — needs an owner decision |
| c8 | VM-test leg for monitor365 in the checks matrix (none exists; every other critical service got one) | Never existed; out of session scope | Worth considering |
| c9 | SigNoz alert-rule sweep for monitor365 metrics that silently return after 66 days dark (rules referencing now-resuming metric streams) | Not researched this session (instruction) | Verify at deploy — the §10 phantom-metric gate auto-loans on config diff, which covers the pre-deploy side |

## d) TOTALLY FUCKED UP

Nothing I broke is STILL broken — but all three of these really happened, and the first one is the kind of mistake that ships to prod when the eval gate doesn't exist:

| # | What | Severity | Root cause | Status |
|---|------|----------|------------|--------|
| d1 | **I wiped the pool-recovery convergence roster.** My first registration `services.pool-recovery.restartUnits = [ "monitor365.service" ]` in the wrapper REPLACED the option's entire default list (mkOption defaults do not concat-merge with the first external definition) — eval #2 suddenly flagged atticd, bank-sync, discordsync, immich-server, immich-machine-learning, all four paperless units, tq-serve, tq-agent-pool as unconverged. Had this been deployed: the next DAS remount stops 11 pool-bound daemons and NOTHING converges them back — the exact 2026-10-04 20-min-dark-outage class, caused by me. | Critical (caught pre-deploy) | I wrote a definition before reading the option's declaration — read-before-write applies to OPTION SEMANTICS, not just file contents | Fixed: reverted to central-list registration + trap-note comment in pool-recovery.nix. The eval gate caught it; that gate is the only reason this list is in (d) and not in a post-mortem |
| d2 | **I started a multi-minute toplevel build on a known-live shared tree, and a parallel session's edit landed under it mid-build.** Build #1's failure verdict (renamer FOD mismatch vs the then-present shim) was VOID per the repo's own vendor-freshness doctrine — a mid-gate mutation invalidates the run. I knew this doctrine exists and ate it anyway. Wasted one full build cycle; worse, I nearly re-added a shim based on evidence from a poisoned run before checking the timeline. | Process (M) | No quiescence/content-pin check before long builds — the doctrine is written for the §11 gate but not habitualized for ad-hoc verification builds | Build #2 re-run against the settled tree: green. Improvement proposed in e3 |
| d3 | **My multiedit left configuration.nix syntactically broken for one tool-call window.** Edit 1 of a 4-edit batch consumed `monitor365 = {` + `enable = false;` in its old_string but did not re-emit them; edit 2 (which was supposed to re-add them) then failed to match. Tree was mid-broken until my repair edit. Any concurrent eval in that window fails with "attribute missing" — the documented tracked-files trap, triggered by me. | Transient (S) | Chained edits where edit N depends on edit N-1's rewrite of the same region — constructively unsafe | Fixed immediately; lesson in e4 |
| d4 | **Standing fucked-up things I noticed (not mine, but this session made them load-bearing):** (1) upstream file-and-image-renamer's baked vendorHash is STALE at its own tip — the shim treadmill took its THIRD bite this week (overview 2026-10-17, renamer drop+re-add 2026-10-18); (2) monitor365 upstream is lock-divergent: 2 unpushed local commits mean the SystemNix lock can never reach local tip until someone pushes — a silent split-brain between what the owner's checkout builds and what SystemNix builds; (3) the renamer shim I re-added has a built-in drop condition nobody is watching — the third shim in the fleet with "drop when upstream bakes the hash" as an unowned, unwired expectation. | Ongoing (M each) | Shim lifecycle is comment-enforced only | Queued: f10, f12; improvement e6 |
| d5 | **I undercounted my own evidence in the closing message: "4 eval-audit findings" — the first eval actually failed with FIVE assertions** (shape-audit timeout, start-limit, signoz-coverage, pool-recovery, io-tier; the CHANGELOG entry lists 4 with pool-recovery narrated separately as the trap). Sloppy summarization from memory instead of counting the list I had in a log file. The repo has a named rule about exactly this (assert WHICH question your evidence answers). | Cosmetic but pattern-relevant | Summarized from memory | Confessed here; evidence logs preserved in /tmp (note: tmpfs — gone after reboot; the claims above are re-derived from this session's transcript) |

**"Did you lie to me?" — audited:** No deliberate lies found. Two precision debts, both confessed above: the 4-vs-5 count (d5) and "the package BUILDS from the restored surface" (a5) — precisely, it realized from the nix build #2 cache; that still proves validity, but "built in this session's run" would be the overstated reading for the agent package (the server/ui/deps chain did build fresh in run #1 before the void).

## e) WHAT WE SHOULD IMPROVE

1. **Read the option declaration before defining against it (d1).** Concretely: before ANY wrapper-side definition of an option another module owns, grep its `mkOption` block for `type`/`default`/`apply`. `types.listOf` with a `default` = first-definition-wins. This cost one eval cycle here; on a less-audited option it ships dark.
2. **Quiescence pin before long builds on shared trees (d2).** Cheap habit: `git status --short | sha256sum` before starting a build and again before interpreting its verdict; mismatch = void, re-run. The vendor-freshness gate does this for deploys; ad-hoc verification builds deserve the same two-line guard.
3. **Never chain same-region edits in one multiedit (d3).** When edit N's old_string lives where edit N-1 wrote, use sequential single edits — the batch is only safe when the regions are disjoint.
4. **Count findings from the log, not from memory (d5).** Evidence-rule hygiene: the closing message should quote the count from the artifact.
5. **Premise-check at queue time applies to MY OWN registrations:** the signoz-coverage entry's serviceName should have carried a "verify at first fire" flag in the checklist row — registered on an assumption, verification only implied. Now it is (f6).
6. **The vendorHash shim lifecycle needs an owner, not a comment.** Three incidents in three days, each "re-add ONLY via nix-hash-fix evidence". Concrete fix: an eval-time check that FAILS when a shim's specified hash equals the upstream-baked hash at the locked rev (the bit-neutral case = auto-drop candidate), so shims retire themselves instead of rotting. This is a small `lib/` audit in the pattern of `flake-input-pin-audit.nix`.
7. **Master-tracking heavy-Rust inputs need a pin POLICY, not case-by-case pain.** monitor365 is now the biggest master-tracking input in the deploy path. The repo already has the deliberate-pin trail pattern (llama-rag, paperless-gpt, qmd — all REV/TAG-pinned with LIFT conditions, audited by `flake-input-pin-audit.nix`). Extending it to monitor365 (or explicitly accepting the rebuild cost) should be a recorded decision, not a default nobody chose.
8. **Bootstrap-SSO-era X11 dead weight in the wrapper:** `runtimeDeps` still ships xdotool/xprintidle/scrot/wmctrl marked "non-functional on niri (Wayland-only)" — 5 packages of known-dead weight in every unit PATH. Prune when upstream's Wayland support lands, or prune now with an upstream-tracking row (f38).

## f) NEXT TASKS (up to 50, ranked by impact — HARVEST PENDING OWNER INSTRUCTION)
> **Harvest disposition (docs-health 2026-10-18):** NOT HARVESTED — because the authoring instruction was report-then-wait (owner-gated; note above). Continuation of this work stream is tracked in docs/planning/2026-10-18_02-35_DOCS-CORPUS-PARETO-COMPLETION-PLAN.md.

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Deploy the re-enable (`nix run .#deploy`) at an owner-chosen window — tree is docs-dirty only now | Critical | S | Feature |
| 2 | Post-deploy: verify 5 units + 2 timers active (monitor365, monitor365-server, schema-migrate, agent-watchdog, server-watchdog) | Critical | S | Verification |
| 3 | Post-deploy: :9191/metrics + :3001/health smoke; post-deploy-check un-SKIPs automatically | High | S | Verification |
| 4 | Post-deploy: agent↔server connectivity (realtime device count ≥ 1, the §"Monitor365 agent ↔ server" section) | High | S | Verification |
| 5 | Post-deploy: uid check + chown `/mnt/pool/services/monitor365` (stale 966:956) | High | S | Bug |
| 6 | Post-deploy: ClickHouse lookup for the real OTLP serviceName; fix the signoz-coverage registry entry if ≠ "monitor365-server" | High | S | Bug |
| 7 | Post-deploy: gatus checks for monitor vHost/:9191 green (they un-gate with enable) | High | S | Verification |
| 8 | Post-deploy: confirm monitor365-backup.prom refreshes after first 03:00 backup fire; watchdog timer fires cleanly | Medium | S | Verification |
| 9 | Post-deploy: boot-transaction check — schema-migrate is boot-blocking; confirm it adds no measurable boot time (5min cap holds the wedge class) | Medium | S | Verification |
| 10 | Watch the renamer shim drop-condition: drop when upstream bakes `4fF/8VOw…` | Medium | S | Cleanup |
| 11 | Upstream file-and-image-renamer: re-pin vendorHash at current tip (queued row in upstream.md; re-verify tip first — parallel session active there) | High | S | Bug |
| 12 | Build the shim-retirement eval audit (shim hash == upstream-baked hash → throw "bit-neutral, drop it") — ends the treadmill | High | M | Quality |
| 13 | Owner decision: pin monitor365 input (rev/tag + deliberate-pin trail + pin-audit allowlist) vs accept master-tracking Rust rebuild per float | High | S (decision) | Decision |
| 14 | Push monitor365 upstream master (2 unpushed daemon commits) so lock can track local tip — kills the lock-vs-tip split brain | Medium | S | Cleanup |
| 15 | Execute the Caddy @noCache drop chain for monitor vHost (push → relock → deploy → verify Cache-Control headers → delete override) | Medium | M | Cleanup |
| 16 | Post-deploy: re-run platform-inventory export — monitor365/monitor365-server zero-deploy chips should flip to deployed | Low | S | Documentation |
| 17 | Triage the 9 zero-deploy catalog entries (services.md:584) — this deploy resolves 2 of the 9 near-misses | Low | M | Cleanup |
| 18 | Investigate the eval warning seen this session: "catalog: 21 integration subdomains without catalog entries — they vanish from derived DNS once dns-local.nix is deleted" | Medium | M | Bug |
| 19 | §11 gate: monitor365's crane cargo-vendor FOD now rides the toplevel dry-run but the §11 anchor only matches `*-go-modules.drv` — decide whether the gate should also pin the Rust FOD class or accept toplevel-build-time discovery | Medium | M | Quality |
| 20 | Decide storage-collector's future now that monitor365 storage metrics resume (duplicate-ish data sources; storage-collector was explicitly the "works while monitor365 is disabled" substitute) | Medium | S (decision) | Decision |
| 21 | Fresh-vs-old state decision for first start: the pre-disable DuckDB (66 days old) + pool event buffer will be OPENED by the heal script, not reset — confirm that's wanted (drives #5's chown too) | High | S (decision) | Decision |
| 22 | Fold the re-enabled monitor365 Pocket-ID client (99d stale secret) into the rotation decision row (services.md:464) | Low | S | Cleanup |
| 23 | Verify sops agent↔server API key decrypts at deploy (eval-green implies declared; runtime check pending) | Medium | S | Verification |
| 24 | Verify §17 memory sweep against monitor365-server's 4G/3G watermarks under first real load | Medium | S | Verification |
| 25 | Verify desktop collectors: grep `displayUser` wiring; confirm which of screenshots/camera/keystrokes actually fire on niri; prune the dead ones from `settings.collectors` | Medium | M | Cleanup |
| 26 | Prune the 5 known-dead X11 tools from wrapper `runtimeDeps` (xdotool, xprintidle, scrot, wmctrl + procfs overlap) with an upstream-tracking row | Low | S | Cleanup |
| 27 | Add a monitor365 VM-test leg to the checks matrix (none exists for a service with DuckDB + watchdog + boot-blocking migrator) | Medium | L | Quality |
| 28 | Consider an eval assertion pinning the pool-recovery roster ⊇ a known minimum set (the d1 wipe would then be structurally impossible, not just gate-caught) | Medium | S | Quality |
| 29 | Run the formatter/lint legs standalone on this session's .nix files at a quiescent moment (daemon sweeps bypassed them) | Low | S | Quality |
| 30 | Re-verify evo-x2 eval immediately before deploy (parallel sessions may have moved nix files since my green) | High | S | Verification |
| 31 | docs-health ANNOTATE: append correction to monitoring.md:82's resolution text ("unblock was the upstream restructure, not crates.io publication") | Low | S | Documentation |
| 32 | Add the RUST preparedSrc variant to docs/agents/nix-flakes.md (the doc describes the Go mkPreparedSource pattern; monitor365's crane variant is now load-bearing and undocumented) | Low | S | Documentation |
| 33 | HARVEST this report's f-items into TODO_LIST + domain libraries (docs-health HARVEST) — pending owner go | High | S | Documentation |
| 34 | Update FEATURES monitor365 chip 🔧→✅ only AFTER deploy (it currently reads ✅ with "deploy pending" — defensible, but post-deploy should drop the qualifier) | Low | S | Documentation |
| 35 | Sequence the pending "deploy pending" backlog deliberately — this deploy plus the 2026-10-17 wave closes many tagged entries at once; one deploy, one verification pass | Medium | S | Planning |
| 36 | Post-deploy: system-health collector's monitor365 buffer-pressure stanza resumes — verify metric presence (§10 loans auto-resolve) | Low | S | Verification |
| 37 | Post-deploy: check for stale SigNoz alert rules referencing monitor365 metrics from the enabled era (false-signal audit, both directions) | Medium | S | Verification |
| 38 | Upstream row: Wayland collector support (grim/slurp/wtype provided by wrapper, upstream support partial — the X11 tools stay dead until then) | Low | M | Feature |
| 39 | Audit whether the input-hygiene ref=master warning count changed with monitor365 re-add (cosmetic CI-noise check) | Low | S | Cleanup |
| 40 | Consider rev-pinning the renamer INPUT in SystemNix until upstream re-pins (alternative to shim churn; policy sibling of #13) | Low | S (decision) | Decision |
| 41 | Record the pool-recovery `mkOption` default-replacement trap in docs/agents/systemd.md (it bit a senior pattern; it will bite again) | Medium | S | Documentation |
| 42 | Post-deploy: verify DuckDB WAL-heal path (ExecStartPre) on the 66-day-old state dir; confirm backup-restore leg finds the nightly backups it expects | Medium | S | Verification |
| 43 | Post-deploy: PSI watch during the FIRST monitor365 cargo rebuild after the next lock float (the freeze-20 suspect class, now in the deploy path) — feeds the #13 decision with data | Medium | M | Verification |
| 44 | Annotate the OLD status reports claiming "re-enable requires owner decision" as superseded (historical layer — lowest priority, ANNOTATE not rewrite) | Low | S | Documentation |
| 45 | Check whether `checks.x86_64-linux` fixtures (forgejo/storage/migrations) need a monitor365 fixture now that the module is live again (fixtures exist for other revived services) | Low | M | Quality |
| 46 | Confirm the flake-input-pin-audit allowlist needs no entry for monitor365 (branch-pin `?ref=refs/heads/master` is the tracking style — audit passed this session, but record WHY in the allowlist comment if it enumerates) | Low | S | Documentation |
| 47 | Post-deploy: confirm `deploy.sh` provisioner leg fires monitor365-schema-migrate (it is in the provisioners list at deploy.sh:718/760 — verify the 300s restart path exercises) | Medium | S | Verification |
| 48 | Decide whether quick-go should gain monitor365 AFTER the build load-shaping policy decision (stability.md [decision] row) lands — revisit the exclusion with data | Low | S (decision) | Decision |
| 49 | Sweep `docs/services/monitor365.md` runbook for further pre-disable staleness on first live contact (it was written while disabled; e.g. daily-event-limit override note) — fix on sight per proactive-maintenance rule | Low | S | Documentation |
| 50 | The d1 trap generalizes: sweep OTHER wrapper modules for wrapper-side definitions of foreign defaulted-list options (same bug class, different module — one `rg` audit) | Medium | M | Quality |

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy now or sequence it?** The tree's nix surface is clean (remaining dirty files are docs-only), the build is green, and this deploy would also close most of the 2026-10-17 "deploy pending" wave — but I cannot see the OTHER session's next move (it was mid-work on monitor365 upstream and repo docs an hour ago), nor do I know your PSI/window preference tonight (the 2026-10-10 storm-deferred-deploy precedent says quiet-window). Deploy now, or wait for the parallel session to land + a quiet window?
2. **First-start state: open the 66-day-old world or start clean?** On deploy, the server will open the pre-disable DuckDB (WAL-heal + backup-restore path armed) and the agent will reuse the uid-966 pool buffer — 66 days of stale events and old-era state. Keep the history (accept the chown + possible schema surprises) or wipe `/var/lib/monitor365-server` + the pool buffer tree for a clean genesis? This decides task #5, #21, #42.
3. **Pin policy for monitor365 (and renamer) inputs?** Master-tracking means every overnight lock float drags a full Rust workspace rebuild into the next deploy (freeze-20's named suspect, now permanently in the deploy path) and keeps the vendorHash shim treadmill spinning. Do you want deliberate rev-pins with LIFT conditions (llama-rag pattern) for heavy Rust inputs, or do you accept the float-and-rebuild cost as the price of tracking?

---

**Report format note:** `.md` at the explicitly requested path (user instruction overrides the skill's HTML-canonical default — flagged per the skill's override rule).
**Loop note:** section (f) is HARVEST-ready but deliberately NOT yet written into TODO_LIST/domain libraries — waiting for instruction, per the standing "report then wait" contract.
