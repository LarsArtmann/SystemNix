# Evening Continuation — Overlay Lift, A/B Verdicts, Eval-Relevance Gaps (2026-11-10 ~21:11)

**Session:** this conversation's evening arc, 20:1x–21:2x CET, under the owner directive "execute and verify until done", closed by the report-and-wait directive. Continues `docs/status/2026-11-10_19-44_float-wave-morning-repair-and-post-rollback-verification-status.md` (whose §h addendum this session wrote and landed).

**Scope line — what this report VERIFIED (with the command/artifact), and what it did NOT:**

| Verified | How |
| --- | --- |
| Root lock revs: nixpkgs `f9a75f41`, dnsblockd `696c73e8`; `1d060086` node serves only `crm`'s unfollowed input | `jq '.nodes[.root].inputs…' < flake.lock` + orphan-cross-reference |
| nixos-unstable tip still `f4a03c00` (20:1x) | `git ls-remote https://github.com/NixOS/nixpkgs refs/heads/nixos-unstable` |
| Bare taskchampion builds green without the overlay | `nix build github:NixOS/nixpkgs/f9a75f41…#taskchampion-sync-server` → `ah978vnf…-0.7.1` (log `~/.cache/lockfloat/taskchampion-lift-probe-20261110.log`) |
| Post-lift toplevel evals green at the pinned nixpkgs | `nix eval --raw …toplevel.drvPath` → `0a4zbvhy…20261105.f9a75f4.drv` (log `~/.cache/lift-eval-gate.log`) |
| Bank-sync shim correct + matching prod | tree eval outPath `ahrazciz…4b0be19c…` == deployed gen-997 unit ExecStart (read from `/nix/store/3yhv8kp…/etc/systemd/system/bank-sync.service:23`); upstream `flake.nix` at `4b0be19c:452` still bakes `iJg1bJqr`; `git diff --stat 40c1feb 4b0be19c` = 6 `.go` files only; HM mirror `systems/evo-x2.nix:79-81` carries the same `65/NbAtF` override |
| Backup timers scheduled, never fired | `busctl get-property …Timer NextElapseUSecRealtime LastTriggerUSec` + `Unit ActiveState` → 2026-11-11 ~03:29 / ~03:58, `0`, both `active` |
| Bank-Sync healthy | metrics scrape `127.0.0.1:8097/metrics` (script `~/.cache/systemnix-probe/banksync-metrics.sh`) → `sync_total 10`, `errors_total 0`, `consecutive_failures{wise} 0` |
| Daemon attribution of the 19:44 surfaces | `git show --stat 8d7079712` (pathspec commit, proper message, carried report + both rows) |
| `systems/` eval-relevance gap | `rg -n "systems/" flake.nix` (:1660 "assembled in systems/*.nix", :1665 `import ./systems/darwin.nix`) vs `rg -c systems scripts/lib/eval-relevant-paths.sh` (0 matches) |

| NOT verified | Why |
| --- | --- |
| No deploy of tonight's commits | agent shells cannot switch (sudo dead); deploys are owner/sudo-gated; gen-997 (`3yhv8kp…f9a75f4`) still live as of 21:0x, no deploy process running |
| Timers' actual first firing | clock-gated (03:29/03:58 tonight); queued for AM |
| Darwin-side eval after the lift | `nix eval` was evo-x2-only; risk assessed structural (the lift strictly REMOVES `prev.taskchampion-sync-server` references — cannot add an attr access), not re-run |
| Full `nix flake check --all-systems` post-lift | hook skipped it on the LIFT commit (the eval-relevance gap, since fixed); only the toplevel eval ran |
| `bank_sync_sync_sustained_failure` gauge direct read | probe's `head -10` cut the line; `0` is implied by `errors_total 0` + `consecutive_failures 0`, not directly observed |
| Sibling `blocked:deploy` row's exact text in `docs/todo/services.md` | known only from their commit message `e4c785e5e`; foreign in-flight file, not opened |
| The 84 DRIFT + 20 UNHARVESTED WARN baseline rows | gate output only; not triaged (pre-existing, queued) |

---

## a) FULLY DONE

