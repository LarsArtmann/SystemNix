# Status: inboxclean-canary quote-escape build-failure fix + latent fail-open finding

**Date:** 2026-10-13 14:02 CEST
**Session scope:** single-thread debugging + fix of the `inboxclean-canary-metrics` derivation build failure reported via `nix log`, plus branch-verification, prevention-layer audit, and follow-up harvest.

---

## TL;DR

The `inboxclean-canary-metrics` package (canary textfile collector for the InboxClean health-timeout IO-saturation signal, landed 2026-10-13 via daemon commit `bbae5884`) **never built**: the source's `''''` quote sequence in a Nix indented string renders to an ODD number of single quotes (`'''`), producing an unterminated bash string at script line 26. The build correctly failed at the `writeShellApplication` check phase (`bash -n`); the `(exit code 0)` in the user's transcript was the `nix log` command's own exit code, not a successful build. Fix: `""|*[!0-9]*` empty-pattern form (immune to Nix `''` escaping). Landed via daemon commit `dc3ad6e7`, verified end-to-end (toplevel build, unit wiring, branch-tested sandbox runs, `nix flake check --no-build` all green). **Two follow-on findings:** (1) the module had been closed out earlier today as "eval-verified only" — eval cannot see build breakage, so a broken collector sat in-tree all day behind a green flake check; (2) the collector's `scrape_errors` gauge is dead code — journal-read failures masquerade as healthy zeros (sandbox-proven).

---

## What did I forget? What could have been better?

Honest self-review of THIS session's execution:

1. **Branch coverage came last, not first.** I verified the burst path (count=12) and `bash -n`, but only exercised the zero-match and journal-failure branches when the review prompt forced a second look — and the journal-failure branch then exposed the `scrape_errors` dead-code defect (§d.1). Branch tests belong in the FIRST verification pass for a fail-closed collector.
2. **I picked the fix form before grepping for the repo idiom.** `discordsync.nix:86-87` already used `'''|*[!0-9]*` (correctly rendering `''`). Finding it only after my edit cost a deliberate re-choose (I stayed with `""` — see §a.2 rationale) and delayed spotting the typo-bait pattern that likely CAUSED the original bug.
3. **Tooling detours.** `nix derivation show` does not recurse into inputs on nix 2.34, and `nix build --check` is gone (removed by 2.34). Two probe cycles burned on discovering this; the toplevel build was the correct verification route from the start.
4. **First probe was mis-built** (`'''` renders to a VALID two-quote script), producing a green probe that proved nothing. Verified the escaping table empirically before retrying.

---

## a) FULLY DONE

1. **Root cause:** `modules/nixos/services/inboxclean-canary.nix:68` used `''''|*[!0-9]*` inside `text = ''…''`. Live-verified Nix 2.34.8 indented-string rendering: `'''` → `''` (two quotes), `''''` → `'''` (THREE), `''` + non-escape terminates the string. Odd count → `bash: line 26: unexpected EOF while looking for matching '` — exactly the build-log error.
2. **Fix:** `""|*[!0-9]*)` — double quotes pass through Nix `''` strings untouched, bash-identical semantics (empty-word arm). Chosen over the discordsync `'''` form deliberately: `'''` reads as a typo and demonstrably invites "balancing" back to `''''`. Landed in daemon commit `dc3ad6e7` (verified: exactly 1 file, 1 line).
3. **End-to-end build verification:** evo-x2 toplevel build green (`system-units`/`etc`/`activate` chain rebuilt); new drv output `5navslyzjrlf8ixdh55wx45hr4vvl6mn` valid + registered; `bash -n` clean; built unit file wires `ExecStart=/nix/store/5nav…/bin/inboxclean-canary-metrics`; `nix flake check --no-build` → all checks passed.
4. **Functional branch tests (sandboxed, redirected paths):** burst path — 12 live Handler-timeout lines/10min → `count=12 burst=1 errors=0`, valid `.prom` emitted; zero-match path — `count=0 burst=0 errors=0` (the `|| count=0` comment's promised behavior holds for that leg).
5. **Prevention-layer audit:** proved via probe derivations that the check phase genuinely fails builds on broken scripts (probe with odd-quote script → build exit 1). The mysterious store path `/nix/store/3bav…` is UNREGISTERED residue of the failed build (`nix path-info` → not valid) — never a real artifact, never shipped; `gc` will sweep it.
6. **Incident-reading corrections:** the module was never deployed (no live journal entries for the unit/timer) — prod is untouched by all of this; "live count 12/10min" provenance now pinned as journal-grep (via the sandbox run), not collector metric.

## b) PARTIALLY DONE

1. **Branch coverage of the canary script:** 2 of 3 behavioral branches verified green; the journal-failure branch was exercised and found to expose a latent defect — the DEFECT is not fixed (queued, §d.1), the quote fix itself is complete.
2. **Trap-class sweep:** found the sibling idiom (`discordsync.nix:86-87`, correct rendering, typo-bait form); migrated NOT done — live deployed service, rides the next deploy (queued).
3. **§f self-harvest:** the 6 direct follow-ups landed in `TODO_LIST.md` + `docs/todo/{monitoring,services,pipeline}.md` this turn (queue↔library edited together); the longer brainstorm list deliberately not harvested (brainstorm ≠ commitment; recorded as such in §f).

## c) NOT STARTED

1. **Deploy of the fix** — prod still runs WITHOUT the canary collector at all (owner-gated timing; `nix run .#deploy` ready whenever).
2. **Post-deploy LIVE verification** of the collector (pre-existing queue row, premise-corrected to `[blocked:deploy]` this session).
3. **`scrape_errors` defect fix** + its SigNoz rule leg.
4. **discordsync idiom migration.**
5. **Commit/CI guard** catching this bug class pre-build.
6. **Quote-rendering table** in `docs/agents/nix-flakes.md`.

## d) TOTALLY FUCKED UP

1. **`inboxclean_web_canary_scrape_errors` is dead code — the canary fails OPEN on exactly its target scenario.** The `|| count=0` fallback swallows journalctl/grep pipeline failures and rewrites count to numeric 0, so the `errors=1` case arm fires only on an exotic empty capture. Sandbox-proven this session: nonexistent-unit probe → `count=0 burst=0 errors=0` (exit 0), while the metric's own HELP promises "1 when the journal read failed". The canary's most probable real-world failure is `timeout 30 journalctl` under IO saturation — precisely when it must NOT look healthy. Inherited defect (predates this session), found during branch testing. Queued with a concrete fix shape: capture the journal-read status separately; keep the grep zero-match leg as success.
2. **The "eval-verified only" close-out class (prior session, recorded because it shaped this one):** the canary landed at 03:52 closed on eval alone while the drv never built. Eval and build verification are different gates; this session proves the gap is real, not hypothetical. Guard queued (§f.5).
3. **Nothing else is on fire:** the broken state never reached prod, no other odd-quote `''''` sites exist in the repo (sweep done), and the check phases held the line.

## e) WHAT WE SHOULD IMPROVE

1. **Repo:** a commit/CI leg catching odd-quote `''` sequences (or broadly: render-and-`bash -n`) in `.nix` shell-script `text` attrs — eval is structurally blind to this class.
2. **Repo:** close-out protocol for new/changed service scripts must include BUILDING the drv (one command, seconds for `writeShellApplication` packages).
3. **Repo:** document the empirically-verified quote-rendering table in `docs/agents/nix-flakes.md` — undocumented behavior cost a build failure.
4. **Repo:** consider a `mkJournalCountCollector`-style lib so journal-count collectors get rendered safely by construction (kills the quoting class at the root; ROADMAP-grade).
5. **Me:** grep for the existing idiom BEFORE choosing a fix form; run branch tests in the first verification pass, not after review.

## f) NEXT — up to 50 (ranked; items 1–6 are HARVESTED this turn, the rest is brainstorm/ROADMAP fuel, deliberately not harvested)

1. **[harvested → queue+services.md]** Fix the `scrape_errors` dead-code path (fail-open defect) + SigNoz rule leg.
2. **[harvested → queue+monitoring.md]** Deploy evo-x2 carrying `dc3ad6e7`, then verify collector LIVE (timer, prom metrics, rule; expect burst=1 first scrape, decay to 0 post cached-health deploy).
3. **[harvested → queue+services.md]** Migrate `discordsync.nix:86-87` `'''` → `""` (typo-bait class).
4. **[harvested → queue+pipeline.md]** Commit/CI guard for odd-quote `''` in shell-text attrs + CONTRIBUTING "build the drv" close-out line.
5. **[harvested → queue+pipeline.md]** Quote-rendering table into `docs/agents/nix-flakes.md`.
6. **[not harvested — micro]** Sweep the repo for any other odd-quote `''` sequences in `writeShell*` texts (sweep this session found none, but make it a habit leg of the guard).
7. Add SigNoz rule `inboxclean_web_canary_scrape_errors == 1` once the defect is fixed.
8. Eval-time contract check: every textfile-collector metric name emitted by modules appears in ≥1 SigNoz rule query string (the `_signoz-alerts.nix` ↔ collector coupling is hand-maintained).
9. gatus-coverage analog for textfile metrics: emitted-but-never-queried metric lint.
10. Generalize the collector fixture-selftest pattern (storage-history-smoke-selftest style) to journal-count collectors: fixture journal + rendered script + assert `.prom`.
11. Watch row: confirm burst decays to 0 after the InboxClean cached-health deploy (the regression-guard purpose; cross-ref the /health-latency-baseline queue row).
12. `mkJournalCountCollector` lib (root-cause-grade fix for the quoting class).
13. Consider `config.services.prometheus.exporters.node.enabled` assertion for the canary's `mkIf` gate (textfile written but unscraped if node_exporter is off).
14. Post-deploy check leg: `inboxclean-canary.prom` mtime-freshness assert (§19 pattern).
15. Audit OTHER `|| var=0`-style journal-count collectors for the same fail-open shape (grep the repo; the discordsync byte-counter variant reads differently but verify).
16. Document nix 2.34's removed `nix build --check` and the current re-verify workflow (`--rebuild` semantics) in nix-flakes.md.
17. jq recipes for structuredAttrs `derivation show` JSON (non-prefixed `outputs.out.path` shape, non-recursive) into shell-devtools.md.
18. Close-out convention: tag count provenance (journal-grep vs collector metric) — extends the verification protocol wording.
19. `nix log` output carries no build exit status — consider an upstream note (verify-before-filing first; only if pursued).
20. Timeout-budget coherence check for the canary class (internal `timeout 30`×2 vs `TimeoutStartSec 2min` — verified coherent this session; generalize only if the existing eval audits don't cover it — decision).
21. SigNoz rule window vs timer cadence documentation (10m window / 2min cadence = 5 samples/window — fine, record intent in the rule comment).
22. Selftest fixture asserting the fixed case-pattern renders an even quote count (marginal — the bash -n gate covers; optional).
23. `docs/services/inboxclean.md`: add the canary section (metric names, expected first-scrape burst, scrape_errors caveat until fixed).
24. CHANGELOG line for the quote fix (docs-health pass picks it up).
25. Store hygiene note: residue paths (`3bav…`, probe outputs) self-clean at next GC — no action needed; recorded for provenance.
26. Probe hygiene: name-tag future broken-build probe residue for easy cleanup (micro).
27. Probe store paths used this session (`crush-broken-quote-probe*`) are self-identifying garbage; sweepable anytime.
28. Cross-ref: the eval warning observed during this session's eval — "catalog: integration subdomain(s) without catalog entries … will vanish from derived DNS once platforms/common/dns-local.nix is deleted" (20 subdomains listed) — prior-session thread, still open.
29. Consider documenting the toplevel-drvPath eval as the fast targeted gate for single-module changes (pipeline.md already has a related row — this session re-confirmed the flow).
30. `nix build --impure --expr` probe pattern is a useful verified-live tool for script-level experiments; consider a devtools doc note.
31. Ring-fence: when the scrape_errors fix lands, re-run the three sandbox branch tests as the regression proof.
32. Optional: extend `scripts/negative-test-lints.sh`-style harness with a rendered-script bash -n selftest for one representative collector.
33. Review whether `onFailure` + `converger` coverage for the canary matches the deploy-restart audit expectations (eval audits passed; spot-verify intent).
34. Verify the canary's `ReadWritePaths` + sticky-dir mv works under the real service user (sandbox ran as `lars`; the nobody-user rename-over-leftover case is the documented trap — first live run will prove it).
35. After deploy: confirm the SigNoz rule fired ONCE for burst=1 and self-resolved (expected-alert hygiene).
36. Consider annotating the expected burst=1 alert in the SigNoz rule description ("expected on first deploy; regresssion guard for cached-health").
37. If the burst does NOT decay to 0 post cached-health deploy, that contradiction IS the signal the upstream fix regressed — runbook it in inboxclean.md.
38. Micro: `/tmp` scratch from probes (`probe2.out`, `top.json/err`) — ephemeral, no action.
39. Micro: PIPESTATUS reporting quirk in this shell env (empty expansion) — cosmetic, skip unless it recurs.
40. Longer-term: collector metric-name registry (single source consumed by both modules and rule lint) — the split-brain guard for §8/§9.

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Deploy composition:** deploy `dc3ad6e7` now as a solo evo-x2 deploy, or bundle with the upcoming InboxClean cached-health deploy? Bundling means the canary goes live roughly when the timeouts should stop (burst=1 may never scrape); solo means one expected burst=1 alert that should decay.
2. **The fail-open defect (§d.1):** fix BEFORE the first deploy (a small second edit can ride the same deploy) or ship the quote fix as-is and fix the gauge in a follow-up?
3. **Discordsync idiom migration** touches a live deployed service's rendered scripts (rendering-identical, but drv hashes change and it rides a redeploy): migrate now or defer to a scheduled deploy window?

---

*Provenance: fix in `dc3ad6e7`; verification artifacts: drv `5navslyzjrlf8ixdh55wx45hr4vvl6mn` (valid), unit `vsribc760pidgvc0yffqjzkjbkmm413g-system-units` (ExecStart line 12), flake check green 2026-10-13 ~13:55.*
