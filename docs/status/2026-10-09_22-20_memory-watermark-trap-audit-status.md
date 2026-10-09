# Status Report — Memory-Watermark Throttle Trap: Fleet Audit, Eval Gate, Negative Test

**Date:** 2026-10-09 22:20 CEST
**Session scope:** the question "how can we throttle apps non-stop and not even know?" — answered for `llama-chat` (prior session), then extended: does any OTHER service carry the `MemoryHigh` << `MemoryMax` silent-throttle trap? → fleet audit (eval + live), prevention gap closed (eval-time assertion audit), negative-tested, docs landed, follow-ups self-harvested.

---

## Verification matrix (one screen)

| Claim | Method | Verdict |
| --- | --- | --- |
| No other unit has the trap (final configs) | `nix eval` over all evo-x2 system units (~300), HM user services, rpi3-dns units; byte-parse both watermarks, flag High < 50% of Max | **0 TRAP rows** in all three scopes; every both-watermarks unit sits at harden's 80% (or deliberate 100%) |
| No unit is throttled RIGHT NOW | direct cgroupfs sweep `/sys/fs/cgroup/system.slice/*.service/memory.events` + user slice | **zero `high` events anywhere**; `llama-chat` re-switched 21:23 (38.4G watermark / 48G ceiling, counter clean) |
| `llama-chat` was the sole victim | audit + git archaeology (17adf93b fix, 14b34d20 runbook, 5d4bb3be comment-only guard) | confirmed — only module that merged `MemoryMax` outside a bare `harden{}` |
| New eval gate actually fires on the trap | `CASES=memory bash scripts/negative-test-lints.sh` then **full suite** | memory group 2/2, then **32/32 PASS** (control green, trap mutation throws `memory-watermark-audit` marker) |
| Gate wired into the fleet | `nix eval toplevel` exit 0, `nix flake check --no-build` exit 0 | auto-discovery imported it on evo-x2 + rpi3-dns; zero offenders today |

---

## a) FULLY DONE

1. **Fleet-wide config audit for the throttle trap.** Parsed `MemoryHigh`/`MemoryMax` for every evo-x2 system unit, every HM user service, and every rpi3-dns unit at eval time (the authoritative merged view, not call sites). Zero sub-50% rows anywhere. Notable healthy-80% cohort: `fastflowlm` 32G/40G, `llama-chat` 38.4G/48G, `hermes` 20G/24G, `ollama` 27.5G/32G, `project-discovery-daemon` 6.4G/8G, rpi3 `dnsblockd` 3.2G/4G. Deliberate non-80% shapes pass correctly (`llama-vlm-*` 100%, `projects-management-automation` 75%, `btrbk-*`/`nix-daemon` high-only throttle-by-design, `gitea-runner` max-only).
2. **Live zero-throttle verification.** Swept `memory.events` on every system + user cgroup: no unit has a nonzero `high` counter. `llama-chat`'s cgroup was recreated 21:23 by the post-fix re-switch and shows the corrected 38.4G/48G pair with `high 0` (peak 34.1G, current 26.2G — matches the runbook's 32.3G idle footprint claim).
3. **`modules/nixos/services/memory-watermark-audit.nix`** (daemon commit `6605945f`): eval-time throw when any system OR NixOS-user unit's final `MemoryHigh` < 50% of `MemoryMax`; percent/`infinity` shapes skip (RAM-relative, not the trap class); `services.memory-watermark-audit.allowUnits` escape with justification requirement. Green on the tree (toplevel eval + `nix flake check --no-build` exit 0). This converts the incident class from "invisible performance failure" to "eval error with the fix in the message".
4. **Negative-test harness extension** (daemon commit `fed05806`): extracted `apply_mutations` (shared), added `eval_toplevel` + `eval_case` runner (assertion audits have no check derivation — their enforcement surface IS the toplevel eval), pristine-eval control, and group `memory` with the llama-chat trap mutation. Full suite: **32 passed, 0 failed** — proves the audit fails on the historical bug shape AND the `run_case` refactor broke nothing.
5. **Docs landed at all three surfaces** (daemon commit `fed05806` + working tree): AGENTS.md prevention-layer table (eval-time row now names memory-watermark incoherence), `docs/agents/systemd.md` gotcha bullet (mechanism + live probe: `memory.events` `high` counter, resets on restart), `docs/services/llama-chat.md` runbook pointer.
6. **Follow-up self-harvest at authoring time** (this report): 5 `[ready]` queue rows + 5 library entries + 2 `[decision]` rows landed in TODO_LIST.md + docs/todo/{stability,monitoring,pipeline,services,upstream}.md; `check-todo-system.sh` structure check passes.
7. **Harness hygiene:** standalone `shellcheck` on the harness — zero findings in the new code (only pre-existing info-level SC2016s on the deadguard fixture lines, where non-expansion is the intent).

