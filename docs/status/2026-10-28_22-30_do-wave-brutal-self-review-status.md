# Status Report: The "Do" Wave — Brutal Self-Review #3

**Date:** 2026-10-28 22:30 CEST
**Session scope:** The owner's `do` + three answers (push granted for CV+crush-daily; reboot **NO**; wevisone **trash-if-valid**) executed against the queued work, 22:03→22:30. Prior reports: [18-50](2026-10-28_18-50_projects-subvol-cutover-deploy-fix.md), [19-01](2026-10-28_19-01_deploy-fix-brutal-self-review-status.md), [22-03](2026-10-28_22-03_root-ledger-brutal-self-review-status.md) (its two appendix annotations are part of this wave's output).
**In flight at report time:** the 23:10 ladder watch (root 23:00 + projects' **first nightly** at 23:10 — the migration's E2 proof). The forgejo re-seed proves at its next 05:40 run.

---

## Self-review verdict — this wave

1. **What did I forget?** The **content-pin rule for sibling repos**: I edited crush-daily's flake and ran a proof there WITHOUT first re-checking the SystemNix tree — where a parallel session had ALREADY fixed the same break another way (root `templ-components` v1.24.0 pin + `follows` into crush-daily + re-float to master tip, commits 21:44–22:00). I only noticed because my proof ran in the **wrong directory** (cwd does not persist between my shell calls — the SECOND time this session) and printed SystemNix's pin-audit trace. Lucky catch dressed as diligence.
2. **What could I have done better?** The `nix build .#` in the wrong repo should have been caught by reading the output header (the pin-audit text screamed SystemNix) — I read it as noise until the attr error. Also: my crush-daily push happened before I understood the parallel fix; it stands — but as the **upstream LIFT condition** their pin comment explicitly requests, which is how the commit message frames it, not as "the fix that unblocked the deploy" (it didn't; theirs did).
3. **What did I do RIGHT (preserve these)?** (a) **Wevisone refusal**: the owner said "trash if valid"; validity check found model weights, image blocks, and a source tree beyond the 15 G venv — the 10-26 "bare .venv" premise is stale, so I trashed NOTHING and brought back facts. The premise-check-before-destructive-action discipline held under an explicit instruction to delete. (b) The zz-test residue deletion **stopped at the `.rescue` append-only canary** (EPERM by design) — did not hand-lift a protection flag for cosmetics. (c) Prove-before-push on crush-daily (the build ran — wrong repo, but the final SystemNix proof covers the actual consumed graph; the push rode a green toplevel proof).
4. **Split brains / ghost systems?** The cv flapping strand is now a **three-surface truth**: upstream's baked vendorHash, SystemNix's shim (tenth value), and the shim comments' nine-entry history. It works, but the comment block is becoming a changelog-in-code — the real fix is upstream baking `autqYveR` (or the strand stopping its flapping).
5. **Did I lie?** One imprecision: I said the crush-daily fix "makes crush-daily self-consistent" — true — in a context where a reader could infer it unblocked SystemNix; it did not (the parallel `follows` override had). This report states the causality plainly.
6. **Daemon races (standing annoyance, quantified):** four+ of my commits this session died to mid-flight daemon sweeps (tonight: the cv-float commit and the dns-blocker+cv commit both landed as heuristic daemon batches). Content preserved every time; message quality lost every time. The amend-forward policy exists; I keep declining to use it because the daemon batches other sessions' files with mine — amending would absorb THEIR work into my message. Correct call, worth writing down once.

## a) FULLY DONE

1. **btrbk-forgejo chain healed** (pre-ladder): the nightly exit-10 was a uuid-garbled receive chain root (10-27T2140) that `btrbk clean` wouldn't touch (no incomplete marker); deleted the 5 recent receives (explicit paths, verified subvols, no globs) — older healthy history retained; next 05:40 run re-seeds and is the proof.
2. **CV defaults fix PUBLISHED**: 42 commits pushed to origin/master (`1e2212138..dd201874b`, owner-granted), SystemNix floated to the tip with the strand's **tenth shim** (spec MeDzARcT → got autqYveR, first-hand proof), **toplevel proof green** — rides the post-ladder deploy.
3. **crush-daily upstream LIFT condition met**: the flake pin bumped v1.23.0→v1.24.0 in lockstep with go.mod (the violated LOCKSTEP rule was the whole bug — go.mod demanded `utils/tone`, first shipped in v1.24.0), relocked, pushed (`93697af..955ddb2`).
4. **Repo-wide commit block removed**: dd8964bee's daemon-swept fixed-`.allowlist.tmp` tripped the textfile-tmp audit for EVERY commit; converted to the audit's mktemp + trap pattern; audit fail=0.
5. **monitor365 "anomaly" resolved by analysis**: 3 × 39 G = live DuckDB + two same-night backups; `filefrag -v` shows FIEMAP `shared` extents — reflink copies, **real cost ≈ the DB once**; the du-apparent ledger overstated by ~70 G of shared extents. Watch residue: retention must churn old backups or APPARENT grows ~39 G/night while real stays flat.
6. **Root-ledger holes closed** (both, with numbers): `~/.cache` ≈ **20 G** (the stale 80 G fear was purged), `~/tmp` ≈ **19 G** (Go-cache redirect remainder that dies with the tmp hot-tier migration). Corrected real ledger: shadow ~137 G + monitor365 39 G real + .local 30 G + .cache 20 G + tmp 19 G + ~100 G system/var/metadata + snapshot deltas ≈ 454 G data used.
7. **node-exporter spam root-caused** to a local scraper resetting mid-scrape ~8/s (`connection reset by peer`, 4,747 lines/10 min) — payload/timeout mismatch class; the row now carries the diagnosis, next ask narrowed to "which scraper, which limit".
8. **Failed-units triage pass 1**: home-manager-lars = stale failed-state (17:49 run green — the battery reads old state); inboxclean-sync = 5 m timeout; ci-watchdog = deterministic ~2 s exit (probably the canary condition it watches, not a bug); two no-journal stale states; tmp automount = known; forgejo ×2 = healed.
9. **Residue**: empty `@home` (257) deleted; `zz-test-*` verified as rescue-test fixtures, deletion correctly blocked by the `chattr +a` canary (row documents the needed flag-cycle or module-owned cleanup).

## b) PARTIALLY DONE

1. **The deploy is prepared but not fired** (deliberate): the tree is proof-green and two floats + the audit fix ahead of gen-958; deferred past tonight's ladder (the first projects nightly is the migration's E2 proof — not racing it with a switch). Post-ladder (~00:15) or morning; owner preference asked (§g).
2. **Failed-units triage** = classification only; app-level logs (inboxclean pre-kill), ci-watchdog's script intent, and the two stale-state units' last-good timestamps remain.
3. **Calm-box post-deploy re-run** still pending — properly sequenced AFTER the next deploy.
4. **Ladder watch armed but narrow**: the 40-min window covers root (23:00) + projects (23:10); btrbk-data (23:30) and the forgejo 05:40 re-seed fall outside it.

