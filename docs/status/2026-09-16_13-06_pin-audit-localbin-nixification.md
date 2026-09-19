# Session Status — 2026-09-16 13:06

**Scope:** this session's three tasks: (1) flake pin-policy conversion, (2) pin-vs-upstream audit
with fixes, (3) `~/.local/bin` nixification. Plus an honest self-review. Everything here is
point-in-time evidence from this session; no other project state was researched.

> FORMAT NOTE: this report is Markdown at the user's explicit request — the status-report skill's
> canonical output is a styled HTML dashboard. One-off override, not propagated back into the skill.

---

## a) FULLY DONE

| # | What                                                                                                                                                                                                                                                                                                                                                                                                     | Evidence                                                                                                                                                            |
| - | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Pin-policy conversion** (directive: `?ref=master` everywhere possible): 6 hard pins → branch-ref governed (BuildFlow, branching-flow, file-and-image-renamer dropped `&rev=`; go-cqrs-lite kept branch ref; art-dupl kept fork ref; browser-history `github:<rev>` → `?ref=master`, the one undocumented pin)                                                                                          | commit `7f513e88` (flake.nix + flake.lock, locked revs byte-identical — python sorted-keys round-trip verified before writing); `nix flake check --no-build` passed |
| 2 | **Pin-policy doctrine documented** in AGENTS.md (Nix & Nixpkaps gotchas) with the full surviving-pin inventory and escape conditions                                                                                                                                                                                                                                                                     | AGENTS.md pin-policy bullet, updated again after the audit                                                                                                          |
| 3 | **Pin-vs-upstream audit** (gh-compare + build probes at every upstream HEAD): fixed 3 more pins — **md-go-validator** (master builds, FOD probe passed), **todo-list-ai** (bun lockfile fixed upstream, builds at `9406be72` from OUR lock incl. nixpkgs-follows), **go-nix-helpers** (/vN fix landed on master as `c42fd778`; consumers `file-and-image-renamer` + `crush-daily` goModules re-verified) | probe logs in session; commits `9e251ef4`, `28c7a675` (daemon)                                                                                                      |
| 4 | **Verified-current pins, no action:** qmd `v2.8.3` and nix-email `v0.2.0` are the latest tags; go-taskqueue's pinned rev is NOT on GitHub (compare API 404) — interim `git+file?rev=` correctly continues                                                                                                                                                                                                | ls-remote / gh-api outputs in session                                                                                                                               |
| 5 | **`print-safe` nixified**: `pkgs/print-safe.nix` (writeShellApplication, full runtimeInputs incl. cups/python3/gawk), overlay entry in `overlays/linux.nix`; **body byte-identical to the working script** (post-build diff, only trailing newline)                                                                                                                                                      | store path `784csqj…-print-safe`; diff run in session                                                                                                               |
| 6 | **`llamacpp-server` nixified** in `ai-stack.nix` — routes through `llama-server-rocm` (GTT-first gfx1150) instead of the bare binary; same CLI/env contract (`LLAMACPP_{PORT,HOST,CTX,SLOTS}`)                                                                                                                                                                                                           | eval passes; definition in ai-stack.nix                                                                                                                             |
| 7 | **Package wiring**: `uv`, `shfmt`, `nodejs` (replaces the `exec bun` node shim), `inputs.buildflow` package, `pkgs.fastflowlm` (replaces the `flm` wrapper — nix pkg sets its own XILINX_XRT) in configuration.nix systemPackages; HM `home.sessionPath` for `~/.local/bin` replaces the uv-installer `env`/`env.fish`/`conf.d/uv.env.fish` boilerplate                                                  | commits `9e251ef4`/`28c7a675`; `nix flake check --no-build` green; treefmt clean (0 changed)                                                                        |
| 8 | **Pre-deploy checks pass**: 63 passed / 0 failed (warnings only: monitor365 + cv metrics down as expected, known §11/§12 WARNs)                                                                                                                                                                                                                                                                          | deploy attempt #3 output                                                                                                                                            |

## b) PARTIALLY DONE