## b) PARTIALLY DONE

1. **Runtime throttle detection is docs-only.** The eval gate makes the trap impossible for config-authored units, but a runtime-throttled unit (manual `systemctl set-property`, future HM gap) still surfaces nowhere automated — the probe is documented, not wired (→ f.1, harvested `[ready]`; hard-gate-vs-warn is f.7 `[decision]`). Effort: M.
2. **HM user services are outside the audit's scope.** NixOS system + user units covered; `config.home-manager.users.*.systemd.user.services` not. Zero HM user services set memory knobs today (verified), so live exposure is nil — future-proofing only (→ f.2, harvested). Effort: S.
3. **CI parity for the negative-test harness: absent.** Grep of `.github/workflows/` finds zero references — the entire selftest suite (now 9 contract groups) runs only when a local session remembers (→ f.3, harvested). Effort: S–M.
4. **Full-suite verification of the harness refactor was in-flight at the mid-session point** — closed before this report: 32/32. No residue.
5. **Formatter reflows uncommitted at authoring time** (`memory-watermark-audit.nix` + `flake/parts/checks/lint-static.nix` — pure alejandra reflow of a pre-existing long line, both semantics-neutral). The daemon sweeps; nothing to do.

## c) NOT STARTED (session-adjacent, deliberately not begun)

- Percent-form watermark doctrine (on 128G, `"80%"` ≈ 102G — never throttles before the kill; audit currently skips it by design). Decision needed, not code (→ f.8).
- Decimal-size support in the audit's byte parser (`"0.5G"` parses null → silently skipped).
- Slice/scope coverage (`systemd.slices` MemoryHigh can throttle a whole group silently — uncovered).
- Gatus latency budgets for memory-heavy endpoints (the throttle class manifests as latency; no check watches it).
- Eval-vs-runtime watermark drift check (deploy-skew class: what the running unit has vs what the tree says).
- `docs/agents/stability.md` cross-link for the throttle gotcha (currently only in systemd.md + runbook).
- rpi3-dns cosmetic watermarks (`dnsblockd` 4G on a 1GB-RAM Pi — inert, misleading on read).
- `llama-rag` presence question (module in tree, no live unit on evo-x2, dark-guard present — disable looks deliberate but undocumented; not verified this session).

None of these block anything; all are ranked in (f).

## d) TOTALLY FUCKED UP

**Nothing.** Nothing this session broke, reverted, or left red: toplevel eval green, `nix flake check` green, negative suite 32/32, `check-todo-system.sh` clean, no prod state touched beyond read-only probes. Honest near-misses (self-corrected, listed under (e), not hidden): two eval-expression stumbles burned one background eval each; the `run_case` refactor was initially verified only against `CASES=memory` before the full suite closed the gap.

## e) WHAT WE SHOULD IMPROVE (process, not bugs)

