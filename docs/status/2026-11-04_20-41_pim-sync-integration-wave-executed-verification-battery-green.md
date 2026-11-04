# Status: pim-sync integration wave EXECUTED — verification battery green, two-session coordinated landing

**2026-11-04 20:41 CET — session report (wave execution 20:19–20:38; no deploy run).**

**Scope line — what this session VERIFIED (fresh commands, this session):**

- Quiescence gate: watched ~40 min through float rounds 9/10/11 + a cvagent burst (`~/.cache/pimsync-int/quiescence.log`); `QUIESCENT at 2026-11-04 20:18:28` fired only after 3 consecutive clean 60 s cycles (no float/build procs, no eval-relevant mtime < 5 min, pim-sync `ahead 0`).
- Baseline eval: `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` rc=0 at HEAD `024794b75` (pre-wave).
- Lock: `nix flake lock --update-input pim-sync --refresh`; `git diff flake.lock` = **28 insertions, ONE new node** (pim-sync, rev `115328707de47f2554eab5060197e1b3763b7065`), all three follows collapsed (flake-parts / go-nix-helpers / nixpkgs; deep treefmt edge rides go-nix-helpers' shared node).
- FOD probe GREEN: throwaway temp flake replicating the exact follows rev-for-resolved-node (script `~/.cache/pimsync-int/fod-probe.sh`, log `fod-probe.log`) built `pim-sync` package → `/nix/store/9ahp75jlk…` under the pinned nixpkgs fe13242. **vendorHash valid, no overrideAttrs shim needed.**
- Wrapper module evals inside the host: targeted drvPath eval rc=0 post-input+module (new drv `3wi4jzf0…`, gate passed with the registry row present).
- **Final full toplevel proof rc=0** (`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going --no-link`, log `~/.cache/pimsync-int/final-proof.log`) on the COMPLETE tree including my `configuration.nix` entry — this supersedes the parallel session's 20:22 proof (theirs predated my last edit).
- `checks.x86_64-linux.doc-counts` builds green (145 modules; re-stamp done by the parallel session, verified by me).
- Scoped fmt: `nix fmt -- flake.nix modules/nixos/services/pim-sync.nix platforms/nixos/system/configuration.nix` → "formatted 3 files (0 changed)".
- Daemon sweeps verified by content: `git show --stat b67179833` (5 files: my flake.nix+flake.lock+tombstone + foreign FEATURES.md rider) and `3b28493b5` (9 files: registry row, module, configuration.nix 16 lines, runbook, queue ticks, README/FEATURES stamps, their status report). `pim-sync.enable = false` confirmed in HEAD `configuration.nix:857`.

**What this session did NOT verify (and why):**

- **A real deploy** — owner-gated (IO-quiet window), per doctrine. Everything is landable; the 20:29 parallel report's deploy note stands.
- **The full `nix flake check --all-systems` walk** (~4–7 min, ~20 GB RSS) — NOT run by me; delegated to the pre-commit leg on the daemon's next eval-relevant commit (the 20:29 session made the same trade with the battery + toplevel build as stand-in). If that hook leg was bypassed by a daemon filetype-keyed commit, the walk is still outstanding — see §f.
- **Runtime unit shape** — enable=false means `pim-sync.service`/`.timer` never render into the closure; the wrapper's ExecStart rendering is unexercised by design (same posture as the 20:29 report noted). An extendModules render smoke is queued (§f / self-harvest).
- **pim-sync upstream drift after lock** — the pim-sync daemon keeps committing (was `ahead 6→8` mid-session, `0` at gate time); whether origin/master moved past `115328707` since is unchecked (re-lock at deploy day covers it; runbook documents this).

**Coordination fact worth recording:** this wave needed THREE actors — my session (design→module→locks→proofs), the parallel float session (registry row + their own toplevel build proof + the doc-counts re-stamp my 145th module tripped), and the auto-commit daemon (two sweeps). The 20:29 report (`docs/status/2026-11-04_20-29_systemnix-flake-verified-pim-sync-float-registered-doc-counts-restamped.md`) is the other half of this story.

---

## a) FULLY DONE

1. Quiescence gate discipline: watcher script + 60 s polls; refused to touch eval-relevant files through float rounds 9–11 (new ceremony pids at 19:50, 20:02) and a third session's cvagent.nix burst at 20:11.
2. flake.nix input `pim-sync` (git+ssh, `?ref=refs/heads/master`, cv/crm/monitor365 pattern) + 4 follow lines in the infra-follows group + the deep treefmt-nix edge in the deep-collapse block — all three edits applied in one atomic multiedit against freshly-verified anchors.
3. Lock landed minimal: one new node, follows collapsed, no other revs moved (diff-verified).
4. FOD probe green at the locked rev **with follows active** (two script bugs found and fixed first — see §d; the corrected probe resolves lock nodes THROUGH `root.inputs` mapping and declares pim-sync's consumer follows).
5. `modules/nixos/services/pim-sync.nix` — thin wrapper (nix-email precedent): upstream import, explicit package pin (upstream option has NO default), OnFailure routing, integration entry `unit/subdomain=null/port=null/vHost.layer="none"/checks=[]/monitored=true`, unconditional catalog entry; created + `git add`ed atomically (tracked-files trap).
6. `configuration.nix` — `pim-sync.enable = false` in the dormant cluster (audible-sync/dmarc-monitor precedent) with the full DELIBERATE rationale + flip-ladder pointer.
7. `docs/services/pim-sync.md` runbook — state, flip ladder, gotchas (package pin, token rotation, kill switch, vendorHash-follows coupling).
8. Queue ticks in BOTH surfaces (`TODO_LIST.md:1887` + `docs/todo/services.md:377`) with DONE notes, no drift.
9. Plan tombstones: `EXECUTING` written at 20:20 (after patching the plan header with the `**Created:**` anchor the marker script requires), flipped to `EXECUTED` at ~20:38; both daemon-swept.
10. Verification battery: baseline eval, targeted eval, final proof, doc-counts, fmt — all green (evidence in scope line).
11. Registry row proven BEFORE its commit landed: the pair went into `3b28493b5` only after two independent rc=0 toplevel proofs (theirs 20:22–33, mine 20:35) — the "never commit an unproven float" class avoided (their earlier `1d5a549a2` 19:29 incident did not repeat).

## b) PARTIALLY DONE

1. **The float-register ceremony** — my wave created the drift; the parallel session's round-11 ran the regen + proof leg and left the registry STAGED-but-uncommitted (their daemon-race fallback path); the daemon completed the commit. Ceremony complete, but spread across three actors with a ~15-minute staged limbo window in between.
2. **Attribution hygiene** — my flake.nix/flake.lock work landed inside daemon heuristic commits (`b67179833`, `3b28493b5`) that also carry other sessions' files (FEATURES.md, README stamps, their status report). The amend-forward doctrine says properly-message them; I did NOT amend because foreign riders made the absorb-risk real. Unresolved judgment call → question (g)1.
3. **The verification battery vs the full check** — five targeted proofs green, full `nix flake check --all-systems` walk still delegated/unconfirmed (see scope line + §f).
4. **Doc-counts** — my module created the 144→145 drift; the parallel session did the re-stamp; I only verified the check green. The chronicle line in README credits "doc-counts catch" — correct, but the catch fired on THEIR ceremony commit, not on any commit of mine (my files were daemon-swept, bypassing hook legs entirely — a known blind spot).

## c) NOT STARTED

1. Deploy (owner-gated) — attaches phase-5 push mirrors for fine-tune + pim-sync AND brings the wrapper (enable=false) to the fleet.
2. Flip ladder steps 1–4 (all owner-gated): GCP OAuth client (In-production publishing) → sops values (DAV creds + client JSON + token seeds) → dry-run timer flip + journal review → live flip + maxChanges + metricsFile + Gatus freshness check.
3. Token-state backup policy: `/var/lib/pim-sync/tokens` is the only rotation-survival store post-first-refresh; no backup-coordination entry yet (deliberate — nothing runs until flip).
4. Any pim-sync upstream improvements (fail-fast assertion on enable-without-secrets; graceful zero-account no-op) — not filed upstream.
5. SigNoz dashboard/rule work for pim-sync metrics — deferred to live flip by design.

## d) TOTALLY FUCKED UP

Nothing shipped broken — the tree is green at every surface. The honest entries are near-misses where the safety net, not my process, made the difference:

1. **The FOD probe's first draft was wrong in TWO independent ways and only ONE of them failed loudly.** (a) It resolved lock nodes by input NAME (`nodes["nixpkgs"]`) — but node names in flake.lock are NOT input names; unsuffixed names belong to unfollowed consumer copies, so it read `1c89083e` (some consumer's nixpkgs) instead of the root pin `nixpkgs_6 = fe13242`. (b) It omitted pim-sync's consumer follows entirely — the probe would have validated the vendorHash against UPSTREAM's nixpkgs closure, silently. Only the missing `...` in the outputs signature (a third, trivial bug) made the run fail loudly and expose both real bugs. Had the signature been sloppier-correct, I'd have recorded a FALSE green probe in the plan's required protocol step. The catch was incidental, not designed.
2. **I came within one action of racing a live ceremony.** At ~20:22–20:24, unknown to me, the parallel session was mid-round-11 (their float-register regen'd my registry row and started a proof). My §6/§7 sequence had float-register as MY step; had I run it while theirs was live, two ceremonies would have interleaved on `expected-locks.nix` (regen + mv races). The proc check before my own ceremony found theirs and I held — again, the gate discipline saved it; my sequencing had no explicit "check for foreign ceremonies immediately before float-register" step.
3. **Staged module shipped with invalid Nix syntax** (`systemd.services.pim-sync.inherit onFailure;` — dot-path inherit). Caught by my own review before landing, but it would have failed every host eval had it slipped through, in the worst possible window (mid-ceremony).

## e) WHAT WE SHOULD IMPROVE

1. **FOD-probe discipline needs codifying**: resolve lock revs THROUGH `root.inputs.<name>` (never by node name); declare the consumer's follows in the probe flake from day one; probe script should assert the resolved nixpkgs rev equals the registry/expected root pin before building (a one-line jq check would have caught bug (a) mechanically).
2. **Promote the probe to a repo tool**: the follows-replicating probe is needed for EVERY new go-standard input (cv, crm, monitor365, quotaboard, pim-sync, next one); `scripts/fod-probe.sh <input>` parameterized, with the node-mapping + follows checks built in.
3. **Quiescence watcher v2**: watch HEAD movement (daemon sweeps change content with dirty=0) and surface foreign float-register pids as a distinct "ceremony in flight" state distinct from generic procs.
4. **Ceremony limbo guard**: float-register's daemon-race fallback accepts staged-but-uncommitted registry as success; consider a post-ceremony assert that the pair is committed within N minutes or a loud warning — the staged window is exactly when another daemon sweep could strand a half-state.
5. **Daemon-commit attribution**: decide once (owner level) whether heuristic commits carrying MY wave work get amended-forward always, or left when foreign riders are present — this session punted on the doctrine's explicit instruction (§b2).
6. **Multi-session landing cost**: an integration wave (input → follows → lock → probe → wrapper → docs → prove) has now recurred enough times (quotaboard, media-atlas, pim-sync) that a checklist/skill would remove the per-session rediscovery — propose skill-creator work.
7. **Anchor freshness**: my flake.nix anchors were read 25 minutes before editing; they survived only because that float round happened not to touch flake.nix. Re-read anchors immediately before every edit batch, always.
8. **Delegated verification needs a receipt**: "the daemon's next commit will run the full flake check" is a hope, not a verification — either run the walk before declaring done, or add a follow-up row that actually checks the hook executed (§f).

## f) 50 things we should get done next (brainstorm — owner-gated items marked 🧑; most are ROADMAP fuel, not commitments)

**pim-sync direct continuations**

1. 🧑 Deploy SystemNix (IO-quiet window) — brings the wrapper to the fleet + unblocks phase-5 mirrors.
2. Attach phase-5 push mirrors for `fine-tune` + `pim-sync` (rides that deploy; 19:14-report f#2/#3).
3. Agent: extendModules render smoke — force-enable in a throwaway eval, extract `ExecStart` + timer unit, verify rendering (queued, self-harvest).
4. Agent: re-lock/verify pim-sync rev at deploy day (runbook documents; verification step at deploy, not queued).
5. 🧑 GCP OAuth client for pim-sync, publishing mode "In production" (InboxClean 7-day-token lesson).
6. 🧑 Stalwart DAV creds (PIMSYNC_DAV_USER/PASS) → sops file (layout decision: new `pim-sync.yaml` vs existing file).
7. 🧑 Per-account browser-consent tokens → `tokenSeedDir` staging.
8. Agent (post-gates): wire sops environmentFile/secretFile/tokenSeedDir, flip `enable = true`, `live = false`.
9. 🧑 First dry-run journal review (Stalwart-single-truth §7.5 gate).
10. 🧑 GO → agent: `live = true` + `maxChanges` cap.
11. Agent: metricsFile textfile wiring (0600 service-user file → node-exporter shared-group readability, btrfs-health pattern).
12. Agent: Gatus freshness check on `pimsync_leg_last_success_unix{leg,account}` (anchored-pat doctrine).
13. Agent: backup-coordination entry or documented restore path for `/var/lib/pim-sync/tokens` (rotation-survival store).
14. 🧑 Real Twenty 139-people import via `internal/twentyimport` (already queued `blocked:user`).
15. Agent: verify catalog pim-sync entry in derived surfaces (catalog-inventory) post-deploy.
16. Agent: confirm OnFailure Discord routing shape eval-verifies against the attic/bank-sync unitConfig contract (negative-test convention — hand-probe the new unit once via extendModules).
17. 🧑 Interval policy call: 5 min vs Google rate budget at live posture (15 min?).
18. Agent: verify MemoryHigh/MemoryMax watermark coherence for the upstream unit at flip (memory-watermark-audit gate will judge it).
19. 🧑 SigNoz dashboard panel + alert rule for sync failures once metrics go live.
20. Agent: re-verify rpi3-dns + zfs-vm evals post-wave (cheap; their session verified pre-my-configuration.nix).

**Session/tooling debt from this run**

21. Agent: promote `fod-probe.sh` to `scripts/fod-probe.sh <input>` with node-mapping + follows assertions (queued, self-harvest).
22. Agent: document the lock-node-name gotcha (resolve via `root.inputs`) in `docs/agents/nix-flakes.md` (queued, self-harvest).
23. Agent: run or confirm the full `nix flake check --all-systems` walk happened on a daemon hook (delegation receipt).
24. 🧑 Decide daemon-commit attribution policy: amend-forward vs leave-with-riders (question g1).
25. Agent: quiescence-watcher v2 (HEAD-movement + foreign-ceremony detection) — small script hardening.
26. Agent: ceremony limbo guard (post-ceremony commit assertion) — float-register.sh hardening.
27. Agent: integrate the wave checklist into a skill (skill-creator; input→follows→lock→probe→wrapper→docs→prove).
28. Agent: gitignore or tmpfiles rule for `tasks.db.readmodel.db.fold-lock` runtime artifact (owner of the writer process unidentified — needs one `lsof` session).
29. Agent: clean `~/.cache/pimsync-int/fod-probe` (holds a committed flake.lock copy; harmless, tidy).
30. Agent: cross-link plan ↔ runbook (runbook links the plan; plan should link the runbook).

**Noticed in passing, unrelated to this wave — verify before queueing**

31. Eval warnings backlog (per 20:29 report, deliberately untouched): catalog integration-subdomains without catalog entries; caddy ghost subdomain `llama`; ZFS deprecation pair on zfs-vm.
32. 🧑 The deploy that carries this wave also owes the 19:14-report f#2/#3 items — bundle-check on deploy day.
33. `nix flake check` skip-leg for eval-irrelevant diffs (2026-11-03 doctrine) — confirm my docs-only sweeps correctly skipped (they did; the eval-relevant sweeps ran the check legs — spot-verify one daemon commit's hook log).
34. 🧑 pim-sync upstream: file the fail-fast assertion idea (enable=true with null secretFile → throw at activation) upstream-first per doctrine.
35. 🧑 pim-sync upstream: graceful zero-account idle no-op (discoverAccounts returns empty) — upstream feature request.
36. Agent: after the next prune pass, expect WARN-count rise from my two `[x]` ticks (2026-10-25 prune class) — recount into the drift row.
37. Agent: verify queue-row/library-row no-drift after the daemon's next docs sweep (my DONE notes are new surfaces).
38. 🧑 Fold the flip ladder into a one-glance flip-card in the runbook when step 1 lands (media-atlas pattern).
39. Agent: evaluate whether pim-sync needs an integration-registry otel/log fan-out entry at flip (conventions check).
40. 🧑 Twenty-import provenance audit post-import (row 375's follow-up, unchanged).

**Standing backlog touched by this session (no new work, pointers only)**

41. Catalog integration-subdomain warnings (T-0265/T-0519) — pre-existing.
42. ZFS kernel-policy decisions — pre-existing.
43. Deploy-script float-register instant-exit expectation — verify on deploy day (20:29 report's own follow-up).
44. Eval-cache SQLite contention ("busy" warnings during parallel builds) — 20:29 report note; run heavy evals sequentially.
45. pim-sync docs/status/README in the upstream repo — its §3 "SystemNix host half" item can be closed once this wave's deploy lands (upstream-side bookkeeping).
46. Phase-5 mirror verification AFTER the deploy (mirror lag/health checks).
47. 🧑 Owner confirmation that `pim-sync` Forgejo-canonical + GitHub-twin topology stays (no re-canonicalization pending).
48. Agent: dry-run `scripts/prune-done-todos.sh` on the next harvest pass (my ticks feed it).
49. Agent: consider `sops-presence pre-deploy gate` generalization (§19-style) so the enabled-without-secrets class is structurally impossible for future services.
50. 🧑 The flip ladder's step-3 Gatus check needs the anchored-pat reviewed against the actual metrics card emitted by pim-sync (label set verification at flip time).

**Self-harvest record (per the status-report discipline):** direct follow-ups QUEUED at authoring time — #3 (extendModules render smoke) → TODO_LIST.md + docs/todo/services.md; #21 (fod-probe tool promotion) → TODO_LIST.md + docs/todo/pipeline.md; #22 (nix-flakes doc gotcha) → TODO_LIST.md + docs/todo/pipeline.md. #4 deliberately NOT queued (documented in the runbook's flip ladder + deploy-day protocol). #23–#30 deliberately NOT queued as individual rows: they are process decisions or verifications belonging to THIS report's reader (§e) — harvesting them as rows would duplicate §e; #31–#50 are pre-existing backlog or ROADMAP fuel per the HARVEST anti-patterns.

## g) Questions I cannot figure out myself

1. **Daemon-commit attribution policy:** `b67179833` + `3b28493b5` carry my wave content under heuristic messages, plus foreign riders (FEATURES.md, their status report). Amend-forward (doctrine) would rewrite unpushed history that includes other sessions' work; leaving them keeps anonymous heuristic messages on a landing this significant. Which do you want — amend both into properly-messaged commits now, or leave and let the wave report carry attribution?
2. **Deploy bundling:** should the pim-sync wrapper ride the NEXT IO-quiet deploy (which also attaches the fine-tune/pim-sync phase-5 mirrors), or do you want a dedicated quiet window just for this wave? I cannot know your IO calendar or whether you want mirror-attachment and a new (inert) service in the same activation.
3. **OAuth client topology for the flip:** reuse the InboxClean GCP project (second OAuth client, same project, shared billing/audit surface) or a fresh dedicated project for pim-sync? This decides the sops file layout and the blast radius of a revoked client, and only you know the project hygiene you want.