| # | What                                                                  | Done                                      | Missing                                                                                                                    | Blocker                                                                                                                                                                                                                                                           | Effort                           |
| - | --------------------------------------------------------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| 1 | **Deploy of the whole session's work** (pin flips + bin nixification) | build tree verified; pre-deploy 63/0      | the actual `nh os switch`                                                                                                  | **Hard-blocked by a sustained REAL IO storm**: PSI full avg10 51-55%, disk busy up to 540%, three llama-servers (two at 92.6% CPU) + parallel-session gopls/go builds. Gate correctly refused 3× (crash-#3 precursor class). 20-min wait loop saw no quiet window | S once quiet: `nix run .#deploy` |
| 2 | **`~/.local/bin` cleanup** (trash of replaced/dormant files)          | full deletion list compiled and justified | deletions deliberately ordered AFTER the deploy lands (else uv/shfmt/node/buildflow/print-safe/llamacpp-server have a gap) | deploy (b1)                                                                                                                                                                                                                                                       | S                                |
| 3 | **Status report handoff**                                             | this report                               | TODO_LIST/ROADMAP harvest of section (f)                                                                                   | not yet run                                                                                                                                                                                                                                                       | S                                |

## c) NOT STARTED (all noticed during this session, none begun)

- **signoz + signoz-otel-collector bump**: master is +42/+7 ahead; pins stay because upstream churn + OUR vendorHashes. This is a **migration-review task** (schema-migrator runs on service start), not a hash refresh.
- **art-dupl-src split-brain check**: `art-dupl` flake input rides the `fork` branch while `art-dupl-src` (raw source consumed by dnsblockd) points at bare master — the fork carries a vendorHash fix master lacks. Alignment never examined.
- **browser-history pin provenance archaeology**: `0971fe9c`'s introduction commit is UNFINDABLE in any ref's history (`git log -S/-G --all` shows only my removal commit and the Aug-8 `?ref=master` integration). A committed state whose introducing commit cannot be located is a history-integrity anomaly, possibly related to the documented 09-14/09-15 rebase/update-ref sagas.
- **CI verification of the git+ssh trio**: dropping `&rev=` means CI resolves via the lock through deploy keys — untested until the next push.
- **print-safe execution test**: `PRINT_SAFE_DRY_RUN=1 print-safe file.pdf` was never run (the script has a dry-run mode; only the build was verified).
- **llamacpp-server smoke test**: the nixified launcher was never executed.
- **tq-redesign cutover**: manual `tq-redesign serve --addr 127.0.0.1:18472` (pid 229432) still double-runs against the systemd tq pool — flagged by pre-deploy every attempt; needs the docs/services/tq.md cutover.
- **Foreign doc review**: daemon commit `9e251ef4` swept in a parallel session's `docs/status/…fixes-signoz-paperless-hermes-pushblocks.md` (91 lines) — per the concurrent-session doctrine it was flagged, not reviewed or co-verified.

## d) TOTALLY FUCKED UP

1. **The status report itself was forgotten twice** — requested at session start, interrupted by new tasks, and only delivered now (13:06 vs first request ~10:44). The skill's process step existed precisely for this.
2. **My deploy wait-loop scripts were buggy twice**: v1 had a broken awk pipeline that did nothing; v2 raced into a deploy attempt because of a float-vs-integer `[ ]` comparison (deploy ran pre-deploy checks again and was correctly re-blocked, but I burned a cycle and added load to a saturated box). A machine-under-pressure situation deserves careful scripts, not improvised one-liners.
3. **Unformatted files briefly existed in the tree**: the first `nix fmt -- --ci` run found 3 files needing changes (my in-flight edits) and the daemon had to sweep them. Better: format immediately after each file write, not after the whole task.
4. **The browser-history provenance hole** (see c) — I converted the pin without resolving WHERE it came from; if it was deliberate for a build reason I did not find, the `?ref=master` conversion needs revisiting. The eval passed and the lock rev is unchanged, so risk is contained until the next explicit update, but the open question is real.

## e) WHAT WE SHOULD IMPROVE