1. **Verify-before-claiming the enforcement surface.** I nearly wrote "prevention complete" when the guard was a comment. The repo rule is now live twice: a *closed* gate needs (1) the assertion, (2) a negative test proving it fires, (3) proof the CI/local gates run it. Items (1)+(2) landed same-session this time; (3) turned out to be a fleet-wide hole (f.3) — worth a habit: every new audit module ships with its harness group in the same commit.
2. **Harness refactors need the FULL suite, not the new group.** `apply_mutations` is shared by every group; group-only testing would have masked a regression. Cost of full suite is ~10 min eval-bound — schedule it, don't skip it.
3. **First-run tooling flags:** `builtins.toInt` (doesn't exist in plain Nix — `fromJSON` is the idiom) and an over-clever jq classifier both cost a ~2-min eval each. Keep eval one-liners dumb: parse defensively, classify in awk.
4. **`systemctl` is tool-blocked in this harness** — cgroupfs reads are the equivalent and richer (`memory.events`, `memory.peak`). Worth a line in `docs/agents/shell-devtools.md` so the next session doesn't rediscover it.
5. **The daemon-swept-commit lint gap is real:** the harness + docs committed via daemon (heuristic), so staged-path lint legs (shellcheck/ruff) silently skipped — standalone shellcheck had to be run by hand (done). The existing "re-run skipped lints standalone after daemon-swept amends" rule should say "after daemon-swept *commits*" too.
6. **Answer-first discipline worked and should stick:** the eval-time audit (merged config, not call sites) is what made the fleet question answerable in one pass — call-site greps (~160 hits) would have been both noisy and unsound.

## f) NEXT TASKS (ranked; harvest disposition explicit)

Harvested this pass → TODO_LIST.md + domain library: f.1–f.5. Report-only with reason noted per item. (Impact/Effort/Category per the quality guide.)

| # | Task | Impact | Effort | Category | Disposition |
| --- | --- | --- | --- | --- | --- |
| f.1 | Automated runtime throttle detection: `memory.events` `high` sweep in post-deploy-check + optional textfile/SigNoz rule | High | M | Feature | **HARVESTED** → monitoring.md + queue |
| f.2 | Extend memory-watermark-audit to HM user services | Medium | S | Feature | **HARVESTED** → stability.md + queue |
| f.3 | Wire negative-test-lints.sh into CI (nightly or push; CASES= splittable) | High | S–M | Quality | **HARVESTED** → pipeline.md + queue |
| f.4 | Fix the `catalog` integration-subdomains eval warning (19 subdomains, prints on every eval) | Medium | S | Bug | **HARVESTED** → services.md + queue |
| f.5 | Drop/fix the `go-structure-linter` `treefmt-nix` override warning in flake.nix | Low | S | Cleanup | **HARVESTED** → upstream.md + queue |
| f.6 | Full negative-test suite as the standard closer for any harness/audit refactor (habit, not code) | Medium | S | Process | report-only — behavior, not a ticket |
| f.7 | `[decision]` Runtime throttle finding: hard deploy gate vs advisory | High | — | Decision | **HARVESTED** → monitoring.md `[decision]` (asked in g.1) |
| f.8 | `[decision]` Watermark threshold policy: single 50% tripwire vs per-class budgets | Medium | — | Decision | **HARVESTED** → stability.md `[decision]` (asked in g.2) |
| f.9 | Percent-form watermark doctrine (forbid `"80%"`-style values in the audit, or document RAM-relative semantics) | Low | S | Quality | report-only — folds into f.8's outcome |
| f.10 | Audit parser: support decimal sizes (`0.5G`) or fail loudly on unparseable values instead of silent skip | Low | S | Bug | report-only |
| f.11 | Slice/scope MemoryHigh coverage (`systemd.slices` can throttle a group silently) | Low | M | Feature | report-only |
| f.12 | Gatus latency budgets for memory-heavy endpoints (llama-chat `/health` 45s-timeout class) | Medium | M | Feature | report-only — needs the gatus coverage audit's pattern |
| f.13 | Eval-vs-runtime watermark drift check (deployed unit pair vs tree pair; deploy-skew class) | Medium | M | Quality | report-only |
| f.14 | Cross-link the throttle gotcha into `docs/agents/stability.md` (+ note memory-emergency-guard is PSI-based, blind to `memory.events`) | Low | S | Documentation | report-only |
| f.15 | Audit CONTRIBUTING.md module templates + integration-registry examples for bare-`harden{}`-then-merge teaching shapes | Medium | S | Documentation | report-only — unverified this session |
| f.16 | Verify `llama-rag` disabled state is deliberate + documented (module present, no live unit, dark-guard present) | Low | S | Documentation | report-only |
| f.17 | Pre-existing SC2016 infos in negative-test-lints.sh fixture lines: add a targeted disable comment (intentional literal `$x`) so future shellcheck runs are noise-free | Low | S | Cleanup | report-only |
| f.18 | rpi3-dns `dnsblockd` watermark resize to Pi-realistic values (cosmetic; inert today) | Low | S | Cleanup | report-only |
| f.19 | `llama-chat` stale 5.6G swap resident post-fix — optional swapoff/swaprefill cycle at a maintenance window | Low | S | Cleanup | report-only — owner window |
| f.20 | `systemd-analyze`-style one-shot: emit per-unit High/Max/ratio table as a flake app (formalizes this session's ad-hoc eval probe) | Low | S–M | Feature | report-only |
| f.21 | `memory.events` `max` counter (hit-the-ceiling alloc failures) as an OOM-adjacent early-warning signal in the same sweep as f.1 | Low | S | Feature | report-only — pairs with f.1 |
| f.22 | Decide whether `harden{}` should take `MemoryHigh` ONLY as a paired argument (API shape that makes the divergence unrepresentable at the call site, complementing the final-config audit) | Medium | M | Quality | report-only — design discussion |

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Runtime throttle detection (f.1): when the `memory.events` sweep fires, should it FAIL the deploy or WARN?** The llama-chat incident argues hard-gate (46k events, zero alerts, 1h53m stuck); the counter-reset blind spot (a freshly restarted throttled unit reads 0) argues advisory. I cannot make this risk call for you. Pairs with the existing IO-PSI-gate advisory-or-hard question already queued in stability.md.
2. **Watermark threshold policy (f.8): keep the single 50% tripwire, or per-class budgets?** If you ever want a deliberate aggressive-reclaim service (e.g. an AI unit reclaiming earlier than 80% of its ceiling), the current design forces an `allowUnits` entry per unit — fine at one, noisy at ten. Your call whether that noise is a feature.
3. **CI appetite (f.3): should the negative-test harness run on every push, nightly, or stay local-only?** Full suite is eval-bound (~10 min warm); the `CASES=` groups allow splitting (e.g. memory + bridge on push, rest nightly). This is a cost/coverage tradeoff only you can price.

---

## Session ledger

**Read:** `lib/systemd.nix` (harden mechanics), InboxClean status report `fb6a954`, SystemNix `5d4bb3be`/`17adf93b`/`14b34d20`, docs/agents/systemd.md, start-limit-audit + port-registry-audit patterns, negative-test harness, llama-chat.nix wiring.
**Wrote:** `memory-watermark-audit.nix` (new), `scripts/negative-test-lints.sh` (+eval runner, +memory group), AGENTS.md (prevention row), `docs/agents/systemd.md` (gotcha), `docs/services/llama-chat.md` (runbook), TODO_LIST.md (5 rows), 5 × docs/todo/*.md (7 entries).
**Commits:** `6605945f` (audit module), `fed05806` (docs + harness) — both via auto-commit daemon, contents verified with `git show --stat`; formatter reflows pending in tree.
**Gates:** toplevel eval ✅ · `nix flake check --no-build` ✅ · negative suite 32/32 ✅ · `check-todo-system.sh` ✅ · standalone shellcheck (new code) ✅.
**Format note:** user explicitly demanded `.md` at a named path; per the status-report skill that is a flagged override of the HTML-canonical default, not propagated anywhere.
