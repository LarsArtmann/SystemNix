# Status Report — the nix-managed Immich key converger (built, verified) + the sed incident

**Session window:** 2026-10-25 ~07:52–12:52 CET (third report of one continuous session; covers everything after the 10:38 report)
**Report written:** 2026-10-25 12:52 · **HEAD:** auto-commit daemon series
**Trigger:** owner challenged *"Why don't we do 'Immich UI → API key (asset.read + asset.upload only)' in Nix? like a one shot?"* — one day's worth of "irreducible manual step" doctrine overturned in one message.

> **Format override (flagged per skill spec):** `.md` demanded by owner prompt; HTML-canonical skill overridden one-off, not propagated.

---

## TL;DR

The paste path is **dead**. The owner's "one shot" instinct was correct and exposed a real hole in my 08:07/10:38 adjudications: I had ruled out machine-provisioning on the **API** surface (Immich is OIDC-only) but never examined the **database** surface — Immich's Postgres runs on this same host with peer auth for root, a privilege root already holds. The new root converger `discordsync-immich-key-provision` mints the scoped key (`asset.read`+`asset.upload`) directly into Immich's `api_key` table and renders the daemon's env file. Every load-bearing fact was live-verified BEFORE building (schema, hash format, permission strings, admin row); the exact INSERT was proven against production inside a ROLLBACK transaction. Go-live is now a single deploy with **no user action**. One serious self-inflicted incident (587 duplicated todo rows from an unvalidated sed) — fully repaired, disclosed below.

