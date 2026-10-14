# Status: Samsung Hot-DB Waves 1+4 (gatus + browser-history) — Live, With a Rough Landing

**Session:** 2026-10-14, ~13:35–16:15 CEST (single agent session, one active
parallel session throughout).
**Scope executed:** move the gatus DB and the browser-history DB off the QLC
root onto the Samsung 970 EVO Plus (`services.hot-db`, waves 1 + 4), per the
owner's standing 2026-09-30 QLC-churn evacuation doctrine and the
`docs/services/hot-db.md` wave procedure.

---

## a) FULLY DONE

1. **Both DBs live on the Samsung TLC.** `hot/gatus` mounted at
   `/var/lib/private/gatus` (3 files, 19,940,064 B byte-exact cutover),
   `hot/browser-history` at `/var/lib/private/browser-history` (3 files,
   204,124,160 B byte-exact cutover; finalize grew to 5 files/204,165,200 B —
   server recreated WAL+shm, the expected live-write signature).
2. **The full wave procedure ran in order, landmine-safe:** warm `prepare`
   both (services running) → entry edit → `nix flake check` green → toplevel
   pre-build → `cutover` both (stop → quiesced delta → verify → marker) →
   deploy → `finalize` both (biggest-file floor + count gates green, units
   restarted). Subvols were populated BEFORE any tree carrying the entries
   could deploy — the 2026-10-12 empty-subvol shadow-split landmine was
   structurally unreachable.
3. **Deployed + anchored: system-885.** `/run/current-system` ==
   `system-885-link` (verified post-deploy). A reboot boots WITH the mounts.
   (The first switch left the profile unset — see d) — closed by re-run.)
4. **Functional verification end-to-end:** `hot_db_entry_mounted{name="gatus"} 1`
   and `{name="browser-history"} 1` in the fail-closed collector textfile;
   gatus `:9110` answers 200 and its watchdog was actively processing alerts
   (thermal + /tmp checks firing) within minutes of restart; browser-history
   `/health` → 200; agent ingest flowed through the mounted DB within 254 s
   of restart (`browser_history_agents_active 1`, `scrape_errors 0`, token
   table readable); both journals clean of error/readonly/panic lines.
5. **Entries declared with stance comments**
   (`platforms/nixos/system/configuration.nix`, hot-db block): gatus (wave-1
   snippet) + browser-history (wave-4 snippet with token-provision + backup
   anti-shadow wiring). Both carry the documented fail-closed stance for
   `*Directory=` implicit RequiresMountsFor (correct for DATABASE stores).
6. **Docs updated:** `docs/services/hot-db.md` Current state (waves 1+4 LIVE,
   combined-window rationale, actual storm-override record) + wave-table rows
   annotated LIVE with the ACTUAL stop-window lengths.
7. **Upstream vendorHash lift queued** in `docs/todo/upstream.md`
   ([blocked:push], one combined row, lift verbs in the flake.nix comments) —
   self-harvested at authoring time per the status-report rule.
8. **Three shared-tree build blockers fixed so the deploy could land at all**
   (detail in d/e): `erraudit` pinned back to `d46cb98`, `crm` to `1ee70909`,
   `golangci-lint-auto-configure` to `ddb54527` (each: FOD + package
   probe-verified green BEFORE pinning; documented ROLLBACK PIN comments with
   lift verbs in `flake.nix`); `go-structure-linter` re-locked to its 15:01
   upstream vendorHash fix `0ee78c8d`. All durable URL hard-pins
   (bank-sync 2026-10-14 pattern — blanket re-locks cannot float them).

## b) PARTIALLY DONE

1. **The stop window was NOT tight: ~48 min of monitoring blindness +
   ingest stall** (cutover ~15:13 → finalize ~16:01) against a runbook
   expectation of ~1–3 min. Root cause: the first deploy died on a
   shared-tree FOD that landed between my pre-build and my deploy. The
   migration itself was correct; the window discipline under an active
   parallel session was not.
2. **The first post-migration deploy was UNANCHORED** (`/run/current-system`
   != `system-884`, "a REBOOT WILL REVERT"). Closed by the sanctioned re-run
   (system-885), but I did NOT root-cause WHY the profile-set failed once and
   succeeded on the next run. The parallel session's `env_keep` fix for the
   nix-heavy-builds-gate was already IN the deployed tree when it recurred —
   so either their fix is incomplete or the mechanism is different. Open.
