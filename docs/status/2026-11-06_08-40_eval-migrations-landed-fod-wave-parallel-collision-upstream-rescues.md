# Everything-Latest Wave — Session 2: Eval Migrations Landed, FOD Wave Split Across Two Sessions, BuildFlow + CV Upstream Rescues

**Filed:** 2026-11-06 08:40 CET · **Directive:** "fix and fucking deploy" (continuation of the 2026-11-06 06-35 everything-latest pin-lift wave) · **Point-in-time:** SystemNix HEAD `7c203affe` (all session work daemon-swept), registry still REVERTED (mid-float), a **parallel float-register proof is LIVE right now** (pid 2958148, started ~08:2x), upstream pushes: BuildFlow `a1d0c1492..ba3cd98f3`, cv `14d3cb29b..64e0e1024` — **not yet re-locked into SystemNix**.

Predecessor: `docs/status/2026-11-06_06-35_everything-latest-pin-lift-wave-status.md` (its §g questions remain UNANSWERED; the "fix and deploy" directive was taken as the answer to "proceed").

---

## a) FULLY DONE

1. **All 4 eval-blocking assertion fixes landed and PROVEN** — float-register iteration 3 (06:58, `float-proof-20261106-065851.log`) evaluated CLEAN past every assertion; the proof now dies only in the BUILD phase (FOD hashes). The eval layer of the everything-latest float is done.
2. **forgejo-runner migration (assertion 4) — researched against LIVE upstream source, not the stale 2026-10-23 plan.** The 2026-10-23 researched shape ("settings-only, no connections") is INVALID against nixpkgs 1d060086: the module now asserts `settings.server.connections != {}` plus per-connection `url`+`uuid`+exactly-one-of `token`/`token_url` (forgejo-runner.nix:153, 255). Verified the canonical flow from the module + `nixos/tests/forgejo.nix` (admin-API uuid+token pair, `replace-secret` templating). Landed shape:
   - `services.forgejo-runner.instances.${hostName}.settings = runnerSettings // { server.connections.default = { url; uuid = "@UUID@"; token = "@TOKEN@"; }; }` — placeholders only in the store copy.
   - **Identity carry**: new `forgejo-provision-runner` root ExecStartPre (`+`-prefixed) extracts the uuid+token pair the Forgejo server already knows from the legacy `/var/lib/gitea-runner/<name>/.runner` (jq) into `.uuid`/`.token` (0400, chowned to the state-dir owner) — no re-registration, no duplicate entity; fresh-host fallback = the proven `gen-runner-token` + `act_runner register` flow (deprecated but functional in v13.2, source-verified in-repo).
   - preStart renders `connection-config.yaml` from the module's configFile via `replace-secret` (the upstream-test pattern, extended to the token because ours is runtime-provisioned — a LoadCredential shape would demand the file BEFORE ExecStartPre, the 2026-10-16 tmpfs boot-failure class). ExecStart points at the rendered copy. Verified preStart ordering source-level: plain-priority ExecStartPre appends AFTER mkForce legs (list merge by priority) → gen → provision → render → daemon.
   - Full family rename: unit override, `-ensure` unit + timer + script text, `buildcache.recoveryRestartUnits`, post-deploy §21 CI canary (now checks BOTH unit names for the transition). `gitea-runner-cache` group kept with a legacy-name comment (decision row stands). Verified the negative-test sed anchor (`wantedBy = lib.mkForce [ "forgejo.service" ]`, 10-space indent) survives verbatim, and `forgejo-family-condition-audit`'s `hasPrefix "forgejo"` matcher covers the new name.
