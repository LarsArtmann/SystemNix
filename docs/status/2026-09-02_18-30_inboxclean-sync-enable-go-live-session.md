# Status Report — InboxClean sync go-live session

**Date:** 2026-09-02 18:30
**Session scope:** InboxClean deployment verification, SSO architecture Q&A, `sync.enable` go-live flip
**Host:** evo-x2 (NixOS, 128 GB RAM, QLC NVMe)
**Tree state during session:** shared — `niri-config.nix` + `memory-emergency-guard.nix` carried UNCOMMITTED changes from a concurrent session (flagged, untouched, respected)

---

## a) FULLY DONE

| Item | Evidence | Scope |
|---|---|---|
| Located the deployed InboxClean instance and answered the domain question | Live probe: `http://127.0.0.1:8099/health` → `status: ok`, `gmail.main: connected`, `gmail.work: connected`, `projections: ready`, `database: ok`, `event_store: ok`; dashboard HTML renders at `inbox.home.lan` (2 tracked emails, last events Aug 30) | evo-x2 runtime |
| Answered the Pocket ID question with code evidence | `inbox.home.lan` = Layer 2 `protectedVHost "inbox"` (`modules/nixos/services/caddy.nix:172`); LAN bypass via `@external not remote_ip 127.0.0.1/8 <lanSubnet>` matcher (`caddy.nix:81`) — Pocket ID login only for non-LAN sources | `caddy.nix` (read-only) |
| Explained why `sync.enable` was still false | Runbook step 5 in `modules/nixos/services/inboxclean.nix:47-49`: gate exists so the sync oneshot cannot fail exit 69 (Infrastructure family) and spam onFailure Discord alerts before OAuth tokens exist | `inboxclean.nix` (read-only) |
| Flipped the sync gate — precondition verified first | `platforms/nixos/system/configuration.nix:429-434`: `sync.enable = true` + comment citing the `/health` verification date. Flip happened only AFTER `connected` was confirmed for BOTH accounts (main + work) | `configuration.nix` |
| Syntax-validated the change | `nix flake check --no-build` → `all checks passed!` (aarch64-darwin omission warning is expected per AGENTS.md) | whole flake (eval-only) |
| Scoped the remaining work on request ("Anything else?") | Reported: deploy pending, Paperless synergy undecided, TODO_LIST Phase-2 hot-DB item lists inboxclean as a measurement candidate | — |

## b) PARTIALLY DONE

| Item | What works | What remains open | Blocker | Effort |
|---|---|---|---|---|
| InboxClean go-live (runbook steps 1-5) | Steps 1-4 done in prior sessions (sops credentials, OAuth flows for main + work, `/health` green — re-verified this session). Step 5 config flip DONE this session | The flip is **inert until `nix run .#deploy`**. After deploy: first sync tick must be verified green (journal exit 0, no `exit 69`, events flowing) | Deploy deferred: the tree carries ANOTHER session's uncommitted work (`niri-config.nix`, `memory-emergency-guard.nix`) — deploying now ships their in-flight deltas to the running system | S |
| Change attribution under the concurrent-session regime | Change made with a self-contained comment in `configuration.nix` | **The predicted hazard OCCURRED**: the auto-commit daemon batched the flip into heuristic commit `d640dc6e` ("chore: auto-commit 5 changed file(s)") before this session could PATHSPEC-commit it — the flip's authorship is now buried in a batch commit. Caught at report time via `git log -1 --stat -- configuration.nix`. Improvement e)2 is no longer theoretical | — | S |
| Paperless synergy (InboxClean attachments → Paperless) | Paperless-ngx is live at `127.0.0.1:2892`; the integration point (`PAPERLESS_URL`/`PAPERLESS_TOKEN` via environmentFile/extraEnvironment) is documented in AGENTS.md | Nothing wired. Needs a Paperless API token (user-created) and a decision that this is wanted at all | User decision + token | M |

## c) NOT STARTED