3. **`docs/services/hot-db.md` wave procedure still says ONE PER WAVE** as
   the only sanctioned shape. This session ran waves 1+4 combined in one
   window (prepare+cutover both BEFORE the single deploy) and it was
   landmine-safe by construction. The Current-state section documents the
   instance; the PROCEDURE section does not yet describe the combined-window
   variant and its precondition (all entries prepared AND cut over before
   ANY deploy carrying them).
4. **Backup-leg verification through the mount is pending by design:**
   browser-history's 02:15 `sqlite3 .backup` has not yet run against the
   mounted subvol (tonight is the first). The anti-shadow wiring is deployed
   and eval-verified; the first real run is the proof. Same for one full
   gatus check cycle + nightly btrbk cycle (the eval-time landmine scan
   passed; a live cycle is the belt-and-suspenders).
5. **Rollback insurance not yet reclaimable:** the shadowed QLC originals
   (20 MB + 204 MB) sit under the mountpoints, per the soak doctrine. Space
   impact is trivial; the RECLAIM step (contents-only removal, keep dirs) is
   documented but time-gated on the owner's soak-end call.
6. **Monitoring-first latency note:** gatus/browser-history moved DESPITE the
   2026-09-21 fsync-matrix "STAY" verdicts because the owner's 2026-09-30
   churn-evacuation doctrine supersedes it (documented in hot-db.md). No
   post-move fsync re-measurement was done — the trade was accepted, not
   re-measured.

## c) NOT STARTED (no work owed by this session; listed for completeness)

1. **Waves 2, 3, 6** (dnsblockd, pocket-id, storage-collector) — remaining
   hot-db migrations, untouched this session.
2. **The future postgres wave** — snippet verified in the runbook, not
   applicable here.
3. **Soak-end reclaim of the two shadowed QLC stores** — time-gated, owner
   call.
4. **fsync re-measurement of gatus/browser-history on TLC** — the 2026-09-21
   matrix was measured pre-move; a post-move confirmation round was not part
   of this session's ask.

## d) TOTALLY FUCKED UP (honest list)

1. **I deployed into a moving tree and it cost a 48-minute window.** Between
   my pre-build (~15:08, RC=0) and my deploy (~15:13), the parallel session's
   daemon commits landed (14:59 / 15:03 / 15:09) registering inputs whose
   upstream HEADs carried stale vendorHashes. My deploy's re-eval picked them
   up and the build died (`erraudit` FOD hash mismatch) — with both services
   already STOPPED. I content-pinned at session start (13:35) but NOT
   immediately before the deploy. The correct move: re-run `git status` +
   `git log` + a fresh toplevel eval in the seconds between cutover and
   deploy, and treat ANY new commit as a stop-and-inspect trigger. The 2026-
   08-30 "12 CV files rode a push" lesson has a sibling: a stale pre-build is
   not a pre-flight check.
2. **The failed first deploy cascaded into three more discoveries I then had
   to fix live with units down** — crm + golangci-lint-auto-configure were
   ALSO stale at HEAD (masked behind erraudit in the first enumeration).
   Fixing them was right (their pins restored last-green, probe-verified);
   doing it while MY units were down and gatus was blind was the wrong
   sequencing — that work should never have been able to block a hot-db wave.
   A pre-deploy tree-drift check would have caught all three BEFORE cutover.
3. **48 minutes of fleet monitoring blindness is a real incident**, not a
   footnote. Gatus is the alerting backbone; every check in the fleet reded
   (Discord storm on recovery). The runbook's "~1-3 min" tolerance assumes a
   tight window; I stretched it 16× on a moving-shared-tree miss.