---

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| a1 | **Adjudication reversed with evidence, not vibes**: the OIDC-only argument is real but only kills the API path; the DB path needs no Immich credential at all. Old wrong claims purged everywhere they lived (runbook 08:07-adjudication paragraph deleted, agent-note superseded marker, TODO rows rewritten) | `docs/services/discordsync.md` "Key lifecycle"; grep clean of the old paste instructions |
| a2 | **Live schema verification before writing a line**: table is `api_key` (SINGULAR — renamed by StandardizeNames; the initial migration still says `api_keys`), `key` is **bytea = raw 32-byte sha256 digest** of the token (`hashSha256(randomBytesAsText(32))` read from the deployed 3.3.3 bundle), `permissions varchar[]`, defaults cover id/timestamps/updateId; exactly one admin user | psql probes via peer-auth scripts; `dist/services/api-key.service.js` + `crypto.repository.js` + migration grep |
| a3 | **INSERT proven against production inside ROLLBACK**: `INSERT 0 1` → row readable with `{asset.read,asset.upload}` → rollback → count 0 | `~/.cache/discordsync-immich/probe-insert.sh` output |
| a4 | **The converger built**: root oneshot (boot + daily timer + deploy.sh provisioner loop entry) with three convergence states (consistent no-op / row-gone re-insert from file / file-gone fresh mint + restart), schema guard failing LOUDLY on drift, stale-own-name row cleanup, atomic 0400 env-file write, `try-restart` of daemon + verify after mints | `modules/nixos/services/discordsync.nix`; deploy.sh loop entry |
| a5 | **Full wiring swap**: sops template is Immich-free in BOTH shapes; `discordsync_immich_api_key` secret + `discordsync-immich.yaml` RETIRED (git rm); daemon carries the provisioned file as a second EnvironmentFile (list-concat with upstream's entry) + ordered after the provisioner; verify script rewritten (reads provisioned file; placeholder branch deleted — state no longer exists); daemon-less provisioner added to `extraMonitoredServices`; configuration.nix + immich.md cross-refs updated; runbook "Key lifecycle" section + rotation recipe | eval-verified; see a7 |
| a6 | **14-case eval regression** pinning the NEW shape (provision unit/timer/env-file/ordering lit-when-enabled + dark-when-disabled; sops env Immich-free both shapes; restartUnits daemon-only) — GREEN | isolated harness eval, same-session re-runs after every change |
| a7 | **Both scripts build clean through writeShellApplication's shellcheck gates** (this SUPERSEDES the earlier "shellcheck not run" gap — the derivation build IS the lint) | `nix-build` of the two drvs from the harness-extracted contexts |
| a8 | **Two self-review gaps fixed pre-report**: provisioner added to `extraMonitoredServices` (daemon-less monitoring parity with the verify unit); post-deploy leg's dead PLACEHOLDER branch replaced with the real "has not converged" classification | discordsync.nix + scripts/post-deploy-check.sh; re-verified |
| a9 | **The sed incident fully repaired** (see d1): 587 duplicated rows removed, `git diff` clean against the daemon commit, single append, structure check OK | `check-todo-system.sh` → structure clean; exactly 1 copy on disk |

## b) PARTIALLY DONE

| # | Item | Works | Missing | Blocker |
| - | ---- | ----- | ------- | ------- |
| b1 | **Go-live** | Everything mechanical: converger + wiring + retirement + smoke leg + regression, all verified as far as the sandbox allows | THE DEPLOY itself (production switch; first real provision run inserts into the live `api_key` table) | This report — awaiting the owner's go (the "deploy today" answer predates the design pivot) |
| b2 | **Full-flake verification** | Isolated harness green for the test + scripts; script derivations real-built | `nix flake check` still blocked by the floated-locks audit gate (owner assigned the float procedure to me at 10:3x — NOT yet executed, see c2/d3) | Fleet locks |
| b3 | **Eval mystery root-cause** (phantom `services.integration` under strict check) | Bounded, queued `[ready]`, repro pointers live | Owner assigned a session to it (Q3 answer) — not started | Budget; this turn belonged to the converger |
| b4 | **drive-paperless adoption** of the converger | Pattern proven + queued `[ready]`; immich.md cross-ref updated | Generalization (`services.immich.apiKeys.<consumer>`) not designed; its sops paste leg still stands until the Drive go-live | Queued deliberately |

## c) NOT STARTED

| # | Item | Why | Wanted? |
| - | ---- | --- | ------- |
| c1 | `nix run .#deploy` (the go-live) | Owner-visible production switch; awaiting this report's confirmation | Yes — the whole point |
| c2 | Float procedure (toplevel `--keep-going` → regenerate `flake/expected-locks.nix` → commit lock+registry together) | Heavy real builds; deliberately sequenced AFTER owner confirms this report (it was pre-assigned via Q1) | Yes — blocks all full-flake verification |
| c3 | Mystery root-cause session (owner-assigned via Q3) | Budget went to the converger | Yes — queued |
| c4 | Post-deploy ritual after c1: provision journal (`minted`/`converged`), verify journal (`Immich API key verified`), `/lookup` E2E found/not-found/asset-link, `git diff` of the tree | Runs with the deploy | Yes |
| c5 | Upstream Tier-3 batch (badge wording, WARN-on-auth-fail, tag carry, module options, healthCheck URL) | verify-before-filing pass pending | Yes — queued |
| c6 | CHANGELOG entry for the converger + retirement | Rides deploy-time review | Optional |

## d) TOTALLY FUCKED UP (radical honesty)

| # | What | Severity | Root cause | Repair + lesson |
| - | ---- | -------- | ---------- | --------------- |
| d1 | **The 587-duplicate incident**: appending a queue row, `LINE=$(grep -n "<pattern>" file \| head -1 \| cut -d: -f1)` returned EMPTY (pattern mismatch — the target row's wording didn't contain it), and `sed -i "$LINE r file"` with an empty address appends after EVERY line. `docs/todo/services.md` ballooned to ~1174 lines with the row after each | **Medium-High (self-inflicted tree damage in a shared file; fully repaired within minutes)** | Unvalidated variable interpolated into a sed address; preceded by a malformed python3 heredoc attempt — sloppy shell stretch | Repaired: matched-prefix delete-all → `git diff` clean → single `>>` append → structure check. **Lesson (durable): NEVER interpolate an unvalidated line number into sed; use `>>` for appends; assert `grep` found exactly one match before using its output as an address** |
| d2 | **Two wrong adjudications before the right design**: 08:07 stated "single paste is the minimal-privilege optimum" as doctrine; 10:38 repeated it in the runbook. The owner needed ONE push ("like a one shot?") to expose that the DB surface was never examined | Medium (a manual step + a user-gated row survived weeks on a half-examined premise) | "Why" questions were answered from the API perspective only — the data layer was never in the hypothesis space | Corrected claims purged at every site; the runbook now records BOTH the wrong adjudication AND the correction (memory doctrine: re-read what you replace). **Lesson: an "impossible in Nix" claim must enumerate the layers examined, not just the conclusion** |
| d3 | **Q1/Q3 answers from 10:3x (run float, root-cause mystery) remain unexecuted** — this turn's budget went to the converger build instead | Low (both queued + owner-visible) | Single-threaded session; the converger consumed it | Named here as owed work, not silently dropped |
| d4 | **Mid-build eval bug shipped-then-caught**: `config.services.postgresql.package` (no value when postgres disabled) would have broken eval on immich-less hosts — caught by the harness BEFORE any commit, fixed to `pkgs.postgresql` | Low (caught in-session) | Option-value vs package-default confusion | The harness paid for itself; both scripts rebuilt green after the fix |
| d5 | **Carried from earlier reports, still true**: full `nix flake check` unrunnable (locks); the 08:07-era `sudo` first-call waste; the `immich.service` unit-name near-miss | Low | — | All previously documented; unchanged |

## e) WHAT WE SHOULD IMPROVE

1. **"Impossible in Nix" claims need a layer checklist**: API / DB / filesystem / socket / process-identity. The converger exists because the DB layer was checked after a user push, not before shipping doctrine. Suggest a line in the docs-health or CONTRIBUTING doctrine: any "cannot be automated" adjudication must enumerate touched layers + the credential state of each.
2. **sed/appends discipline**: `VAR=$(grep … \| head -1)` + `sed -i "${VAR}…"` is a loaded gun (d1). The repo's shell style should state: validate-or-abort before address interpolation; prefer `>>`/`tee -a` for appends.
3. **Daemon-less convergers need the full monitoring parity checklist** (OnFailure + extraMonitoredServices + deploy.sh registration + timer). I landed 3 of 4 and missed the fourth until self-review — make it a checklist item in the converger pattern docs (the deploy-restart-audit already covers deploy.sh; the other three are convention).
4. **The writeShellApplication build-as-lint trick deserves promotion**: `nix-build <script-drv>` runs shellcheck + `bash -n` without the full flake — it closed the 10:38 report's biggest verification gap. Document the context-extraction one-liner (`builtins.getContext` on the ExecStart string).
5. **Live-DB proof-by-ROLLBACK is the right pre-deploy ritual** for any converger that writes a foreign app's schema — cheap, zero-risk, and it caught nothing this time precisely because it ran (that's the point). Candidate for the converger-pattern docs.

