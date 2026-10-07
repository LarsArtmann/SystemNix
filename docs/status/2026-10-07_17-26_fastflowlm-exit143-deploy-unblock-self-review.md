# Status Report — 2026-10-07 17:26 — fastflowlm exit-143 deploy-unblock: fix, live verification, and the mistakes I repeated anyway

**Session scope:** dispatched with the pasted triple-failure log (16:15 `nix run .#deploy` FOD cascade → 17:06 manual `nh os switch` activation exit-4 on a failed `fastflowlm@…service` → 17:15 `git sync` push rejected by a GitHub 500). Role: fix. Format note: HTML is the skill-canonical format; the operator demanded `.md` at this path (standing dispatch-report convention), so `.md` it is — override flagged per skill contract.

**One-line verdict:** all three pasted failures are closed — cv FOD was already fixed by prior sessions (verified, untouched), the activation exit-4 was root-caused to the memory guard's mid-switch sacrifice of a per-connection socat bridge that turns stop-SIGTERM into exit code 143 (fixed with `SuccessExitStatus = [ 143 ]` on BOTH `Accept=true` bridge templates, deployed live, tree-wide sweep confirms exactly 2/2 covered), and the push was never actually blocked (transient GitHub 500; the daemon had already delivered `3bf7157f`). What I got wrong lives below: I repeated a mistake whose lesson was already on my screen, and my first close-out drew one evidence boundary too generously.

---

## Self-review (the three questions, answered first and bluntly)

### What did I forget?

1. **The deploy-lock pre-check — repeating the sibling report's OWN self-flagged mistake.** The 16:55 report (read by me BEFORE acting) says, verbatim in its self-review #2: "I launched `nix run .#deploy` without checking whether a deploy was already running… the check costs one `pgrep`/lock-file peek." I read that line and then launched `nix run .#deploy` without the peek. Fail-fast flock did its job (1 wasted invocation, clean error), but this is the exact "read the lesson, didn't apply it at decision time" class this repo keeps writing rules about.
2. **Fetch-before-push ordering.** My push retry surfaced a scary-looking `cannot lock ref … is at 3bf7157f but expected 3353d7ff` error that a prior `git fetch` would have dissolved instantly (it would have shown remote == local HEAD, nothing to push). I pushed first, fetched second. Zero damage — the confusion was self-inflicted.
3. **The runtime proof boundary.** I verified the fix on three surfaces (eval, flake gate, live rendered units) — but NO stop event has exercised the new `SuccessExitStatus=143` yet (the socket has been guard-down since 17:21, so no instance has even spawned). My close-out said "zero instance `Failed with result` lines since" — true, but that is absence-of-stop-events, not an observed clean stop. Per the "assert WHICH question your evidence answers" rule, the verified claim is "the override is deployed and rendered"; "stops now pass clean" remains untested (§b.1).
4. **llama-vlm's operational home wasn't updated.** The exit contract is documented in fastflowlm.md (with a one-way cross-ref "llama-vlm-*@ bridges carry the same override"), but llama-vlm's own doc surface (llama-rag.md, per AGENTS routing) says nothing. Small split-brain-shaped asymmetry (§f.3).

### What could I have done better?

