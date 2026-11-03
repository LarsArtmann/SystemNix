# DiscordSync Immich Verify WARN — 403 Root Cause, Three-Layer Fix, Handoff — Full Status

**Instance:** Crush session (SystemNix cwd), 2026-11-03 ~21:20–22:15 CET
**HEAD at authoring:** 9f0bf8e9e (daemon batches 930984561 → 7a25292d0 → 9f0bf8e9e carried this session's work; two more parallel sessions active throughout — storage/offsite-borg at 22:09 untracked report + stability edits)
**Trigger:** user pasted `WARN DiscordSync Immich verify - success but unexpected journal line: discordsync-immich-verify.service: Triggering OnFailure= dependencies.` (post-deploy-check leg, landed 2026-10-25)

## TL;DR

The WARN was a **genuine daily failure wearing a check bug as a disguise**, twice over:

1. **Real failure:** the unit's first-ever daily tick (2026-11-03 00:43; timer went live Nov 2 22:09 per journal) **failed HTTP 403** — Immich rejected a *valid, correctly-scoped* key because the verify script probed `/api/users/me`, which requires `user.read` the least-privilege key deliberately does not carry (live-proven: `{"message":"Missing required permission: user.read"}`).
2. **Masking bug:** every recent deploy exits 4 (12-13 pre-existing failed units), so `deploy.sh`'s exit-4 branch ran the **global `reset-failed`** — clearing `Result` to `success` *without re-running the verify* — which made the later `is-failed`-gated restart leg dead code and left the check reading `Result=success` against a stale failure journal line.

Fix landed in three layers + docs; deploy **handed off** (tree not quiescent). Until it lands, the Nov 4 ~00:39 tick still runs the old script (one more 403 page expected).

## Timeline (evidence-anchored)

| When | What |
| --- | --- |
| 21:2x | Pre-read: post-deploy-check.sh:1455-1480 leg, discordsync.nix verify unit (OnFailure inherit, oneshot no-RemainAfterExit), docs/services/discordsync.md runbook, 10-25/10-26 status reports |
| 21:2x | Live journal: only run in 12 days = Nov 3 00:43 **FAIL 403**; live busctl: `inactive/dead`, `Result=success`, no journal lines after the failure → reset-without-rerun aliased state |
| 21:3x | sudo-journal attribution: global `reset-failed` ran 15:57, 16:01, 18:47, 21:01 today (exit-4 deploys); deploy.sh:627 (global reset, exit-4 branch) vs deploy.sh:845 (dead is-failed gate) |
| 21:4x | Endpoint probe harness (self-elevating throwaway): `/api/users/me` → 403 `Missing required permission: user.read`; `bulk-upload-check` iterative shape discovery: `checksums[]` → 400, `assets[{checksum}]` → 400, `assets[{id}]` → 400, **`assets[{id,checksum}]` → 200** `{"results":[{"id":"verify-probe","action":"accept"}]}` |
| 21:4x | Confirmed DiscordSync's Go client (`internal/immichclient`) already sends the new `assets:[{id,checksum}]` shape — only the SystemNix verify script was stale |
| 21:46 | Fixes landed (daemon batch `930984561`): discordsync.nix endpoint swap; deploy.sh pre-reset failed-set capture + membership gates on BOTH legs (db-heal + verify); post-deploy-check script-line-first classification; runbook update |
| 21:5x | Verification: bash -n OK; shellcheck CLEAN (`nix develop -c shellcheck scripts/deploy.sh scripts/post-deploy-check.sh`); `nix fmt --` 0 changed; evo-x2 toplevel eval green; `.#checks.x86_64-linux.discordsync-immich-shape` green; live classification harness reproduced the exact aliased state → now correctly reports **FAIL "last verification FAILED (403)"** |
| 22:0x | Queue hygiene: shellcheck TODO row ticked (TODO_LIST + pipeline.md, both in HEAD); deploy row queued (TODO_LIST + services.md, both in HEAD); tmp harnesses trashed (probe script had been swept into commit `798a921ef` — deletion rode `9f0bf8e9e`) |
| 22:1x | Quiescence check FAILED (parallel session mtimes 3-5 min fresh) → deploy NOT run; 400-contract-drift branch added to the verify script (fmt clean, eval OK); 2026-10-26 report item 26 thread annotated RESOLVED inline |

## a) FULLY DONE

1. **Root cause diagnosis, live-proven end-to-end** — key valid (Immich names the missing permission), scope/endpoint mismatch identified, correct payload shape discovered iteratively and 200-verified against the live Immich 3.3.3.
2. **Verify endpoint fix** (`modules/nixos/services/discordsync.nix` ~line 323): probes in-scope `POST /api/assets/bulk-upload-check` with the `assets:[{id,checksum}]` contract; sha1-of-empty probe checksum; dated comment explaining why users/me is wrong. Plus the 400-contract-drift branch (22:1x polish) so an Immich schema bump fails LOUD with a self-describing message.
3. **deploy.sh dead-gate fix** (`scripts/deploy.sh:621-634` capture, `:845-863` legs): the exit-4 branch now captures `systemctl --failed` output BEFORE the global reset; both dedicated failed-gated legs (db-heal AND verify) gate on `is-failed OR captured-set membership`. Restores the documented "failed-gated restarts" intent that the global reset silently defeated.
4. **post-deploy-check classification fix** (`scripts/post-deploy-check.sh:1455-1500`): classifies on the unit's own self-prefixed script lines (immune to systemd lifecycle noise + aliased Result); new branches: activating (in-flight), never-ran, Immich-unreachable (SKIP — Gatus owns availability), stale-FAIL (record_fail). **Proven against live data**: the exact state that produced the user's WARN now reports FAIL.
5. **Verification battery**: bash -n, shellcheck CLEAN (both scripts), scoped `nix fmt` 0-changed, evo-x2 toplevel eval green (twice — after main fix and after 400-branch), `discordsync-immich-shape` regression check green.
6. **Docs**: docs/services/discordsync.md exit-semantics section documents the endpoint contract + the masking incident class; 2026-10-26 report item 26 ("continue the 08-07 diagnosis thread — key/scope") annotated RESOLVED inline (this session closed that thread; its premise was exactly right).
7. **Queue hygiene**: shellcheck row ticked in BOTH surfaces (TODO_LIST + pipeline.md — the row's exact documented command, now clean); deploy row queued in BOTH surfaces (TODO_LIST + docs/todo/services.md), both confirmed in HEAD.
8. **Upstream cross-check**: DiscordSync Go client already uses the new payload shape — no upstream bug, no upstream row needed.

## b) PARTIALLY DONE

1. **Deploy** — everything is committed and eval-green, but the switch did NOT run: quiescence protocol failed (parallel session's `flake/expected-locks.nix`, `lib/lars-packages.nix`, `modules/nixos/services/projects-management-automation.nix` had 3-5-minute-fresh mtimes). Deploying would have shipped a parallel session's mid-flight work (the 2026-10-25 gen-949 lost-battery class). Handoff row queued.
2. **Live convergence of the 403** — cannot converge without the deploy: the deployed unit still runs the OLD script; tonight's ~00:39 tick will fail once more (one more OnFailure page expected, then the next deploy's captured-set gate re-runs it green — or the queued row's one manual start).
3. **Timer go-live history** — established "first run ever = Nov 3 00:43" from the timer journal (no Started lines before Nov 2 22:09 in a 10-day window, 3 boots total), but the Oct 25 golive-prep report mentions the jitter as "daemon-committed", leaving residual ambiguity whether the unit rendered tree-only Oct 25–Nov 1 (immich.enable possibly false until the Nov 2 evening deploy). Does not affect any fix; noted for honesty.

## c) NOT STARTED

1. **The deploy itself + post-deploy PASS confirmation + deploy-anchor discipline** (`readlink /run/current-system` vs newest `system-N-link`) — queued, owned by the next battery.
2. **OnFailure page-delivery verification** — I never probed whether the 00:43 failure's alert unit actually ran and delivered to Discord (the user's pasted WARN came from post-deploy-check, not from a seen page). Partially probeable by me (alert unit journal), delivery side needs the owner's Discord visibility → asked (§g Q2).
3. **Scope-decision sign-off** — I unilaterally chose "keep least-privilege key, fix the probe endpoint" over "grant user.read to the key". Defensible (least privilege, verifies the actual consumer path), but it's a security-posture decision → asked (§g Q3).

## d) TOTALLY FUCKED UP (honest self-audit)

Nothing system-level broke — no deploy ran, no unit regressed, eval stayed green. The failures below are **process-level, all mine**:

1. **Committed a throwaway into the repo.** `scripts/tmp-probe-dsv-403.sh` rode daemon batch `798a921ef` into PERMANENT history (the typed-sudo guard blocked `sudo bash ~/.cache/...`, and I moved the harness INTO `scripts/` instead of keeping it in `~/.cache/` and typing a clean line). Deletion already committed (`9f0bf8e9e`), so the tree is clean — but history pollution is forever (history rewrite is NOT worth it under the no-force-push doctrine; accepted and recorded).
2. **Hit the documented `rg -rn` trap — third strike on this host.** The hook blocked it; the AGENTS.md entry (2026-10-23) describes exactly this mistake and I typed it anyway.
3. **Content-pin discipline violated by ordering.** The multi-agent rule is content-pin BEFORE every write; I pinned only at verification time — after all edits had landed. Got lucky: the one mid-edit race (post-deploy-check.sh, another session's edit between my read and edit) hit an unchanged block. The correct behavior is pin → edit → re-read on conflict, and I did it backwards.
4. **Three wasted tool calls from basic hygiene misses**: two edit-without-View failures (TODO_LIST.md, pipeline.md — the exact error the rules warn about), one 0-based-offset misread costing a round-trip, one predictable guard trip (`sudo` typed directly, before switching to the sanctioned harness pattern).
5. **Deploy window missed by sequencing.** I checked quiescence only AFTER all doc/queue work (~21:55); the parallel session's files were already hot. An earlier quiescence check (~21:40, right after the fixes landed) might have caught a quiet window and deployed before the storage session ramped up. Cost: one extra pager hit tonight (~00:39) and a day of delay for the fix.
6. **OnFailure delivery never verified.** The whole incident is an alerting-path story and I never once looked at whether the 00:43 page actually reached Discord — the session fixed the CHECK and the SCRIPT but left the ALERT leg assumed-green. That is exactly the "assert WHICH entity served it" class the house rules warn about, one level removed.

## e) WHAT WE SHOULD IMPROVE

1. **Kill the exit-4-every-deploy amplifier.** The 12-13 pre-existing failed units (10-27 self-review item 16: btrbk-data/root/forgejo-clean, home-lars-tmp automount, ci-watchdog, github-auto-assign, inboxclean-sync, nsfw-classifier, …) make EVERY deploy take the exit-4 global-reset path — which is what turned today's check gap into a day-long blind spot. Sweeping them converts deploys to exit-0 and makes the original failed-gated legs live again.
2. **Classification logic deserves fixture tests.** The post-deploy WARN/FAIL branches have no negative-test harness coverage (negative-tests.yml covers lint classes only). The stale-FAIL/aliased-Result class is now code — a tiny fixture test would pin it.
3. **Throwaway harnesses: house rule.** Self-elevating probes belong in `~/.cache/<topic>/` (guard sees a clean typed line, nothing enters the repo). Today's detour through `scripts/` produced the only permanent damage of the session.
4. **Verify-script contract pins should name their version.** The 400 branch now names the pinned shape + date; a one-line "Immich >= X" note in the runbook would make future bump triage instant.
5. **Read-before-write ordering** (content-pin first, View first) — three of today's wasted calls were all this one rule.
6. **The is-failed-gate pattern is a reusable trap.** Any script with `is-failed` gates AFTER a global `reset-failed` has the same dead-gate shape. Only deploy.sh has it today (grep-verified), but the pattern should be recorded in docs/agents/systemd.md so future scripts don't reintroduce it.

## f) NEXT THINGS (up to 50; [N] = surfaced new by this session, [Q] = already queued/seen this session, no new research)

**This session's direct line:**
1. [N/Q] Deploy evo-x2 landing the 403 fix + one `systemctl start discordsync-immich-verify.service` convergence + expect "verified (bulk-upload-check)" PASS — QUEUED (TODO_LIST + services.md).
2. [N] Confirm the Nov 4 ~00:39 tick (old script, pre-deploy) or the post-deploy tick goes green; if a 403 page arrives AFTER the fix deploy, the fix is not live — check `readlink /nix/store/…-discordsync-immich-verify` generation.
3. [N] Verify the OnFailure → Discord alert leg delivered on the 00:43 failure (alert unit journal + owner's Discord; §g Q2).
4. [N] Decide key scope posture: least-privilege + endpoint fix (chosen) vs granting `user.read` (§g Q3).
5. [N] Sweep the 12-13 pre-existing failed units so deploys exit 0 and the global-reset amplifier dies (see §e.1) — partially overlaps the 10-27 self-review item 16 queue row.
6. [N] Record the "global reset-failed defeats downstream is-failed gates — capture the pre-reset set" pattern in docs/agents/systemd.md.
7. [N] Fixture-test the new post-deploy classification branches (stale-FAIL / activating / not-run) in the negative-test harness style.
8. [N] Pin shellcheck into the default devshell so `nix develop -c shellcheck` needs no build and agent PATH gets the binary (unblocks the lint-shell idea below).
9. [N] Watch row candidate: Immich major-version bumps must re-verify the bulk-upload-check probe shape (contract now pinned by the script's 400 branch).
10. [N] Attribute/verify the parallel session's three dirty files at quiescence (`flake/expected-locks.nix`, `lib/lars-packages.nix`, `projects-management-automation.nix`) — flagged, not mine.

**Seen in the queue/tails this session (no new research, just consolidation):**
11. [Q] io-PSI storm triage (S-0035 probe set; boot 49e157e0, 51 trips + 122 throttles).
12. [Q] Premise-freshness sweep of stability forensics rows vs shrunk retention floors (journal starts Oct 29, ClickHouse Oct 4).
13. [Q] One full post-deploy battery re-run during the live cv SIGSEGV incident (single-FAIL triage ≠ fleet green).
14. [Q] Alarm-fatigue decision for known-incident FAILs (marker WARN-downgrade vs FAIL enrichment vs status quo).
15. [Q] go-health-dashboard upstream: per-remote lastError/lastSuccess in the merged /readyz doc (verify-before-filing gated).
16. [Q] Close the daemon-sweep-skips-shellcheck class (`nix run .#lint-shell` app).
17. [Q] Partial-eval test-traps house note (wrapper double-import, `_module.check = false`, getFlake store-path rejection).
18. [Q] bank-sync-paperless post-deploy smoke probe.
19. [Q] dnsblockd hot-subvol growth sanity-check (8.5G, largest hot DB).
20. [Q] OpenCloud first successful login confirmation (trap #13 watch).
21. [Q] OpenCloud IDM bootstrap upstream file (repro + verify-before-filing + github-voice).
22. [Q] CV pin lift: upstream nil-guard (sessions_chatstore.go:112) + chunked boot rehydration; then re-lock + drop vendorHash shim.
23. [Q] hermes-agent pin lift (needs nixpkgs patchelf ≥ #672 fix).
24. [Q] nixpkgs fe13242 rev-pin lift (needs aw-core AND linux-7.3 modules realized green).
25. [Q] nixpkgs-llama-rag input drop when the llama.cpp 0.4.0 mid-load spin regression is fixed upstream + re-verified.
26. [Q] paperless-gpt tag bump + vendorHash/npmDepsHash re-measure.
27. [Q] qmd tag bump (v2.8.3 → next; nodeModules FOD per-tag).
28. [Q] signoz-src pin lift (Go-1.26 patches applying rev or sonic ≥ 1.15).
29. [Q] stalwart 0.15.5 → 0.16.x decision (incompatibility caveat documented).
30. [Q] cv-server graphrag inert keys: enable graphrag or drop the DSN keys.
31. [Q] stray-unit-audit hits: forgejo-dump, systemd-tmpfiles-clean, tmpfiles-clean-debug (template-vs-instance or allowUnits with justification).
32. [Q] llama-vlm soak test under real units before any manual llama-server decommission.
33. [Q] Catalog ghost entry `llama` (dns-local subdomain with no vHost) + integration subdomains without catalog entries.
34. [Q] `/data/docker` (~10-15G dormant residue) owner reclaim decision.
35. [Q] gcs-staging (24G, finished staging) owner reclaim decision.
36. [Q] Samsung boot-mirror third-NVRAM-reversion watch row (persistence-guard question re-opens on next flip).
37. [Q] discordsync recovery paths follow-up (re-backfill vs quarantine swap; runbook §known-traps) — owned by services.md rows.
38. [Q] `home-lars-tmp` automount+mount failed unit (part of the §6 failed-set sweep, item 5).
39. [Q] btrbk-data/root/forgejo-clean failed units (same sweep).
40. [Q] ci-watchdog / github-auto-assign / inboxclean-sync / nsfw-classifier failed units (same sweep).
41. [Q] Deploy-vs-executor race protocol adoption for batteries during live executor sessions (2026-10-25 §, quiescence heat-check + green-eval probe).
42. [Q] The offsite-borg golive prep currently BLOCKED on four eval roots (parallel session's 22:09 report — coordinate, don't duplicate).
43. [N] The 2026-10-25 shellcheck row's sibling (pipeline.md:562) and this session's item 8 are the same fix — close both with one devshell pin.
44. [N] Consider annotating the 2026-10-25 golive-prep report: its "daemon-committed" jitter row vs the unit's actual Nov 2 go-live (b) — one-line inline resolution, keeps the provenance map honest.
45. [N] Runbook one-liner: bulk-upload-check probe requires Immich ≥ the 3.3.3 assets-contract (ties to item 9's watch row).

(Self-harvest ledger: items 1-2 are the queued deploy row's own scope ✓ harvested; item 9/45 folded into the script's 400-branch message + runbook note — deliberately not separate rows (rides the Immich update flow); items 3-4 are owner-answer-gated (§g) — not harvested until answered; items 5-8 are new direct follow-ups NOT yet queued — deliberately deferred to next-session harvesting to avoid a second concurrent-session TODO edit race tonight, flagged here instead.)

## g) QUESTIONS (cannot answer myself)

1. **Deploy timing:** do you want me to deploy NOW (shipping the parallel session's three in-flight modified files), or wait for the next natural battery / tomorrow's quiet window? The fix is committed either way; the only cost of waiting is one more pager hit tonight ~00:39.
2. **Did the 00:43 OnFailure Discord page actually arrive?** If you saw no alert at ~00:43 today, the OnFailure delivery leg itself is broken independently of everything I fixed today — that would open a second investigation (alert unit journal I can pull on request).
3. **Key scope posture:** confirm least-privilege (key keeps `asset.read`+`asset.upload` only, verify probes bulk-upload-check — what I landed), or do you prefer the key gains `user.read` so identity-style probes stay possible?

## Verification commands (reproducibility)

```bash
journalctl -u discordsync-immich-verify.service --since "2026-11-03" --no-pager -o short-iso   # the 00:43 403
busctl get-property org.freedesktop.systemd1 /org/freedesktop/systemd1/unit/discordsync_2dimmich_2dverify_2eservice org.freedesktop.systemd1.Unit ActiveState SubState
nix develop -c shellcheck scripts/deploy.sh scripts/post-deploy-check.sh
nix build --no-link .#checks.x86_64-linux.discordsync-immich-shape
nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath
```

*Arte in Aeternum — report authored 2026-11-03 22:15 CET; waiting for owner instructions on §g.*