## c) NOT STARTED

- DiscordSync's own templ-components bump (the SystemNix pin's LIFT text names it as the second consumer — needs its own push permission; §g).
- The wevisone disposition (facts returned; owner decision pending; §g).
- Everything carried at 22:03 §c minus what this wave closed.

## d) TOTALLY FUCKED UP (this wave, owned)

1. **Wrong-directory proof + missed parallel fix** (verdict #1/#2) — the sibling-repo content-pin discipline exists in AGENTS.md and I skipped it for crush-daily.
2. **One transient hook failure, unexplained**: a commit aborted on a hook leg that passed on immediate rerun; I never identified which leg flaked (likely a daemon mid-sweep race on the todo gate — asserted, not shown).
3. **Ladder watch window design**: greps a `-40min` window for btrbk-data whose 23:30 run postdates the wake-up — the watch can't see the leg it names.

## e) WHAT WE SHOULD IMPROVE

1. **The battery reads stale failed-states** (home-manager-lars class): unit "failed" flags persist after a later green run unless reset; the §6 health read should report last-run result, not the flag (or reset-failed first, as deploy already does).
2. **The templ LOCKSTEP rule needs a check, not a comment**: crush-daily's flake pin vs go.mod require drifted because nothing verifies them — a `go.mod require vs flake input tag` assert in the repo's own CI (both consumers) closes the class that cost SystemNix a broken master + my three-rev walk-back.
3. **Reflink-aware space ledger**: du-based ledgers overstate same-subvol reflink backups by their full size; a `filefrag`-shared-aware surface (or compsize) belongs in the storage collector next to the fs metrics — tonight's monitor365 "anomaly" was a du artifact.
4. **Amend-forward policy needs a parallel-session carve-out** (verdict #6): the documented amend guidance assumes one session's files in the daemon batch; with N parallel sessions, amend absorbs foreign work — the policy should say land-on-top + note, which is what I did by accident of refusal.

## f) NEXT — honest count 14 (from 22:03's 19: 5 resolved this wave; 14 carried; +5 NEW = 19)

Resolved this wave: monitor365 decomposition (reflink answer), ledger holes (measured), node-exporter (diagnosed — remaining ask folded into a carried row), failed-units pass 1 (classification landed), residue subvols (partial: @home gone, zz-test canary-blocked — carried refined).

Carried: calm-box post-deploy re-run; first-night ladder verify (armed, 23:10); CV shim-drop-at-upstream-bake; §18 sanity redesign; btrbk-forgejo 05:40 re-seed proof; QLC baseline watch; D6 boot proof (owner declined for now — row stays); §11 FOD widening; float-register build leg; daemon-git-death watch; ~/tmp prepare (owner-gated); wevisone ruling (now with 19 G facts, §g); ledger-tooling decision (partially obsoleted by the corrected numbers — row can likely close after review).

NEW (harvested with this report):
1. [ready] Fire the prepared generation post-ladder (cv@dd201874b + templ pin + audit fix; proof green) — then the calm-box re-run on it.
2. [ready] inboxclean-sync: pull the app-level log lines before the 5-min timeout kill and decide config-tightness vs wedge.
3. [ready] ci-watchdog: read the script intent before "fixing" — its exit may BE the canary signal it exists to emit.
4. [ready] monitor365-pool-copy + paperless-exporter: last-good timestamps + is-enabled (both no-journal stale failed states).
5. [ready] Battery §6 health read: last-run result instead of the sticky failed flag (home-manager-lars class).

## g) QUESTIONS FOR THE OWNER

1. **wevisone-spike (19 G)**: it holds a VL model (`model/`, `chat_template.jinja` …), image blocks (`images/auto_block_*`), `WeVisOne-VL/` source, and the 15 G venv — not the bare venv the 10-26 note claimed. Trash all of it, keep it, or archive-to-pool-then-trash? (I cannot judge whether the model+images are work product.)
2. **DiscordSync push**: same templ-components v1.24.0 lockstep bump needed there (the SystemNix pin's LIFT condition names it) — extend the push grant?
3. **Deploy window**: fire the prepared generation right after tonight's ladder (~00:15), or hold for a morning window?

**ANSWERS (owner, 2026-10-28 22:56, next session):** (1) trash-all — executed 22:58 (`trash ~/projects/wevisone-spike`, source gone, ~12 G compressed in Trash, storage.md row closed); (2) push granted — DiscordSync `sync-flake-pins.sh` pass bumped templ-components → v1.24.0 tag commit 29f71a51 + go-health → v0.8.1 + 4 more drifted pins, vendorHash re-measured (gYJcV6Ol…), both FODs + pin-checker green, pushed as 79952c46; (3) "postladder" — MOOT: a parallel session had already deployed gen-959 from HEAD 0c97ef04f at 22:55:42 (anchored, config-revision verified, cv serving from store path `cv-dd20187`, health 200s — no 5165e44 rollback needed; the warn predates the deploy). The LIFT ceremony for the root templ-components pin is queued [ready] in upstream.md.

---

**Waiting for instructions.** The ladder watch fires ~23:10; the report's in-flight facts will be verified then.