## f) Up to 50 things we should get done next — session-scoped, ranked

> Honesty note: **18 items are genuinely derivable from this arc**; padding to 50 would be filler. Full-project pareto = separate explicitly-requested task.

| # | Task | Impact | Effort | Category | Harvest status |
| - | ---- | ------ | ------ | -------- | -------------- |
| f1 | `nix run .#deploy` — the paste-free go-live (provision mints on first boot convergence) | Critical | S (sudo) | Feature | HARVESTED — `services.md:112` (deploy-only row) |
| f2 | Post-deploy ritual: provision + verify journals, `/lookup` E2E (found/not-found/asset-link), daemon env contains both files | Critical | S | Verification | Part of f1 — row 112 step list |
| f3 | Float procedure (assigned; blocks ALL full-flake verification incl. the new unit's audit legs) | High | L (real builds) | Infrastructure | Owner-assigned; queued — `TODO_LIST` float ownership now resolved |
| f4 | After f3: full `nix flake check` (validates deploy-restart-audit admission of the new provisioner, the shape test in the real closure, extraMonitoredServices wiring) | High | M | Verification | Part of f3 |
| f5 | Root-cause the phantom `services.integration` check-ON throw (owner-assigned session) | Medium | M-L | Bug (tooling) | HARVESTED — `TODO_LIST.md` + `pipeline.md` |
| f6 | Adopt the converger for drive-paperless (generalize to `services.immich.apiKeys.<consumer>`) | Medium | M | Feature | HARVESTED — `services.md` new row |
| f7 | Upstream Tier-3 batch (badge wording not-configured≠unreachable≠rejected; WARN on proxy auth fail; tag carry; module options; healthCheck URL) | High (UX/obs) | M | Bug/Feature | HARVESTED — `services.md:113` |
| f8 | Shell-lint discipline note: never interpolate unvalidated grep output into sed addresses (d1) | Medium | S | Process | HARVESTED — new row below (TODO_LIST + pipeline.md) |
| f9 | "Cannot-be-automated adjudications must enumerate layers + credential state" doctrine line | Medium | S | Documentation | HARVESTED — new row below |
| f10 | Converger-pattern checklist (OnFailure + extraMonitoredServices + deploy.sh + timer) into CONTRIBUTING/converger docs | Medium | S | Documentation | HARVESTED — new row below |
| f11 | Document the `nix-build <script-drv>` build-as-lint trick (getContext extraction one-liner) | Low | S | Documentation | HARVESTED — folded into f10's row |
| f12 | `nix develop -c shellcheck scripts/post-deploy-check.sh` (the leg's `bash -n` is clean; the full-script lint still hasn't run — writeShellApplication covered only the two module scripts) | Low | S | Quality | HARVESTED — existing row (TODO_LIST f3 from 10:38) |
| f13 | CHANGELOG entry: converger + sops retirement + retired paste path | Low | S | Documentation | Deliberately NOT harvested (c6 — rides deploy review) |
| f14 | After f1: confirm no SigNoz/Gatus regressions (provision OnFailure wiring fires only on real failures; Turso check stays deliberately red) | Low | S | Verification | Part of f2 |
| f15 | If the provision ever trips its schema guard: the runbook's paste-path fallback is documented — re-verify Immich source before resurrecting it (verify-before-filing applies) | Low | — | Contingency | Documented in runbook; no row |
| f16 | Re-run the isolated harness after the next flake.lock float (revs are read live; expect green, prove it) | Low | S | Verification | Deliberately NOT harvested (rides f3's natural cycle) |
| f17 | The 10:38 report's f12 (immich.md unit-name trap) — immich.md was touched THIS session (cross-ref edit); the trap note could ride a future immich.md pass | Low | S | Documentation | Deliberately NOT harvested (that file's edits belong to another session's scope; mine was one sentence) |
| f18 | Consider `RandomizedDelaySec` collision matrix audit across ALL daily timers (verify=1h, provision=6h, immich=10m, bank-sync…) — cheap eval assertion, prevents future 00:00 pileups | Low | M | Quality | Deliberately NOT harvested (scope beyond this arc; note kept here) |

## g) Questions I can NOT figure out myself

Presented interactively after this report; recorded here for the file:

1. **Deploy now**: switch production with the converger this session (it mints into the live `api_key` table on first convergence), or hold until the float + full `nix flake check` have run?
2. **Float ordering**: run the float procedure BEFORE that deploy (heavier preamble, cleaner verification) or AFTER (deploy first, float as follow-up)?
3. **drive-paperless scope**: fold its key adoption into the same generalization now, or strictly after its Drive go-live (as queued)?

---

## Evidence appendix

```bash
date '+%Y-%m-%d %H:%M:%S %Z'                       # 2026-10-25 12:51:47 CET
bash /home/lars/.cache/discordsync-immich/probe-insert.sh
# BEGIN / INSERT 0 1 / {asset.read,asset.upload} / ROLLBACK / after_rollback=0
nix eval --impure --raw --expr 'import /home/lars/.cache/discordsync-immich/eval.nix'
# → /nix/store/…-discordsync-immich-shape-regression.drv   (14/14 cases pass)
nix-build <provision.drv> <verify.drv> …           # both scripts build (shellcheck gates)
bash scripts/check-todo-system.sh                  # OK: structure clean (post-incident)
```
