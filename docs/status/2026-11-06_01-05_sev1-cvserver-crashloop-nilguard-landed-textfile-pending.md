# SEV1 cv-server crash loop root-caused + fix landed upstream (local, unpushed); crush_events EACCES confirmed deploy-pending — 2026-11-06

**Instance:** ad-hoc "what is the problem?" session (user pasted `journalctl -xe` tail from 23:21:44). **Concurrent sessions live during this window (co-attribution):** SystemNix dio-falsification batch (AGENTS.md/stability.md/flake.lock, report `2026-11-06_00-08_dio-falsification-batch-status.md`), the float-register recovery commit 86d6b9a1f (00:49 — lock+registry together), and in CV a packaging session with mid-flight `nix/packages.nix`+`nix/templ.nix` vendorHash edits plus templ handler edits (never touched by me).

## What the pasted journal actually contained (two independent problems)

1. **`node_exporter` textfile EACCES ×many** — full line extraction: `collector=textfile file=crush_events.prom err="open /var/lib/prometheus-node-exporter/textfile_collectors/crush_events.prom: permission denied"`. NOT a new bug: monitoring.md row (2026-10-30 §f.14) fixed the writer (`chmod 644` before the mv, commit 574626a03 2026-11-05 20:00:15) — but the DEPLOY carrying it never landed. Live proof: the deployed gen-983 collector script (`/nix/store/mw1zvdl9…-crush-events-collector/bin/…`) has mktemp+mv and NO chmod line; the live file was still `-rw------- root root` at 23:47.
2. **SEV1 `UNIT CRASH LOOP` (sev1-bridge severity=notify)** — the unit is `cv-server.service`, restart counter 15 tonight (12→15 across 23:04–23:28). Panic: `nil pointer dereference addr=0x8` at `CV/internal/agent.(*ChatstoreSessions).HealthCheck` (sessions_chatstore.go:112) via `samber/do/v2 serviceLazy.healthcheck` → `raceWithTimeout`, ~1 s after a health sweep; process dies at ~20 min uptime every cycle (OnFailure fires, systemd restarts, loop).

### Root cause (crash loop) — and a premise correction

`openAgentChatstore` (internal/di/services_agent.go:39) returns a **typed nil** on two branches: engine ≠ sqlite (intentional disabled state) or open failure (loud log, ring fallback). Live config truth: `sessions_engine` is set NOWHERE — not in the sops `cv-env` template (sops.nix:836-891 keys grep-verified), not in cv.nix/cvagent.nix — so **memory mode is the standing prod config** and the typed nil is the intentional disabled branch. The do sweep still healthchecks/shuts down the lazy service → methods run on a nil receiver → `c.store` deref → SIGSEGV. **0 `unusable` open-failure logs tonight** and the pipeline tracker rehydrates 42819 events in ~585 ms — so the cv.nix pin-note's "pipeline_events outgrew the 5 s timeout" story is NOT the live crash cause (it was already marked retracted-adjacent in the note; this session journal-verifies the correction). The rehydration-hardening leg is re-rowed in docs/todo/upstream.md as `[watch]` latent sqlite-mode debt.

## What landed

**CV local master `8f999a2de`** — `fix(agent): nil-guard ChatstoreSessions lifecycle sweep methods`: `HealthCheck` and `Close` (Shutdown delegates) return healthy/no-op on nil receiver/nil store, per the replyloop sweep precedent (nil receiver = healthy-disabled); CHANGELOG [Unreleased] row added; regression test `TestChatstoreSessions_TypedNilLifecycleMethodsAreSafe` (typed nil + zero value); test-count baseline 3948. All pre-commit gates green (lint 0 issues, staged tests, test-count, event-map freshness).

## What did NOT land (gates, honestly)

- **The CV fix is UNPUSHED** — agents never push (owner window). The SystemNix cv input is `git+ssh://…/CV?rev=16a656f4…` (deliberate pin, build-hash stability only) — the pin lift is [blocked:push].
- **No deploy tonight** — profile still gen-983 (08:37). Four attempts failed: 19:48 nh-switch exit 1 (621 s), 20:02 died during "Activating configuration", 22:18 PSI pressure gate (3 s), 23:15 float-register red ("floated revs do not build": pim-sync +1, quotaboard +5 unpushed). The blanket ~70-input lock float had been daemon-swept into 99af6e0d4 (22:11); **another session recovered it at 00:49** (86d6b9a1f, lock+registry committed together) — re-verified live: `nix eval …toplevel.drvPath` now passes the audit (`/nix/store/dmhrdgi3…`, ≠ deployed deriver 89ysb14 ⇒ real tree drift, deploy still needed).
- **vendorHash under SystemNix's graph: unknown until post-push.** First-hand FOD probe at dirty-8f999a2 under CV's OWN graph (my background build): got `sha256-aCVmXAeF…` — the parallel packaging session's mid-flight `6kt8Fbqe…` does NOT reproduce. `cv.inputs.nixpkgs.follows = "nixpkgs"` (flake.nix:1055) means SystemNix's followed fe13242 graph will produce its own value — re-probe at ceremony time, never paste.

## Verification matrix

| check | result |
| --- | --- |
| Full journal error lines (not truncated paste) | EACCES on crush_events.prom; panic stack names sessions_chatstore.go:112 |
| Crash-loop unit identification | cv-server.service, counter 15, ~20 min death cycle |
| Config truth (`sessions_engine`) | unset everywhere — sops.nix:836-891 + both cv modules grep-verified |
| Open-failure path live tonight | 0 `unusable` journal lines; tracker rehydration 585 ms |
| Deployed gen-983 collector has the fix | NO — grep of the store script shows mktemp+mv only |
| CV fix tests | package suite + di suite + `go build ./...` + vet + full pre-commit gates green |
| SystemNix eval (lock audit) | RED at session start → GREEN after the parallel 00:49 float-register commit |
| Deploy-needed probe | repo drv dmhrdgi3 ≠ deployed deriver 89ysb14 ⇒ real drift, deploy pending |

## §f Follow-ups — harvest record

All follow-ups are gate-blocked, so per the queue header ("blocked … → library only") they are **deliberately NOT in TODO_LIST.md**; the domain library rows are updated in the same session (upstream.md):

1. Owner: push CV master (8f999a2de) — recorded in upstream.md row (vendorHash paste/ceremony row, UPDATE 2026-11-06). `[blocked:user]`
2. Post-push ceremony: re-lock cv past 16a656f4, probe got-hash under SystemNix's followed graph, drop-or-repin the cv.nix shim (drop-preferred: CV's own packages.nix will carry a real committed hash), lift pin + comment, toplevel proof, deploy. `[blocked:push]`
3. Chatstore rehydration hardening (latent sqlite-mode debt) — new `[watch]` row in upstream.md.
4. Post-deploy probes (next session after deploy): `node_textfile_scrape_error 0` + `crush_events_lines_total` on :9400; cv-server uptime > 1 h with counter frozen; SEV1 bridge reports no UNIT CRASH LOOP condition. These ride the deploy row, no separate queue entry (verification is part of the deploy arc itself).

Residue observed, not owned here: CV's pre-commit reports `/mnt/buildcache/*` dead-mount warnings (healed to `~/.cache/cv-go` per its 2026-11-02 go-env canon — the go-cache relocation session's env still exports the old paths somewhere upstream of CV's hook); CV tree carries additional parallel-session edits (templ handlers) unrelated to this fix.
