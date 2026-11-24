# timesheets dashboard CSS fix: upstream landed, deploy storm-gated (overnight)

- **Session window:** 2026-11-17 19:05 to 2026-11-18 06:42 CET (report authored 06:42, per owner request)
- **Verdict:** the timesheets.home.lan unstyled-dashboard bug is FIXED UPSTREAM and PUSHED (`0372bb8`); the SystemNix lock float is evaluated green; the only remaining step is one deploy that the pressure gate has refused for ~11 hours under multi-session build churn. The box also took a probable freeze (#57) at 21:01:48 during my watch, mid-storm.

---

## 0. The bug, in one paragraph

`timesheets.home.lan/` (302 → `/health`) renders an unstyled page with console spam. The go-health-dashboard library renders its Tailwind utility markup but ships no stylesheet: without `dashboard.WithCSSPath` it falls back to the Tailwind Play CDN script (`https://cdn.tailwindcss.com`, nonce'd so it runs), whose entire job is injecting runtime `<style>` elements. The dashboard's own strict CSP (`style-src 'self'`, `csp.go:34`, pinned by tests) blocks every injected rule and every JS style mutation: unstyled page plus the exact console violations the user pasted. The library documents this as failure signature "Unstyled page (all or parts)" (its README); timesheets was simply missing the consumer-side compiled-CSS wiring that invoices and dnsblockd already have.

## a) FULLY DONE

1. **Root cause chain pinned with file:line evidence.** CDN emitter: `view.templ:125/132` (CDN when `CSSPath == ""`); CSP: `csp.go:34` (`style-src 'self'`, docstring: "no 'unsafe-inline' for styles", pinned by tests + `scripts/check-ui-pins.sh`); the `<link>` contract: `templ-components@v1.27.0/layout/base.templ:274-275` renders `<link rel="stylesheet" href={CSSPath}>` when set; option: `options.go:404-408` (`WithCSSPath`).
2. **False upstream lead investigated and CLOSED before editing.** I briefly concluded go-health-dashboard "half-implements" the contract (no `<link>` anywhere in its module). Disproved: the link comes from templ-components `layout.Base`, which the dashboard passes `CSSPath` into. No upstream change needed; consumer-side fix only.
3. **Fleet precedents studied and adopted.** invoices: `scripts/build-dashboard-css.sh` (absolute `@source` paths, module-cache scan, committed artifact, go:embed, same-origin route) — copied at matching scale. dnsblockd: `gen-library-classes.sh` + `WithCSSPath` consumer wiring — confirmed the pattern generalizes.
4. **Fix implemented in timesheets, commit `0372bb8`** (6 files, 166 insertions, pushed `5c32b1a..0372bb8`):
   - `scripts/build-dashboard-css.sh` — Tailwind v4.3.3 CLI; `@import "tailwindcss" source(none)`; absolute `@source` over repo `internal/`, go-health-dashboard `**/*.templ` + `status.go` (Go-file classes), templ-components `**/*.templ` + `templates/templ-components-classes.txt`; `@custom-variant dark`; theme + custom css imports. Module dirs resolved via `go mod download -json` (replace-aware).
   - `internal/server/assets/dashboard.gen.css` — 128,890 bytes committed artifact; **10/10 sentinel classes verified** (bg-green-100, dark\:bg-green-900\/30, outline-dashed, shadow-xs, sr-only, amber-500, text-gray-900, grid-cols-3, focus\:ring-blue-500, motion-reduce).
   - `internal/server/assets.go` — go:embed + handler (text/css, no-cache), CSP-clean same-origin serving.
   - `internal/server/routes.go` — `GET /health/dashboard.css` registered in the dashboard branch (matches `isDashboardPath`, so the CSP middleware covers it consistently).
   - `cmd/timesheet/cmd/serve_cmdguard.go` — `dashboardCSSRoute` const + `dashboard.WithCSSPath(dashboardCSSRoute)`.
   - `internal/server/dashboard_test.go` — test helper now mirrors production wiring; new `TestDashboardCompiledCSS` pins the contract: page must link the artifact and must NOT contain `cdn.tailwindcss.com`; artifact must be served 200 text/css and contain sentinel classes from the pinned library versions (drift tripwire per the fleet compiled-CSS rule).
5. **Verification green.** `GOEXPERIMENT=jsonv2 go build ./...`; full `go test -race ./...` PASS; targeted dashboard battery PASS; treefmt 0-changed. BuildFlow pre-commit: my files passed shellcheck/templ-fmt/file-size; the gate failure was 100% pre-existing red (13 oversize files, docs-gates audit+freshness) — the exact documented debt in `docs/todo/upstream.md`, same rationale as `e90e7a1`'s `--no-verify`.
6. **Daemon-race discipline held.** The auto-commit daemon swept 5 of 6 files mid-edit (`ec177b7`); verified `git show --stat` contained exactly my files, then pathspec-amended into `0372bb8` with `--no-verify`. BuildFlow's unrelated auto-fix (`.github/workflows/ci.yml` setup-go pin v7.0.0→v7.1.0) was deliberately LEFT uncommitted in the tree, not absorbed.
7. **SystemNix lock floated and evaluated.** `nix flake update timesheets` (modern form; the command printed a git exit-128 warning but the lock verifiably moved): timesheets `5c32b1ad2e48` → `0372bb89fb4a`; invoices (`4c4512b8`) and nixpkgs untouched. Eval green: toplevel drv `dw0aizac6r23mrgfypcc4xxgj1cr330r` (differs from live `0ail8450sm...` = real drift, deploy will do real work). The float rode another session's commit `275f9b137` (pushed; branch in sync with origin).
8. **Live incident witnessed and evidenced.** Boot `783f2d13` died 21:01:48 mid-journal-stream (services logging normally, a `nix-daemon` connection accepted at the death instant, no shutdown trail) → fresh boot `cd60fc6b` 21:02:44. Pre-freeze profile matched the crash class exactly: zram 97.2% fill + io PSI 97.6%, all six NVMe/SATA devices ~101-103% util. Another session's commit (`275f9b137`, 20:14) already counts a "freeze-#56" inside that same boot — so the 21:01 death is freeze #57 by their numbering. Also captured: `node_exporter`'s `system_health.prom` textfile was failing to parse ("expected float as value, got \"\"") for hours before death — monitoring was blind to its own health signal going into the freeze.

## b) PARTIALLY DONE

1. **Deploy: attempted four times, gate-refused every time, fix NOT live.** My 19:52 attempt hit the full storm block; on-disk evidence of others: `2026-11-17_11-16-25.log` and `2026-11-17_19-58-55.log` (both `deploy exited code=12`). I then ran three chained calm-wait→deploy scripts (bounded 30/30/60 min, polling 60s→10s): ALL TIMED OUT — io PSI `some avg10` hovered 25-99 for ~11 hours and never held under the gate's <20 threshold (closest: 28 at 21:53). As of 06:42: io 77.46, gen still `system-1015`, the box still serves the unstyled dashboard.
2. **Storm attribution: identified the load class, not the full causal map.** During the wait I caught the concrete churners: another session's `nix build .#checks.x86_64-linux.test --keep-going`, stray `go build -o /tmp/...` compiles, Go link at 102% CPU, qmd/bun, 3-4 concurrent `crush -y` sessions. The 21:01 freeze happened during exactly this churn. Attribution of WHO owned which build (for the incident report) is incomplete.
3. **CI verification: premise found stale, not yet resolved.** `gh run list` on timesheets shows NO push-triggered workflow at all (only Dependabot/Graph runs, latest 11-14). TODO row 3594 ("Verify timesheets upstream CI green at 4db9566") presupposes a CI that does not exist. My `0372bb8` push triggered nothing. Row needs rewriting or a workflow needs adding (owner question 3).
4. **Close-out docs: deferred, with explicit disposition.** The runbook CSS sentence (`docs/services/timesheets.md:21`), the harvest rows for this report's §f follow-ups, and the freeze note were deliberately NOT written yet — the owner instruction was report-then-wait, and the two live candidate rows are named in §f so nothing is silently dropped.

## c) NOT STARTED

1. Post-deploy verification battery (the moment a deploy lands): HTML contains `<link rel="stylesheet" href="/health/dashboard.css">` and no CDN; `/health/dashboard.css` → 200 text/css ~129 KB; `/version` shows the `0372bb8` short rev; anchor `readlink /run/current-system` == newest `system-N-link`; `scripts/post-deploy-check.sh` re-baseline.
2. `docs/services/timesheets.md` runbook sentence (dashboard styled via compiled CSS since 0372bb8; unknown-path 404 posture unchanged).
3. Freeze #57 incident evidence pull (pstore is root-only; NNP blocks agent sudo — needs owner or an owner-launched session) and its status note.
4. `system_health.prom` collector repair (textfile parse failure = blind monitoring before the freeze).
5. Parity check: does invoices' dashboard CSS pipeline have a sentinel drift test like the one I added to timesheets? If not, add one (same class of protection).

## d) TOTALLY FUCKED UP (honest roll)

1. **The upstream false lead.** I nearly wrote an upstream patch to go-health-dashboard for a "missing link" that templ-components' `layout.Base` renders. Cost ~15 minutes of upstream repo forensics (tags, CHANGELOG, OIDC-unreleased state) before the base.templ grep killed the premise. The check that mattered (`grep '<link'` in the component that receives CSSPath) should have been step one, not step nine.
2. **I fired my first deploy attempt into a measured storm.** At 19:52 the gate output showed zram 97.2% and io PSI 97.6% — I had already watched several minutes of storm readings while diagnosing, and still armed `nix run .#deploy` without a pre-flight PSI check. The gate (correctly) refused; the gate is the backstop, not the first line. My chain scripts should have been attempt one.
3. **The freeze happened on my watch and I did not flag it in real time.** I observed the exact pre-freeze pressure profile at 19:52 and spent the next 70 minutes politely waiting; the box died at 21:01. The freeze-#54 lesson (re-boot-identity + escalate when the box is in the pre-freeze zone) argues I should have surfaced the risk to the owner mid-storm, not discovered the corpse 15 minutes later via a PSI total-counter reset.
4. **11 hours of deploy deadlock without owner escalation.** Three chained timeouts (22:53 last) each ended in re-arm rather than a message to you with the option set (force / kill competing builds / wait for daylight). The autonomy instruction says exhaust approaches, but a multi-hour external blocker with a risk tradeoff is owner-decision territory.
5. **My own chain granularity nearly missed the window.** 60s polling against a 10s-PSI window metric meant a brief sub-20 gap would have been missed; the 28 reading at 21:53 may have BEEN the window. Re-armed at 10s an hour late.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-flight the deploy gate inputs before arming a deploy** (one command: io PSI + zram fill + disk busy). The gate is a last-line protection; treating it as the first check avoids refused deploys entirely.
2. **Chained calm→deploy with the gate-identical predicate is the right shape** — make it a repo script (candidate: extend `scripts/deploy-when-quiescent.sh` or add `deploy-when-calm.sh`) instead of session-local throwaways.
3. **Escalation timer:** if an external blocker exceeds ~30 minutes and the next step is an owner risk decision, report with options instead of silently re-arming.
4. **Boot-identity re-diff on EVERY discontinuous reading** — the reboot was only caught because a PSI total counter dropped; the reboot-signature checklist (14-0x) exists and I applied it late.
5. **Monitoring-the-monitor:** a textfile collector that fails to parse should WARN loudly (it paged nobody while the box slid into a freeze). Candidate: gatus/SigNoz rule on `node_exporter` textfile scrape errors, and fix whatever emitted the empty line into `system_health.prom`.
6. **Multi-session build churn needs a serialization story** (repo-level flock around heavy nix builds, or a session convention: checks builds yield to deploys). Tonight: 3+ sessions building concurrently fed two freezes.
7. **Sentinel drift tests should exist in EVERY compiled-CSS consumer** (invoices next; dnsblockd already has byte-freshness gates).
8. **timesheets needs a real push CI or the CI-green queue premise dies** (see question 3).

## f) UP TO 50 NEXT TASKS (ordered; P0 = deploy path, P1 = close-outs, P2 = debt)

1. **[P0] Deploy** when the gate passes: pre-flight PSI/zram; if competing builds hold PSI up past ~30 min more, escalate per question 1.
2. **[P0] Verify live CSS** (§c.1 probe set) immediately after the switch.
3. **[P0] Anchor check** `readlink /run/current-system` == newest `system-N-link` (exit-14 class).
4. **[P0] `scripts/post-deploy-check.sh`** re-baseline; expect the out-of-scope FAILs to persist (tq-agent-pool, papdashboard, cvagent, embeddings).
5. **[P0] Runbook sentence** in `docs/services/timesheets.md` (§c.2).
6. **[P0] Freeze #57 evidence**: journal tail capture (done, quoted above), pstore pull via owner sudo, freeze-counter confirmation against the other session's #56 numbering, status note.
7. **[P0] `system_health.prom` repair** + a rule that pages on textfile parse errors (§c.4/§e.5).
8. **[P1] Harvest this report's §f P0 rows into `TODO_LIST.md` + domain libraries** (explicitly deferred to the next work turn; candidate rows: deploy follow-up #1-4, collector repair #7, CI-row rewrite #10).
9. **[P1] Storm-attribution note**: map tonight's freezes (#56, #57) to the build-churn timeline; name the owning sessions where /proc evidence allows.
10. **[P1] Rewrite TODO row 3594** (CI-green verify at 4db9566): no push CI exists; either kill as Won't-implement or fold into a new "add push CI" row (question 3).
11. **[P1] invoices: sentinel drift test** for `internal/dashboard/assets/dashboard.gen.css` (parity with timesheets' new test).
12. **[P2] Commit or revert BuildFlow's ci.yml pin bump** sitting uncommitted in `~/projects/timesheets` (setup-go v7.0.0→v7.1.0, buildflow-authored; legitimate repair, needs an owner-sanctioned commit).
13. **[P2] go-health-dashboard upstream idea**: ship a class-manifest (dnsblockd `library-classes.txt` pattern) so consumer CSS builds are robust against module-cache scanning drift; file as upstream row.
14. **[P2] `scripts/deploy-when-calm.sh`** productization (§e.2).
15. **[P2] Multi-session build serialization** convention or tooling (§e.6).
16. **[P2] Gatus coverage question**: is `timesheets.home.lan/health/dashboard.css` (and invoices' `/assets/dashboard.css`) probed? Unstyled regressions currently surface only via humans.
17. **[P2] `tc doctor` / templ-components CLI check** on the new timesheets CSS pipeline (the library's diagnostic; one-time confirmation).
18. **[P2] Add the compiled-CSS rebuild step to the timesheets dependency-bump runbook** (README failure-state section references it; make the consumer runbook say it too).
19. **[P3] Sweep `/tmp` for the stray `go build -o /tmp/...` test binaries** other sessions left (they re-link on every run; owner-visible disk churn).
20. **[P3] timesheets `docs-gates` + file-size red gates** — the standing upstream-debt row (13 oversize files, docs-gates audit/freshness) still forces `--no-verify`; unchanged by this session.

(30 items intentionally not padded to 50; items 1-8 are the deploy path and its obligations.)

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy policy under chronic churn:** the gate has refused for ~11 hours because other sessions keep the box at PSI 25-99. Do you want `DEPLOY_FORCE_PRESSURE=1` used at a moderate-PSI moment (e.g. PSI < 40, zram < 50%) once competing builds finish, or do we hold for a genuine <20 window? I will not force without your word.
2. **Freeze #57 (21:01:48):** do you want the full incident pull now (pstore is root-only and agent sudo is NNP-dead, so it needs you or an owner-launched session), and is another session already writing the freeze report (their `275f9b137` commit already counts a #56 inside that boot)?
3. **timesheets CI:** there is no push-triggered workflow at all (Dependabot only). Kill TODO row 3594 as a dead premise, or do you want me to add a real CI workflow (build + race tests + golangci on push/PR)?

---

_Evidence appendix: user console paste (CSP violations + CDN warning); timesheets `0372bb8` diff (6 files); sentinel grep 10/10 on `dashboard.gen.css` (128,890 B); full race suite PASS output; BuildFlow pre-commit summary (21 findings, 15 info, my files clean); push `5c32b1a..0372bb8`; lock diff timesheets rev; eval drv `dw0aizac...`; deploy logs `2026-11-17_11-16-25` + `2026-11-17_19-58-55` (both code=12) and my live refusal output; PSI timeline (19:52: 97.6%/zram 97.2%; 21:05-21:07: 61-71; 21:53: 28; 22:53: 81; 06:42: 77.46); boot list (`783f2d13` ended 21:01:48, `cd60fc6b` 21:02:44); previous-boot journal tail (mid-stream cut, nix-daemon accept at death)._
