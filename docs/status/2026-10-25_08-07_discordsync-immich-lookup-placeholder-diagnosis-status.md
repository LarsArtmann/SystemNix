# Status Report — DiscordSync Immich `/lookup` diagnosis + stale-tracking sync

**Session window:** 2026-10-25 ~07:52–08:07 CET (single session, 2 user turns)
**HEAD at start:** `050567953` · **Report written:** 2026-10-25 08:07
**Trigger:** "Why does `https://discordsync.home.lan/lookup` report 'Immich: unavailable' with 'Also check Immich' selected, while `/health` claims it's all green?"
**Scope discipline:** per owner instruction, this report covers ONLY this session's run and what it noticed in passing — no fleet-wide research was done for it.

> **Format override (flagged per skill spec):** the status-report skill is HTML-canonical; the owner's prompt explicitly demanded `.md` at `docs/status/<YYYY-MM-DD_HH-MM_*>.md`. Explicit instruction wins. This one-off override is NOT propagated into the skill as a new default.

---

## TL;DR

`/lookup`'s "Immich: unavailable" badge is the **never-pasted Immich API key** — the env still carries the shipped `PLACEHOLDER` (go-live step 2 of `docs/services/discordsync.md`, pending since 2026-09-19). Immich itself is UP; the placeholder key fails auth, the daemon's proxy answers 502, the badge renders "unavailable". `/health` is green **by design**: its 13 checks are DiscordSync-internal subsystems only; Immich is deliberately not a DiscordSync health check. The stale `[blocked:deploy]` tracking row (whose FOD/deploy blockers cleared weeks ago) was corrected in both todo surfaces.

