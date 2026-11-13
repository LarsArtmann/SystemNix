# 2026-11-13 22:00 — W3b-resume + shape-test fix + live-skip + A1b wave: brutal self-review

Session: resumed the paused W3b/A1a handoff ~15:15 CET under the standing GO, ran to 22:00.
Companion reports: `21-45_w3b-resume-shape-test-live-skip-a1a-tree-green-status.md` (morning arc:
resume gate, shape-test diagnosis/fix, live-skip verification, row ticks) +
`22-20_a1b-four-gates-delegated-parity-green-status.md` (A1b arc). THIS report: the honest audit of
how it all went. Evidence cited inline; claims are from this session's runs only.

## a) FULLY DONE (each with its proof)

1. **Resume gate**: absorbed the parallel gen-1005 deploy (anchor by number verified, timer NEXT
   Sat 04:10, CAP_SYS_PTRACE live in the rendered unit, cvagent inactive per the standing row);
   owner §g.1/§g.2 resolved-by-events documented; deploy watcher (pid 461418) killed as redundant —
   no double-deploy fired.
2. **Shape-test 5-red-legs: root-caused + fixed + green** — evidence chain: reproduced builder
   exit 1 on the exact 5 legs; direct fixture eval showed the ONLY audit failure everywhere is
   class 7 flagging nixpkgs' 4 unbounded base oneshots (linger-users, logrotate-checkconf,
   post-boot, resolvconf) in every bare nixosSystem fixture; class-7 logic byte-equal
   old-vs-collection (928ecd774 vs 46e36b7) → delegation innocent, test red-on-arrival ~11h.
   Fix: 5min TimeoutStartSec floor in `evalAssertions` (collection contract idiom, tripwire armed).
   Both audit checks build rc=0. Committed (`c4fa20cbb`; the test file itself rode daemon
   `2ab545bf8`).
3. **Live-skip verified LIVE on gen-1005**: synthetic `comm=crush` fd-holder (copied-bash +
   run_in_background loop) skipped by name — journal `skip live-skip-verify: live crush session
   holds it open` — plus 3 REAL live sessions, touchbase fresh-write, games manual-merge all
   correct; 0 relocated; exit 0. Cleanup verified (no holder, no scratch, no hot-side residue).
4. **Pipeline gap exposed + row minted both surfaces**: no surface BUILDS `checks.*`
   (pre-commit/CI run `--no-build`; nix-check builds only VMs) AND `tests/` is missing from
   `EVAL_RELEVANT_PATHS` — that's HOW the red test sat 11h unnoticed. Row in pipeline.md +
   TODO_LIST twin.
5. **A1b wave end-to-end**: mount-gating, memory-watermark, dynamic-user, capability-grant →
   collection `176bcf9` (pushed; 4 modules + READMEs + 4 contract checks + 14/14 negative legs;
   all 4 checks probed GREEN from the pushed GitHub rev); SystemNix 4 delegation layers +
   test-mount-gating import conversion + lock bump + 2 new infra-follows overrides
   (docs-gates.nixpkgs; erraudit's go-nix-helpers.treefmt-nix — the lock-audit gate had blocked
   EVERY eval until followed). Parity: rpi3-dns **byte-identical** 1809/0; evo-x2 2686/0 with the
   +1-vs-baseline **proven** to be a foreign boot-mirror self-assertion riding the same lock move
   (pre-burst rev `73793638a` = 2685; daemon commit `38fd412f4` carried only my 6 files).
   Full `nix flake check --no-build --all-systems` **rc=0** — also clearing the morning's
   immich-blocked sweep debt.
6. **The tryEval finding**: `builtins.tryEval config.sops.secrets` on a sops-less host DIES under
   Nix 2.34 (the missing-option error escapes the seq-checked config fixpoint) — proven by the
   contract's bare-host leg + isolated repro; guard is now `options ? sops.secrets`. Also proven:
   tryEval cannot force assertion MESSAGES either (fileSystems cycle-message class) — parity
   stays total+failed.
7. **Row/report hygiene**: 4 rows ticked/annotated on BOTH surfaces (shape-test DONE ×2, plan-wave
   UPDATE ×2, storage VM-row live-proof note), 2 rows minted, 2 reports committed
   (`c4fa20cbb`, `751ecfd78` + daemon sweeps `152494412`).

## b) PARTIALLY DONE

