# nixos-module-collection W1+W2 landed, deploy pending — session status (owner-interrupt report)

**Created:** 2026-11-12 18:26 CET
**Session:** continuation of the 2026-11-11 00:47 plan-execution instance (owner GO: "execute the whole list"; resumed 2026-11-12 ~15:20 with a continue directive; interrupted 18:26 for this report)
**Plan:** `docs/planning/2026-11-10_05-07_SUPERB-nixos-module-collection-extraction.md` (EXECUTING marker live)
**Prior report:** `docs/status/2026-11-12_14-11_nixos-module-collection-pilot-w1-execution-status.md`

---

## a) FULLY DONE (verified this session)

1. **Resume recon + parallel-session diff-review** — collection HEAD had moved `0a8d973 → 229f441` (a parallel session's buildflow/pma pass: dprint.json, SECURITY.md, .gitignore, full reformat churn incl. flake.nix restyle + a nixpkgs float). Reviewed the full diff: semantic-preserving. My formatter split-brain hypothesis (dprint vs treefmt) was DISPROVEN by the arbiter itself — `nix fmt` in the collection reports "0 changed" (its pinned alejandra is a newer version whose style legitimately differs — the 2026-10-14 lesson, not a split brain). watch.sh reformat = indentation-only (spaces→tabs), and SystemNix's lock pin `0a8d9731` is unaffected.
2. **W1b tail 1 — watch-script content identity PROVEN at both levels**: source-level `git show` byte-diff of the script at baseline rev vs collection rev = identical; build-level `diff -r` of both wrapped trees = exactly 2 changed lines (bash shebang hash + PATH hashes of the SAME package versions — iproute2-7.2.0/gnugrep-3.12/coreutils-9.12, pure nixpkgs-float rehash). All 164 lines of watch logic identical.
3. **W1b tail 2 — SystemNix delegated VM test GREEN**: `nix build .#checks.x86_64-linux.wifi-failover.test` rc=0 (311s VM run; drives the delegation wrapper with real inputs incl. gateway feed + registry entry).
4. **W1b tail 3 — post-delegation sweep**: full `nix flake check --no-build --all-systems` GREEN ("all checks passed", ran ~15:26–15:45). Caveat in §e: a parallel session's lock surgery landed 15:45–15:48, so this check's coverage of the FINAL tree state is timing-ambiguous; later evo-x2 drv evals were green but the full battery was not re-run (§b).
5. **W1b tail 4 — old script deleted**: `git rm scripts/wifi-failover-watch.sh`; straggler grep clean (runbook + router.md pointers updated; only TODO rows and historical reports reference it).
6. **W1b tail 5 — docs**: runbook header owning-module line (`docs/services/wifi-failover.md`), router.md pin-pointer, CHANGELOG W1 entry (SystemNix), collection CHANGELOG created with the W1 pilot entry.
7. **W2a — boot-mirror extracted to the collection** (`9deac01`, pushed): `modules/boot-mirror/{default.nix,README.md}` with the full option surface (device nullOr+assertion, mountPoint, sourceEsp, fsType, mountOptions; unit names unchanged for fleet audits); eval-contract check (`tests/boot-mirror.nix` — fixture host forces the full merge; module's self-assertions + a hardcoded contract chain); collection `nix flake check --no-build --all-systems` GREEN; probe-before-lock GREEN from GitHub (`nix build github:…/9deac014#checks.x86_64-linux.boot-mirror-contract`).
8. **W2b — SystemNix boot-mirror delegation**: `platforms/nixos/system/boot-mirror.nix` rewritten as the layer (enable + Samsung device fact + guarded system-health entry; activate script + flake app + pre-reboot-check §11 stay SystemNix-side BY DESIGN); lock bumped `0a8d9731 → 9deac014`; evo-x2 toplevel eval GREEN under delegation.
9. **W2b — PARITY PROVEN (same-lock baseline captured pre-edit)**: path unit + all boot/mirror fileSystems entries **semantically identical** (store-hash-stripped diff); service differs ONLY in the two description strings (deliberate de-Samsung-ification for the public module — documented in CHANGELOG); build-level `diff -r` of the sync script trees = comment-only deltas + same-version runtimeInputs rehash — **zero executable-line changes**.
10. **Negative-test migration**: collection harness `tests/negative/run.sh` (copy-mutate-prove method ported; 5 legs incl. green control — **5/5 PASS**, after fixing one no-op sed from an indentation mismatch); SystemNix `scripts/negative-test-lints.sh` bootmirror legs retired with a redirect note (the phantom-leg class documented: sed mutations must trip the CHECK's hardcoded expectations, not a self-referential assertion rendered from the same expression); iotier tier-stripped leg retargeted boot-mirror-sync → `bank-sync-storage-dir` (**2/2 PASS**); host-eval selftest `boot-mirror-path-trigger` KEPT as the lock-side pin — GREEN through the delegation.
11. **X0 — collection-delegation recipe** landed in `docs/agents/integration-registry.md` (7 steps: positional-lib convention, untracked-files-invisible trap, same-lock baselines + store-hash-strip diffing, build-level script-tree diff, negative-leg travel + phantom-leg class, probe-before-lock, layer shape incl. the options?-guard lesson; reference impls named).
12. All W1-tail + W2 SystemNix changes are COMMITTED (daemon commits `b9af54019`, `5306984d3`, `7a8817a08`, `a1699cba2`, `ed7feb6f8` — my pathspec commit attempts were blocked by the standing TODO-gate hard-fail, expected; the daemon is the sanctioned path). SystemNix tree is CLEAN as of 18:26. Collection HEAD `dec6f36` (one staged chmod on run.sh awaiting sweep).

## b) PARTIALLY DONE

1. **W1b-6/W2 deploy — window found but deploy NOT FIRED**: the quiescence poll (4×60s clean + green drv eval `gc5a863x`) completed QUIESCENT at ~17:07 — but I was heads-down in W3 module design and did not loop back to the completed background job before the owner interrupt. THEN a further parallel wave landed (`ed7feb6f8`: CHANGELOG + a 526-line flake.lock churn — another lock surgery) AFTER the poll window, so that specific green probe is stale anyway: the deploy needs a fresh poll + fresh eval at execution time (the deploy's own gates + §11 battery own that). Live host still runs the pre-delegation generation (verified: the live wifi-failover-watch PID uses the baseline store path `vr2gjw86…`).
2. **W3a — designed, not written**: all four hot-tier sources read (crush-hot-db.nix only through line ~200 of 311 — the migrate script tail + timer unit unread); design settled: `modules/hot-tier/` (plain-mount family generalizing journal-hot + caddy-logs-hot: attrsOf {device, subvol, mountOptions, tmpfiles owner/mode, service wiring, *Directory= neutralization + ownership-heal ExecStartPre}) + `modules/hot-dir-migrate/` (the crush-hot-db engine generalized: dirName/matchComm/projectsDir/mountPoint/user/unitName); **hot-user-caches deliberately stays SystemNix** (its disko cross-guard + fleet cache defaults ARE the fleet; W3b's delegation list is ×3). Zero collection files written yet.
3. **Full flake check on the FINAL tree** (post `ed7feb6f8` lock surgery + W2) not re-run — see §e.

## c) NOT STARTED

- W3 collection modules + VM-test ports (journal-hot, caddy-logs-hot, crush-hot-db×2 test files)
- W3b delegation layers ×3 (journal-hot.nix, caddy-logs-hot.nix, crush-hot-db.nix → layers) + parity + re-lock
- A0 negative-harness generalization; A1 (8 pure audit gates); A2 (6 coupled option-ify); A3 audit close-out
- P1 pool-recovery; D1 dual-wan retire; C1 collection CI matrix; C2 options.json docs; C3 search site; Y1 close-out pack
- TODO rows for this session's follow-ups (see §f harvest note)

## d) TOTALLY FUCKED UP

Nothing destructive shipped. The honest near-misses:

1. **The missed deploy window** — the session's core operational gate (activate W1+W2 on the live host) sat READY and I let it idle while writing W3. No damage (the host is stable on the old generation), but the wave is "landed-not-live" because I failed to watch a background job I myself started. This is the exact "background job completes silently" trap.
2. **Pipe-masked verdicts, twice, same class, same hour**: `nix build … | tail -5; echo rc=$?` reported rc=0 on a FAILED build (the contract check's `cp: cannot stat ''`) and again on the syntax-error rebuild. I noted the trap after the first hit and re-committed it minutes later. Both caught by follow-up runs before any claim rode them; the false "CONTRACT-GREEN" echo never entered a report or commit.
3. **Test-file syntax fumble**: `tests/boot-mirror.nix` took 3 build iterations (missing `;`, paren miscount, `passAsFile` on a null) — sloppy first writes in a language with no cheap pre-commit parse check in my loop.

## e) WHAT WE SHOULD IMPROVE (session lessons — candidates for lessons/AGENTS)

1. **Chain the action INTO the gate script**: a quiescence poll whose whole purpose is to authorize a deploy should end with the deploy (or at minimum a loud marker + immediate follow-up check). "Start it in background and continue" only works if the completed job reliably wakes the dependent action.
2. **`rc=$?` after a pipe is tail's rc, not the command's** — banked mid-session and then violated again. Standing form: no pipe on verdict commands, or `PIPESTATUS[0]`.
3. **Re-run the full `nix flake check --no-build --all-systems` after ANY foreign lock surgery that lands mid-session** — cheap insurance; my W1 sweep is timing-ambiguous against the 15:45/15:48 lock commits and the 18:xx `ed7feb6f8` wave.
4. **The standing TODO-gate hard-fail taxes every wave** (blocked pathspec commits, daemon-dependence, daemon-fragmented commits across 5 heuristic commits for one logical change). The queued triage row owns the scanner fix; this session's friction is another argument for escalating it.
5. **Parallel-storm reality**: three separate foreign waves landed on this tree during the session (collection reformat pass, nixpkgs-unpin/hermes-re-pin surgery, final 526-line lock churn). Parity baselines MUST be captured immediately before their edit and re-validated if a lock wave lands in between (my W2 baseline survived by luck — the float rehash was strip-diffed away; the discipline is the store-hash-strip + semantic diff, which held).

## f) NEXT (execution order; 22 items)

1. **[ready] Fire the W1+W2 deploy at the next fresh quiescent window** — re-poll (4×60s + fresh drv eval), `nix run .#deploy`, anchor by generation NUMBER, passive smoke: `journalctl -u wifi-failover` + `boot-mirror-sync` markers. THIS IS THE WAVE'S LIVE GATE.
2. **[ready] Post-`ed7feb6f8` full sweep**: `nix flake check --no-build --all-systems` (tee to `~/.cache/fc-*.log`) before the deploy builds.
3. **[ready] W3a: finish reading crush-hot-db.nix (lines 200–311)** then write collection `modules/hot-tier/` (mount family).
4. **[ready] W3a: port test-journal-hot.nix + test-caddy-logs-hot.nix** to drive the collection module (collection checks).
5. **[ready] W3a: write collection `modules/hot-dir-migrate/`** (crush-hot-db engine; options incl. unitName to preserve `crush-hot-db-migrate`).
6. **[ready] W3a: port crush-hot-db tests** (test-crush-hot-db, test-hot-db-assertions; check test-hot-db.nix overlap) collection-side.
7. **[ready] W3a: push + probe-before-lock; negative legs for both modules in tests/negative/run.sh** (mutation cases: wants-not-requires drop, Directory-neutralization drop, liveness-guard strip).
8. **[ready] W3b: delegation ×3** (journal-hot.nix, caddy-logs-hot.nix, crush-hot-db.nix → layers feeding options; same-lock parity baselines BEFORE edits; fstab render parity included).
9. **[ready] W3b: hot-tier migrate scripts decision** — migrate-journal-hot.sh / migrate-caddy-logs-hot.sh stay SystemNix (one-time, already-run fleet migrations; document in layer headers).
10. **[ready] W3b: deploy + anchor + smoke** (journal/caddy ordering edges are boot-relevant — pre-reboot-check §11 owns the boot-mirror leg; no reboot planned).
11. **[ready] A0: generalize tests/negative/run.sh** (per-module case groups; wire into collection CI later via C1).
12. **[ready] A1a: move the 4 simplest pure audit gates** (systemd-shape, start-limit, timeout, tmp-cleaner) + selftests; SystemNix imports from collection.
13. **[ready] A1b: move mount-gating, memory-watermark, dynamic-user, capability-grant**; rpi3-dns eval green too.
14. **[ready] A1c: delete originals, wire collection imports in host assembly, full check both repos.**
15. **[ready] A2a-c: option-ify the 6 coupled gates** (port-registry ← ports.nix feed; stray-unit allowlist; otel-endpoint expectations; gatus-coverage, deploy-restart, script-port) — each with a fail-on-bug negative leg FIRST.
16. **[ready] A3: re-point/retire scripts/negative-test-lints.sh legs for moved gates; CI negative-tests.yml both repos; full sweep ×2 repos.**
17. **[ready] P1: pool-recovery extraction + delegation** (options: pool devices, restartUnits set).
18. **[decision→default RETIRE] D1: dual-wan** — awaiting owner ruling (§g.2): git rm module + scripts (the wifi-failover assertion's `or false` shape already tolerates the absent option tree).
19. **[ready] C1: collection CI** (F6 eval-matrix over stable+unstable via --override-input; full check on pinned lock; aarch64 eval leg; negative-harness job).
20. **[ready] C2: options.json + per-module README example snippets wired into checks** (F9: nixosOptionsDoc; warningsAreErrors as description lint).
21. **[ready] C3: NuschtOS/search static options site on GitHub Pages** (optional at ≥5 modules — we will have 4-5 post-W3; decide then).
22. **[ready] Y1: close-out pack** — CHANGELOG both repos, runbook headers, TODO ticks + WARN recount (prune-done-todos.sh dry-run-first), plan EXECUTED flip via plan-marker.sh, tick the two W1/W2 queue rows + library entries (already-harvested rows from the 14:11 report now partially superseded by this report's items — update, don't duplicate).

Harvest note: items 1–22 above ARE this report's §f self-harvest; they land in `TODO_LIST.md` + `docs/todo/upstream.md` as rows citing this report (the standing gate hard-fail means they ride the daemon sweep — same as the 14:11 report's rows did). NOT separately harvested: the d) near-miss narratives (session-internal, no dispatch value) and e) lessons 1–3 (behavioral, already encoded in this report; lesson 4 is the existing queued triage row; lesson 5 is now in the X0 recipe).

## g) OWNER QUESTIONS (cannot figure out myself)

1. **Deploy GO/hold under the live storm**: three foreign waves landed on the tree during this session (collection reformat pass, nixpkgs-unpin + hermes re-pin surgery, latest a 526-line lock churn at ~17:xx). The W1+W2 deploy will necessarily ride whatever the tree carries at its window (currently also including a parallel session's nixpkgs float + hermes re-pin — their own proofs, not mine). Fire at the next fresh quiescent window (my default), or hold until the storm drains?
2. **D1 dual-wan ruling**: plan default is RETIRE (`git rm modules/nixos/services/dual-wan.nix` + its scripts; git history preserves recoverability). Alternative: extract to the collection as standby-reference. I default RETIRE — confirm?
3. **TODO-gate triage priority**: the standing pre-commit hard-fail (~86 drift rows + 37 unharvested reports + timegate trips) blocked both my manual commits this session and fragments every wave into daemon heuristic commits. The queued [ready] row owns the scanner-side fix. Escalate it to the NEXT dispatch (before A-wave — it will bite ~10 more times otherwise), or keep it queued behind the module-collection waves?