- **Make the pin policy mechanical**: an eval-time lint (flake check) that fails when an input URL carries a rev/tag WITHOUT a machine-readable reason marker (e.g. `# PIN-REASON:` in the adjacent comment). Today the policy lives in prose; the 2026-09-13 wave proved prose pins rot. The audit probes (compare + goModules got-hash) could become `scripts/audit-flake-pins.sh` wired into CI.
- **The wait-for-quiet deploy is a recurring need**: today's buggy loops should become `scripts/deploy-when-quiet.sh` (integer-safe PSI+disk-busy polling, phantom-vs-real classification mirror of the gate, max-wait timeout, then either deploy or hand the decision back).
- **Run `nix fmt` right after each file write** when the auto-commit daemon is active — never give the daemon a window with unformatted files.
- **Probes should distinguish "upstream healthy" from "upstream compatible with our follows"**: the todo-list-ai lesson — upstream `#default` build passes but the FOD content can differ under our nixpkgs; the correct probe is building the input FROM OUR LOCK post-re-lock (done this time; encode it in the pin-audit script).
- **Deletion lists should ship as a checklist in the repo** (scripts or docs) when ordering matters (deploy-then-trash), so an interrupted session leaves an auditable state rather than tribal memory.

## f) UP TO 50 THINGS TO GET DONE NEXT (ranked; harvest into TODO_LIST/ROADMAP)

