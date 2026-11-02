# Lock-Float Unblock: 11 FOD Shims, 4 Rev-Pins, Toplevel Green (2026-11-02 03:16–05:35 session)

**Scope:** single Crush session, SystemNix repo only. Trigger: owner asked "Still?" / "Now?" about the `overview` vendorHash shim (overlays/linux.nix). Discovery: the 03:16 + 04:12 blanket lock-float waves (9ff1d1645, 3709f06b0) had landed **unproven** (daemon sweeps — the float ceremony's prove-then-commit ordering was violated by daemon batching), leaving the toplevel RED with 11 FOD hash mismatches + 3 upstream compile breaks + 1 toolchain floor. Session ended with proof rc=0, lock+registry committed together, gate green.

**Timeline:** 04:32 first keep-going enumeration (11 mismatches) → 04:44–04:50 shim re-pins/drops/pins (7 files) → 04:50 proof RED (2 survivors: tq + pma, old specs from MISSED service-module mirrors) → 04:52 mirrors fixed → 05:22 proof RED (1 survivor: library-policy compile break — FOD fix unmasked it) → 05:22 library-policy rev-pinned → 05:26 proof **rc=0, zero mismatches** → 05:27 daemon landed lock+registry pair, float-register verified content.

---

## a) FULLY DONE

1. **Overview shim question answered twice, evidence-first.** At lock `1c467991` (pre-float): shim load-bearing (upstream baked `NQ0ICMtk…`, true hash `QweKquKP…`). After the float to `ef901296`: got == upstream-baked (`p91o0rkP…`) → **shim DROPPED** per the drop condition, first-hand.
2. **One-pass failure enumeration** (Critical Rule: `--keep-going` first): 04:32 log enumerated all 11 stale FODs + surfaced upstream breakage classes.
3. **9 shim re-pins with RE-STALE records** (every value first-hand from the enumeration, never hand-copied): go-humanize-linter `v6zJv2bV`, golangci-lint-auto-configure `Uvi1KtDo`, journal `1JuET6kA` (THREE sites: lars-packages + journal-serve + journal-backup), project-meta `CejG7L+`, pma `tR/Y9ul` (TWO sites), tq `wtkejgEG` (TWO sites), crm `J9L/KEVb`, cv `bPvMOBEz` (TWELFTH RE-STALE).
4. **2 bit-neutral drops**: overview (got == baked), crush-daily (upstream `85b1d7a1` bakes the shim's own `iPis8A3A…`, verified by reading upstream `vendorHash.nix` at the locked rev).
5. **1 bootstrap shim added**: emeet-pixyd `WONlox/C` — upstream `612e42fa` ships a raw `sha256-AAAA…` placeholder (probe mandatory, documented exception).
6. **4 upstream-broken inputs REV-PINNED** to last build-proven revs, each with a flake.nix comment + `lib/flake-input-pin-audit.nix` row (prose + concrete LIFT observable):
   - `project-discovery-daemon` → `145cd73d` (upstream `983928ff`: `server.go:1061` references non-existent `godmn.ReadNotifyCounters` — half-wired refactor).
   - `vision-review-agent` → `8cbb0ec9` (upstream `5f6cbbed`: go.mod demands go ≥ 1.27.3; our pinned nixpkgs fe13242 ships 1.27.2 under GOTOOLCHAIN=local).
   - `monitor365` → `10d25291` (upstream `31ea3b7b`: wasm-bindgen 0.2.129→0.2.130 bump without re-pasting the tarball hash in nix/tools.nix; spec `gtEruUDi`, got `lofzu1Ubn`).
   - `library-policy` → `f3651092` (upstream `beb8d9ed`: vendored go-health-dashboard `InstanceID` became a struct, call site not updated — status.go:309 fails to compile). Shim value restored to the f3651092-proven `UtUhdbS9` ("tracks the LOCKED rev", cv.nix precedent).
7. **4 inputs re-locked** onto their pinned revs (`nix flake update <input>` ×4, revs verified in flake.lock).
8. **Proof GREEN**: run 3 (`float-proof-20261102-052603.log`) rc=0, zero hash mismatches, all previously-failed FODs and units realized.
9. **Lock+registry committed together** (7ad49750d via daemon during the proof; float-register's daemon-race fallback verified content: `regen_body == registry_rows && git diff --quiet`).
10. **Gate green**: `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` resolves (was throwing the lock-float audit at session start).
11. **Race forensics**: pinned down the two daemon commits mid-race (6b8e19210 = bank-sync.nix only, other session; e13b9d0a0 = my flake.lock + pin-audit sweep); tq hash history single-flip (no clobber — the "old spec" proof failures were the missed mirrors, not a lost edit).
12. **Monitor365 fix-state established**: the wasm-bindgen hash paste (`lofzu1Ubn…`) already sits in `~/projects/monitor365` (37 commits ahead of origin, unpushed, in-flight session) — the pin is the correct consumer posture until that lands.

## b) PARTIALLY DONE

1. **Upstream-side fixes for the 4 pinned inputs: 0 of 4 pushed.** Monitor365's is pasted-but-unpushed (not mine to push); pdd/visionreviewd/library-policy fixes not started upstream. The pins hold; LIFT conditions documented.
2. **Shim-class documentation**: drops landed, but the `fleetVendorHashShims` class comment (overlays/linux.nix) still frames itself as the "2026-10-15 fleet wave" block; the lars-packages class comment similarly accretes history. Minor polish, not blocking.
3. **TODO self-harvest**: being done at authoring time (see §f harvest markers + TODO_LIST.md rows added this session).
4. **The got-hash paste ritual upstream** for the new wave values (cv/crm/journal/golangci/go-humanize-linter/project-meta/pma/tq/emeet-pixyd): the existing upstream.md `blocked:push` row covers the 10-29 trio; this session's nine new values extend it — row updated this session.

## c) NOT STARTED

1. **Darwin-host proof** — `mkLarsPackages` feeds both hosts and the re-pinned shim values are shared; only evo-x2 was proven (nix flake check skips aarch64-darwin by default, so nothing forces it).
2. **Deploy of the proven toplevel** — rides the shared deploy window (the parallel session has an armed pressure/quiescence watcher for its opencloud+bank-sync fixes; my tree changes ride the same gen bump). Not requested, not fired.
3. **TODO-gate backlog remediation** — 161 unharvested §f status reports make `check-todo-system` fail EVERY pre-commit; float-register's own commit leg failed on it this session (daemon fallback saved the audit-log invariant, but that is luck-shaped). Queued, not run.
4. **Pin-lift probes** — all four LIFT conditions require upstream action first; no probes run (nothing to probe yet).
5. **Bit-neutral shim detection** — a lint that flags "shim value == upstream-baked at locked rev" (crush-daily rode stale for days before today's drop) was identified as an idea, not built.

## d) TOTALLY FUCKED UP

1. **Shipped a wrong intermediate claim to the owner**: after proof run 1 I reported "overview/crush-daily did NOT fail" — based on a `head`-truncated grep that missed the overview mismatch at log line 398. The overview FOD HAD failed with the exact got hash that decided the whole session's question. Caught two tool calls later by dumping all error blocks, but a wrong evidence claim was asserted first. Textbook violation of "the number/claim must survive one known-value check before it enters a report."
2. **Missed the pma service-module mirror that I WAS LOOKING AT**: my own edit to `lib/lars-packages.nix` preserved (and re-worded!) the comment "The service module (modules/nixos/services/projects-management-automation.nix) carries the same value" — and I did not edit that file. Cost: one full wasted proof cycle (~10 min), a RED ceremony that reverted registry rows, and churn. The `tq-agent-pool.nix` mirror I had never inventoried at all.
3. **Incomplete surface inventory before the fix wave**: my "full shim inventory" pass covered only `lib/lars-packages.nix` + `overlays/linux.nix`. A single repo-wide `rg 'vendorHash\s*='` at inventory time would have surfaced ALL live surfaces (including the two mirrors) in one call and saved the cycle. This is the root cause of §d.2.
4. **rg flag hygiene**: hit the `-rn` replace-display trap TWICE in one session (the hook's third-strike warning names this host). Typo-level, but each occurrence blocked a tool call and one produced a mangled-intent command in the transcript.
5. **Broken prefetch URL** for monitor365 `10d25291` (mangled rev concatenation) silently degraded into a diff that proved nothing — a wasted call masked as a check.

Nothing data-destroying: no reverts of others' work, no force-push, no deploy, no history rewrite. All §d items were self-caught and corrected within the session; the final state is proven green.

## e) WHAT WE SHOULD IMPROVE

1. **Surface-map BEFORE the fix wave**: one repo-wide live-`vendorHash` grep is step zero of any shim wave. The multi-surface rule ("edit ALL THREE/SURFACES") is documented per-row but there is no mechanical inventory step.
2. **Untruncated error extraction**: `rg -c` count first, then full `-A2` blocks; `head` is never the only view of a failure list. Today's wrong claim came exactly from treating a truncated grep as the complete set.
3. **Pre-read the domain doc**: AGENTS.md routing says read `docs/agents/nix-flakes.md` before Nix/lock/FOD work; I reconstructed the shim/drop/pin protocols from inline file comments (worked, but slower and riskier than the canonical doc).
4. **Upstream-compile precheck before re-pinning a shim to a got hash**: library-policy's FOD fix unmasked a compile break (one wasted cycle). When a sibling checkout exists, a quick upstream health probe (compile at the new rev) before the shim round would fold both cycles into one.
5. **"Other SURFACE?" before "eval bug?" theories**: when an eval result contradicts known file content, the first hypothesis should be an undiscovered consumer surface, not nix caching/race theories — I burned four tool calls on the wrong branch of that fork.
6. **Check `.crush/crush.db` for concurrent sessions** before racing shared surfaces (registries, flake.lock): I did /proc + pgrep checks, but the DB query is the documented attribution tool and would have shown the other session's ceremony in flight earlier.
7. **float-register as the only proof path**: manual keep-going runs are fine for enumeration, but the ceremony manages registry state; running both today created the "no drift then RED then drift again" noise.
8. **roots-extraction head-limit in float-register**: the script prints only the first 20 matching lines; today's 12-root wave overflowed it and forced manual log greps. Small script fix (full table or file pointer per class).

## f) NEXT TASKS (from this session's observations only)

Harvest status per item: **[HARVESTED]** rows landed in TODO_LIST.md + domain library this session; **[NOT HARVESTED: reason]** recorded inline.

1. [HARVESTED → upstream.md, watch] **Lift the four rev-pins when upstream heals** — monitor365 (drop pin when the 37-commit stack with the `lofzu1Ubn` paste lands on origin/master), pdd (when `godmn.ReadNotifyCounters` compiles again), vision-review-agent (when go.mod fits go 1.27.2, or the fe13242 nixpkgs pin lifts), library-policy (when the go-health-dashboard InstanceID change is propagated). Every lift: drop pin + audit row, re-lock, re-probe the shim value ("tracks the LOCKED rev"), re-run the toplevel proof.
2. [HARVESTED → upstream.md, ready] **Add the repo-wide live-`vendorHash` surface inventory as step zero of the shim protocol** (would have saved today's wasted cycle; nix-flakes.md drop-protocol section + class comments).
3. [HARVESTED → pipeline.md, ready] **Clear the 161-report TODO-gate backlog** — `check-todo-system` fails every pre-commit and blocked float-register's own commit leg today.
4. [HARVESTED → pipeline.md, ready] **float-register roots extraction: stop head-limiting** (full table; today's 12-root wave overflowed the 20-line print).
5. [HARVESTED → pipeline.md, decision] **Bit-neutral shim lint**: flag any shim whose value equals upstream's baked hash at the locked rev (crush-daily rode neutral for days).
6. [HARVESTED → upstream.md, blocked:push] **Bake the 2026-11-02 got hashes upstream** (extends the existing 10-29 trio row): cv@aa878d2 `bPvMOBEz`, kith-crm@900bf55f `J9L/KEVb`, journal@3542a958 `1JuET6kA`, golangci-lint-auto-configure@f4df57a6 `Uvi1KtDo`, go-humanize-linter@8ac99125 `v6zJv2bV`, project-meta@17dbf3d0 `CejG7L+`, pma@fde1c413 `tR/Y9ul`, go-taskqueue@0e1679dd `wtkejgEG`, emeet-pixyd@612e42fa `WONlox/C`.
7. [NOT HARVESTED: owner-gated] **Push authorization for ~/projects/monitor365's unpushed 37-commit stack** (contains the tools.nix fix) — owner call, in-flight session's work. → see §g.1.
8. [NOT HARVESTED: owner-gated] **Deploy the proven toplevel** — rides the shared window with the parallel session's armed watcher. → see §g.2.
9. [NOT HARVESTED: another session owns it] **nh `stc test` UNANCHORED + opencloud 9100→9500 deploy** — already queued by the deploy session (TODO_LIST tail); my tree changes ride their next deploy.
10. Darwin-host eval/proof of the re-pinned shim set (mkLarsPackages feeds darwin; nothing forces it today) — [NOT HARVESTED: low priority, no failing signal; fold into the next flake-check pass].
11. Update `docs/agents/nix-flakes.md` drop-protocol with today's two lessons (surface inventory step; untruncated extraction) — [NOT HARVESTED: duplicates queue rows 2/3 above until executed; the rows own it].
12. gotchas-archive.md entry for the "unproven float via daemon sweep" incident (03:16/04:12 waves violated commit-together; gate caught it at eval) — [NOT HARVESTED: owner convention decision — status report vs gotchas entry].
13. Process gap: daemon sweeps of IN-FLIGHT ceremonies break float-register's commit-together invariant (happened twice today: wave-1 registry landed unproven at 04:12, and the script's own commit was hook-blocked) — consider daemon exclusion or lock-fingerprint pre-commit for flake.lock+registry pairs — [NOT HARVESTED: needs owner directive on daemon config].
14. Overview/crush-daily drops: watch the NEXT float for re-stale (overview's drop is correct at THIS rev; its goPkg-pinned build can re-diverge) — [NOT HARVESTED: the next float's keep-going proof IS the probe; no separate action].
15. pdd sibling checkout +21 commits unpushed, vision-review-agent +41 — attribution/ownership unknown (who is mid-work there?) — [NOT HARVESTED: → §g.1-style owner question, folded into it].
16. go-health-dashboard: the InstanceID struct change that broke library-policy is itself an upstream API break worth an issue in THAT repo — [NOT HARVESTED: cross-repo, owner-gated push; fold into the upstream paste ritual when authorized].
17. emeet-pixyd had NO shim before today and its upstream ships AAAA placeholders — candidate for the paste-upstream ritual too — [NOT HARVESTED: covered by queue row 6's ritual once authorized].
18. The four audit rows make `nix flake update` silently no-op for those inputs (intended) — consider a nightly "pin health probe" (upstream-compile check per pin) — [NOT HARVESTED: → §g.2 owner preference on automation].
19. lars-packages.nix class comment + overlays fleetVendorHashShims comment still reference stale wave framing — [NOT HARVESTED: cosmetic, self-heals on the next edit].
20. Pre-commit hook bypass reality: the daemon commits (and today's hook-blocked script commit) mean the TODO gate does not actually gate anything on the green path — [NOT HARVESTED: same root as item 3; fixing the backlog restores the gate's meaning].

(20 items enumerated; the list is deliberately bounded to what THIS session observed — no speculative roadmap items.)

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **May I push `~/projects/monitor365`'s unpushed 37-commit stack** (contains the wasm-bindgen `lofzu1Ubn` paste that lifts the monitor365 pin)? It is not my session's work; the float-register unpushed-hints explicitly warn against re-locking into in-flight churn, and pushing someone's mid-flight branch without knowing its completeness is exactly the 2026-10-11 trap. Who owns that stack and is it push-complete?
2. **Deploy the proven toplevel now, or hold for the shared window?** The tree is proof-green (05:26), but the parallel deploy session has an armed pressure/quiescence watcher for its opencloud bind-race + bank-sync TimeoutStartSec fixes — my changes would ride the same gen bump. Do you want me to fire a deploy (or their watcher) once the tree is quiet, or wait for their session to land first?
3. **The TODO gate is failing on 161 unharvested §f reports and now blocks float-register's own commit leg on every green proof.** Do you want a docs-health harvest pass over the backlog NOW (my next task), or is a harvest session already planned/owned elsewhere — and if the backlog is expected to persist, should float-register opt out of the TODO leg for lock+registry pairs so the audit-log commit never depends on the daemon fallback?

---

## Evidence appendix

| Surface | Old → New | Proof |
| --- | --- | --- |
| overview shim | `QweKquKP` (load-bearing at 1c467991) → **DROPPED** (got `p91o0rkP` == upstream-baked at ef901296) | float-proof-20261102-043225-lars.log L398 |
| crush-daily shim | `iPis8A3A` → **DROPPED** (upstream 85b1d7a1 bakes same) | store-prefetch of upstream vendorHash.nix |
| go-humanize-linter | `k7GyCaMU` → `v6zJv2bV` | 043225 log L129-131 |
| golangci-lint-auto-configure | `6rIzqRAD` → `Uvi1KtDo` | 043225 log |
| journal (×3) | `OzU6YCvB` → `1JuET6kA` | 043225 log |
| project-meta | `+rbh2A6r` → `CejG7L+` | 043225 log |
| pma (×2) | `uTanAcTC` → `tR/Y9ul` | 043225 log + 045044 log |
| tq (×2) | `4zISVNEX` → `wtkejgEG` | 043225 log + 045044 log |
| crm | `LpMsryrv` → `J9L/KEVb` | 043225 log |
| cv (12th re-stale) | `g1hKglo` → `bPvMOBEz` | 043225 log |
| emeet-pixyd | none → `WONlox/C` (upstream AAAA placeholder) | 043225 log |
| pdd pin | float `983928ff` → pinned `145cd73d` | 043225 log compile error |
| vision-review-agent pin | float `5f6cbbed` → pinned `8cbb0ec9` | 043225 log go-floor error |
| monitor365 pin | float `31ea3b7b` → pinned `10d25291` | 043225 log wasm-bindgen mismatch |
| library-policy pin | float `beb8d9ed` → pinned `f3651092` (shim back to `UtUhdbS9`) | 052231 log compile error |

Final proof: `~/.cache/lockfloat/float-proof-20261102-052603.log` — rc=0, 0 hash mismatches. Gate: toplevel drvPath resolves. Lock+registry: committed together (7ad49750d), float-register content-verified.

## Self-harvest record

- Queue rows added to TODO_LIST.md this session: 4-pin lift watch, surface-inventory step, TODO-gate backlog, float-register roots fix, bit-neutral lint (§f items 1–5).
- Domain-library rows added: docs/todo/upstream.md (items 1, 2, 6), docs/todo/pipeline.md (items 3, 4, 5).
- All other §f items carry explicit NOT-HARVESTED reasons inline (owner-gated / another-session-owned / cosmetic / covered by the next proof).
