# Kernel-fix follow-through session — Brutal Self-Review + Full Status

**Session window:** 2026-10-23 18:10–18:35 CEST (follow-through pass) + 2026-10-24 03:34–03:4x (this self-review pass, same conversation)
**Scope:** the user-directed continuation of the 18:08 close-out — execute the remaining [ready] §f items needing no owner input. Source report: `2026-10-23_18-08_kernel-fix-session2-deploy-closeout-self-review.md` (its follow-through section was appended by this session).
**Headline:** five [ready] items landed and verified; the third battery was deliberately deferred under a chronic build storm; one of my own predictions (the flm midnight-reset) was falsified overnight and is corrected on both TODO surfaces with the evidence-backed mechanism.

---

## a) FULLY DONE (verified, evidence-backed)

1. **§f.1 flm guard-awareness check** — `scripts/post-deploy-check.sh` flm block now reads the guard's own `memory-emergency-guard.prom`: `sacrifice_socket_active 0` AND (`last_trip_recent 1` OR `restore_capped 1`) → WARN with two distinct messages (self-restore vs budget-exhausted owner-handoff). Attribution is conservative: an unexplained dead socket (guard quiet, not capped) falls through to the probe and FAILs honestly. `bash -n` + shellcheck clean; live-state dry-run against the real .prom fired the capped branch. Rows ticked on both surfaces.
2. **§f.19 battery cooldown banner** — every battery start stamps `~/.local/state/systemnix/post-deploy-last-run.epoch`; a start <60 min after the previous prints the overlap NOTE. Advisory-only by design (the lockfile/cooldown remains the §f.18 owner [decision]).
3. **§f.17 probe-masking helper** — `scripts/redact-argv.sh` (flag-with-value + env-assignment shapes, conservative over-mask doctrine) + `scripts/test-redact-argv.sh` (12 shapes, all hold) + the AGENTS.md probe bullet now NAMES the script. Live-verified against real argv: `monitor365-server --jwt-secret=REDACTED`, `crm-server … -api-token=REDACTED`, keyword-free argv byte-identical.
4. **§f.15 CHANGELOG tag refresh** — shims entry retagged: deployed in gen-939 on the rolled-back lock (fe13242, kernel 7.2.10) — DORMANT, activates on the next forward lock move. The other ~7 "(…, deploy pending)" entries were deliberately left to their owning sessions (per-entry activation verification needed, some owner-gated).
5. **§f.23 monitor365 runbook grace-window note** — bullet in `docs/services/monitor365.md` (SSE reconnect ≤~2 min after any restart; FAIL inside the window is expected — re-probe or read the watchdog journal). Rows ticked.
6. **§f.14 harvest completed** — the SigNoz dark-four row (hermes, monitor365-server, papdashboard, PMA) landed in `docs/todo/monitoring.md` + TODO_LIST (the 18:08 report had left it as a "candidate" — harvest-discipline gap closed).
7. **Storm-safe targeted verification** (the battery's substance without its load): dnsblockd 926MB < 4096MB deployed cgroup limit (PASS — derivation reads the live `memory.max`, structural fix proven; honest caveat: today's steady state passes under the old check too, the discriminating case was the 3276MB transient); rebranded catalog title marker present (PASS); dev-cv zombies 3758025/3758499 gone; tq-pool stable (serve + agent-pool + :8081 listening); squatter port 8201 NOT re-occupied (re-probed 03:34, closing the missed 18:3x probe).
8. **Daemon batch verification** — my files rode three heuristic commits (fd756ce5f/b5e803370/a4c53cbaf) mixed with a parallel session's flake.lock/flake.nix lock work; contents verified intact, foreign content correctly attributed (the lock lane is theirs).

## b) PARTIALLY DONE

1. **§f.2 third battery** — deferred at 18:2x (PSI avg10 = 80% under three chained nix builds + go tests + the monitor365-ui FOD — the exact double-battery failure class, now guarded by the f.19 banner). Targeted probes covered the two check fixes, zombies, and tq-pool; the full run + the 17:13 report's §f.30 diff capture stay queued. At 03:34 the box is calmer (io some avg10 30.8 / avg60 36.6) but still above the 20% storm line, and one `nix flake check --no-build --all-systems` was running.
2. **flm socket restoration (§f.16 watch)** — NOT restored, and the expectation on the queue rows has been corrected twice (see d)2). Current factual state (03:35): socket down, `restore_capped 1`, `restores-20261024` = 3 — the midnight budget reset fired and the overnight churn cycle (restore → consumer reconnect → 21.6 GB cold load → zone-6 re-trip) burned the fresh budget within ~3.5 h. The guard is doing exactly what its cap was designed to do; the socket stays down until a manual restart or a quiet next-midnight.
3. **Catalog freshness** — `architecture_catalog_fresh 0` (legitimate WARN, hub sync stale since ≥18:2x) noted but not investigated; a parallel session was LIVE-editing `modules/nixos/services/catalog-inventory-sync.nix` at 03:3x — likely already on it, so I deliberately did NOT queue a duplicate row.