1. **A1a+A1b are tree-green but NOT deployed** — gen-1005 predates both waves; they ride the next
   quiescent window. On that activation cvagent serve RESTARTS (the standing watch-and-stop row
   owns it; today's 15:12 report showed what 4h43m of missing that watch costs: 236G).
2. **CI verdict for collection push 176bcf9 unwatched** — I probed all 4 checks green from the
   pushed rev (stronger than a CI watch for MY files) but did not watch the workflow run to
   verdict; the 19:27 session's own rule ("watch every push's CI") slipped for the push itself.
3. **SystemNix commits not verified pushed** — `c4fa20cbb`, `32748ec4a`, `751ecfd78` et al are
   local; the daemon usually pushes, unverified at report time.
4. **The CI-gap FIX is queued, not built** — row minted; no checks-build job, no
   EVAL_RELEVANT_PATHS edit.
5. **Live-skip natural-fire unobserved** — timer fires Sat 04:10; my verification was the
   manual-restart + synthetic-holder form (the plan's prescribed shape; the natural fire would
   just re-confirm).

## c) NOT STARTED (this session's natural scope)

1. A2b/A2c option-ifications (A2a's port-registry + gatus-coverage halves were landed by the
   parallel bridge `8c108bdef` before my session — verified in the collection tree).
2. A3 (negative-test-lints re-point at the collection harness; I grep-verified no SystemNix
   negative-lint legs reference the 4 A1b gates, but did not re-run the full
   `scripts/negative-test-lints.sh` suite).
3. P1 (pool-recovery), D1, C1-C3, Y1 waves.
4. Collection FEATURES.md: the audit-modules row still counts the pre-A1b module set (my 4 gates
   not added; the 19:27 session owns that doc's cadence).
5. SystemNix CHANGELOG entry for the A-wave arc (collection CHANGELOG done; docs-health pass may
   want the SystemNix side).

## d) TOTALLY FUCKED UP (radical honesty)

1. **Masked-output recidivism, FOUR instances**: (i) first diag piped `nix eval` through a python
   parser — the eval error was swallowed and I nearly read "empty" as data; (ii)+(iii)+(iv) A1b
   probe runs through `2>/dev/null` / no-rc-capture that came back silently empty (twice for the
   count probe, once for the collection neg-log tail). Every one caught within one command — but
   the no-mask rule is WRITTEN DOWN and my first instinct kept being the anti-pattern. Worst
   personal repeat-offender class of this session.
2. **The paren bug, third strike in this wave family**: the capability-grant contract shipped
   one-paren-short (6 throwIfNot levels, 5 closers) and was caught only by `nix fmt`'s alejandra
   parse. The morning handoff documents this exact class; I re-authored it anyway.
3. **`systemctl start` on a RemainAfterExit oneshot that is `active (exited)` is a NO-OP** — I
   typed `start`, read `is-active` = active as success, and would have concluded from an empty
   journal had the status line not shown the 16:35 invocation. This class is in my own session's
   audit lore; behavior lagged canon.
4. **Three consecutive holder-spawn failures** (~6 tool calls): coreutils multicall copy
   (`unknown program 'crush'`), setsid+`&` children reaped by the tool shell, then bash's
   last-command tail-exec turning comm=crush into comm=sleep. I theorized about the guard instead
   of testing the SPAWN mechanism first; the working shape (run_in_background + exec'd named
   binary + `while/sleep` loop) took three rounds.
5. **`git add -A` in the collection staged a foreign in-flight run.sh edit** — the multi-agent
   pathspec discipline violated by reflex; caught and unstaged within one command, and my group
   insert deferred ~15 min for their edit to quiesce. The final run.sh commit deliberately carries
   both changes (attribution in the 22:20 report).
6. **Parity baseline captured ~70 min before the burst** (21:1x baseline, 22:3x after-tree) —
   an hour of parallel churn in between produced the +1 mystery and forced pre-burst-rev A/B
   forensics. Baseline-immediately-before-edit would have made parity trivial.
7. **First commit attempt died on the 72-char subject limit** (97 chars) — a documented house
   rule, costing a full hook cycle and widening the daemon-race window (a foreign commit landed
   inside it; correctly NOT amended, re-committed instead).
8. **Edit-tool mtime races ×3** (TODO_LIST ×2, test file) — all handled by fresh VIEW reads, but
   two were self-inflicted by editing off stale bash reads instead of VIEWing first.

## e) WHAT WE SHOULD IMPROVE

1. **Build the checks-build CI leg + add `tests/` to EVAL_RELEVANT_PATHS** (the minted row) —
   the systemic fix for the 11h red-window class; pure-eval negative tests currently have NO
   automated verifier anywhere.
2. **Sweep the tree for `tryEval config.` guards** — the dynamic-user finding generalizes: any
   `builtins.tryEval (<option read>)` is a latent eval bomb under Nix 2.34; the fix is always
   `options ?`. One `rg` pass converts them all.
3. **Record the lock-bump-forensics move in the delegation recipe**: a collection lock bump
   carries EVERYTHING in its range — run the pre-burst-rev assertions A/B whenever parity drifts,
   and expect new collection INPUTS (docs-gates class) to demand infra-follows overrides before
   any eval passes.
4. **A tiny spawn-holder helper script** (named binary + fd + managed lifetime) — live-probe
   verification needed it; the unit-name-resolver family keeps growing evidence for one
   `scripts/live-probe-tools.sh`.
5. **Kill the `2>/dev/null` reflex structurally** — every probe redirects to a file and echoes
   rc FIRST; consider making that the written rule in CONTRIBUTING (it is the pipe-masking rule,
   restated for eval probes).
6. **Contract-check authoring aid**: the paren-count class has now struck 3×; a contract template
   with pre-balanced chain (or `lib.pipe` form) would make it structurally impossible.

## f) NEXT (ranked; deduped against the 15:12 report's 50-list — items it already owns are marked [theirs])

1. Deploy A1a+A1b at the next quiescent window; anchor by NUMBER; cvagent watch-and-stop.
2. Post-deploy smoke + verify the 8 delegated audits behave live (units unchanged; `flake check`
   already forces the assertions).
3. Implement the checks-build CI job [minted row, mine to take].
4. Add `tests/` to `scripts/lib/eval-relevant-paths.sh` [same row].
5. `rg 'tryEval.*config\.'` sweep → `options ?` conversions + negative leg.
6. Watch the collection CI run for 176bcf9 to verdict (gap b.2).
7. Verify SystemNix local commits pushed (gap b.3).
8. A2b: option-ify stray-unit + otel-endpoint.
9. A2c: option-ify gatus-coverage/deploy-restart/script-port (fail-on-bug legs FIRST).
10. A3: re-point scripts/negative-test-lints.sh at the collection harness (or retire).
11. P1: pool-recovery extraction.
12. Re-run the FULL `scripts/negative-test-lints.sh` suite once (A1b regression proof, c.2).
13. Collection FEATURES.md + options docs for the 4 new gates [docs-gates cadence, theirs].
14. SystemNix CHANGELOG A-wave entry [docs-health, theirs].
15. `games` project manual-merge disposition (hot target exists + real dir — same class as §g.1
    below).
16. Watch crush-hot-db-migrate natural fire Sat 04:10 (journal skip-set on the real projects).
17. cvagent upstream full-scan fix [row, theirs — 236G/day cost re-proven today].
18. cvagent git-on-PATH /health fix [row 745, theirs].
19. borg tripwire + SigNoz v3 smoke fixes [rows, theirs — every deploy exits 3 until then].
20. The two shell-trap lessons from this arc (tryEval uselessness; RemainAfterExit start no-op)
    → docs/agents/nix-flakes.md + systemd.md gotcha bullets (memory-maintenance duty, not yet
    written into the agents docs).
21. Boot-mirror +1: confirm the authoring session annotates their self-assertion SystemNix-side
    (it rode my lock bump undocumented).
22. The duplicated PASS lines in the collection neg harness (foreign per-group logging) — confirm
    their session finished and the log dir cleans up on green.
23. Consider `lib.pipe` (or a balanced template) for future contract checks (e.6).
24. Holder/spawn helper script (e.4).
25. §f self-harvest check for THIS report (rows 3/4/5/20 minted or explicitly deferred — see §g).

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **monitor365-ui-sdk 21:48 stranding + today's `games` (same class)**: a populated hot-side
   target with the source dir still real → the engine refuses ("manual merge needed"). For BOTH:
   manual merge, or drop the hot-side copy and let the next run converge? (Carried from the 10:48
   §g.3; re-proven live today by the `games` skip line.)
2. **Deploy hold-vs-fire**: the tree is eval-green (full sweep rc=0) but CI's VM-test legs have
   been red all day (pre-existing, foreign-diagnosed rows). Fire the A1a+A1b deploy at the next
   quiescent window regardless (per the standing chain), or hold until the VM-leg cluster is
   diagnosed?
3. **Pressure-override semantics (carried, 15:12 §g Q1, unanswered)**: `DEPLOY_FORCE_PRESSURE=2`
   carried a deploy through a REAL-storm branch today. Should real-storm overrides require a
   fresh explicit go each time (gate split phantom/real)?

---

Scores (self-assessed): Accuracy 8.5 — every shipped claim names its run/rev; two probe lapses
caught before quoting. Fitness 8 — waves complete at the plan's own bar (contracts, legs, parity,
sweep); deploy + CI-watch gaps keep it from 9. Honesty: §d is complete to my reconstruction; the
masked-output and paren repeat-offenses are the embarrassments the next session should not
reproduce.
