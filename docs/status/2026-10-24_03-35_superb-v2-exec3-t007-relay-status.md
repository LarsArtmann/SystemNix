# SUPERB v2 Execution Session 3 — T-007 Gatus Alert Relay

**Instance:** superb-masterplan-v2-exec-2 (marker start stamped 03:39, this session's own convention; sprint T-007 only)
**Date:** 2026-10-24, 03:35–~04:50 CEST
**HEAD at close:** `b4e6c3efc` (session commits `e22397e03` relay, `98475de30` close-out, `b4e6c3efc` decoupling+rows; marker-start rode `e22397e03`)
**Plan:** docs/planning/2026-10-23_15-00_SUPERB-backlog-masterplan-v2.md — EXECUTING exec-2 stamped, flipped EXECUTED at this session's close

## a. What ran

Single-sprint session (owner SUPERB directive as license; owner-gated items untouched):

- **T-007 (monitoring:199, plan S-041, effort 96 — the plan's largest): gatus-alert-relay**, a local Go gate on gatus' Discord webhook path. gatus posts to `127.0.0.1:9111/hook`; the relay re-posts pass-through bytes to the real webhook (same `gatus-env` sops secret, now shared by both units). Four suppression rules: boot-grace (15 min from relay start — covers boot windows AND deploy restarts), sev1-mute (SEV1 bridge page-tier active + storm-attributable DisplayName list), flap-collapse (>4 forwarded triggers/6h + 30 min quiet reset — the only LOSSY rule), rearm-guard (10 min post-resolve). Contract: every other rule QUEUES and replays when its condition clears without an intervening resolve — a mute may delay, never lose.
- **On-sight fix (session-2 residue, self-review §f.47): flm-coredumps walk decoupled from `collectPmaCommits`** — the walk, consume, and emission all sat inside the PMA gate; disabling PMA would have silently killed a fastflowlm metric and false-alarmed the anchored Gatus check. Now unconditional; pair degrades to standing 0 when PMA is off; flm selftest re-run green against the restructured script.
- **5 self-review observations cleared** (the entire §c/§f.44-48 unqueued list): 2 queued as rows (pma-commits dead-string probe, node_load1 zero-in-selector — monitoring.md + TODO_LIST mirrors), 2 AGENTS.md doc fixes (scoped `nix fmt --` form works; `-b` index-vs-stream clause), 1 fixed (the flm gating above).
- **Bonus row queued:** lint-static.nix statix debt committed to HEAD via hookless daemon commits now BLOCKS hook-gated commits of that file (hit twice this session; pipeline.md + TODO_LIST).

## b. Premise corrections (research-first, before building)

- **The row's core premise was wrong**: "gatus re-sends initial alerts on every process start" is true only for in-memory storage. Verified against gatus 5.37 source: sqlite storage persists triggered-alert state (`endpoint_alerts_triggered`, restored at startup — `sendInitialAlert := !Triggered` stays false). The repo already uses sqlite. The Oct 20 boot storm was NEW triggers while services settle (gatus up early, storm boots 8-13 min), not restart re-sends.
- **Gatus 5.37 maintenance windows exist but are time-fixed** — cannot key on boot settle or SEV1 state; and `custom` provider is a single slot (taken by papdashboard), which forced keeping the `discord` provider and repointing its `webhook-url`.
- **Provider-level `webhook-url` is NOT part of gatus' alert checksum** — the relay switchover wipes no persisted alert state, so no deploy re-fire storm (this made the whole design safe to deploy).

## c. Verification (every gate green)

- Go unit tests run in-build (`doCheck`, buildGo126Module, vendorHash=null, ai-meter doctrine): every rule, replay transitions, cancel-on-resolve, fail-open, window pruning, quiet reset.
- Live smoke of the BUILT binary against a fake upstream (python http.server): trigger during grace suppressed (not upstream-received), resolve forwarded AND canceled the queued trigger, post-grace triggers forwarded ×2, 3rd flap-collapsed, `/healthz` counters exactly matched the journal decisions (forwarded 3, boot-grace 1, flap-collapse 1, queued 0).
- evo-x2 toplevel eval green; full `nix flake check --no-build` green at sprint commit; `checks.gatus-config-parse` (real `gatus validate` on the rendered yaml) green twice — once with the relay URL live, once with the new relay-pointing grep leg.
- `checks.flm-crash-trigger-pair` VM selftest green after the decoupling (slices still anchor).
- Shellcheck standalone on post-deploy-check.sh clean; scoped treefmt (`nix fmt -- <files>`) canonical on all touched nix files.

## d. Multi-agent discipline (parallel sessions live throughout)

- Lock-wave + SEV1 + catalog-inventory + kernel-fix sessions all active; git index locked ~5 min by a pathspec commit whose pre-commit `nix flake check` ran under load-81 — waited, never forced.
- The tracked-files trap hit as documented: new module file un-staged = "attribute does not exist" eval failure; `git add` fixed.
- statix pre-commit leg aborted my close-out commit: staged lint-static.nix carried PRE-EXISTING debt from hookless daemon commits (verified statix on the HEAD blob — the findings are in HEAD, not my hunks). Excluded lint-static.nix from my commits (the grep-leg edit rides the daemon); queued the debt row rather than racing the active forgejo-census session on that region.
- TODO_LIST.md carried the SEV1 session's staged tick all session — my queue ticks (T-007 + 3 new rows) are in the working tree for the daemon to batch; both surfaces edited per the no-drift rule.
- Self-inflicted and corrected mid-session: `rg -rn` replace-trap hit once (mangled names read as literal `n` — the exact AGENTS.md doctrine from yesterday; caught immediately, re-ran with `rg -n`).

## e. Deploy-gated surface (rides the owner's deploy train, Q1)

The relay is eval-green and INERT until deploy. At deploy: relay unit starts, gatus re-renders with the relay webhook, boot-grace mutes the deploy-window churn by construction. Post-deploy asserts already wired: the `Gatus Alert Relay` healthz probe in post-deploy-check.sh (`9111/healthz` 200 + "forwarded" in body). First live boot after deploy = free end-to-end verification of the boot-grace leg.

## f. Follow-ups (self-harvested — all queued)

1. pma-commits dead-string probe (monitoring.md, queued this session) — P0-adjacent phantom-green risk.
2. node_load1 zero-in-selector root-cause (monitoring.md, queued this session).
3. lint-static statix debt (pipeline.md, queued this session) — blocks hook-gated commits of that file.
4. client.timeout batch row (monitoring:197, sibling of T-007 — kills the false-REDs the relay mutes the noise of) — next sprint candidate.
5. Deploy train (owner Q1): relay + flm decoupling + session-1/2 stack (kernel shims, forgejo-runner, DNS unification, T-002/T-004 alerts) — post-deploy §10 asserts to extend with `system_flm_crash_trigger_pair_24h` / `system_memcg_oom_*` / relay healthz.

## g. Owner questions (carried from session 2, still pending)

- **Q1 — deploy timing:** the train stacks kernel shims (new 7.3 kernel), forgejo-runner migration, DNS unification, T-002/T-004 alerts, and now the relay + flm decoupling. Storm has calmed (PSI avg300 ~30% vs 64% at session-2 close) but load still spiked to 81 mid-session. Deploy now or hold for calm?
- **Q2 — lock-wave row attribution:** their forgejo-runner fix verified green by me (session 2) but their rows (services.md:741 + TODO_LIST:686) remain `[ ]` — tick on their close-out, or may a later session?
- **Q3 — truncated journal recovery:** 54k readable entries already secured (T-006); attempt recovery of the truncated `system@00065dd5….journal~` tail or accept the loss?

## Census at close

TODO_LIST open rows: 1,605+3 queued −1 ticked = 1,607 (tree in constant parallel churn; re-baseline at next session start).