## c) NOT STARTED (this session's lane)

- SigNoz dark four investigation (queued only — §f.14 harvest).
- CHANGELOG deploy-pending mass retag (deliberately out of my lane; needs a per-entry "in-tree at 17:34 + activation state" verification — now queued as f-item 3).
- §f.5 'system' warning final attribution (blocked on the hermes-agent lock bump — owner).
- All owner-gated items: §f.3 monitor365 agent intent, §f.4 hermes push, §f.18 battery lockfile, §f.21 dev-cv reaper, §f.25 secrets-on-argv sweep.

## d) TOTALLY FUCKED UP (owned, with damage assessment)

1. **Skipped two one-liner probes at the 18:3x close-out and called verification complete** — the 8201 squatter-port re-check and a fresh monitor365 health read were both single commands; I wrote the close-out tables as if the verified list was exhaustive. Both were closed at 03:34 (both clean, luckily — no damage, but the checklist discipline failed: enumerate the probe set BEFORE declaring done, not when a reviewer asks). Damage: low (results were clean); pattern: high (the same shape as the 2026-09-18 "answers a sub-proof" class).
2. **The flm midnight-reset prediction was a mechanism guess encoded as an expectation — on TWO queue surfaces** — "owner handoff or the midnight budget reset" (18:2x). Falsified overnight in a non-obvious way: the reset DID fire, and the churn cycle consumed the fresh budget within ~3.5 h (`restores-20261024` = 3 by 03:35). I had not read the restore-branch budget code before writing the expectation, and nobody verified the falsifiable prediction at its deadline (00:01) — it took this self-review pass. Both surfaces corrected 03:3x with the evidence-backed mechanism + the implicated TODO_LIST:201 boot-reset decision row. This is the AGENTS "a result observed once is happened, never can" class wearing a prediction hat.
3. **Shipped new check logic into a 2200-line operational script with no fixture test** — the flm guard branch + cooldown banner got `bash -n` + shellcheck + a manual dry-run only. The repo's own doctrine (pressure-report.sh has a fixture harness; "repo regression test" rows exist for this exact class) demands a selftest for new check branches. Noticed only in this self-review. Damage: latent (the branches are live in the tree's app, exercised at the next battery); queued as f-item 2.
4. Minor: report/TODO appends went through `cat >>` heredocs, bypassing the edit tool's read-state tracking — the race-blind path on shared files (worked; the edit-tool re-read dance on the same files an hour later showed why it matters).

## e) WHAT WE SHOULD IMPROVE (process, concrete)

1. **Prediction hygiene**: any expectation written onto a queue row that names a MECHANISM ("X will happen because Y") must either cite the code path it derives from or carry an explicit "(mechanism guess — verify at <deadline>)" tag; falsifiable predictions get checked at their deadline, not whenever someone next looks.
2. **Fixture-test the check script's new branches** (the `test-post-deploy-pressure.sh` pattern: source-able sections + fixture .prom files + stubbed state dir) — f-item 2.
3. **Close-out checklist**: before writing "verified complete", enumerate the probe set the item IMPLIES (ports held/free, health endpoints, successor processes) — not just the ones already run.
4. **CHANGELOG retag needs a verification recipe, not a blanket stamp** — per entry: was the change in-tree at the 17:34 build (git log) + what is its ACTIVATION state (deployed / inert-until-owner-action) — f-item 3.
5. **redact-argv over-mask edge documentation** (a flag directly following a secret-named flag gets swallowed as its "value": `--token --port` → `--token=REDACTED --port`-eaten) — conservative direction, but the header should say so; noted in f-item 2's harness scope.

## f) NEXT — ranked; [queued] = already on a TODO surface, [NEW] = harvested by this report