1. **Session content-pin + state verification** — HEAD/tree/newest-reports/deploy-process snapshot before every mutation; caught 3 sibling HEAD moves (`8d7079712` → `41afb72b3` → `94dc35c33` → `e4c785e5e`) mid-session.
2. **Daemon-sweep attribution audit** — the 19:44 report + both re-float queue rows landed properly attributed in `8d7079712` (a sibling's pathspec commit with an accurate message naming all carried surfaces). No footless-commit repair needed.
3. **Lock-archaeology false alarm resolved (root-cause: my own misread)** — direct `.nodes.nixpkgs.locked.rev` returned `1d060086` and looked like lock↔registry drift; root-resolution proved no drift (root = `f9a75f41`, matching registry + deployed stamp), and the `1d060086` node is `crm`'s private unfollowed input. Full chain documented in §d.1.
4. **Re-float gate evidence refreshed** — tip still `f4a03c00`; the nixpkgs+dnsblockd pair remains blocked upstream (§g Q3 unchanged).
5. **`taskchampionPkgConfigOverlay` LIFTED** — the overlay's self-removal contract met: bare probe green (`ah978vnf…-0.7.1`), overlay definition + list entry removed, post-lift toplevel eval green, pipeline row updated with re-add instructions. Commit `645032159` (+9/−21, overlays/linux.nix + docs/todo/pipeline.md).
6. **Eval-relevance gap #1 fixed (`overlays/`)** — the pre-commit hook had skipped the flake-check leg on the LIFT commit (classified `overlays/linux.nix` eval-irrelevant); the shared `EVAL_RELEVANT_PATHS` array (pre-commit eval-skip + deploy quiescence heat-check consumers) gained `overlays`; AGENTS.md heat-check prose updated. Commit `632cfb1e3` (+8/−1).
7. **Eval-relevance gap #2 fixed (`systems/`)** — found while writing this report: host assemblies live in `systems/*.nix` (flake.nix :1660/:1665) but the array never listed the directory, while a sibling's `systems/evo-x2.nix` edit was literally in flight. Array + AGENTS.md prose updated. Commit in flight at report time (blocked by a sibling's malformed queue row — see §d.7); if still uncommitted, the working-tree change is present and the daemon sweeps it.
8. **Bank-sync vendorHash shim A/B: GREEN (the "never run" gap, now run end-to-end)** — upstream `4b0be19c` still bakes stale `iJg1bJqr` (shim REQUIRED), hash-relevant files unchanged since the shim's reference rev, deployed ExecStart binary = tree-eval outPath, AND the HM mirror surface (`programs.bank-sync`) carries the identical `65/NbAtF` override (verified after nearly mis-filing a split-brain finding — §d.6). Shim, lock, NIXOS surface, HM surface, tree, and prod all agree.
9. **Bank-Sync live state refreshed (§g Q1 evidence)** — errors 0 (was 1 at 19:44), wise consecutive failures 0, 10 green cycles; the SCA challenge no longer surfaces in counters.
10. **Backup timers verified scheduled** — both ACTIVE, first elapse 2026-11-11 ~03:29/~03:58 CET, `LastTriggerUSec` 0; AM first-fire verification queued in TODO_LIST with the deploy-before-fire dependency and a gate-compliant ` — BLOCKED:` marker (commit `6e79583b3`).
11. **Report lineage maintained** — §h addendum written into the 19-44 report and landed; this report closes the arc.

## b) PARTIALLY DONE

1. **Overlay lift + CAP_DAC_READ_SEARCH backup fix: committed, NOT deployed** — gen-997 still runs the pre-lift, pre-cap-fix units. Until a deploy lands, tonight's first scheduled backup fire repeats the empty-write, and the lifted overlay simply doesn't apply yet (no harm — the pin's module ships pkg-config anyway).
2. **Eval-relevance array coverage: 2 gaps found and fixed, completeness not PROVEN** — `overlays/` and `systems/` are closed, but the audit was informal (flake.nix read + consumers grepped), not an exhaustive derivation of every path that can move a drv (e.g. `docs/` readFile consumers like the buildcache entry, `hosts/`-style future dirs). A systematic derivation pass is queued (§f.9).
3. **First-fire verification: queued, not run** — clock + deploy gated (TODO_LIST row, `[ready]` + ` — BLOCKED:` marker).
4. **Bank-Sync §g Q1: evidence says healthy, ceremony question still open** — metrics can't distinguish "SCA challenge permanently resolved" from "challenge window not yet re-triggered"; owner answer still authoritative.
5. **Backup-fire queue pairing: mine (TODO_LIST `[ready]`+marker) vs sibling's (services.md `[blocked:deploy]`)** — both exist (correct queue↔library pairing) but with different tags; also their commit message cites elapse "03:20/03:50" vs my measured "03:29/03:58" (likely OnCalendar+RandomizedDelaySec — unreconciled).
6. **This report itself: uncommitted at write time** — per the status-report skill's harness rule (Crush forbids unprompted commits → daemon sweeps). The `systems/` fix rides a background retry because the shared TODO gate is currently FAILED by a sibling's row (§d.7).

## c) NOT STARTED

1. nixpkgs+dnsblockd coherent-pair re-float (tip-gated, queued row unchanged).
2. patchelf mis-routing upstream filing (owner appetite, §g Q3).
3. The 7 baseline smoke FAIL triage (§g Q2 — Health Hub 503, Offsite Borg tripwire, crm-server CPU, tq-agent-pool CPU, node-exporter journal rate, Bank-Sync counter, storm-suspect).
4. pipewire `services.pipewire.jack.enable` deprecation (eval warning observed twice tonight, predates session).
5. Caddy dns-local ghost subdomains `nsfw` + `llama` (eval warning, no vHost, no registry entry).
6. Formal `nix flake check --all-systems` re-run on the lifted tree (only toplevel evo-x2 eval ran).
7. `crm`'s private nixpkgs node at `1d060086` (Nov 3) — intent unestablished (§g Q3-adjacent).
8. Adoption of the shared array as §11's tree-stamp source in `vendor-freshness.sh` (existing queued row — §11's inline list already covers overlays+systems manually).
9. The 84 queue/library DRIFT WARNs + 20 UNHARVESTED §f reports (gate-hardness decision queued; harvest pass belongs to docs-health).
10. The offline-banner sibling arc's own closeout (their files, their report).

## d) TOTALLY FUCKED UP

1. **The lock-node misread rabbit hole (~5 tool calls, ~15 min on a phantom)** — I read `.nodes.nixpkgs.locked.rev` directly, got `1d060086` (Nov 3), and spent five evidence commands investigating "lock↔registry drift" and even a suspected nixpkgs DOWNGRADE — while the 19-32 deploy report (which I had read an hour earlier, and which my own session summary cited!) states the rule in bold: root-referenced node moved to `nixpkgs_8`, resolve via `.nodes[.root].inputs.nixpkgs`, never a remembered node name. The one jq line would have settled it. Contributing cause: the 19:44 session's own "registry↔lock in sync" claim was made (or at least summarized) without root-resolution, so the stale summary amplified the phantom.
2. **`rg -rn` — the third strike of a triple-documented trap** — typed `rg -rn "EVAL_RELEVANT_PATHS"` mid-session; the hook blocked it (it is a replace-expression, not recursive-search). AGENTS.md documents this exact trap as having corrupted two prior sessions, and I have read that paragraph three times. Inexcusable; only the hook saved the output from being silently mangled.
3. **My queue row violated the repo's own TODO gate** — I wrote the first-fire row as `[ready]` with clock language ("after ~04:05") but no ` — BLOCKED:` marker, which is the documented 2026-10-04 early-harvest class. The gate FAILED my docs commit AND my unrelated predicate commit (the gate reads the working tree, so one malformed row blocks every commit in the tree). One wasted commit cycle + the fix.
4. **Commit subject 73 chars vs the 72 house limit** — my docs commit was rejected post-hooks on the first attempt. Trivial, but it means I didn't check a rule I already knew.
5. **Blind index.lock retry** — after the first `Unable to create '.git/index.lock'` failure I retried immediately WITHOUT checking for a live holder; the second failure was identical. Only then did I `pgrep` and find the sibling's live commit (PID 531132). The check should have been first. Two burned cycles.
6. **Near-miss: a false split-brain finding** — my first view of `systems/evo-x2.nix` truncated at line 71 ("If a shim is ever…") and I nearly filed "HM surface missing the bank-sync mirror" as a §d finding in this very report. The mirror exists three lines below (`:79-81`, same `65/NbAtF` override). Caught because the report-writing discipline forced a second look; a lesson in not filing findings from truncated reads.
7. **Shared-tree gate coupling, lived from the receiving end** — at report time MY `systems/` fix commit is blocked by a DIFFERENT session's malformed `[ready]` row ("Codify the git-trap pair from tonight's commit races…", staged with the 21-04 doc-wave report, no ` — BLOCKED:` marker). The gate's working-tree-global scope means any session's mistake freezes all commits. Not my row — but the third time tonight the gate/index.lock serialization cost cycles; the coupling needs a design decision (§f.27).
8. **(Inherited, surfaced tonight) the 19:44 "no drift" verification claim** — my earlier session reported "registry↔lock in sync" without the root-resolution step; had tonight's question been "is the tree still coherent?", that claim would have been taken on faith and was not re-derivable from its stated method. Verification claims must name their command.

## e) WHAT WE SHOULD IMPROVE

1. **Root-resolve EVERY lock read** — `jq '.nodes[.root].inputs.<name> as $k | .nodes[$k].locked.rev'` is the only honest form. Promote from the 19-32 report into `docs/agents/nix-flakes.md` (and AGENTS.md if it fits) so the rule survives outside one report.
2. **Draft queue rows against the gate checklist, not the muse** — `[ready]` + any time-word (tonight/tomorrow/clock) ⇒ must carry ` — BLOCKED:`. One-line pre-commit habit would have saved two of tonight's failures.
3. **index.lock protocol: holder-check FIRST** — `pgrep -af 'git commit'` before any retry; wait-loop only after confirming a live holder. Codify in `docs/CONTRIBUTING.md` daemon-race section (it already covers daemon races; add the human-race variant).
4. **Subject-length check before committing** — 72 chars; count it.
5. **Manual toplevel eval after ANY eval-surface commit whenever the hook skips the check** — tonight the skip was itself a bug; even with the array fixed, the skip-leg will always trail reality. The 10-second eval is the backstop.
6. **Fix classifier FPs in the gate, not at call sites** — the sibling's "tonight's commit races" row is retrospective language misread as time-gating (the same doctrine as the dead-guard-lint fix). Small `check-todo-system.sh` tweak + selftest case.
7. **Handoff summaries must carry root-resolved revs and the exact verification commands** — tonight's starting summary said "held at f9a75f41" while its own provenance method was unsound; the summary's stale/unsound claims cost real investigation time.
8. **Truncated reads never become findings** — a view that cuts mid-comment gets re-issued with a wider window before any conclusion is written (§d.6 nearly shipped a ghost).
9. **Queue-row tag reconciliation when a pairing spans sessions** — pick ONE tag convention for the same underlying work ([ready]+marker vs [blocked:deploy]) at pairing time, or the drift checker will keep narrating the mismatch.

## f) NEXT (up to 50 — session-scoped brainstorm; most are ROADMAP fuel, harvest with docs-health routing rigor)

**Tonight/tomorrow (time-critical):**
1. Deploy `e4c785e5e` (CAP_DAC_READ_SEARCH backup fix) + the overlay lift before 03:29 CET — else tonight's first scheduled backup fire repeats the green-but-empty write. (sudo-gated.)
2. AM: verify first scheduled backup firings (`timesheets-backup` + `invoices-dashboard-backup`, journalctl + artifacts + quick_check) — queued row.
3. Reconcile the elapse-time discrepancy (sibling "03:20/03:50" vs measured 03:29/03:58 — read the OnCalendar/RandomizedDelaySec spec once).
4. Reconcile the two backup-verification rows' tags (mine `[ready]`+marker vs sibling's `[blocked:deploy]`) into one convention.
5. Land/verify the `systems/` eval-relevance commit if the gate cleared (it was blocked at report time — §d.7).