3. **crowdsec-setup wiring (assertions 1+2)** — `late-applications.target` seat (mkForce over upstream multi-user: the 2026-10-26 ordering-cycle class AND keeps the DNS-dependent hub update off the boot critical chain), `after`+`wants crowdsec-prereq` (closes an ordering hole the upstream split CREATED: without it, setup's `machines add` runs BEFORE the orphan-machine repair, and its hub update predates the DNS gate), `TimeoutStartSec = "10min"`, `ioTier.background`.
4. **`boot.initrd.verbose` removed** (Scripted stage 1 deleted upstream; option is a loadErrorAssertion now).
5. **FOD wave fully enumerated + attributed**: 47 mismatch lines → 40 unique, from the RAW log (never the console root list — it truncates at 20): 20 HaGeZi list FODs + 19 Go vendorHashes + signoz-frontend pnpm + 1 templ `source.drv` (fakeHash). Built the tool→got-hash table (`~/.cache/lockfloat/mismatch-table-0814.tsv`) and mapped EVERY tool to its consumption surface (module-side shims vs lars-packages vs upstream-baked).
6. **Unknown-FOD attribution by derivation forensics** (the method that worked): `nix derivation show` + `nix-store -q --referrers` walks identified (a) the fakeHash `source.drv` = a-h/templ v0.3.1070 fetched by **cv's own `nix/templ.nix`** (standing AAAA placeholders, deliberately probe-refreshed per wave) feeding `cv-cli`, and (b) the HaGeZi FODs = **SystemNix-owned `platforms/common/dns-blocklists.nix`** — NOT upstream dnsblockd as the prior session's summary assumed (cost: ~4 greps in the wrong repo before the referrer walk settled it).
7. **BuildFlow master RESCUED upstream** (`ba3cd98f3`, pushed): the overnight "chore(deps)" (a1d0c14, 04:56 — AFTER last night's 02:16 green) broke master's compile three ways: art-dupl `0cfc9966` dragged a-h/parse `db268905` whose API removed `parse.Parser.Match` (incompatible with EVERY released templ — 0.3.1070 AND 0.3.1100 both fail), samber-do-auditlog 0.12.2's generated code needs templ ≥ 0.3.1084, and go.mod's uncommented replace down-forced templ to v0.3.1070 while the indirect resolved 0.3.1100. Fix: revert art-dupl to `1b165cdb`, pin parse back to `74294add`, raise the templ replace → v0.3.1100; `GOWORK=off go mod tidy`; COMPILE OK; vendorHash re-probed for the CHANGED graph (`7F+fM3mx…` — the proof-log `SRdpoBO+…` was for the old, uncompilable graph); `nix build .#` GREEN.
8. **cv FOD hashes refreshed upstream** (`64e0e1024`, pushed, from a worktree at tip — the main checkout is behind 1295/ahead 5 and was left untouched): templ src `9H5X5eiB…` (SystemNix proof got), templ vendorHash `WXUlbUR+…`, cv vendorHash `aCVmXAeF…` (probe chain), `nix build .#cv` GREEN.
9. buildflow `nix-hash-fix` attempted first per doctrine — ran but DEGRADED (flake-show blocked by the mid-float gate); the documented bootstrap exception (2026-10-03) applied: hashes pasted from first-hand proof output, never invented.

## b) PARTIALLY DONE

1. **The FOD wave itself** — a PARALLEL session landed `768ac75bb` (08:22, 12 files) covering nearly the whole SystemNix-side wave while I was mid-mapping: dns-blocklists HaGeZi (18 hash swaps), lars-packages shims (I sampled 10/10 against my got-table — all match), `_signoz-packages.nix` pnpm, module shims (crm/discordsync/inboxclean/journal-serve/mr-sync/papdashboard/PMA/visionreviewd), `overlays/linux.nix` (dnsblockd go-modules). NOT yet verified by a proof — and I did NOT co-verify their files beyond the hash sampling (shared-tree discipline).
2. **SystemNix re-lock of my upstream fixes** — buildflow + cv pushes are NOT yet pulled into flake.lock (`nix flake update buildflow cv` pending). Blocked on the LIVE parallel proof (a lock edit mid-proof voids their battery — the 2026-10-25 race doctrine).
3. **float-register iteration 4** — pending the parallel proof's outcome. Expected residuals: paperless-gpt (its FODs never RAN in the 06:58 proof — masked; v0.31.0 vendorHash+npmDepsHash in `pkgs/paperless-gpt.nix` are still v0.28.0-era per the prior session), any further masked dominoes (cvagent surfaces, `meta` consumers), plus whatever the parallel session's own 07:27 proof iteration already covered.

## c) NOT STARTED

1. paperless-gpt v0.31.0 hash paste (vendorHash + npmDepsHash) — expect mismatch once unmasked.
2. The GREEN-path work: registry+lock pair commit (float-register's job), LIFT-observable verification (aw-core, linux-7.3 r8125, signoz sonic patches, dms-shell, hermes pm-* patches), darwin eval probe.
3. Deploy + anchor verify + post-deploy battery (crowdsec FIRST — unit shape changed wholesale; runner identity-carry verify per the standing watch row; `go version` == 1.27.3).
4. Docs close-out: tick TODO_LIST.md:682 + services.md:609 (runner migration) + services.md crowdsec-setup row + pipeline.md:595/564 watch rows; CHANGELOG; go-ecosystem.md/nix-flakes.md pin-policy prose; wave-completion report with self-harvest.

## d) TOTALLY FUCKED UP!

1. **I skipped the parallel-session pre-read.** The 06-45 freeze-50 report was VISIBLE as untracked at session start; I noted "not mine to touch" and moved on — the status-report-pre-read doctrine (2026-10-23) exists for exactly this. A 10-second read would have revealed the second executor; instead I burned ~30 minutes mapping a hash wave another session was landing under me, and watched dns-blocklists.nix go dirty → committed BETWEEN two of my tool calls.
2. **The `rg -r` trap hit me TWICE in one session** (`rg -rn`, then `rg -rln` hours later) — the host's most-documented flag trap, both caught by the hook, both wasting a round trip.
3. **A false "BUILD OK"** — `go build … 2>&1 | head -5 && echo "BUILD OK"` printed OK while go FAILED (head's exit code masked go's). Caught only by re-reading the output above the OK line. This is the quote-scrutiny doctrine pointed at my own verification one-liners.
4. **BuildFlow hash paste before compile** — I pasted the proof-log got-hash FIRST, then discovered master didn't compile; after the graph fix that hash was wrong anyway (re-probed to a different value). Correct order: compile-green first, hash last.
5. **Lost the daemon race on my own SystemNix commit** — four recon rounds + a skill load between my edits and the PATHSPEC commit let the daemon sweep both batches (attribution recovered via verify+amend on HEAD only; `a5f863068` keeps a heuristic message forever).

## e) WHAT WE SHOULD IMPROVE!

1. **Repo-to-repo parallelism check**: before planning ANY wave that spans repos, `ls -t docs/status/` + read visible untracked reports + `pgrep -af` for live proofs/builds of the SAME wave. Two sessions converged on one deploy tonight; only the pgrep check (before my re-lock) prevented a mid-proof lock edit.
2. **`set -o pipefail` (or PIPESTATUS) on every verification pipeline** — "would I quote this in a report?" must also gate "did it compile?".
3. **Unknown FOD → referrer-walk FIRST**: `nix derivation show` + `nix-store -q --referrers` identified both mystery FODs in minutes; name/grep archaeology sent me to the wrong repo first.
4. **Upstream fix order**: compile → graph → THEN vendorHash (graph changes invalidate hashes; pasting early is wasted work).
5. **Expect placeholder economics**: LarsArtmann repos deliberately ship AAAA/BBBB probe placeholders (cv) — a fakeHash mismatch is not always an accident; read the file's comment block before "fixing" it.

## f) NEXT — things to get done

1. Wait for the live parallel proof (pid 2958148); read its log + the 07:27 iteration's log; reconcile what's already covered.
2. Confirm with the OTHER session's output that the wave is jointly complete (do not double-fix paperless-gpt if they took it).
3. `nix flake update buildflow cv` (pull `ba3cd98f3` + `64e0e1024` into flake.lock).
4. paperless-gpt v0.31.0 vendorHash + npmDepsHash paste (probe if masked).
5. float-register iteration 4 → RED roots from RAW log only; iterate to clean build.
6. GREEN → verify the pair commit (lock + registry together).
7. LIFT observables: aw-core peewee, linux-7.3 r8125 modules, signoz patches/sonic ≥1.15, dms-shell installPhase, hermes pm-ripgrep/pm-node patchPhase.
8. `nix flake check --no-build --all-systems` (darwin eval leg).
9. `nix run .#pre-deploy-check` (19 sections).
10. PSI-gated `nix run .#deploy` — NO force past the pressure gate (2× WDT freeze evidence).
11. Deploy anchor verify by generation NUMBER (`ls /nix/var/nix/profiles/ | grep system- | sort -V | tail -1` vs `readlink /run/current-system`), after `pgrep -f 'nh os|switch-to-configuration'` is EMPTY.
12. Post-deploy battery — crowdsec FIRST (LAPI :8082, metrics :6061, acquisitions on /var/log/caddy, convergers green; unit shape changed wholesale).
13. Post-deploy: runner identity carry verify (one "carrying identity from legacy … .runner" journal line, SAME uuid online, no duplicate entity) — the standing watch row.
14. Post-deploy: `go version` == 1.27.3 from the deployed profile.
15. Post-deploy: CV status re-probe (the crash-loop question — cv re-lock rides this deploy).
16. Remove the cv worktree (`~/.cache/cv-fixwt`) after GREEN.
17. Tick TODO_LIST.md:682 + docs/todo/services.md:609 (runner migration rows).
18. Tick the services.md crowdsec-setup wiring row + pipeline.md:564/595 eval-gate/watch rows as appropriate.
19. CHANGELOG: 4 migration fixes, the parallel hash wave, BuildFlow/cv rescues, the float itself.
20. go-ecosystem.md + nix-flakes.md: root-pin-gone policy prose + the art-dupl/parse/templ incompatibility note (fleet-relevant: any repo pulling art-dupl ≥ 0cfc9966 + templ breaks).
21. Wave-completion status report with full §f self-harvest (docs-health rules).
22. Upstream candidates (verify-before-filing first): BuildFlow's own daemon landing a non-compiling deps bump despite a go-build gate (how?); art-dupl vs templ release-matrix break.
23. `gitea-runner-cache` rename-or-leave decision row: close it (left-with-comment landed).
24. Check `meta` (project-meta) consumers beyond lars-packages for the new hash's six-surface parity.
25. Watch: the OTHER session may also fire the deploy — coordinate via tree state, not assumption (whoever's proof goes GREEN last owns it).

## g) QUESTIONS (cannot figure out myself)

1. **cv re-lock scope**: my fix landed at cv tip (`64e0e1024`); SystemNix's lock holds `8594d9d` — re-locking moves cv through everything between (the main checkout is 1295 commits behind origin, so I could not cheaply audit that span). The everything-latest directive says tip; the crash-looping cv-server question (06-35 report §g.2, still unanswered) says caution. Re-lock to tip on THIS deploy, or hold cv at 8594d9d + cherry-pick the hash fix onto a branch and point the lock there?
2. **BuildFlow's templ replace**: the `replace templ => v0.3.1070` line was UNCOMMENTED — I bumped it to v0.3.1100 to un-break master (compile + nix green), but if it existed for a generator/`_templ.go` parity reason I could not see from the repo, regeneration expectations may shift on the next `templ generate`. Do you know why the downforce existed (and should BuildFlow's devshell templ CLI pin move with it)?
3. **Deploy timing + ownership** (06-35 §g.3, still unanswered, now sharper): a SECOND session is one proof iteration behind me on the same deploy. Fire the deploy the moment a proof goes GREEN (PSI-gated, auto-blocks at ~66%), or do you want to serialize: one session owns deploy + battery, the other stands down?

---

**Working-tree state at authoring time:** SystemNix clean at `7c203affe` (all my edits daemon-committed; mine amended into `6164fc7b1`). ~/projects/BuildFlow clean at `ba3cd98f3` (pushed). ~/.cache/cv-fixwt holds cv at `64e0e1024` (pushed); main cv checkout untouched (behind/ahead as found). Proof logs: `float-proof-20261106-065851.log` (mine, eval-clean/build-RED enumeration), `-072722.log` (parallel, unread), one LIVE (pid 2958148).

**Verification receipts:** iteration-3 proof log (4 assertions → 0 eval errors); upstream module + nixos-test source reads (store paths in-session); negative-test anchor grep; preStart-ordering source check (systemd-unit-options.nix:489-495); 10/10 parallel-wave hash sampling vs my got-table; BuildFlow `GOWORK=off go build` + `nix build .#` green; cv `nix build .#cv` green; both pushes confirmed on origin/master.