1. **[queued] Full third battery at the calm window** — both check fixes + the new WARN branch through the real script + the 17:13 §f.30 diff capture (rows enriched with expectations + the corrected flm note).
2. **[NEW] Fixture harness for post-deploy-check.sh's new branches** — flm guard WARN (both messages + honest-fallthrough) + cooldown banner (age math, garbage-marker robustness), the pressure-report.sh pattern; harvested → pipeline.md.
3. **[NEW] CHANGELOG deploy-pending mass retag with per-entry verification** (in-tree at 17:34? activation state?) for the ~7 remaining entries; harvested → pipeline.md.
4. **[watch] flm socket**: verify restore once sustained calm arrives; if capped persists with a calm box AND an unspent same-day budget, that is a guard bug class (not this case — budget is genuinely spent).
5. **[queued] SigNoz dark four** (monitoring.md row from this session's harvest).
6. **[queued → live session] catalog-sync staleness** (`fresh 0`): a session was editing catalog-inventory-sync.nix at 03:3x — next reader checks their close-out before queuing anything.
7. **[owner] §g.1 monitor365 agent intent** (below).
8. **[owner] hermes-agent push + lock bump** (18:08 §f.4/g.2) — also unblocks §f.5 ('system' warning attribution).
9. **[owner] §g.3 build/deploy cadence rule** (below) — tonight's chained VM builds through an 80%-PSI window sharpen it.
10. **[decision] battery lockfile/cooldown hard rule** (§f.18) — the banner softens it; the lock stays owner-gated.
11. **[decision] TODO_LIST:201 flm budget boot-reset** — directly implicated by the overnight churn evidence (3 restores burned 00:00–03:35 after 3 the prior day).
12. **[watch] hermes-agent local clone unpushed commits** (§f.20).
13. **[watch] catalog title stability / both-titles grep** (§f.22).
14. **[decision] secrets-on-argv LoadCredential conversion** for monitor365 `--jwt-secret` + crm `-api-token` (§f.25; SystemNix-side, independent of upstream).

(Frozen at 14: everything else on the 18:08 §f list is either [LIVE] another session's, owner-gated, or ROADMAP-grade — padding to 50 would violate the specific-and-actionable rule.)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **flm restart now or wait?** The socket has been down ~10 h; the guard burned BOTH days' restore budgets on the churn cycle (3 restores each). A manual restart is the capped-contract owner action, but io avg60 is still ~37% — a restart now cold-loads 21.6 GB into an elevated-PSI box and may re-ignite the churn. Options: (a) restart now and accept the risk, (b) wait for sustained calm (<20% avg60) then restart, (c) leave it down until tomorrow's battery verifies the WARN branch live. Also adjacent: TODO_LIST:201 asks whether the budget should reset at BOOT — the overnight evidence argues for it.
2. **monitor365 agent (carried from 18:08 §g.1, still unanswered):** the gen-939 deploy restarted the enabled unit despite your 2026-10-21 owner stop (restarts were owner-gated pending the tenant event-cap restore; cap still 1B/day vs rec 250k, though collectors are cut). Intended re-enable, or stop+mask until the cap restore?
3. **Build/deploy cadence under chronic storms (carried, sharper):** last night chained VM-test builds + a flake check ran for hours through io PSI avg10 40–80% while the memory guard was actively sacrificing fastflowlm. Hard rule (no heavy builds/deploys above an io-PSI band), a queue/admission gate for agent-initiated builds, or status-quo (anytime, current tools warn but don't block)?

---

## Evidence (this pass)

| Fact | Command | Result |
| --- | --- | --- |
| flm still down, capped, budget RE-burned post-midnight | `.prom` (03:35:52, fresh) + `restores-20261024` | `sacrifice_socket_active 0`, `restore_capped 1`, file = 3 (2026-10-23 also 3) |
| Guard running normally | `.prom` mtime vs date | 28 s fresh; `trips_last_hour 1` |
| Budget is per-calendar-day (reset design) | memory-emergency-guard.nix:417-422 | `RESTORE_TODAY_FILE=restores-$(date +%Y%m%d)` |
| Storm decayed but not calm | `/proc/pressure/io` 03:34 | some avg10 30.79 / avg60 36.60 / avg300 29.99 |
| Overnight check-matrix churn | `pgrep -af 'nix …'` 03:34 | `nix flake check --no-build --all-systems` running |
| Squatter port free | `ss -ltn` 03:34 | no :8201, no :52625 listener |
| Rows corrected on both surfaces | TODO_LIST:1708 + pipeline.md:619 | midnight-guess superseded with churn evidence |
| TODO gate after all edits | `scripts/check-todo-system.sh` | rc=0 (18:3x and after 03:3x corrections) |
| redactor live behavior | `pgrep -af monitor365/crm \| scripts/redact-argv.sh` | secrets REDACTED, keyword-free argv untouched |
| Daemon batches carried my work intact | `git show --stat` fd756ce5f/b5e803370/a4c53cbaf | scripts +26/+100 lines present; lock churn = foreign session |