---

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| a1 | **Root cause diagnosis, live-verified** (no doc-only claims): `discordsync-immich-verify` logs *"API key is still a PLACEHOLDER (inert by design)"* every daily 00:00 run Oct 19–25; daemon logs `Immich cross-archive comparison enabled, url http://127.0.0.1:2283` on every restart Oct 23/24/25; user's browser (192.168.1.62) requests hit `POST /lookup/immich → status 502`; `immich-server.service` active/running and listening on 127.0.0.1:2283 (config: `lib/ports.nix` immich=2283, discordsync-api=8085) | `journalctl -u discordsync-immich-verify`, `journalctl -u discordsync`, `busctl get-property …immich_2dserver_2eservice`, `ss -ltnp` |
| a2 | **`/health` scope proven**: raw HTTPS GET through Caddy enumerated all 13 checks — api-server, background-jobs, capture-dlq, content-storage, database, discord-gateway, disk-space, event-capture, otel-tracing, projection-dlq, projection-lag, projection-runtime, prometheus-metrics — **zero Immich entries**; runbook exit-semantics table + module comment (`modules/nixos/services/discordsync.nix:291-297`) confirm this is deliberate (availability is the Gatus Immich check's job; placeholder is inert-by-design) | openssl s_client probe of `discordsync.home.lan/health` + module source |
| a3 | **Gatus Immich check located** (the check that DOES own Immich availability): `modules/nixos/services/gatus-config.nix:531`, group "Media", probes `/api/system-config` on localhost:2283 | grep |
| a4 | **Stale tracking row corrected in BOTH surfaces** (no-drift rule): `docs/todo/services.md:146` re-tagged `[blocked:deploy]` → `[blocked:user]`, false "NOT deployed / blocked by 5 FODs" premise replaced with the live-verified state and a 3-step remaining chain; `TODO_LIST.md:440` one-liner synced | edit + `bash scripts/check-todo-system.sh` → *"OK: TODO queue/library structure clean"* |
| a5 | **Unit-name trap caught before it became a wrong diagnosis**: first probe of `immich.service` returned inactive/dead — that unit DOES NOT EXIST; the cgroup chase (`/proc/<pid>/cgroup`) proved the real unit is `immich-server.service`, active/running. Recorded in the corrected todo row so the next session doesn't repeat it | busctl + /proc |

## b) PARTIALLY DONE

| # | Item | Works now | Remaining open | Blocker |
| - | ---- | --------- | -------------- | ------- |
| b1 | **Immich cross-archive go-live chain** | Wiring fully deployed + live (daemon feature enabled, toggle renders, verify unit + daily timer run, deploy.sh convergence present) | User creates the Immich API key (`asset.read` + `asset.upload` ONLY) → interactive sops paste into `platforms/nixos/secrets/discordsync-immich.yaml` (runbook one-liner) → deploy (secret's `restartUnits` restarts discordsync + verify) → E2E check (verify journal "Immich API key verified", `/lookup` found/not-found cards, perms 0400, key absent from journald) | **USER-only**: key creation needs Immich UI credentials; sops edit needs the host age identity via sudo (blocked in agent sandbox) — tracked `docs/todo/services.md:146` |
| b2 | **Session doc changes** | The two todo-surface corrections are on disk and structure-checked | Not committed by me (harness forbids commit without explicit request); auto-commit daemon will pick them up | Harness contract (expected) |
| b3 | **Self-harvest of this report's §f** | 2 new items landed before writing (upstream Tier-3 row extended in `docs/todo/services.md:147`; stale-claim sweep queued as `[ready]` in `TODO_LIST.md`); 2 items deliberately NOT harvested with reasons recorded in §f | — | — |

## c) NOT STARTED

| # | Item | Why | Still wanted? |
| - | ---- | --- | ------------- |
| c1 | The actual key paste + go-live deploy + E2E (see b1) | User-gated (Immich UI credentials, sudo sops) | Yes — that is the feature's whole point |
| c2 | "Cheap adds riding the same deploy" from the corrected row: `RandomizedDelaySec` on the daily verify timer (00:00 nix-gc collision), post-deploy-check smoke leg for the verify unit, persisted eval-level regression test for the immich-disabled shape | Bundle with the go-live deploy; none are urgent alone | Yes (all three queued in `docs/todo/services.md:146`) |
| c3 | Upstream Tier-3 fix-at-source items incl. this session's two new ones (badge wording; WARN on proxy auth failure) | Requires verify-before-filing pass against the DiscordSync repo (not vendored here) | Yes — queued `docs/todo/services.md:147` |
| c4 | Repo-wide stale deploy-gated claim sweep (new, this session) | Just queued; no session budget left in this run | Yes — `TODO_LIST.md` `[ready]` row |
| c5 | ChangeLog entry for this diagnosis | Diagnoses live in status reports; CHANGELOG accompanies tree changes — the todo corrections are tree changes, so the daemon commit may merit one line at review time | Optional |

## d) TOTALLY FUCKED UP (radical honesty — my own failures this session)

| # | What | Severity | Root cause | Mitigation |
| - | ---- | -------- | ---------- | ---------- |
| d1 | **Wasted first probe on `sudo journalctl`** — blocked at command-parse; the sandbox sudo ban is a documented standing constraint I should have applied from memory | Low (one wasted call) | Did not consult known constraint before typing | Plain `journalctl` works for read-only journal reads (already known) — no data risk |
| d2 | **The `immich.service` near-miss**: unit probe returned "inactive/dead" and it contradicted the listening socket; had I trusted the unit-state probe I would have reported "Immich is DOWN" — a WRONG diagnosis — instead of "placeholder key" | **High (potential wrong verdict; caught)** | Assumed the nixpkgs unit name instead of resolving it; "an inactive reading is never evidence" applies to unit names too | Chased `/proc/<pid>/cgroup` → `immich-server.service` active/running; trap recorded in the corrected todo row (a5). Corollary of the journal empty-read rule: resolve the entity BEFORE concluding |
| d3 | **One link in the causal chain is inferred, not code-verified**: the 401-from-Immich → daemon-502 mapping comes from the runbook's "auth_error degradation" wording + observed 502s + placeholder evidence; I did NOT read DiscordSync's `internal/immichclient` source (repo not vendored here) | Low (diagnosis doesn't hinge on it — placeholder-fails-auth is certain) | Stopped at the evidence needed to answer; did not flag the inference in my first answer | Flagged here; upstream source read is part of the Tier-3 verify-before-filing pass (c3) |
| d4 | **First WARN/ERROR journal grep found nothing** — the daemon logs auth failures ONLY as INFO request lines (502s); I initially searched for an error-class log line that does not exist | Low (cost one query) | The observability gap is real, see e2 | Filed as improvement item |

Nothing in the SYSTEM is newly fucked up by this session: no tree changes beyond 2 todo-doc rows (+ this report), no deploys, no config edits, no service restarts.

## e) WHAT WE SHOULD IMPROVE

1. **Misleading UX wording (upstream)**: "Immich: unavailable" renders for a *missing/rejected key* while Immich is up — a config state wearing an availability costume. Fix at source: distinguish not-configured / unreachable / auth-rejected badges. (Queued, Tier-3 row.)
2. **Silent failure surface (upstream)**: a broken Immich key surfaces only as INFO-level 502 request lines + the daily verify unit's log. One WARN log line at proxy auth failure (or a SigNoz alert on the verify unit's `still a PLACEHOLDER` line) would make the state visible without journal archaeology. (Queued, Tier-3 row.)
3. **Stale-premise rows age silently**: the corrected row sat 5 weeks claiming "NOT deployed, blocked by FOD wave" while the feature went live. The premise-check rule exists at queueing and owner-question time; there is no periodic re-adjudication of `[blocked:deploy]` rows against the live generation. Sweep queued (`TODO_LIST.md` [ready] row).
4. **"Green" needs a scope label**: `/health`'s green is (correctly) DiscordSync-internal, but the page itself admits "green rows are unproven, not verified" AND the static render showed "0 of 13 services reporting pass" beside "All Systems Operational" — almost certainly the pre-SSE initial render, but unverified in a live browser (see f12). A one-line scope hint on the health page ("covers this daemon's subsystems only") would prevent exactly the confusion that triggered this session.
5. **Probe-set knowledge gap**: `immich.service` vs `immich-server.service` cost a near-miss (d2). Unit-name resolution (`/proc/<pid>/cgroup` or ListUnitsByPattern) should precede any unit-state conclusion — same shape as the boot-id prefix rule. Noted for `docs/services/immich.md` (not harvested this session — see f13).

## f) Up to 50 things we should get done next — session-scoped, ranked

> Honesty note: the owner asked for "up to 50". **16 items are genuinely derivable from this session**; padding to 50 would be filler violating the section-quality guide (vague items get routed to ROADMAP, not actioned). The remaining 34 would require researching work outside this session's run, which the owner explicitly forbade for this report. Say the word and I'll run a full-project pareto pass for the complete 50.

| # | Task | Impact | Effort | Category | Harvest status |
| - | ---- | ------ | ------ | -------- | -------------- |
| f1 | Immich API key: create (`asset.read`+`asset.upload` ONLY) → sops paste → deploy → E2E `/lookup` verify | Critical | S (user) + M (verify) | Feature | HARVESTED — `docs/todo/services.md:146` |
| f2 | `RandomizedDelaySec` on `discordsync-immich-verify.timer` (00:00 nix-gc collision) | Medium | S | Quality | HARVESTED — `:146` |
| f3 | post-deploy-check smoke leg: verify-unit result=success + env perms 0400 | Medium | S | Quality | HARVESTED — `:146` |
| f4 | Eval regression test: immich-disabled shape renders no template/unit/secret | Medium | M | Quality | HARVESTED — `:146` |
| f5 | Upstream: release TAG carrying ADR-062 (tag-pinned consumers) | Medium | S | Feature | HARVESTED — `:147` |
| f6 | Upstream: nixos-module `immichUrl`/`immichApiKeyFile` options | Medium | M | Feature | HARVESTED — `:147` |
| f7 | Upstream: fix malformed `healthCheck` readiness URL (verify-before-filing first) | Low | S | Bug | HARVESTED — `:147` |
| f8 | Upstream: contribute verify-oneshot pattern as optional module feature | Low | M | Feature | HARVESTED — `:147` |
| f9 | Upstream: fix "Immich: unavailable" badge wording (not-configured ≠ unreachable ≠ rejected) | High | S | Bug (UX) | HARVESTED — `:147` (new this session) |
| f10 | Upstream: WARN log on Immich proxy auth error (today: silent INFO 502s) — or local SigNoz alert on the verify unit's PLACEHOLDER line | Medium | S | Bug (obs.) | HARVESTED — `:147` (new this session) |
| f11 | Sweep repo docs for stale "NOT deployed"/"blocked by FOD" claims; re-adjudicate each against live state | High | M | Documentation | HARVESTED — new `[ready]` row in `TODO_LIST.md` (new this session) |
| f12 | Verify the `/health` "0 of 13 services reporting pass" static-render oddity in a LIVE browser (SSE state) before deciding it's a bug | Low | S | Bug? | **Deliberately NOT harvested** — premise unverified (queue premise-check rule: no unverified rows) |
| f13 | Add the `immich.service`-doesn't-exist / `immich-server.service` probe trap to `docs/services/immich.md` | Low | S | Documentation | **Deliberately NOT harvested** — file is mid-edit by a parallel session (git status `M`); editing risks the mid-edit race; defer to that session's close-out |
| f14 | CHANGELOG line for the todo-surface corrections when the daemon commit lands | Low | S | Documentation | **Deliberately NOT harvested** — optional, owner's call (c5) |
| f15 | Re-run `discordsync-immich-verify` immediately after key paste instead of waiting for the next 00:00 (restartUnits covers it — just verify the journal after deploy) | Low | S | Verification | Part of f1's chain — `:146` step 3 |
| f16 | Fold the "Immich availability is Gatus's job" scope note into `docs/agents/monitoring.md` cross-refs if not already there (NOT researched this session — verify first) | Low | S | Documentation | **Deliberately NOT harvested** — existence unverified (would need out-of-scope research) |

## g) Questions I can NOT figure out myself

See the interactive questions presented after this report — recorded here for the file:

1. **Priority**: should the Immich key go-live happen today (you create + paste, I verify after the deploy), or does it stay parked until you need `/lookup` for real?
2. **Product decision**: while the key is placeholder, do you want the "Also check Immich" toggle hidden/degraded entirely (no misleading badge), or keep it visible as-is and accept the wording until the upstream fix (f9)?
3. **Bundle decision**: should the cheap adds (f2–f4) ride the go-live deploy unconditionally, or only if that deploy happens within a bounded window (they're harmless but each deploy on this box carries risk)?

---

## Evidence appendix (commands that produced the load-bearing facts)

```bash
journalctl -u discordsync-immich-verify --since "7 days ago" --no-pager | tail -40
journalctl -u discordsync --since "3 days ago" --no-pager | grep -i immich | tail -15
printf 'GET /health HTTP/1.1\r\nHost: discordsync.home.lan\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -connect 192.168.1.150:443 -servername discordsync.home.lan
busctl get-property org.freedesktop.systemd1 /org/freedesktop/systemd1/unit/immich_2dserver_2eservice \
  org.freedesktop.systemd1.Unit ActiveState SubState   # "active" "running"
cat /proc/3788/cgroup   # → system-immich.slice/immich-server.service
bash scripts/check-todo-system.sh   # → OK: TODO queue/library structure clean
```