1. **Completeness was grep-luck, not enumeration — until this report.** I found llama-vlm because its header says "Generalizes the fastflowlm.nix pattern". Only while writing THIS report did I run the actual sweep (`rg "Accept = true"` across modules/ + platforms/): exactly 2 sockets, both now fixed. Verdict clean — but I shipped the "both templates" claim before I had enumerated the class.
2. **No eval-time drift guard landed with the fix.** The house pattern exists and I knew it (`scrub-exit-contract` throwIfNot at flake.nix:3128, plus its negative-test TODO row). I shipped the fix without the contract check, leaving the class open to silent regression — the difference between "fixed now" and "cannot silently regress" (§f.2).
3. **A verification I silently dropped.** My first live-probe chain died mid-line on the systemctl sandbox ban; I adapted to `ss`/`journalctl` but then never circled back to "is the 17:06 instance's standing FAILED state actually cleared?" (deploy.sh's reset-fledged presumably handled it on the concurrent deploy — unverified). Boundary now stated (§b.2) instead of skipped.
4. **Noticed-and-ignored micro-defect:** `fastflowlm.nix:136` carries `|| true || true` (double-or-true, harmless but wrong) — seen while reading, neither fixed nor flagged. Kept silent to keep the daemon-swept commit surgical; queued now (§f.4).

### What could I still improve?

1. **Apply read lessons at the moment of action, not as post-hoc citations.** Both process failures this session (lock peek, fetch-first) were lessons I could quote from documents already in my context. The fix is mechanical: the pre-flight peeks belong in a checklist, not in memory (§f.11).
2. **Fix + guard pairing as a default:** class fixes should land WITH their eval-time contract in the same session — the scrub precedent even provides the copy-ready negative-test pattern.
3. **Close-out boundary discipline:** every "no X since Y" claim must name the event that would prove it and whether ANY such event occurred.
4. **Treat sandbox denials as verification-scope declarations,** not just obstacles — when `systemctl` is denied, the report should immediately scope which live assertions are impossible from this seat.

**Did I lie?** No — but one close-out line was stronger than its evidence (§Self-review #3 / §d.2), corrected here.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a.1 | **Root-caused the 17:06 activation exit-4** (the actionable failure in the pasted log): memory-emergency guard Zone 6 (IO-PSI avg60 = 63.77%, "crash #3 class", trip #2211) stopped `fastflowlm.socket` + `fastflowlm.service` + the live `fastflowlm@2-…` instance MID-switch; the per-connection socat bridge propagates the stop-SIGTERM as **exit code 143** (`code=exited, status=143` — socat re-raises TERM as an exit code, NOT a signal-kill, so systemd's clean-stop handling does not apply) → instance parked FAILED → stc "warning: the following units failed" → exit 4 | guard journal 17:16:56 trip #2211 line; instance journal 17:06:51-53; sacrifice list `memory-emergency-guard.nix:1124-1132`; backend journal shows clean stops (only the instance class is affected) |
| a.2 | **Confirmed the 16:15 cv FOD failure already fixed** by prior sessions — re-pin + shim-drop verified green in the 16:55 sibling report; the 17:06 manual build carried zero cv errors. Did not re-touch | sibling report §a.1-a.7; pasted 17:06 build log (22 derivations, no cv) |
| a.3 | **Fix landed: `SuccessExitStatus = [ 143 ]` on BOTH per-connection bridge templates** (`fastflowlm@`, `llama-vlm-*@`) with class-traceable comments (hermes `= 1` 2026-09-20 → `btrfs-scrub@` `[ 1 ]` 2026-09-29 → bridges `[ 143 ]` 2026-10-07) | `modules/nixos/services/fastflowlm.nix`, `modules/nixos/services/llama-vlm.nix`; daemon commit `3bf7157f` verified by `git show --stat`: exactly my 3 files, 20 insertions, nothing else swept |
| a.4 | **Eval verification:** both templates render `[ 143 ]` | `nix eval … systemd.services."fastflowlm@".serviceConfig.SuccessExitStatus` and `…."llama-vlm-e4b@"…` → `[ 143 ]` both |
| a.5 | **Full gate green:** `nix flake check --no-build` all checks passed (expected aarch64-darwin omission); `nix fmt` 0 changed | background job output in-session |
| a.6 | **Deployed live WITHOUT racing:** my deploy hit the flock (fail-fast), I waited for the concurrent session's deploy to release, then asserted WHICH generation carries the fix | `readlink /run/current-system` = `acrc1r92…`; live rendered `fastflowlm@.service` AND `llama-vlm-e4b@.service` both carry `SuccessExitStatus=143` |
| a.7 | **Push closed:** the 17:15 GitHub 500 was transient; remote already at `3bf7157f` (daemon pushed before me); after `git fetch`, local == origin, ahead 0, clean | `git fetch` + `git status` + `git show --stat 3bf7157f` |
| a.8 | **Class-completeness sweep (run during this report):** exactly 2 `Accept = true` sockets exist tree-wide; both covered. No un-swept siblings | `rg "Accept = true" modules/ platforms/` → fastflowlm.nix:255, llama-vlm.nix:216 only |
| a.9 | **Runbook documented:** fastflowlm.md bullet records the mechanism (socat exit-143 ≠ signal-kill), the trip-#2211 incident, the precedent chain, and why there is no crash-visibility tradeoff (stateless bridges; backend's `fastflowlm_failed`/crash-loop metrics own alerting) | `docs/services/fastflowlm.md` (1 insertion in `3bf7157f`) |
| a.10 | **PSI discipline held:** did NOT cold-pin the 21.6 GB model into an ongoing 60%+ IO-PSI storm for a live test; left the guard-cycling socket down as designed (tracked bring-up item) | socket journal 17:21:42→:57 cycle; guard still tripping |

## b) PARTIALLY DONE

1. **Runtime proof of the fix.** Works: eval, gate, live rendered units, two live precedents of the same fix class (hermes, scrub — both verified live by the same mechanism). Missing: an observed stop-event passing clean under the new override — the socket has been guard-down since 17:21, so not even one instance has spawned since the fix went live. Blocker: a controlled test needs `systemctl` (sandbox-denied) AND would cold-load 21.6 GB into the storm; the natural experiment is the next guard trip with a live connection (the guard cycles the socket every ~15 min while the storm lasts, and any client connection re-arms it). **Effort:** S to observe, S to control (storm-gated). Queued (§f.1).
2. **Standing-FAILED clearance of the 17:06 instance.** deploy.sh's pre/post-switch `reset-failed` presumably cleared it on the concurrent deploy; unverified from this seat (no `systemctl`, textfile-metric check not run). **Effort:** S. Queued (§f.5).
3. **Self-harvest:** 4 new synced queue/library pairs landed with this report (see ledger); everything else deliberately not-harvested with reasons.

## c) NOT STARTED (deliberate — scope was "fix the pasted failures")

1. **Eval-time exit-contract drift guard** for the socket-bridge class (scrub-exit-contract sibling) — designed in §f.2, not implemented.
2. **llama-rag.md runbook line** for the llama-vlm@ override (§f.3).
3. **Everything already owned by fresh tracked items:** the IO storm + its attribution (new evidence noticed — §e.4), the socket-start mystery (16:03/16:29/17:06:39/17:14:55/17:21:42 "Listening" events seconds before guard closes — services.md:34-35 owns it; this session adds two timestamps), the flm v1.0.2 heap-crash class + go-commit `OPENAI_TIMEOUT` re-vendor (runbook bullet read this session), the 14 baseline smoke FAILs, forgejo G1.
4. **`|| true || true` cleanup** — deliberately not touched mid-fix to keep the daemon commit surgical; queued (§f.4).

## d) TOTALLY FUCKED UP

1. **I repeated the sibling report's own self-flagged mistake.** The 16:55 report's self-review #2 (deploy-lock pre-check) was IN MY CONTEXT and I still launched the deploy without the one-line peek. Cost: one wasted invocation + a moment of "is another session racing me". No damage — fail-fast flock absorbed it — but citation-without-application is precisely the anti-pattern this repo's rules exist to kill.
2. **One close-out line outran its evidence:** "zero instance `Failed with result` lines since" read as "the fix works live", when the truth is "no stop event has occurred to test it". Sibling of the 2026-09-18 browser-history-gate rule (answer the question ASKED; assert which question your evidence answers). Boundary corrected in §b.1; the claim is now scoped to "deployed + rendered".
3. **Pushed before fetching** and briefly mistook my own stale remote-tracking ref for a new GitHub-side problem ("cannot lock ref"). Self-inflicted confusion, zero damage, ordering lesson queued (§f.11).

## e) WHAT WE SHOULD IMPROVE (concrete)

1. **Pre-flight peeks belong in a checklist, not in memory** — `pgrep`/lock peek before `nix run .#deploy`, `git fetch` before any push/retry. Both of this session's process failures were lessons I could QUOTE; neither survived contact with the action. One CONTRIBUTING checklist edit makes them structural (§f.11).
2. **Fix + guard pairing:** when a fix generalizes a class AND an eval-time contract pattern already exists (scrub-exit-contract), land both in one session. I left a (small) regression window open.
3. **Close-out boundary rule:** "no X since Y" requires naming the proving event and whether it occurred. Cheap, kills the §d.2 class.
4. **The guard now emits per-unit IO attribution** ("top io since last trip: system.slice +12680MB, inboxclean-web.service +7952MB, user.slice +5448MB") — that is the per-unit attribution the 16:55 report (§b.3) called MISSING. Not my scope today, but the storm-attribution tracked item should consume this signal instead of `ps`-guesswork. Noticed, pointed, not researched further.
5. **Sandbox `systemctl` ban degrades live verification** (ss/journalctl only). The read-only allowlist row already queued in pipeline.md is the fix; this session is another concrete case study (§b.2 was impossible from this seat).

## f) Next things to get done (honest count: 11 — no padding; harvest disposition marked)

| # | Item | Impact | Effort | Category | Harvest |
|---|------|--------|--------|----------|---------|
| 1 | Observe (or run, storm-gated) ONE clean stop of a `fastflowlm@`/`llama-vlm-*@` instance under `SuccessExitStatus=143` — natural guard trip with a live connection, or controlled test in a PSI-calm window; assert `Success`/`Deactivated successfully` in the journal, NOT just absence of failure lines | High | S | Verification | **QUEUED** (stability) |
| 2 | Eval-time socket-bridge exit-contract check (generalize flake.nix:3128): every `Accept=true` template whose ExecStart is a socat bridge MUST carry `SuccessExitStatus = [ 143 ]`; scope question (auto-class vs enumerate) in §g.2; pairs with a scrub-style negative test | High | S | Quality | **QUEUED** (stability) |
| 3 | llama-rag.md: one-line exit-contract note for the llama-vlm@ bridges (close the one-way cross-ref from fastflowlm.md) | Low | S | Documentation | **QUEUED** (services) |
| 4 | fastflowlm.nix:136 `|| true || true` → single `\|\| true` (noticed while reading; harmless but wrong) | Trivial | S | Cleanup | **QUEUED** (services) |
| 5 | Verify the 17:06 instance's standing FAILED state was cleared by the concurrent deploy's reset-failed (`systemctl show` or the system-health textfile metric) | Low | S | Verification | **QUEUED** (stability, folded into #1's probe) |
| 6 | Feed the guard's new per-trip per-unit IO attribution into the storm-attribution item (16:55 §b.3) — the signal now exists, the item should cite it | Med | S | Observability | tracked — no new row (attribution item exists) |
| 7 | Socket-start mystery: what STARTS `fastflowlm.socket` during storms (now 5 timestamps: 16:03, 16:29, 17:06:39, 17:14:55, 17:21:42 — each "Listening" seconds before the guard closes it; the churn burns guard trips) | High | M | Bug | tracked (services.md:34-35) — evidence enriched, no new row |
| 8 | go-commit `OPENAI_TIMEOUT` re-vendor completion (runbook: implemented locally 2026-10-07, pending push + `nix flake update go-commit`; also the flm crash-trigger fix chain) | High | S | Bug | tracked (runbook + services.md) |
| 9 | Scope decision (§g.3): extend the SuccessExitStatus fleet sweep from oneshots to bridge templates + TERM-exiting daemons (discordsync drain class, 2026-09-20 report §f.3) as one dispatch, or keep classes separate | Med | S | Quality | decision-gated |
| 10 | Pre-flight peeks into CONTRIBUTING deploy/verification checklists (lock peek + fetch-before-push) — make §e.1 structural | Med | S | Documentation | roadmap |
| 11 | Watch the next root-nixpkgs bump for the ~13-FOD re-hash class (cv re-pin survival) — carried concern from the 16:55 sibling, noticed not researched | Med | S | Bug-verify | tracked (sibling §f.21) |

## g) Questions I cannot answer myself (max 3)

1. **Live-proof policy (§f.1):** once IO PSI calms, do you want the CONTROLLED stop-test (start the socket, make one real connection — cold-pins the 21.6 GB model for ~2-5 min — then stop the instance and assert a clean journal result), or wait for a NATURAL guard-stop to observe it? Controlled = definitive but costs one cold load in a post-storm window; natural = free but may take days. I cannot weigh model cold-load IO against verification certainty for you.
2. **Exit-contract check scope (§f.2):** should the eval-time guard AUTO-CLASS the rule (any `Accept=true` socket's per-connection template with a socat/bridge ExecStart must carry `[ 143 ]`) or ENUMERATE the two units scrub-style? Auto-class catches future bridges but may false-positive a future non-socat `Accept=true` design; enumeration is exact but silently misses new bridges.
3. **Sweep scope (§f.9):** extend the standing SuccessExitStatus fleet-sweep row (currently oneshot-scoped, stability.md) to cover per-connection bridge templates and TERM-exiting long-running daemons as ONE dispatch, or keep the classes in separate rows? It changes an existing tracked row's scope, so it is your call, not mine.

---

## Harvest ledger (TODO contract compliance)

- **Queued this session (synced pairs, TODO_LIST.md stability + services clusters):** §f.1+§f.5 (live clean-stop proof incl. failed-state clearance check → stability.md), §f.2 (eval-time socket-bridge exit-contract check → stability.md), §f.3 (llama-rag.md runbook line → services.md), §f.4 (`|| true || true` cleanup → services.md).
- **CLOSE-OUT UPDATE 2026-10-07 (evening "fix things" session):** §f.2 DONE (`checks.bridge-exit-contract` in flake.nix — fastflowlm enumerated, llama-vlm DERIVED from `services.llama-vlm.servers`; negative-proven both legs in `scripts/negative-test-lints.sh` bridge group; §g.2 auto-class question stays open by design). §f.3 DONE (bullet appended to llama-rag.md). §f.4 DONE (single `|| true`). §f.1/§f.5 remain open (natural-observation gated). Premise correction recorded in the stability.md library row: the "only two tree-wide" count was template FAMILIES — the live config has THREE bridge instances (`fastflowlm@`, `llama-vlm-e4b@`, `llama-vlm-cap@`), all covered.
- **Deliberately NOT harvested, with reasons:** §f.6 (attribution signal for an already-tracked item — enrich the existing row, no duplicate); §f.7 (tracked services.md:34-35, this session adds timestamps as evidence only); §f.8 (tracked in the runbook + services items); §f.9 (decision-gated by §g.3 — queueing a scope decision as `[ready]` would violate the dispatch-queue contract); §f.10-11 (roadmap/checklist fuel + tracked elsewhere).

## Evidence appendix

| Claim | Command / artifact |
|---|---|
| Guard trip #2211 mid-switch, IO-PSI class | `journalctl -u memory-emergency-guard --since 17:00` (17:16:56 line, zone 6, avg60=63.77%) |
| Instance exit-143 → FAILED | `journalctl -u 'fastflowlm@2-53252-127.0.0.1:52625-127.0.0.1:53126.service'` (17:06:51-53) |
| Backend stops clean (only the instance class affected) | `journalctl -u fastflowlm.service --since 2026-10-05` (all stops "Deactivated successfully") |
| Fix renders in eval | `nix eval … 'fastflowlm@'/'llama-vlm-e4b@' …SuccessExitStatus` → `[ 143 ]` both |
| Gate green | `nix flake check --no-build` → all checks passed |
| Fix live | `/run/current-system/etc/systemd/system/{fastflowlm,llama-vlm-e4b}@.service` both `SuccessExitStatus=143`; `readlink /run/current-system` = `acrc1r92…` |
| Commit attribution | `git show --stat 3bf7157f` → exactly 3 files, 20 insertions |
| Class completeness | `rg "Accept = true" modules/ platforms/` → 2 hits, both fixed (2 MODULE families; the llama-vlm mapAttrs' template fans out to 2 enabled servers → 3 live bridge instances — `fastflowlm@`, `llama-vlm-e4b@`, `llama-vlm-cap@`, clarified 2026-10-07 evening) |
| Push closed | `git fetch` → `## master...origin/master` (ahead 0) |
