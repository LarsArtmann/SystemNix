# Pareto T0–T4 Executed — The "3-Day Outage" Was Config-Off, Not Failure

**Session:** 2026-08-15, ~00:45 → 01:45 CEST (session 7, continuing from docs-health audit closure)
**Task:** Execute `docs/planning/2026-08-14_20-58_pareto-outage-recovery-trust-restoration.md` top-down, one verified step at a time.
**Defining discovery:** The outage narrative that motivated the plan was WRONG. Live evidence overruled the plan's premises — this report documents the correction.
**Note:** This report was delivered inline at ~01:44 but never written to disk (session handoff error #1). Reconstructed faithfully; timestamps reflect the original session.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **T0.1 — Deleted stale "Reboot evo-x2" P0** | Commit `d4895c91`. Verified LIVE before deletion: `findmnt` shows ext4 `data=writeback,commit=120` on `/dev/sda1`. TODO_LIST + CHANGELOG updated in same commit. |
| 2 | **T0.2 — Routed MiniMax decision (carried ×3)** | Added next to Turso in the decisions block (`d4895c91`). No longer a floating carry. |
| 3 | **T0.3 — Stale-item re-scan** | browser-history P0 outage item DELETED (self-resolved; root-cause work remains tracked in P3 release item). Disk usage figure corrected 86→87%. |
| 4 | **T1.4/1.5 — aw-watcher forensics + permanent fix** | Root cause found: `After=graphical-session.target` without `Wants=` is skipped at boot when the target has no pending job — that's why deploy-restarts worked but boots died. Fix: `aw-watcher-window-wayland-gate` wrapper (waits ≤60s for live `wayland-[0-9]` socket, re-resolves `WAYLAND_DISPLAY` at exec) + `Wants = graphical-session.target`. Commit `6ea92969`. **Start blocked: `systemctl` tool-banned even with `--user` — needs user action (see g).** |
| 5 | **T2 — Alerting audit: DELIVERY PROVEN** | Fresh Gatus alert sends confirmed in journal 00:39–01:03. browser-history's real outage was properly paged: TRIGGERED 20:37 → RESOLVED 21:42. The webhook, severity routing, and Discord channel all work. |
| 6 | **T2 — Root cause of the un-paged "outage"** | TWO causes, neither is delivery: (1) monitor365/discordsync checks are wrapped in `lib.optionals (cfg.enable)` (`gatus-config.nix:423` pattern) — config-off services have NO checks, so "monitoring wasn't failing, it was disarmed"; (2) Gatus fires an initial alert once per failure episode — a multi-day condition = one page, then silence. Escalation gap → folded into T9.3. |
| 7 | **T3 — immich backup "repair": was never broken** | Backups were landing all along. The collector was blind: `harden {}`'s empty `CapabilityBoundingSet` stripped `CAP_DAC_OVERRIDE`, so root obeyed immich's 0700 dir bits and `stat` failed. Contrast-test proved it (755 root:root dirs readable; 0700 immich dirs EACCES). Fix: `CapabilityBoundingSet = "CAP_DAC_READ_SEARCH"` on backup-health-metrics collector (`backup-coordination.nix`). Daemon-swept into `2566b900`. |
| 8 | **THE OVERTURN — 4 services config-disabled since Aug 12 08:47** | Commit `a941f88d` mass-disabled monitor365-server, monitor365-agent, AND discordsync (a 4th dead service nobody had reported) to unblock a deploy during the WDT-crash window. Only PMA/hermes were ever re-enabled. The "3-day silent outage" was a config state, not a runtime failure. discordsync since RE-ENABLED with truth comments (daemon-swept into `2566b900`; locked rev builds clean — the Aug-12 blocker was a stale FOD cache, not a broken build). monitor365 stays off — blocked on G7 (see g). |
| 9 | **T4 ~80% — browser-history upstream release chain** | Reaper root cause SOLVED (T18.1): auth store's `CREATE TABLE IF NOT EXISTS sessions` collided with the behavioral `sessions` table; behavioral won silently → auth sessions never persisted → `no such column: expires_at` every 5 min. Renamed to `auth_sessions` + legacy migration + 2 regression tests (`b66fb6d`). OTel endpoint `Normalize()` (strips scheme+path) wired into both exporters (`843310d`, moved to `internal/otlpendpoint` after an import cycle). go.mod pins cqrs-htmx v4.8.0 + internal v0.5.0 (`b9842b8`). Templ-generated files force-committed after `.gitignore` exclusion broke clean clones (`1445ade`). Dead go.work replaces dropped (go-cqrs-lite refactor in flight — that repo untouched). |
| 10 | **monitor365 upstream left clean** | Fake-hash outputHashes experiment fully reverted. No changes remain. |

## b) PARTIALLY DONE

| # | Item | What's missing |
|---|------|----------------|
| 1 | **T4 release chain** | Tag `v0.5.0` pushed but NOT nix-buildable (stale vendorHashes + missing `subModules` for templ-components). Needs: subModules fix → hash re-harvest → commit → **clean-clone verify** → tag `v0.5.1`. bh flake.nix tree is dirty with blanked hashes (stop-point). | ~~chain advanced past this stop-point: deployed input `4e7604d` (storage/v4.7.0 era); templ-components ≥v1.8.3 pin documented in AGENTS.md; LIVE 403 verification remains TODO_LIST Priority 1~~ |
| 2 | **T1.1–1.3 service restores** | Resolved DIFFERENTLY than planned: browser-history self-recovered (3 crash-loops 21:13–21:29, stable since — permanent fix rides T4). monitor365 = config-off, blocked on G7 (wireguard-collector is a PRIVATE repo — `gh repo view` proves it — so the nix build can never fetch it from the sandbox). | ~~browser-history permanently fixed since (v4.7.0 + mkOidcGate); monitor365 remains G7-open~~ |
| 3 | **SystemNix deploy batch** | Staged in tree/commits but NOT deployed: activitywatch gate (`6ea92969`), discordsync re-enable + capability fix + bh OTel scheme (`2566b900`). All await `nix run .#deploy` (sudo banned). | ~~deployed since: gate healthy (idle/resumed 2026-08-17), discordsync running + events flowing, collector unblinded (all seven backups green, 10-28 §a.1), OTel errors gone~~ |
| 4 | **T5+** | Untouched (off-site backup slice, disk <80%, dnsblockd oomd, hermes bump, deploy reliability…). | ~~all routed: off-site P0 (pool live, 3rd copy open), disk P0 (hit 95%), dnsblockd oomd P0, hermes bump P2~~ |

## c) NOT STARTED (deliberately)

- T5 (StorageBox off-site slice) — gate G3 (order decision) with the user. ← open — TODO_LIST Priority 0 (3rd-copy decision; pool safety net live)
- T6 (disk <80%) — needs sudo for GC/prune; not attempted. ← open — escalated to 95%, TODO_LIST Priority 0
- T7–T16, T17+ — not reached this session. ← superseded — the source plan is annotated + archived by the 2026-08-17 pass; surviving work lives in TODO_LIST
- Post-deploy verification battery (backup_healthy flip, 403 register, second-login rejection) — waits on the deploy. ← open in part — backup flip VERIFIED (10-28 §a.1); 403 + second-login remain TODO_LIST Priority 1

## d) TOTALLY FUCKED UP (honest ledger)

1. **Status report never written to disk** — delivered inline only. This file is the remediation.
2. **Tagged/pushed v0.5.0 before clean-clone testing** — moved the tag 3× in 10 min (amend → fetch race → templ miss), force-pushed twice. Clean-clone build is the only real release gate; it now runs BEFORE tagging, always.
3. **v0.5.0 shipped unbuildable** despite "done" claims — stale vendorHashes, missing subModules. v0.5.1 will supersede.
4. **Monitor365 hash dance before diagnosis** — blanked hashes, burned a build cycle, THEN discovered the private-repo truth. `gh repo view <owner>/<repo> --json visibility` BEFORE any git-dep hash workflow, every time.
5. **Misread `stat` EACCES as ENOENT** — "dir doesn't exist" was actually permission-denied; re-ran with stderr and corrected.
6. **Left SystemNix edits uncommitted ~40 min** — the auto-commit daemon bundled 3 of them into parallel `2566b900`. Commit immediately after each edit; the daemon does not wait.

## e) WHAT WE SHOULD IMPROVE (session-derived)

1. **Verify outage claims against the live system before planning around them.** The entire Pareto plan's premise (3 dead services) dissolved under `git log` + config inspection. Pattern that paid off all session: verify-then-edit (reboot options, bh port, immich file existence, repo visibility).
2. **Contrast-test healthy vs failing cases** — 755-root:root vs 0700-immich `stat` results proved the capability theory in one command.
3. **`gh repo view --json visibility` is step zero for any git-dep nix workflow.**
4. **Commit after every edit** — daemon race lost twice this session.
5. **Gatus optionals-guards disarm monitoring silently** — a config-off service leaves NO trace in Gatus. Post-deploy-check should diff expected-vs-present checks, or the plan's T9.3 escalation should fire on "check vanished", not just "check failing". ← open — untracked (phantom-metric validation exists; vanished-check diff does not)
6. **One-shot-per-episode alerting means long outages page exactly once** — escalation on duration (T9.3) is the fix; don't blame the webhook. ← open — TODO_LIST Priority 3 (post-deploy failure semantics + escalation half)

## f) NEXT ACTIONS (ranked)

~~1. Write this report file (done — this is it).~~ done
~~2. Finish bh flake: `subModules = { "github.com/larsartmann/templ-components" = [ "errorpage" "htmx" "icons" "utils" ]; }` on the server's mkPreparedSource → build both packages → harvest real vendorHashes → commit → push → **clean-clone verify** → tag `v0.5.1`. (Agent unaffected — no templ-components in its module graph.)~~ superseded by the v4.7.0-era chain — deployed input `4e7604d`; templ-components pin rules documented in AGENTS.md; live-gate verification remains Priority 1
~~3. SystemNix: `nix flake lock --update-input browser-history` → eval → hand deploy batch to user: activitywatch gate + discordsync re-enable + collector capability + bh v0.5.1 + OTel scheme.~~ done — all five verified live since (gate healthy, discordsync flowing, backups green, bh healthy, OTel quiet)
4. Post-deploy verify: `backup_healthy{immich}=1` within 10 min; 403 on logged-out register; second Pocket-ID login rejected; reaper quiet; aw-watcher alive (needs `systemctl --user reset-failed` from USER). ← open in part — backup flip + aw-watcher verified; 403/second-login remain TODO_LIST Priority 1; reaper remains Priority 3
5. Answer gates (g) → resume plan at T5. ← open — owner decisions pending (G7, G3/G5/G6)
~~6. Update TODO_LIST/CHANGELOG with this session's truth.~~ done

## g) QUESTIONS I CANNOT ANSWER MYSELF (gates)

- **G7 (NEW):** wireguard-collector is a **PRIVATE** repo — publish to crates.io / make public / vendor into the workspace? Blocks monitor365 + agent + watchdog restore entirely. ← OPEN owner decision (TODO_LIST Priority 1) — DO NOT CLOSE
- **G2:** Did you receive ANY Discord alerts Aug 11–14? (Delivery is proven working now; your answer decides process-fix vs re-alert escalation under T9.3.) ~~— superseded: end-to-end delivery proven 2026-08-15 (96% event TRIGGERED/RESOLVED on Discord); the escalation half remains TODO_LIST Priority 3~~
- **Deploy authority:** run the queued deploy batch yourself (`nix run .#deploy`), or approve T12 polkit first? ~~— moot: the batch was deployed; polkit remains TODO_LIST Priority 3~~
- G3 (StorageBox order), G4 (SigNoz dashboard purge), G5 (MiniMax quota), G6 (Turso plan) — unchanged, still open. ~~— status 2026-08-17: G3 open (P0 3rd-copy decision), G4 DONE (251 zombie dashboards purged by the v7 provisioner, 2026-08-16), G5 open (carried ×4), G6 open (Turso quota outage, TODO_LIST P0)~~

---

**Runtime state at report time (01:44):** browser-history healthy post-self-recovery · monitor365 + agent config-OFF (G7) · discordsync re-enabled, awaiting deploy · aw-watcher fix committed, start blocked on systemctl ban · Discord alerting PROVEN · immich backups fine, collector now unblinded (awaiting deploy).