**Immediate (this session's tail):**

1. Deploy when IO quiets (`nix run .#deploy`) — Impact: Critical, Effort: S, Quality
2. Trash the compiled deletion list (buildflow{,.bak-v0.6.2}, flm, fastflowlm share dir, 23 himalaya artifacts, node shim, shfmt, uv, uvx, env, env.fish, conf.d/uv.env.fish, print-safe, llamacpp-server) — Critical, S, Cleanup
3. Verify post-switch: `which uv shfmt node buildflow print-safe llamacpp-server flm` resolve to nix paths; new shell PATH contains `~/.local/bin` via sessionPath — High, S, Quality
4. `PRINT_SAFE_DRY_RUN=1 print-safe <some.pdf>` smoke test — High, S, Quality
5. `llamacpp-server` launch smoke test (then kill; it's the :8899 crush provider) — High, S, Quality
6. Run `docs-health` HARVEST on this report's (f) into TODO_LIST/ROADMAP — High, S, Documentation
7. Review the parallel session's `…fixes-signoz-paperless-hermes-pushblocks.md` doc (rode commit `9e251ef4`) — High, S, Documentation

**Pin/lock follow-ups:**
8. Build `scripts/audit-flake-pins.sh` (compare + probe protocol from AGENTS.md, machine-readable PIN-REASON markers) — High, M, Quality
9. Eval-time lint rejecting rev-in-URL inputs without PIN-REASON marker — High, M, Quality
10. signoz + signoz-otel-collector bump WITH migration review (schema-migrator; ClickHouse compat; do in a maintenance window) — High, L, Feature
11. DiscordSync pin lift procedure: watch for upstream master goModules probe passing, then lift per the documented hold rule — Medium, S, Maintenance
12. Resolve browser-history `0971fe9c` provenance (git history anomaly) or accept + document it — Medium, M, Quality
13. Align `art-dupl-src` (bare master) with the `fork`-branch flake input, or justify the divergence — Medium, S, Cleanup
14. go-taskqueue: flip `git+file?rev=` → `github:?ref=master` the moment `1a4eb480` is pushed — Medium, S, Maintenance
15. Re-verify the git+ssh trio fetches on CI at the next push (deploy-key path without `&rev=`) — Medium, S, Quality
16. qmd: check for a new tag upstream monthly (currently current at v2.8.3) — Low, S, Maintenance
17. nix-email: next tag bump needs BOTH repos' nixpkgs pins moved together (compat doctrine) — Low, M, Maintenance

**bin/tools follow-ups:**
18. Decide hf/huggingface-cli/tiny-agents fate: keep uv-managed vs nixpkgs `huggingface-hub` — Medium, S, Decision
19. Document the "uv stays the python-tool manager, uv itself is nix-provided" pattern in AGENTS.md — Low, S, Documentation
20. himalaya: record the removal decision + nix re-add recipe in a doc line (it was dormant 5 months) — Low, S, Documentation
21. fish conf.d: `00-go-cache-guard.fish.backup` stray file — user-owned; delete or leave (noticed, untouched) — Low, S, Cleanup
22. Consider a proper socket-activated service for the :8899 personal llama server (currently a launcher script; GPU is idle-paid when unused) — Low, M, Feature

**Deploy-infra improvements (all noticed today):**
23. `scripts/deploy-when-quiet.sh` (proper wait-for-quiet; the two buggy one-liners today prove the need) — High, M, Quality
24. Pressure-gate WARN: print the top-3 IO-attributable processes (pid/comm via /proc/$pid/io delta) to make "who is the storm" instant — Medium, S, Quality
25. The gate's phantom-vs-real classification oscillated (idle→busy) as workloads burst; consider requiring 2 consecutive same-verdict samples before acting on either — Medium, S, Quality
26. treefmt/fmt state: ensure daemon commits never carry unformatted files (pre-commit fmt hook timing) — Medium, S, Quality

**Concurrent-session hygiene (noticed today):**
27. Daemon commit `9e251ef4` mixed my flake changes with a foreign doc — the known limitation; consider per-session pathspec staging hints — Low, M, Process
28. `tq-redesign` manual process cutover (recurs in every pre-deploy) — Medium, S, Cleanup

**Everything below is ROADMAP fuel harvested from session observations (lower priority):**
29. Signoz exemplar persistence upstream watch (AGENTS.md note) — Low, S, Watch
30. Signoz dashboard: flake-input/lock-age panel fed by `scripts/audit-flake-pins.sh` output — Low, M, Feature
31. AGENTS.md: add the "two-probe rule" (upstream probe + from-our-lock probe) to the CV probe-protocol section — Low, S, Documentation
32. flake.lock surgery helper: `scripts/rewrite-input-url.sh <input> <new-url>` (the python round-trip is proven; make it a tool) — Medium, S, Quality
33. Add `flake.lock` integrity check (original URLs ⊆ flake.nix inputs) as a flake check — Medium, M, Quality
34. nodejs closure size on this box: if nobody uses it, drop it and re-add on demand (bun covers interactive use) — Low, S, Decision
35. Write the interrupted session's ORIGINAL status report scope (pin policy round 1) into docs-history — Low, S, Documentation (superseded by this report)

**Not session work but visible from it (parking here so they are not lost):**
36. `nix-email` stalwart/parsedmarc: confirm the mail-relay Resend domain verification landed (pre-deploy output still showed cv/monitor365 metrics down — unrelated, but relay was the chain) — Low, S, Verification
37. llama-server ×3 running at high CPU with SLOTS=1 launch config — check whether the draft-model spawn or duplicates explain it (user workload; observed only) — Low, S, Investigation
38. `iotop-c` running persistently (pid 7082) — fine, but note it perturbs PSI readings marginally — Low, S, Note
39. Pre-deploy §11/§12 WARNs (goModules "unable to determine", one ExecStart not-built-yet) — benign but could resolve by teaching the check the buildGoModule detection — Low, M, Quality
40. Monitor365 + cv metrics endpoints down in §10 WARNs — expected (disabled/auth-gated) but worth a periodic confirm that "expected-down" stays expected — Low, S, Verification

_(40 items; the remaining 10 slots intentionally unfilled — padding to 50 would create fake work.)_

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Deploy now or wait?** The IO storm is driven by _your_ workloads (two 92%-CPU llama-servers + a parallel agent session's builds). I cannot know whether that parallel work is nearly done (wait) or shoppable. If you want the switch regardless: `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` is the sanctioned override; the gate has refused it 3× with real-storm verdicts.
2. **browser-history `0971fe9c`: did you (or a session you authorized) pin it deliberately** — e.g. for a cqrs-htmx tag coupling — or is it an untracked accident? Git archaeology across ALL refs cannot find the introducing commit; if it was deliberate, my `?ref=master` conversion should be reverted to a documented pin.
3. **himalaya: remove permanently or nixify for future use?** It sat unconfigured in `~/.local/bin` for 5 months; I staged deletion (23 files) rather than adding `programs.himalaya`. If you plan to use it, I'll wire the nixpkgs package + HM module instead of trashing.

---

_Report ends. Waiting for instructions. Section (f) is the docs-health HARVEST input._
