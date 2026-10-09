# Status Report — 2026-10-08 08:22 · Handoff Next-Steps Execution: Forensics, Closeouts, Two New Facts

**Scope:** the 07-38 report's Exact Next Steps (rows queued from its §f) executed end-to-end under the
owner's "READ, UNDERSTAND, RESEARCH, REFLECT / execute and verify" directive: negative-test completion,
cv forward-verify build, §g.2 actor forensics, hermes drain check, 14-FAIL baseline triage, push-backlog
diagnosis, live-state checks — plus two NEW facts the verification surfaced (current-tree deploy blocker;
phantom-PSI relocation). No owner-gated decisions were taken unilaterally; §g.1/§g.3 remain owner calls.

---

## §a Executed, with verdicts

| # | Item                                           | Verdict                                                                                                                                                                                                                                           | Evidence                                                                                                                                                                                                                                                                                                                                                           |
| - | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1 | Daemon sweep of report-phase files             | Confirmed                                                                                                                                                                                                                                         | 5fa34b98 (AGENTS.md + 07-38 report), 8241a29e (TODO twins ×5 files); tree clean at session start; content-pins taken before every edit window                                                                                                                                                                                                                      |
| 2 | Push state                                     | ahead 38 → **premise corrected**, see §c.1                                                                                                                                                                                                        | `git ls-remote` succeeds; remote master = 618ef8cc = HEAD at 18:18:35                                                                                                                                                                                                                                                                                              |
| 3 | FULL negative-test suite (gap §e.2)            | **30 passed, 0 failed**                                                                                                                                                                                                                           | `bash scripts/negative-test-lints.sh` unfiltered; all 7 controls + 23 mutation cases green, incl. new controls entry + absent-list case                                                                                                                                                                                                                            |
| 4 | Absent-list negative case (gap §e.3)           | **Landed**                                                                                                                                                                                                                                        | `bridge/fastflowlm-absent`: sed-DELETE of `SuccessExitStatus = [ 143 ];` (valid-nix empty line) → guard fires with same marker; also added `bridge-exit-contract` to the controls loop (script's own "green control for every touched check" contract — the 2026-10-07 addition had skipped it)                                                                    |
| 5 | cv@e76d638 forward-verify (§g.1 evidence half) | **BUILDS CLEAN**                                                                                                                                                                                                                                  | throwaway `nix build …toplevel --override-input cv 'git+ssh://…?rev=e76d638…' --keep-going` (no tree mutation): `cv-e76d638-go-modules`, `cv-e76d638`, `_fish-completions` all built; ZERO cv/web errors in log; toplevel exit 1 caused ONLY by an unrelated bank-sync FOD (see §b.1)                                                                              |
| 6 | §g.2 actor forensics                           | **ANSWERED: owner terminals, unflushed history**                                                                                                                                                                                                  | §c.2 evidence table                                                                                                                                                                                                                                                                                                                                                |
| 7 | hermes drain check                             | **No drain occurred**                                                                                                                                                                                                                             | hermes.service main pid 224523 continuously alive since 10-07 16:29 (true start time via /proc stat field 22); zero Stop/Start lifecycle lines 19:00:30–19:12; only hermes-github-verify oneshot re-ran twice. deploy.sh's restart warning fired conservatively; the gen-840 switch restarted nothing in the hermes family → no in-flight session could be aborted |
| 8 | 14 baseline smoke FAILs triage                 | **All known/tracked; no re-baseline**                                                                                                                                                                                                             | Bank-Sync→SCA rows+runbook; CV→cv.md+forward-verify row; Caddy catch-all→caddy.md+rows; FastFlowLM→guard-down/live-stop rows; Forgejo ×6→migration+upstream-issues rows; Overview ×3→"Root-cause the Overview outage" row; SigNoz Coverage→coverage rows. 19:01 smoke matched baseline exactly = no NEW fails                                                      |
| 9 | Live state                                     | :52625 NOT listening (no bridge spawn post-fix — natural stop-observation still pending); D-state count **0** (was 1 at 07:38); zero failed units in system_health.prom; stale `/tmp/.systemnix-deploy.lock` (PID 262091 dead, no holder) trashed |                                                                                                                                                                                                                                                                                                                                                                    |

## §b New facts (found during verification)

### b.1 The CURRENT tree's toplevel does NOT build — next deploy blocked (bank-sync FOD)

`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` on HEAD
(no override) fails:

```
error: hash mismatch in fixed-output derivation
  '…-bank-sync-ab2c9dcd6437e59d1eab9f8592ce748f1e162f90-go-modules.drv':
  specified: sha256-rd4R+EG5saCRZAjrT/HaAoi8lhzcwkJAoTGoD/NLT/o=
  got:        sha256-vn4URiyNOT+8/yxTlOvUYW7qDwRIuB5E7kI2ficbkvg=
```

Notable: bank-sync has sat at ab2c9dc since ≤18:23 **2026-10-07** and the 19:01 gen-840 deploy built it
fine; nixpkgs (a7868a727837) and go-nix-helpers pins are unchanged since 18:50; the vendorHash is baked
in the upstream bank-sync repo (mkLarsPackages consumes `input.packages.<system>.default`), and NEITHER
hash appears anywhere in this tree. This is the [watch] row's drift class, but **without a rev move**
(same rev + same recipe → different fetch result). The concurrently-running
`buildflow -s nix-hash-fix --fix` session owns exactly this repair class; this report records the
blocker and does NOT race it. Next deploy must re-verify toplevel green after that fix lands.

### b.2 Phantom-PSI relocated: 5 idle ghostty scopes pin system IO-PSI ~26-32% with disks 0% busy

Yesterday's deploy-gate blocker was narrated as "2 node_exporter D-threads on a dead automount".
Today those are GONE (node_exporter pid 1962 — same boot process — all 12 threads S-state), but the
phantom persists in a new location: **5 user-scope ghostty terminals** (the owner's monitoring windows:
nvtop, btop, iotop-c, and shells; opened 15:2x–17:23 on 10-07) each carry scope io.pressure some
avg10 52–100%, aggregating to root some avg10 ~26–32% while max disk busy = 0.0%.

Decisive measurements (agent-side, no sudo):

- Live accrual: worst scope io.pressure `total` grew 6,094,272 µs over ~6 s ≈ **1.01 s/s = continuous ~100% some-stall**
- memory.pressure `total` delta = 0 (not memdelay)
- 300 task-state samples at 20 ms across the scope: **0 D-state hits** — the io-accounted sleep is
  invisible to D-scans (io_schedule-class stall, likely pipe/pty path)
- All 5 scopes' autofs candidates unchanged: `/mnt/rust-cache` (timeout=0), `/mnt/btrfs-root`, `/home/lars/.cache` (timeout=600)

**Owner test (30 s):** close/reopen those 5 ghostty windows → root io.pressure should collapse toward
~0 idle → deploy PSI gate unblocks naturally and the force-override stops being the standing answer.
Root-cause (per-tid kernel stack) remains sudo-gated. Recorded on the stability row (§harvest).

## §c Premise corrections (count-claim/surface-claim class)

### c.1 "daemon pushes not delivering" — the daemon never pushes

The 07-38 §f.9 premise was wrong on mechanism. Evidence: `projects-management-automation.nix` contains
no push automation; the daemon journal shows ZERO push-related lines since 16:00 10-07 (only
watch/commit cycles); `git ls-remote` now succeeds (connectivity + credentials fine). The last
successful remote update was the **owner-side** `projects-management-automation run --command "git town
sync"` at 18:18:35 (or the owner's `git sync` at 18:18:44), which pushed 618ef8cc — remote master sits
exactly there. Nothing "stopped delivering": **nobody ran a sync since**. Resolution is one owner
`git sync`/`mr push`; unpushed risk is real (ahead 38) but the diagnosis work is complete.

### c.2 The 17:43/17:48/18:23 blanket lock updates — actor identified by elimination + positive match

| Sweep (commit)   | Inputs moved                   | Writer identified                                                                           |
| ---------------- | ------------------------------ | ------------------------------------------------------------------------------------------- |
| 17:43 (a58d8e4f) | 12 (blanket)                   | **Owner fish 17:28:30** `nix flake update && nh os switch . -v` — fish_history, exact match |
| 17:48 (618ef8cc) | monitor365+nur                 | Unattributed blanket write 17:43–17:48 — see below                                          |
| 18:23 (fc2643bc) | 6 (cv→339ca0f, hermes→0e21933) | Unattributed blanket write ≤18:23                                                           |
| 18:33 (5de4ff20) | 7 (cv→e76d638)                 | Unattributed blanket write ≤18:33                                                           |
| 18:50/18:56      | cv→b3a9172, hermes→e76fb95     | Prior session's rollback `--override-input` pins (its report)                               |

Elimination (all read-only): no crush session ran ANY flake command 17:35–19:30 (full-text LIKE over
the project `.crush/crush.db`, 15 overlapping sessions — the only mentions are the prior session's
rollback reasoning); bash history and cron empty; the pma daemon never executes flake commands
(journal); `git sync`=`git town sync` (git-only). Positive match: **five fish terminals alive since
17:03–17:25 with cwds in SystemNix/CV never flushed their in-memory history** (fish writes on exit) —
fish_history only contains EXITED sessions' commands. The owner's visible activity (fixing CV upstream
18:10–18:18: `cd projects/CV; buildflow --fix; git sync; mr push`) correlates exactly with cv advancing
in the 18:23/18:33 sweeps. **Verdict: owner interactive terminals; not automation; not agent sessions.**
The "gate automation behind a toplevel build" follow-up is moot; the CI-toplevel-build row (§f.6)
remains the right structural guard for the CLASS. Owner can self-confirm by scrolling those 5 terminals
(tty 7/17/23/24 + the CV one on tty9).

## §d Self-review (what I could have done better)

1. I initially trusted `/proc/<pid>` dir mtimes for fish start times (all read "19:00") — wrong;
   recomputed via stat field 22. Anyone repeating this forensics should go straight to field 22.
2. My first two crush-DB query attempts had schema/parsing bugs and printed nothing; the empty result
   could have been mistaken for "no sessions" — the fix was parsing raw parts defensively and
   cross-checking against a KNOWN case (the prior session's 18:44 pin) before trusting the negative.
3. I almost stacked the negative-test suite + cv build on top of a live build battery at IO-PSI 47
   (freeze-#20 class); deferring until PSI ~30 and monitoring during runs was the right call and
   should stay the pattern for eval-heavy batches.

## §e Handoff / open

- **§g.1 (cv direction)** — now evidence-complete: e76d638 BUILDS CLEAN (§a.5). Owner decides: pin
  forward (one `nix flake lock --override-input` + deploy after b.1 is fixed) or hold at b3a9172.
- **§g.3 (controlled stop-test)** — unchanged; natural observation still pending (no bridge spawn).
- **b.1 deploy blocker** — buildflow nix-hash-fix session owns it; verify toplevel green before ANY
  next deploy.
- **b.2 owner test** — close/reopen the 5 ghostty monitoring terminals; expect PSI collapse.

## Harvest ledger (TODO contract compliance)

- **Closed this session (synced pairs):** absent-list case (pipeline §f.4); actor identification
  (pipeline §f.5 — answered, no gating follow-up); push backlog (pipeline §f.9 — premise corrected,
  owner push remains); hermes drain (services §f.11 — no drain occurred); 14-FAIL triage (services
  §f.7 — all tracked, no re-baseline).
- **Annotated, not closed:** cv forward-verify (services §f.2) — verify half DONE (builds clean),
  retagged `[blocked:user]` for the pin decision.
- **Extended rows:** stability §f.1 dead-automount row (corpses gone; phantom relocated to ghostty
  scopes + owner test + sudo-gated remainder); services bank-sync [watch] row (same-rev drift instance,
  current-tree blocker, buildflow ownership).
- **Deliberately not harvested:** none — all §-section follow-ups above are either closed, harvested,
  or explicitly owner-gated.