4. **I accepted heavy eval/build IO into a 50–70% PSI storm** on the owner's
   "just do it now anyway" — the box survived, but the nix-heavy-builds-gate
   exists precisely because this class has produced freezes (#14→#25). The
   owner override makes it sanctioned, not smart. The smarter execution of
   the same order: prepare (tiny) immediately, then cutover+deploy with the
   SHORTEST possible build (everything pre-built + fresh-eval-gated), and if
   the tree was dirty, cutover would have waited for the fix instead of
   services waiting down.
5. **`MIGRATE_PSI_FILE=/dev/null` bypassed the script's own pressure gate.**
   Sanctioned hook, owner override, tiny data — but it means the "the script
   refuses during storms" story did NOT hold this session. If this pattern
   repeats, the gate should learn an explicit, loud `MIGRATE_ALLOW_STORM=1`
   instead of a silent /dev/null side-channel.
6. **Minor: the first `du` probe returned nothing** (DynamicUser 0700 dirs)
   and I burned a round-trip before switching to the harness pattern; and my
   first window-waiter had a broken trip-age calculation (journalctl epoch
   field) that silently printed garbage for 90 minutes while its PSI
   condition (the part that mattered) still worked.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-cutover freshness gate (new doctrine candidate):** the wave
   procedure should END with "re-pin, re-eval, deploy" — a `git log -1` +
   fresh `nix eval toplevel` check in the same breath as cutover, so a moving
   tree aborts BEFORE services stop, not after.
2. **Root-cause the deploy anchor failure mode once** (see b2). "Re-run until
   anchored" is not a fix; the second unanchored switch was one bad
   coincidence away from a reboot reverting the hot-db mounts into a
   split-brain (services writing the QLC shadow dirs under the mounts).
3. **Codify the combined-window variant** in hot-db.md (precondition:
   every entry prepared AND cut over before any deploy carrying them; single
   deploy; verify each marker separately). Waves 2+3 are the natural next
   combined pair.
4. **Parallel-session deploy handshake:** with ≥2 active sessions, the
   cutover→deploy gap should include a "no new commits in the last N minutes
   AND deploy lock free" assertion. The tq pool / auto-commit daemon makes
   commit-storms routine; the wave procedure predates that reality.
5. **Soak monitoring:** add the two new stores to whatever soak checklist
   tracks discordsync (one verified 02:15 backup + one week uptime) so the
   reclaim decision is evidence-driven, not memory-driven.
6. **fsync re-measurement post-move** would close the loop on the 2026-09-21
   trade reversal with data instead of doctrine.

## f) NEXT (up to 50, ordered by impact; items marked ⭕ are this session's direct follow-ups and are harvested into TODO_LIST/domain libraries per the standing rule)

**This session's direct follow-ups (⭕ harvested now):**
1. ⭕ `[watch]` Verify tonight's 02:15 `browser-history-backup` lands pool-side through the mounted subvol (first real run).
2. ⭕ `[watch]` Soak gate (≥1 week, incl. one verified gatus check cycle + backup): then reclaim both shadowed QLC stores (contents-only, keep dirs).
3. ⭕ `[blocked:user]` Root-cause the deploy profile-set/anchor failure (recurred once WITH the env_keep fix deployed); fix the mechanism, not the retry.
4. ⭕ `[ready]` Codify the combined-window wave variant in `docs/services/hot-db.md` (precondition + marker-per-entry verification).
5. ⭕ `[blocked:push]` Upstream vendorHash refreshes in erraudit / crm / golangci-lint-auto-configure, then lift the three rollback pins (row landed in docs/todo/upstream.md).
6. ⭕ `[watch]` One full gatus check cycle + one nightly btrbk cycle with live confirmation that no btrbk instance touches `hot/gatus`/`hot/browser-history` (eval scan passed; live belt-and-suspenders).

**Hot-DB tier continuation:**
7. Wave 2: dnsblockd → Samsung (LAN DNS blip window).
8. Wave 3: pocket-id → Samsung (SSO blip window).
9. Wave 6: storage-collector → Samsung + flip the 1 GiB window knobs in the SAME window.
10. Consider waves 2+3 as the first sanctioned combined window (validates the b4 variant).
11. Re-measure gatus/browser-history fsync latency on TLC post-move (closes the 2026-09-21 trade with data).
12. After all six waves land: revisit the root `@` btrbk retention bump (storage.md notes "revisit to 1w then").

**Shared-tree / pipeline (observed live this session):**
13. Deploy-script guard: abort cutover-class procedures when `git log` moved since pre-build (generic form of #1).
14. Investigate why nh's profile-set can silently no-op under the heavy-gate even with FORCE exported (anchor b3).
15. `cv-server` journal rate 2060 lines/min (deploy §18 FAIL, baseline-matched) — find the log flood source upstream.
16. `bank-sync` sync cycles failing since restart (deploy §18 FAIL) — likely the known go-cqrs-lite ceiling class; confirm which.
17. `/tmp` tmpfs >80% (~38 GiB of 48) — gatus alerted mid-session; identify the accumulator before it wedges builds.
18. Forgejo `memory.events` high-counter at 959k (deploy §17 WARN) — investigate reclaim-thrash vs real pressure.
19. discordsync MemoryHigh 37,690 hits — same §17 sweep class.
20. inboxclean-web has read ~833 GB cumulative and drove tonight's storm windows — is a re-index loop stuck? (top-IO in the guard's own trip reports).
21. The storm itself: 6+ guard trips/hour for 3+ hours — post-storm review of what the Zone-6 cycling actually protected vs delayed.
22. The parallel session's active work ("fix build / improve architecture") — coordinate before it re-bumps the three pinned inputs past the pins (it now CANNOT via blanket lock — good — but a flake.nix edit can still fight mine).

**Pre-existing rows I touched/read this session (execute, don't re-file):**
23. Lift the bank-sync `?rev=` ceiling pin when upstream lands the stream-key fix (docs/todo/upstream.md row 1).
24. Audit the other four `618d4593` wave inputs against documented ceilings (row 2).
25. Fleet-wide infra follows in the LarsArtmann tool repos (the 454-node regrowth class — row 3).
26. Push go-taskqueue master (ahead 13) + re-add the `done-preflight` key on re-lock (row 4).
27. SigNoz coverage: overview + PMA span sites, papdashboard metrics, hermes Python SDK (rows 7-8).
28. Forgejo upstream: file the 3 verified mirror-outage issues once a Codeberg token exists (row 9).
29. browser-history read-model Count()=0 gate gap upstream (row 10).
30. cqrs-htmx usermgmt: ES-registered user LOST across restarts (row 11).
31. Propagate the cqrs-htmx import-gate fix to browser-history (row 12).
32. PMA discovery daemon starvation upstream fix (row 13).
33. go-commit build gate (HEAD was committed BROKEN once) (row 14).
34. go-commit OPENAI_TIMEOUT release chain (row 15).
35. PMA CI guard against go-commit pin regression (row 16).

**Verification hygiene from this session's evidence:**
36. Add `hot_db_entry_mounted` for the two new entries to a SigNoz dashboard tile (registry checks exist; dashboard panel may need the new names).
37. Confirm the `browser-history-agent-metrics` collector's sqlite read path (CAP_DAC_READ_SEARCH) works against the mounted 0700 DynamicUser dir (it read fine pre-move at the same path; one post-move confirmation).
38. Spot-check `system-health`'s gatus.db `sqlite3 -readonly` staleness metric after tonight's first full check cycle (DynamicUser uid stability through the mount).
39. Record the ACTUAL cutover sizes for waves 2/3/6 in the runbook's wave table as they land (keeps the "longest delta" planning column honest).
40. Post-soak: `compsize` both subvols on TLC (zstd ratio for the DB class; feeds the wave 6 window sizing).

**Doctrinal/documentation:**
41. Add the storm-override pattern (NIX_HEAVY_GATE_FORCE + MIGRATE_PSI_FILE + DEPLOY_FORCE_PRESSURE, all three named OUT LOUD) to hot-db.md as a documented emergency shape rather than tribal memory.
42. Document in `docs/agents/nix-flakes.md`: rollback-pin protocol now has THREE live instances (bank-sync, + this session's three) — the lift verb list should be greppable in one place.
43. Consider a flake check that FAILS when a `flakePkg` input's locked rev has an upstream HEAD newer than N days with a vendorHash drift gate in place (early-warning instead of deploy-time discovery).
44. The `library-policy`/`go-auto-upgrade`/`overview`/`projects-management-automation`/`md-go-validator` class (2026-09-16 pins-kept list) deserves the same drift-gate treatment erraudit got upstream.

**Owner-facing:**
45. Decide the combined-window doctrine question (g7 below) before waves 2/3.
46. Decide soak length for gatus/browser-history (g6 below).
47. Decide whether storm-window FORCE escapes stay owner-gated per-instance or become standing policy for [watch]-class IO-tiny migrations.
48. Post-storm: revisit whether inboxclean-web belongs in the guard's sacrifice set (it was the top-IO name in every trip report tonight).
49. Sweep `/var/tmp/io-psi-forensics-*` snapshots (11:22/11:32 today) into the storm post-mortem, then trash.
50. After waves 2+3+6: update `docs/services/overview.md`/architecture-catalog if the hot tier's role description needs the final shape.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Soak + reclaim:** Are you comfortable reclaiming BOTH new shadowed QLC
   stores at the same ≥1-week mark as discordsync's (i.e. one joint
   ~2026-10-21 sweep), or does each wave keep its own clock? (I cannot know
   your risk appetite for the un-rehearsed combined window.)
2. **Doctrine:** Should future waves be allowed to combine (e.g. dnsblockd +
   pocket-id in one window, prepared AND cut over before a single deploy) —
   halving the monitoring/DNS/SSO windows — or do you want strict
   one-per-wave back after this session's 48-minute stretch?
3. **Anchor failure ownership:** The first switch after my migration left the
   boot profile unset even though your `env_keep`/sudo fix was already in
   that tree. Do you already know the mechanism (nh profile-set vs
   nix-heavy-gate vs something else), or should I get root-cause ownership
   of it as a fresh `[ready]` row in stability?

---

**Verification receipts (key evidence, this session):**
- Cutover: `files: src=3 dst=3 bytes: src=19940064 dst=19940064` (gatus);
  `src=3 dst=3 bytes: src=204124160 dst=204124160` (browser-history)
- Finalize: gatus `cutover=3 now=3` exact; browser-history `cutover=3 now=5`
  (WAL/shm regrowth = live writes)
- Mounts: `hot_db_entry_mounted{name="gatus"} 1` / `{name="browser-history"} 1`
- Anchors: `/run/current-system` == `system-885-link` →
  `3jp1v37gi3v8nq3i1mpd4253yyi3xxlx-nixos-system-evo-x2`
- Functional: gatus `:9110` → `HTTP/1.1 200 OK`; browser-history `/health` →
  `HTTP/1.1 200 OK`; `browser_history_agent_last_ingest_age_seconds 254`
- Flake: `nix flake check --no-build` → `all checks passed!` (post-entries,
  post-pins)
- Tree state at authoring: clean at `a493f8e1` (daemon-swept)

---

## Appendix A (2026-10-14 16:44): Live re-verification + the low-downtime retrospective

### A.1 Owner challenge: "both fully migrated AND VERIFIED?" — re-verified live

Fresh receipts at ~16:25, not from memory:

| Check | hot/gatus | hot/browser-history |
|---|---|---|
| Kernel mount table | `/dev/nvme1n1p2[/hot/gatus]` at `/var/lib/private/gatus` | `/dev/nvme1n1p2[/hot/browser-history]` at `/var/lib/private/browser-history` |
| Mounted-metric (fail-closed) | `hot_db_entry_mounted{name="gatus"} 1` | `hot_db_entry_mounted{name="browser-history"} 1` |
| Functional | `:9110` → 200 OK, watchdog actively alerting | `/health` → 200 OK |
| Writes flowing | checks landing in mounted DB | agent ingest 75 s old, `agents_active 1` |
| Journals (30 min) | 0 errors | 0 errors |
| Boot | ANCHORED: profile == current-system | same |

Residuals unchanged (time-gated, queued): first 02:15 backup through the
mount (tonight), one live btrbk cycle for the landmine scan, ≥1 week soak
before shadow reclaim.

### A.2 How the next waves get downtime to the ~3-minute floor

The window is only as long as the riskiest thing that can still happen AFTER
the units stop — so every failure mode must be forced to fail BEFORE cutover.
This session's 48 minutes came from exactly one miss: the tree moved between
pre-build (15:08, RC=0) and deploy (15:13) — the deploy re-evaluated a tree
that had never been built, and the FOD failure landed with units already
down. Timeline fix:

| T-minus | Step | Downtime |
| --- | --- | --- |
| −30 min | Content-pin + tree-quiescence gate (no daemon commits ≥10 min, flock free, no other active session) | none |
| −30 min | `prepare` (warm, services running) | none |
| −25 min | Edit config + `nix flake check --no-build` | none |
| −20 min | `nix build` toplevel — the ONLY heavy step, services up | none |
| −1 min | **Fresh-drift gate (the missing step):** `git log -1` equals the built rev + one cached re-eval; any drift → rebuild while UP | none |
| 0 | `cutover` (stop + seconds-scale delta + verify + marker) | **starts** |
| +1 min | `deploy` — pure switch of the pre-built closure; anchor assert | |
| +2 min | `finalize` + probes | **ends** |

Structural candidates (awaiting owner go-ahead, not yet implemented):

1. **`preflight` action for `migrate-hot-db.sh`** — eval + build + drift +
   PSI + flock → GO/NO-GO verdict, so the window is mechanically
   "preflight GO → cutover → deploy".
2. **deploy.sh anchor self-heal** — already queued by the parallel session
   (docs/todo/pipeline.md); cost this session ~7 min.
3. **gatus waves last, or blind window accepted deliberately** — it is the
   monitoring hub; also consider suppressing Discord resolve-notifications
   during a planned window (the recovery alert storm).
4. **Storm quiescence still matters** — not for the tiny rsync, but because
   eval/build into 50% PSI is slowest exactly when the switch must be fast,
   and the gates fire mid-window.
5. **Combined windows** (see §g2): waves 2+3 as one prepared-and-cut-over
   pair halves the DNS + SSO blips into a single shared window.

Data movement was never the bottleneck: 20 MB + 200 MB quiesced deltas are
seconds. The tree, the anchor, and the storm were.