| Item | Why not started | Still wanted? |
|---|---|---|
| Deploy of the sync flip | Deliberately held during the session: concurrent session's changes were then uncommitted in the tree. Resolved since: the other session landed (`1363219d`, `1ac39689`) and the tree is now clean — deploy is UNBLOCKED and is the immediate next action | Yes — blocked on nothing but the user's go |
| Post-deploy first-sync verification (journal `status=0`, timer registered at 30-min cadence, events appear in dashboard) | Depends on deploy | Yes — a green `/health` proves tokens, NOT that a sync run succeeds; first real run is the only proof |
| Sync-failure observability check (does anything page if sync silently stops succeeding? `onFailure` covers hard failures; a "no successful sync in N hours" freshness signal is NOT verified to exist) | Not researched this session (out of scope per user instruction) | Probably — candidate for a Gatus check mirroring backup-coordination freshness |
| Sync cadence tuning (`interval` defaults to 30 min) | Assumed default is fine; never confirmed with user | Needs answer (Q2) |
| AGENTS.md InboxClean section touch-up noting step 5 is now DONE on evo-x2 | Low value while undeployed; revisit post-deploy | Nice-to-have |

## d) TOTALLY FUCKED UP

Nothing this session broke. Honest findings:

1. **No damage:** the only write was the one-line config flip, validated by eval. No service was touched, no deploy ran.
2. **Pre-existing contradictions NOTICED (not caused, not investigated — flagged only):**
   - AGENTS.md carries a **FastFlowLM v1.0.3 contradiction**: the package section says "v1.0.3 HELD BACK (2026-08-31, XRT never enumerates the NPU on kernel 7.2.0)" while the freeze-#3 section says "flm bumped to v1.0.3" same day. At most one can be true; a future session touching flm could act on the wrong one.
   - The tree currently holds another session's uncommitted module edits; any `nix` eval of shared surfaces in THIS window partially reflects their in-flight state (my `flake check` passed WITH their edits present — fine today, but the pass is not purely mine).
3. **Severity of open risk:** undeployed flip = zero runtime risk. The only active hazard is process-level (commit batching / premature deploy), both flagged above.

## e) WHAT WE SHOULD IMPROVE

1. **Verify past `--no-build` for behavior-bearing flips.** I validated syntax only. For a flag that materializes a new unit (`inboxclean-sync.service` + timer), the AGENTS.md-sanctioned throwaway `extendModules` eval would have proven the unit actually renders BEFORE any deploy. Cost: ~1 min. Make it a reflex.
2. **PATHSPEC-commit session-owned files immediately in shared trees.** The auto-commit daemon batches; my flip sat uncommitted for the rest of the session. The attribution rule exists precisely for this — commit your own file the moment the eval is green, not at report time.
3. **Gates should verify, not just flip.** The runbook gate pattern (step 5) worked, but the "flip when tokens exist" precondition was only discovered by a user question. A one-line AGENTS.md/state note ("tokens live since <date>") would have made the flip self-evident at session start.
4. **Freshness monitoring for timer-driven syncs is a recurring gap class** (backup-coordination exists for backups; Gmail sync has no verified equivalent). Same shape as the PMA-commit-blackout lesson: liveness green while outcomes fail for 11 days.
5. **AGENTS.md self-contradiction check.** Two sections asserting opposite facts about the same version bump slipped through. When writing incident follow-ups, grep the doc for prior claims about the same artifact before asserting state.

## f) Top things to get done next (up to 50 — brainstorm, HARVEST will route)

> Items 1-9 are session-scoped (this run). Items 10+ derive from project context loaded during the session (AGENTS.md / TODO_LIST) — no new research was done. Sorted by impact within each block.