**This session's direct follow-ups:**
6. Systematic derivation of the eval-relevant path set (prove the array complete instead of iteratively discovering gaps: walk flake.nix's imports/transfers to closure).
7. Add a selftest leg asserting `EVAL_RELEVANT_PATHS` covers every directory flake.nix imports (`systems/` regressed silently for months).
8. Consider the `docs/` readFile class: `lib/buildcache-cache-names.nix` parses `scripts/lib/buildcache-reap-names.sh` — are there OTHER readFile/parse consumers outside the array?
9. Adopt `scripts/lib/eval-relevant-paths.sh` as §11's tree-stamp source (existing queued row; §11's inline list now duplicates three entries — drift risk).
10. Wire `test-precommit-eval-skip.sh` (or a sibling) to fail when a flake-imported directory is missing from the array (fixture: touch a file in each imported dir).
11. Check the pre-commit hook's staged-eval-relevance pathspec covers `git diff --cached` renames into eval-relevant dirs (the array gates by path — rename detection semantics unverified).
12. Make the TODO gate's cross-session coupling survivable: scope the hard-FAIL legs to staged rows (or fail loud but name the owning file/session) — one session's malformed row froze the whole tree tonight (§d.7).
13. `check-todo-system.sh`: stop flagging retrospective time-language ("tonight's commit races") as time-gating — classifier FP fix + case.
14. After the gate clears, verify the sibling's staged TODO edits (their git-trap codification row is genuinely good — from tonight's races, which this session also hit) pair with a library entry.
15. Probe whether `crm`'s private nixpkgs node (`1d060086`, Nov 3, unfollowed from root) is deliberate or a stale accident (§g Q3-adjacent).
16. Prune `nixpkgs_9` (`3ec63636`) orphan node from flake.lock at the next legitimate lock rewrite (inert; documented in the 19-32 report).

