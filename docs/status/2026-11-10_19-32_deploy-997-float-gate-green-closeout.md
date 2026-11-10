# Deploy gen-997 landed: float-gate red→green arc, calm-gate fallout, and post-switch truth (2026-11-10 19:32)

Session: resume of the 13:35 deploy-rescue session (its pending item: "post-deploy smoke exit 3 +
calm-gate failed — awaiting owner answers §g"). The owner pasted a fresh `nix flake update` +
`DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` that died rc=12 in the float-register gate. This session
diagnosed that failure completely, discovered a concurrent session had ALREADY driven the gate to
green and launched the deploy, monitored the activation to completion without interfering, and ran
the full post-switch verification battery. HEAD at authoring: `34b95d7d7`. **Tree is LIVE: another
session has staged `modules/nixos/services/audible-sync.nix` + `docs/todo/services.md` and modified
`TODO_LIST.md` + `pkgs/print-safe.nix` while this report was being written — presumably fixing the
namespace paradox found below. Nothing in this report touches those files.**

## The pasted failure, fully diagnosed (rc=12 float-register proof RED, 15:51)

Three INDEPENDENT causes in `~/.cache/lockfloat/float-proof-20261110-155143.log`:

1. **patchelf-0.15.2.drv: real build failure** — `applying patch …patchelf-fix-executable-header-load-overlap.patch … 4 out of 6 hunks FAILED` at nixpkgs `f4a03c00`. The 15:51 lock had `nixpkgs_9 = f4a03c00` (the patchelf-broken rev the 13:35 session re-landed away from). Same blocker as the 2026-11-09 gen-992 arc (CHANGELOG, same day, same patch name, same poisoned chain ffmpeg/node/pnpm/ripgrep/hermes). **Known recurring; float onto this graph = guaranteed red.**
2. **`Could not resolve host: cache.nixos.org`** — TRANSIENT. `getent` green at 18:22 (Fastly dualstack via local resolver `127.0.0.1` + `9.9.9.9` fallback). Likely the local resolver starving under the 4-session IO storm (PSI 41-58% all session).
3. **go-humanize-linter go-modules: `proxy.golang.org … i/o timeout`** — TRANSIENT network, NOT a code break; the same input built green in the later proof.

## Timeline of the concurrent resolution (not this session's hands)

- ~17:26:57 — a sibling session re-landed nixpkgs at **`f9a75f41`** (patchelf 0.19.2, the deployed system's own rev). **The root-referenced lock node MOVED: it is now `nixpkgs_8`; `.nodes.nixpkgs_9` (3ec63636) is an ORPHAN** — the 13:35 summary's "root pin lives at nixpkgs_9" guidance is stale. Rule holds: resolve via `.nodes[.root].inputs.nixpkgs`, never a remembered node name.
- 17:27:21 — sibling's `float-register` proof **GREEN** (rc=0, `float-roots-20261110-172759.md`: "no root signatures — proof green", 19 drifted inputs adopted: bank-sync, buildflow, cv, cvagent, dankMaterialShell, go-commit, go-humanize-linter, go-structure-linter, go-taskqueue, hermes-agent, homebrew-cask, index, nur, pim-sync, quotaboard, rust-overlay, signoz-collector-src, signoz-src, todo-list-ai — nixpkgs NOT among them). Registry rows committed (tree clean at 18:22 — the known 72-char-subject hook rejection likely fired again and the daemon swept; row 728's open bug re-confirmed in the wild).
- 17:55:57 — sibling launched `deploy` (log `/var/log/systemnix-deploys/2026-11-10_17-55-57.log`).
- 18:00:13 — toplevel built (9s, warm): `3yhv8kp…-nixos-system-evo-x2-26.11.20261105.f9a75f4`.
- 18:01→19:01 — activation held **60 min by `post-crash-calm-gate.service`** (its `maxWaitMin=60` default; PSI hovered 43-58% under 4 concurrent sessions incl. BuildFlow-repo and CV-repo sessions seen in pgrep). Gate FAILED at cap; switch proceeded past it (2026-11-10 morning pattern repeated).
- 19:01:05 — activation completed exit 4 (9 units failed pre-reset; script reset start-limits + retried; then anchor self-repair: **profile `system-996 → system-997` pointing at the running `3yhv8kp`** — the "unanchored" state this session saw mid-flight at 18:22 was the deploy's own pre-repair window).
- 19:12:35 — **deploy exited code=0** (4598s). Battery: **168 PASS / 7 FAIL / 4 SKIP / 19 WARN / 1 STORM-SUSPECT; "All FAILs match the previous run's baseline — advisory"** — zero new regressions.

## Post-switch verification (this session's hands)

- **Anchor FORMAL PASS**: `readlink /run/current-system` == `readlink /nix/var/nix/profiles/system` == `system-997-link` == `3yhv8kp…f9a75f4`.
- **cvagent dashboard LIVE** (the 14-59 session's deliverable, in this deploy): service active/running, loopback `127.0.0.1:8787`, `cvagent.home.lan → 192.168.1.150`, HTTPS `/` **200 via Caddy**. `/health` **503** — body: `"startup":"fail","error":"startup latch not set"` + `"git":"warn","error":"git binary not found on PATH"`. DB + AI-key checks PASS. Scan ran green 07:04 (scanned=23 failed=0); `cvagent-scan.timer` re-arms ~05:58 tomorrow.
- **Backup timers ARMED**: `timesheets-backup.timer` next-elapse ≈ 03:29:15, `invoices-dashboard-backup.timer` ≈ 03:58:29 CET tonight (03:20/03:50 + jitter) — the 13:35 session's §next item satisfied at the schedule level; first-fire proof is tomorrow.
- **The 7 baseline FAILs, all explained**: (1) Health Hub /readyz 503 — chained to cvagent's own 503 (it is now a federated remote) + llama dark; (2)+(3) llama.cpp Embeddings :8848 /health + /v1/embeddings unreachable — see fallout below; (4) Offsite Borg tripwire binary not executable/missing; (5) crm-server 175% CPU (storm); (6) node-exporter 430 journal lines/min (storm); (7) tq-agent-pool NOT active — in `activating/auto-restart` loop at 19:2x.
- **STORM-SUSPECT (1)**: CV browser-render smoke — unverified under load; needs calm-window re-run.

## The calm-gate Requires fallout (new precision on §g Q1)

`llama-embeddings.service` carries `Requires = llama-rag-model-fetch.service post-crash-calm-gate.service`. Gate failed at 19:00:50 → **llama-embeddings start failed with result 'dependency' and is INACTIVE/DEAD** ("Dependency failed for llama.cpp embeddings server"). Blast radius of the gate failure is EXACTLY this one unit (grep of rendered units). Precedent: TODO_LIST:361 — same stranding 2026-11-08 ("dark since 09:14", gatus "Enabled But Inactive Units" expected to page). So the morning's ":8848 likely settling" read was wrong twice over: it is not settling — it is **stranded by design until the gate succeeds**, and PSI is still 44% so a gate re-start now would fail again. Recovery is an owner act: start `post-crash-calm-gate` at a PSI<40 window (then `llama-embeddings` can start), or next boot.

## Pre-existing breakage surfaced by the battery (NOT deploy regressions)

- **`audible-sync-dirs` + `journal-sync-export`: 226/NAMESPACE bootstrap paradox** — mount-namespace setup requires `/mnt/pool/services/audible` / `/mnt/pool/services/bank-sync/journal-exports` to EXIST, but these are the very dirs the units create; the pool IS mounted (/dev/sda btrfs) — only the subpaths are missing. Pre-existing: 4× and 28× failures since 11-08. **Consequence that matters: this morning's flagship "journal FULL auto-sync every 15 min" chain is dead on arrival — `journal-sync-export` fails every tick, so its OnSuccess→`journal-import` never fires.** Also blocks the audible seed run. The sibling session's staged `audible-sync.nix` edit right now is presumably the fix for half of this.
- **`forgejo-github-sync` exit 1 = deliberate tripwire**: `✗ dnsblockd: still a PULL mirror — refusing (flip first: sudo systemctl start forgejo-flip@dnsblockd.service)` — documented procedure (docs/services/forgejo.md §139), owner decision pending.
- **`service-health-check` failed = CORRECT symptom reporting** of the above (plus browser-history-agent, inactive since).

## Already done by others before I could (dedup findings)

- Registry-matrix doc **already carries the cvagent row** (`docs/agents/integration-registry.md:192`) — 14-59 §b2 CLOSED, no regen eval needed.
- Catalog entry **already in `modules/nixos/services/cvagent.nix:72`** — 14-59 §f1 CLOSED.
- TODO_LIST rows 3372/3386 ("complete the float registration", 15/16-input drift from 11-07) — **premise RESOLVED today 17:27**; tick pending (below).

## a) FULLY DONE (this session)

1. Ground-truth recovery per handover: tree/HEAD, lock topology (root-referenced node resolution), anchor, DNS, PSI, sibling sessions + newest status reports.
2. Full 3-cause diagnosis of the pasted rc=12 with log citations (patchelf real; DNS + go-proxy transient).
3. Live-process probe before any interference → discovered the concurrent driver; NO double-deploy, NO lock surgery mid-flight, NO extra eval load during the calm-gate hold.
4. Watched activation to completion (background watcher on the switch PID; zero storm-feeding).
5. Formal anchor verification (gen 997 == current-system == running toplevel).
6. Deploy battery verdict parsed: 168/7/4/19/1, baseline-matched, rc=0.
7. cvagent live battery: unit, listener, DNS, HTTPS 200; /health 503 root-caused to latch+git-PATH.
8. Backup timers verified armed for tonight.
9. All 7 FAILs + STORM-SUSPECT attributed (see above).
10. Calm-gate Requires-fallout root-caused with exact blast radius (1 unit) and recovery path.
11. Pre-existing namespace paradoxes + forgejo tripwire attributed with failure counts and consequences (the journal auto-sync chain is DOWN).
12. Dedup pass: registry-matrix + catalog rows found already landed; float-registration TODO rows found premise-resolved.
13. Existing-row map built (stability.md:300 device-truth, services.md:716-721 cvagent, services.md:1068 audible post-wave) so the queue wave extends instead of duplicating.
14. This report.

## b) PARTIALLY DONE

1. **Documentation wave NOT yet landed** (owner instructed report-then-wait): TODO ticks (3372/3386), new domain rows (services.md ×3, stability.md ×1), queue one-liners, CHANGELOG entry for gen-997. Exact content designed (§f items 2-5); not written.
2. **gen-997 storm-window verification is done; calm-window verification is not**: STORM-SUSPECT CV render + the 7 baseline FAILs need a calm `nix run .#post-deploy-check` re-run.
3. **cvagent go-live is 80% proven**: `/` 200; `/health` 503 until the startup latch sets (expect first post-restart scan ~05:58+~64min tomorrow) and the git WARN needs the serve-unit PATH fix.
4. **Timesheets/invoices**: timers armed (verified); first actual backups + `backups.prom` freshness only provable after tonight's 03:29/03:58 window.
5. **13-35 report §b3 harvest deferral**: the sibling WAVE landed (deployed), but the STORM has not ended (4+ sessions, PSI 44-58%) — deferral continues, now for the storm reason, not the wave reason.

## c) NOT STARTED

1. All §b1 doc edits + commits.
2. Calm-window post-deploy-check re-run.
3. llama-embeddings recovery (owner-gated: gate start at calm).
4. journal-sync-export / audible-sync-dirs namespace fix (sibling appears to be mid-flight on audible-sync.nix RIGHT NOW).
5. cvagent serve-unit git PATH fix (module edit, rides next deploy).
6. nixpkgs DURABLE pin (URL PATH-form + `lib/flake-input-pin-audit.nix` allowlist row + LIFT condition) — designed, not implemented, owner-gated (§g Q2).
7. tq-agent-pool restart-loop diagnosis.
8. Offsite Borg tripwire-binary expectation investigation.
9. forgejo dnsblockd mirror flip (owner).
10. hermes upstream patchelf-version gate (13-35 §f item) — untouched.
11. Tomorrow's backup first-fire verification + cvagent latch re-check.

## d) TOTALLY FUCKED UP (own mistakes, no varnish)

1. **Lock-node archaeology reflex**: my first lock read jq'd `.nodes.nixpkgs_9` (the 13:35 summary's stale guidance) and returned 3ec63636 → I briefly concluded "someone re-floated nixpkgs onto the bad rev AGAIN". The documented rule (resolve via `.nodes[.root].inputs.<name>`; node names renumber) saved it one probe later — but I had the rule IN THE HANDOVER and still reached for the remembered name first.
2. **Two malformed probes in a row**: grep pattern `'"nixpkgs'` (quote on the wrong side → empty result) and busctl paths missing `_2d` for hyphens (the ListJobs output I had ALREADY read literally showed `forgejo_2dgithub_2dsync` and I still built the escape without it). Two wasted tool rounds on escaping/pattern sloppiness — the exact "quote-scrutiny" class AGENTS.md warns about.
3. **Check-then-do inversion on the heavy eval**: I was ABOUT to launch the registry-matrix eval build when the dedup grep showed the doc row already landed. If the grep had come after the build, I'd have burned 10+ minutes of storm IO for nothing. The multi-session tree moves faster than plans; verify existence FIRST.
4. **Live-process probe landed in batch 2, not batch 1**: the session-start discipline (probe for live executors BEFORE anything) was in the handover ("read `ls -t docs/status` + `git log` FIRST") and my first batch had the file-level checks but the pgrep for RUNNING deploys/nix processes only came in the second batch. On a box where a sibling is mid-deploy, the process probe is the single most important first call.
5. **Investigation tail outran the writing phase**: verification was green by ~19:15, but I kept probing micro-details (tq state, row locations) instead of starting the docs; the owner had to interrupt to get the report. The write-up should have started the moment the anchor verified.
6. **Near-miss on planned work already owned elsewhere**: my §f plan included "add catalog row + regen matrix" — both already done by the 14-59/17:2x sessions. Duplicated work was one grep away from happening; the near-miss is the same species as 14-59 §d5 (ignored the multi-session reality).

## e) WHAT WE SHOULD IMPROVE

1. **First-batch composition for resumed sessions in this repo**: `pgrep -af 'nh os|switch-to-configuration|nix build|nix flake|bin/deploy' | redact` + `ls -t ~/.cache/lockfloat/ | head` belong IN batch 1, beside the git/status checks. A running deploy changes every decision downstream.
2. **systemd unit-state probe helper**: a `scripts/unit-state.sh <unit>` wrapping the `_2d`/`_2e` escaping + ActiveState/SubState busctl calls would kill this recurring two-round probe tax (both escapes, one helper, selftest-able).
3. **Lock reads are ALWAYS root-referenced**: memorize the jq one-liner (`'.nodes[.root].inputs.<name>'` → node → rev) as THE only read form; node names are throwaway.
4. **Existence-check before any planned eval/build**: grep the target artifact (doc row, store path, unit file) for evidence a sibling already did it — cheaper than any eval and it is the multi-session box's base rate.
5. **Write while verifying**: the report skeleton can start at the first green anchor check; probes append sections. The current pattern (probe → probe → write) left a 40-minute dead zone the owner had to interrupt.
6. **Battery FAIL extraction**: `sed 's/\x1b\[[0-9;]*m//g' log | grep '^FAIL'` FIRST — raw grep on the colored log silently misses (my first attempt matched only the STORM-SUSPECT lines).
7. **Calm-gate design debt is now TWO mechanisms**: (a) phantom-PSI starvation (device-truth fix, stability.md:300) and (b) gate FAILURE strands its Requires-chain (llama-embeddings) with no recovery path short of a calm manual start or a reboot. (b) needs its own row + design decision (wants-vs-requires, or a post-switch gated-fleet recovery step in deploy.sh).
8. **Handover summaries must be treated as perishable**: "root pin lives at nixpkgs_9" was true at 13:35 and false at 18:22. Handovers should carry the root-referenced READ COMMAND, not the node name.

## f) NEXT (ordered; harvest of this report — NOT yet landed, owner instructed report-then-wait)

1. **Land the doc wave for this report** (items 2-5 + this file's commit) — each §f item below routes into TODO_LIST one-liner + matching domain row per the harvest doctrine.
2. **Tick TODO_LIST 3372/3386** (float registration completed 17:27, proof green, deploy gate passed) — tick + commit in ONE tool call, full-line edit.
3. **services.md row: journal-sync-export 226/NAMESPACE breaks the 15-min FULL auto-sync chain** (OnSuccess→journal-import never fires; fix = tmpfiles existence rule or bind-path rethink; NOTE the sibling's staged audible-sync.nix edit may own the audible half — coordinate, don't duplicate).
4. **services.md row: cvagent serve unit PATH lacks git** → /health git WARN (scan unit got this fix 2026-11-04; serve unit needs the same runtimeInputs treatment; rides next deploy).
5. **services.md row: gen-997 calm-window re-verification** — re-run `nix run .#post-deploy-check` when PSI < 20: clears the CV render STORM-SUSPECT and re-verifies all 7 baseline FAILs.
6. **stability.md row: calm-gate failure strands llama-embeddings (Requires chain)** — recovery = owner `StartUnit` the gate at a PSI<40 window (busctl explicit `ss` signature) or next boot; cross-link device-truth row 300; consider wants-vs-requires redesign.
7. **CHANGELOG entry for gen-997** — cvagent dashboard go-live (attribute 14-59 wiring + 17:2x deploy drive), the float-gate green arc, calm-gate fallout, and the namespace-paradox finding on this morning's journal auto-sync.
8. **Owner: start `post-crash-calm-gate` at the first PSI<40 window** (then `llama-embeddings` starts; verify :8848 /health) — OR accept next-boot recovery.
9. **Re-run post-deploy-check at calm** (item 5's execution).
10. **Verify tonight's first timesheets/invoices backups** (03:29/03:58 + `.last_success` markers + backups.prom freshness) — tomorrow morning.
11. **Verify cvagent startup latch after the ~05:58 scan** (+~64 min) → /health should go 200 → Health Hub baseline FAIL clears.
12. **Diagnose tq-agent-pool auto-restart loop** (battery FAIL names the pool.conf-key-typo class; read its journal since 19:01).
13. **Offsite Borg tripwire**: investigate "tripwire binary not executable/missing" — check-executable expectation vs the store path (`/nix/store/v6w2k44x…/bin/borg-offsite-golive-check`).
14. **Owner decision: forgejo dnsblockd mirror flip** (`sudo systemctl start forgejo-flip@dnsblockd.service`) or accept the tripwire state as permanent and silence its sync-failure page.
15. **Health Hub /readyz 503**: after items 8+11, confirm the dark/fail remote set is empty; if remotes remain dark, enumerate (the check message names HEALTH_HUB_REMOTES).
16. **§g Q2 execution if approved**: nixpkgs durable pin — `flake.nix` URL `github:NixOS/nixpkgs/f9a75f41be3a74eab55d3a7679d34ad6cc0da977` (PATH-form, never `?rev=`) + `lib/flake-input-pin-audit.nix` allowlist row with LIFT "patchelf patch-apply fixed upstream, float-register proof green on tip" + the 2026-10-23 workflow check (grep `.github/workflows/` + `scripts/` for nixpkgs update sites feeding off the pin).
17. **Upstream watch: nixpkgs patchelf** — when the `patchelf-fix-executable-header-load-overlap.patch` hunk mismatch is fixed on master, re-float nixpkgs via the ceremony deliberately (this is the actual §g Q2 endgame condition).
18. **hermes upstream: patchelfFixed overrideAttrs vs snapshot ancestry** (13-35 §f item) — verify-before-filing candidate issue if b27d1995..master doesn't self-fix.
19. **Check whether the 17:2x driver session writes its own close-out report** — cross-link; avoid duplicate narratives.
20. **`nix flake check --no-build --all-systems` on the settled tree** — confirm registry-matrix-drift is green with the cvagent row landed, and no other check rotted under the day's 30+ commits.
21. **rpi3-dns targeted eval** (platforms/common surfaces were touched by the wave; nix-flakes doctrine).
22. **Calm-gate device-truth fix** (stability.md:300) — port the per-device %util crosscheck into the admit decision; this session adds evidence: gate starved the FULL 60 min again under mixed real+phantom load.
23. **Calm-gate failure-policy decision** (new, from this session): gate fail → switch proceeds but gated fleet stays down; decide wants-vs-requires for llama-embeddings or add a deploy.sh post-switch gated-fleet start attempt.
24. **Confirm the gatus "Enabled But Inactive Units" check paged for llama-embeddings** (TODO_LIST:361 predicted the first live cycle pages; verify the alert fired, else the check's threshold is wrong).
25. **Audible seed verification after the sibling's fix deploys** (services.md:1068 battery: audible-sync + dirs units live, seed journal three-phase markers, backup-coordination freshness row).
26. **journal-import first live tick after the namespace fix** (15-min cadence; verify per-balance coverage rows + the "statements never synced" table updates).
27. **Memory-throttle WARN review at calm**: forgejo 1.87M, monitor365-server 984k, nix-daemon 277k, clickhouse 229k MemoryHigh hits accrued in ~11 post-restart minutes — real pressure vs storm artifact (§17 sweep rerun).
28. **crm-server 175% CPU + node-exporter 430 lines/min**: re-classify at calm (storm artifact vs the DiscordSync-hotloop class the §18 check exists for).
29. **Verify sigNoz fleet green post-deploy** (signoz.service + signoz-collector.service are NEW units this gen; provisioner convergence ran).
30. **hermes.service post-float health** (b27d1995 adopted; unit started per activation log; probe its serve surface).
31. **bank-sync-rev-drift tripwire stays inactive** (= green; it was failed pre-reset, inactive after heal — confirm it stays that way after tonight's runs).
32. **Orphaned `.nodes.nixpkgs_9` (3ec63636)**: harmless but the lock carries dead nodes after the day's surgeries — fold a worktree-canonicalize pass into the next DELIBERATE lock wave (never a bare `nix flake lock`).
33. **Update 13-35 report §b3 deferral note**: lift condition moved from "sibling wave lands" (done 19:12) to "multi-session storm ends" — the 50-item §f harvest remains deferred.
34. **Harvest 13-35 §f (50 items) when sessions quiet** — the original obligation, still open.
35. **Run docs-gates freshness** after this report + the pending ticks land (newest-report open-items routing gate).
36. **§g answers**: Q1 calm-gate policy, Q2 nixpkgs endgame, Q3 namespace-path intent — owner input still required (see below).

## g) Questions for the owner (cannot self-answer)

1. **Calm-gate failure policy**: tonight the gate held the switch 60 min, failed, and the deploy continued — but the fleet it gates (llama-embeddings) then sat DEAD for hours with no recovery path except a calm manual start or reboot. Do you want (a) the Requires→wants redesign + a post-switch gated-fleet start attempt, (b) keep the stranding (strict admission, manual recovery), or (c) prioritize the device-truth crosscheck (stability.md:300) so phantom-PSI storms stop starving the gate in the first place — and in what order?
2. **nixpkgs pin endgame (§g Q2, now with a second data point)**: the patchelf-0.15.2 graph broke deploys on 11-09 AND 11-10; both times the fix was "re-land f9a75f41". Shall I implement the DURABLE pin (URL PATH-form + pin-audit allowlist row with LIFT = "patchelf fixed upstream + proof green") so `nix flake update` becomes a no-op for nixpkgs until you lift it — or keep nixpkgs floatable with the float-register ceremony as the sole guard?
3. **journal-sync-export staging path intent**: this morning's CHANGELOG entry says exports land "inside the dataDir", but the deployed unit mount-namespaces `/mnt/pool/services/bank-sync/journal-exports` (which doesn't exist → 226 every 15-min tick → `journal-import` never fires → the FULL auto-sync you commissioned this morning is DOWN). Which surface is intended — pool (HDD, current unit) or dataDir (morning entry) — so the fix lands on the right one (and should I let the sibling's in-flight audible-sync.nix edit ride, or coordinate the journal half separately)?
   **WITHDRAWN 2026-11-10 ~19:4x — superseded by the sibling session's live fix** (`modules/nixos/services/journal-import.nix` worktree edit): staging moves OFF both disputed surfaces to a dedicated `/var/lib/journal-sync` StateDirectory (bank-sync-owned 0755, files 0644) — systemd creates StateDirectory during namespace setup (kills the 226 chicken-and-egg) and the 0700 dataDir traversal block disappears (the sibling's root cause: the primary-user import side could not traverse the DAC-private dataDir even to world-readable staging files). Pool dependency fully removed (`RequiresMountsFor` + pool-recovery exemption dropped). The question's premise (choose pool vs dataDir) is moot; the sibling also queued the `[blocked:deploy]` post-deploy battery row in `docs/todo/pipeline.md`. This session claims no further action on the journal chain.