| # | Task | Impact | Effort | Category | Source |
|---|---|---|---|---|---|
| 1 | Rule on Q1, then `nix run .#deploy` to activate the InboxClean sync flip | Critical | S | Ops | session |
| 2 | Post-deploy: verify first `inboxclean-sync.service` run green (journal, no exit 69) + timer armed | Critical | S | Ops | session |
| 3 | Answer Q2 (sync cadence — 30 min default vs. tighter) | High | S | Decision | session |
| 4 | ~~Commit/land the concurrent session's `niri-config.nix` + `memory-emergency-guard.nix` work~~ RESOLVED during session: landed via daemon commits `1363219d`/`1ac39689`, tree clean | ~~High~~ | — | Hygiene | session |
| 5 | Verify `inboxclean-sync` onFailure Discord routing actually fires (trust-the-module today, never negative-tested) | Medium | S | Quality | session |
| 6 | Add sync-freshness signal (Gatus check on last-success age) if confirmed absent | Medium | M | Feature | session |
| 7 | Paperless synergy: decide + create API token + wire `PAPERLESS_URL`/`PAPERLESS_TOKEN` | Medium | M | Feature | session |
| 8 | Reconcile the AGENTS.md FastFlowLM v1.0.3 held-back-vs-bumped contradiction | Medium | S | Documentation | session |
| 9 | Answer Q3 (Paperless attachment archiving wanted?) | Medium | S | Decision | session |
| 10 | Repair the /data EIO inode (TODO_LIST P0 — btrbk-data sends abort nightly, /data backup coverage still broken) | Critical | L | Data | backlog |
| 11 | Rotate the still-LIVE context7 key (public git history; rotation is the fix per incident doctrine) | High | S | Security | backlog |
| 12 | Mail relay go-live: fill `mail_relay_password` placeholder + verify Resend sending domain | High | S | Ops | backlog |
| 13 | New Resend key into Pocket ID sops (old key revoked 2026-08-18; Pocket ID email broken) | High | S | Ops | backlog |
| 14 | ClickHouse telemetry backup coverage (`clickhouse-backup` follow-up — btrbk excludes it by design) | High | L | Ops | backlog |
| 15 | Execute Samsung 970 EVO role plan (64 G XFS hot-DBs + ~860 G BTRFS `/nix` per ratified design) | High | L | Infra | backlog |
| 16 | Drop the bank-sync vendorHash override in `bank-sync.nix` once upstream refreshes its flake vendorHash | Medium | S | Cleanup | backlog |
| 17 | Prune `/data/docker` (~17 G of the ~20 G is pruneable garbage per 2026-08-31 audit) | Medium | S | Ops | backlog |
| 18 | SignoZ: human `DROP TABLE` decision for the 13 permanently read-only zombie log tables (~10 GiB reclaim) | Medium | S | Ops | backlog |
| 19 | Convert `test-cv` `/mnt/pool` to `virtualisation.fileSystems` + re-verify cv-backup under a real mount | Medium | M | Quality | backlog |
| 20 | Gate browser-history `importUsers()` CSV path with `MAX_USERS` (only ungated registration path left) | Medium | M | Security | backlog |
| 21 | Verify zram auto-scaled (~62 GiB at 50%) after the 512 MiB VRAM-carveout flip reboot | Medium | S | Ops | backlog |
| 22 | Flip the 6 known OTel `wiring = "upstream"` gaps to enforced as instrumentation lands (dnsblockd, bank-sync, overview/PMA, papdashboard) | Medium | M | Quality | backlog |
| 23 | Drop still-droppable go.dev-tarball overrides on touch (browser-history, papdashboard, crush-daily, PMA — nixpkgs go ≥ floors since 2026-08-29) | Low | S | Cleanup | backlog |
| 24 | Add eval-time guard for `StartLimitBurst`/`StartLimitIntervalSec` placed in `serviceConfig` (documented trap, no guard yet) | Low | M | Quality | backlog |
| 25 | tmp-cleaner-audit: extend coverage to store-path scripts (inline-text class only today) | Low | M | Quality | backlog |
| 26 | Capture a SIGQUIT goroutine dump on the NEXT dnsblockd :9090 wedge before restarting (root cause still unknown) | Medium | S | Ops | backlog |
| 27 | Re-evaluate Helium `--disable-gpu-watchdog` / zero-copy removal after observing display-hotplug behavior | Low | S | Watch | backlog |
| 28 | Track Quickshell ScriptModel UAF upstream fix; retire the Restart=always mitigation when landed | Low | S | Watch | backlog |
| 29 | Hermes workspace layout: revisit the DEFERRED decision per its TODO trigger | Low | S | Decision | backlog |
| 30 | Delete `~/backups/activitywatch-sqlite-preDecimation-13GB.db` once settled | Low | S | Cleanup | backlog |
| 31 | macbook: free SSD space (90%+ full; nix-collect-garbage hangs — clear caches first) | Medium | M | Ops | backlog |
| 32 | Decide Gmail Takeout → immich-go ingestion path for Photos | Low | M | Decision | backlog |
| 33 | Immich admin-UI SMTP: point notifications at the mail relay (127.0.0.1:25) | Medium | S | Ops | backlog |
| 34 | Paperless inbound mail consumption: pick the mailbox + configure UI rules | Medium | S | Decision | backlog |
| 35 | Old Paperless SQLite export in `/mnt/pool/services/paperless/export`: recover-or-delete decision | Low | S | Decision | backlog |
| 36 | Wire SLO/RP-initiated logout for Layer 1 apps (per-app work, currently partial logout) | Low | L | Feature | backlog |
| 37 | Drill restore paths for twenty/manifest pg_dumps (backups exist, restores untested) | Low | M | Quality | backlog |
| 38 | Re-enable crush minimax provider when its Token Plan renews (`provider add minimax --disable true` currently rejects selection) | Low | S | Ops | backlog |
| 39 | Remove the inert `mimo_api_key` PLACEHOLDER line from sops (needs one interactive sudo sops edit) | Low | S | Cleanup | backlog |
| 40 | Signoz: decide on deleting the 251 pre-v2 zombie dashboard copies (provisioner ignores them) | Low | M | Cleanup | backlog |
| 41 | TODO_LIST Phase 2: measure fsync pain of gatus/discordsync/browser-history/inboxclean/bank-sync before moving hot DBs to the `hot` subvol | Medium | M | Perf | backlog |
| 42 | Watch for JMS567 bridge wedge recurrence; record replug outcomes in AGENTS.md (recovered 2026-08-31 after 9 days) | Low | S | Watch | backlog |
| 43 | After any future crash reboot: verify `/run/booted-system` == `/run/current-system` (Aug-16 rollback-generation trap) | Low | S | Ops | backlog |
| 44 | Rotate old store-era crush provider keys to inert the session-DB residue (relocation ≠ rotation; only rotation fixes the old bytes) | Medium | M | Security | backlog |
| 45 | Annotate aging status reports via docs-health ANNOTATE (point-in-time docs going stale) | Low | M | Documentation | backlog |
| 46 | Confirm `paperless-exporter.timer` Persistent override landed and boot catch-up works next deploy | Low | S | Quality | backlog |
| 47 | Audit whether any other backup timer lacks `Persistent` (paperless was the only found one — verify the claim once) | Low | S | Quality | backlog |
| 48 | btrfs-emergency-reserve: decide whether to auto re-provision after use (currently manual `systemctl start`) | Low | S | Ops | backlog |
| 49 | SearXNG: re-check `enable` recursion guard and restartTriggers still correct after nixpkgs module churn | Low | S | Quality | backlog |
| 50 | Feed sections (f) items 1-9 into TODO_LIST via docs-health HARVEST so they don't die in this timestamped file | Medium | S | Documentation | session |

**HARVEST note:** items 1-9 and 50 are TODO_LIST material; 10-49 are mostly ROADMAP fuel pending routing rigor.

## g) Questions I cannot answer myself

1. **Deploy now?** The blocker that held the deploy (other session's uncommitted tree changes) resolved itself mid-session — their work landed via daemon commits and the tree is clean. Deploying now activates committed state only. Still your call on timing (machine is in active use; deploys restart services).
2. **Sync cadence:** InboxClean's sync timer defaults to 30 min. Is that the cadence you want for a Gmail assistant, or tighter/looser?
3. **Paperless synergy:** do you actually want InboxClean email attachments archived into your local Paperless instance? If yes, it needs a Paperless API token only you can create (Settings → API Tokens).

---

*Point-in-time snapshot. Section (f) is HARVEST input for TODO_LIST/ROADMAP. Written as Markdown per explicit user instruction (skill default is HTML — override honored).*