**Owner-gated (from the 19-44 report §g, evidence refreshed tonight):**
17. Bank-Sync: is the SCA question closed (metrics now clean), or do you still want the `bank-sync sca approve` ceremony?
18. Triage order (or indefinite acceptance) for the 7 baseline smoke FAILs.
19. Re-float timing for the nixpkgs+dnsblockd pair when tip moves past `f4a03c00` (+ patchelf upstream filing appetite).
20. Deploy window for tonight's commits (cap fix is time-sensitive — see #1).

**Pre-existing queued arcs this session re-confirmed live (no new work, just adjacency):**
21. go-humanize-linter vendorHash re-stale (queued; the bank-sync A/B tonight is the template for its probe).
22. patchelf stage-gate row (pipeline.md:1096-1098 — the PROGRESS entries landed tonight via `8d7079712`).
23. journal-import auto-sync post-deploy battery (blocked:deploy).
24. cvagent dashboard deploy + live battery (owner go).
25. CV push wave (blocked:push, 20 commits ahead).
26. llama-embeddings stranding recovery (sibling-queued tonight).
27. rpi3 (.151) down — LAN DNS failed over to evo-x2 (blocked:user).
28. TODO-gate hardness decision (84 DRIFT WARNs; strict-mode currently fails).
29. Harvest pass for the 20 unharvested §f reports (docs-health HARVEST mode).
30. tq agent-pool lease extension (>45-min dispatches die).
31. Standing eval-drift probe: lock vs registry (~60 inputs drifted invisibly once; tonight's root-node confusion is the same disease one level down).
32. Per-commit footer verification habit (queued row; tonight's three gate-races reinforce it).
33. pipewire jack deprecation cleanup.
34. Caddy ghost subdomains `nsfw`/`llama` (vHost⇒registry reconciliation — the rpi3-dns inertness row is adjacent).
35. `/data/docker` volumes-only tar + trash (disposition decided; sudo execution pending).
36. quotaboard CI workflow.
37. buildcatrust upstream filing + rpi3 confirmation probe.
38. netbird multi-host parameterization (rpi3 next).
39. 192.168.1.16 rogue-DHCP identification.
40. hermes tracing approach decision (fork vs patch queue vs upstream).
41. fastflowlm alert-firing verification during the Oct 29 loop.
42. Guard stateDir persistence audit for the three epoch/count files.
43. CV login-loop test pinning + stored-logins signal.
44. Email forwarding verify (applications@ artmann.tech → larsartmann.cloud, corrected tonight by a sibling).

**Roadmap-fuel (explicitly NOT commitments — from §e + §d):**
45. Codify the holder-check-first index.lock protocol in CONTRIBUTING.
46. Codify root-resolution as THE lock-read form in nix-flakes.md (+ AGENTS.md if it fits).
47. Gate-compliant row-drafting micro-checklist into CONTRIBUTING (tag × time-language × marker matrix).
48. Stub-report convention for interrupted sessions (queued twice already — dedupe).
49. "Truncated read ≠ finding" micro-rule: re-issue any view that cuts mid-comment before writing a conclusion.
50. Consider a queue-row lint MODE that only hard-fails on the STAGED diff (today's coupling), leaving repo-wide WARNs advisory — decision row material.

## g) QUESTIONS FOR THE OWNER (cannot self-answer)

1. **Deploy tonight or accept one empty fire?** The CAP_DAC_READ_SEARCH backup fix (`e4c785e5e`) and the overlay lift are committed but gen-997 still runs. Do you want a deploy before ~03:29 CET so tonight's first scheduled backup firings run the fixed units, or do you accept one more empty write and the AM re-verify after a morning deploy? (Agent shells cannot switch; I can't know your deploy plans.)
2. **Is Bank-Sync's SCA question closed?** Counters are clean (0 errors, 10 green cycles) — do you treat the challenge as resolved (no ceremony), or do you still want to run `bank-sync sca approve` to close it durably before the next challenge window?
3. **`crm`'s private nixpkgs node at `1d060086` (Nov 3) while the root pins `f9a75f41`** — deliberate (crm validated against that base) or an accident to align on the next crm pin wave? The pin-audit documents crm's own rev-pin as deliberate but is silent about its unfollowed nixpkgs; intent isn't derivable from the repo.
