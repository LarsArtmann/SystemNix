# Status: Docs-Health Audit Resumed — 08-13 Annotation Batch Complete, Commit Blocked

**Date:** 2026-08-14 16:20 CEST
**Session scope:** Resume docs-health ANNOTATE pass — all 9 remaining 2026-08-13 reports annotated inline; commit attempt blocked by pre-existing statix findings; 08-14 batch not yet started
**Prior context:** `docs/status/2026-08-14_15-24_docs-health-audit-annotations-partial.md` (10 of 35 reports done at interruption)

---

## a) FULLY DONE

### 1. Session state reconstructed and corrected

- Stale todo list fixed first action (5 falsely-pending items marked completed — living docs rebuild was already done in `61a2224b`)
- Marker-count audit of all 37 status files: confirmed exactly 22 at zero `~~` markers (9× 08-13, 13× 08-14)
- Full commit map pulled (`git log --since=2026-08-10`, ~90 commits) — every annotation verdict cites a hash from this map

### 2. All 9 remaining 2026-08-13 reports annotated (every numbered item resolved)

| Report | Verdicts | Highlights |
|---|---|---|
| `04-47` buildflow-templ | ~40 (§c 10, §e 7, §f 30, §g 3 Q) | templ sweep closed at `43e11db3`/`6ee6c3c`/`2322979`/`f8ea2f4`; signoz churn Won't-implement (alejandra makes revert a no-op); sandbox timer `c39b6d50` |
| `05-48` fix-sweep | ~45 (§b 2 inline, §c 10, §f 30, §g 3 Q) | BuildFlow→v0.9.2 done at `4e4b5538` (verified in upstream repo); browser-history `expires_at` moot (column since `6d4622c` 06-23, DB rebuilt) |
| `09-06` hdmi-wireplumber | SUPERSEDED banner + ~25 + §F table 13 rows + 3 Q | Marked superseded by `smart-audio` (`8ad493c9`) — the 09-06 "solved" claims were wrong, exactly as `23-39` §d.1 said |
| `15-04` zram-io-pressure | ~60 (§c 6, §e 10, §f 50, §g 3 Q) | 6 sysctls done at `0bd8a272`; PSI checks exist at `004924be`; commit=120 and qgroups Won't-implement with AGENTS.md-documented rationale |
| `15-09` tv-display | ~25 + 3 Q | HaGeZi → `88c594cc`; nix.gc.automatic exists; pre-deploy disk thresholds verified at 85%/95% (`pre-deploy-check.sh:135`); go-cqrs-lite dupes CONFIRMED STILL OPEN |
| `16-11` hagezi-mirror | ~15 (tables + §f 20 + 3 Q) | AGENTS.md mirror note added at `61a2224b`; **rpi3-dns eval verified clean** with shared GitLab blocklists; archived session-37 note left open |
| `18-36` flake-lock-repair | ~25 + §f table 19 rows + 3 Q | Deploy confirmed same evening (`990fcd66`); follows dedup done `82963f04`/`caf2cab8`; vendor-CI for crush-daily/PMA/erraudit left open |
| `19-01` nar-hash | ~55 (§b/§c/§d tables, §f 50, §g 3 Q) | NAR time-bomb DEFUSED — lock now pins fresh `github` tarball rev `064a269e`, machine rebooted repeatedly with nix ops green; renamer follows confirmed STILL missing (lock forensics: root pins `go-nix-helpers_2`, renamer pins divergent `go-nix-helpers`) |
| `23-39` hdmi-persistence | ~35 + 3 Q | Persistence gap RESOLVED by `smart-audio` (`8ad493c9`); 09-06 reconciliation done; FEATURES.md Smart-Audio row exists (`61a2224b`) |

### 3. Live system findings verified during annotation

- **Disk at 97% (27G free of 723G)** — worse than the 91-93% all reports claimed; approaching the 95% deploy hard-fail. Routed for TODO_LIST.
- **`file-and-image-renamer` still lacks `go-nix-helpers.follows`** — flake.lock carries a divergent node (verified via lock JSON, not grep)
- **Root `go-cqrs-lite` input still fetches via `ssh://`** (`type: git`, `url: ssh://git@github.com/...`) plus `_2`/`_4`/`_5` git nodes — the NAR-divergence root-cause vector from `19-01` persists
- Monitor365 agent+server both `enable = false` (upstream wireguard-collector break) — Gatus checks correctly conditional
- `nix.gc.automatic = true` exists; `auto-optimise-store = false` is deliberate (QLC NAND)
- Gatus inventory: 93 checks incl. ClickHouse, Browser History `/health`, OOMD Kills, I/O Stall Rate, PSI memory
- 08-14 templ sweep re-verified: cqrs-htmx 8/8 tracked, templ-components tracked==ondisk, BuildFlow's 2 untracked templ files are vendored deps (correctly `/vendor`-ignored)

---

## b) PARTIALLY DONE

### ~~1. Commit of the 08-13 annotation batch — STAGED, BLOCKED~~ resolved — commits landed; the chain continued (18-31, 20-31 reports committed).

- All 10 files staged (9 annotations + the 15-24 session report)
- Pre-commit hook FAILED: statix flags 2 pre-existing `assignment-instead-of-inherit` warnings in `modules/nixos/services/buildcache.nix` (lines 109, 164) — a file this session never touched; the statix gate runs repo-wide, not staged-only
- gitleaks/deadnix/shellcheck/flake-check all passed inside the hook
- **Nothing committed** — HEAD still `61a2224b`; the auto-git daemon will sweep this unattributed if left

### ~~2. buildcache.nix statix fix — LOCATED, NOT APPLIED~~ applied — `inherit (cfg) device;` (buildcache.nix:165) + `inherit onFailure;` (266) present. Annotation 2026-08-17.

- First `multiedit` failed with mtime guard (the hook's alejandra pass reformatted the file during the failed commit)
- Lines re-located (`device = cfg.device;` at 109, `onFailure = onFailure;` at 164); the corrected `inherit (cfg) device;` / `inherit onFailure;` edits were NOT yet re-applied when the session was halted

---

## c) NOT STARTED

~~1. **Annotate the 13 remaining 08-14 reports**~~ done — 11 archived via the 18-31 → 20-31 chain; `10-00` (pre-struck item 25) and `12-30` (SUPERSEDED banner) were closed out by the 2026-08-17 pass.
~~2. **TODO_LIST additions**~~ done — routed: disk (P0), renamer follows (P3), go-cqrs-lite ssh→github (P3), zram ADR (P3), vendor-hash CI (P6), session-37 note (P6), test-tone tooling (P5); audio.nix em dashes fixed outright (0 in file today); OTel-scheme check + committed-templ CI + zram-fill alert SHIPPED (see f.23/24/26).
~~3. **Correct 2 misleading annotations** written this session (see §d.2)~~ done — "Correction 08-14" notes present in archived 04-47 §f.20 and 18-36 §f.9.
~~4. **ARCHIVE pass**~~ done — all 08-12/08-13 reports archived; 08-14 completed 2026-08-17.
~~5. **Quality gate** — canonical `nix flake check --no-build`~~ done — green 2026-08-17 ("all checks passed").
6. **Inline health report** ← open at annotation time — owed by the 2026-08-17 docs-health pass (printed at its close).
~~7. **Final attributed commit**~~ done — via auto-git daemon sweeps (e.g. `46b5ffdb`).

---

## d) TOTALLY FUCKED UP

### 1. Fired a parameterless `bash` tool call

End of session, right before the halt: an empty `<invoke>` with no command. **Second occurrence of the exact error class that interrupted the previous session.** Zero information content, wasted a round trip, and it happened immediately after a prior tool error — chasing a failure while sloppy. Parameter-check before send, always.

### 2. Wrote 2 annotations whose evidence was a too-narrow grep

In `04-47` §f.20 and `18-36` §f.9 I wrote "flake.lock now has zero `git+ssh` fetches". The grep `grep -c 'git+ssh' flake.lock` → 0 is string-true but **functionally false**: the lock carries `go-cqrs-lite` (+`_2`/`_4`/`_5`) as `type: git` with `url: ssh://git@github.com/...` — discovered via later JSON forensics for a different item. The annotations overstate closure; must be corrected to "URL-string migration done, ssh:// type=git nodes remain (go-cqrs-lite family)".

### 3. Initially violated the annotation grammar with "still open" labels

Added `← still open` labels to open items in `04-47` (items 17-19, 24-25) and `15-09` (item 16). The skill explicitly forbids this: absence of a marker IS the open signal; labels are noise. Caught on self-review within the same file pass and removed both — but the mistake repeated across two files before the rule internalized.

### 4. 7 multiedit partial failures from whitespace assumptions

§e lists in `15-04`, §A items in `09-06`, §g.1 in `04-47`, the deploy section in `18-36` — all failed because I assumed single-newline separators where the file had blank lines (or vice versa). Every one recovered by re-viewing exact bytes, but each failure cost a round trip. Pattern is now known: **§e/§b sections in these reports use blank-line-separated numbered items; §f sections use single-newline runs.**

### 5. Misread a transient eval failure as a real regression

First `rpi3-dns` eval failed with `fileSystems does not exist` from `buildcache.nix` — I spent 5 tool calls investigating a suspected module-basis bug before re-running and getting a clean pass (twice). The failure was a transient store-source race while the daemon committed mid-eval. Lesson: **re-run once before investigating any eval failure that coincides with daemon activity.**

### 6. Session halted with work uncommitted

The blocked commit was left blocked; the buildcache fix was left half-applied. Next session inherits a fragile state (daemon sweep risk).

---

## e) WHAT WE SHOULD IMPROVE

1. **Never emit a tool call without parameters** — two sessions in a row now. The failure mode is firing the next call while still reacting to the previous error. Pause, then send.
2. **Verification greps must match semantics, not strings** — `type: git` + `ssh://` ≠ the literal `git+ssh`. For lock/graph claims, use JSON inspection (`python3 -c json.load(...)`), not substring counts.
3. **Pre-existing lint debt blocks ALL commits** — the statix gate is repo-wide; any pre-existing warning stops every future commit until fixed. Fix-on-sight the moment the hook first trips, not after planning around it.
4. **Re-read files the pre-commit hook touched** — the hook reformats staged files; any in-flight edit plan is invalidated (mtime guard). Sequence: hook → re-view → re-edit.
5. **Section-aware edit batching** — learn per-file list spacing before the first multiedit (one `view` with `cat -A` on the section beats 3 failed edits).
6. **Transient-eval rule** — one clean re-run before root-cause analysis when the daemon is active.

---

## f) Up to 50 Things To Get Done Next

### Immediate (unblock the commit)
~~1. Apply `buildcache.nix` inherit fixes~~ done — `inherit (cfg) device;` :165, `inherit onFailure;` :266.
~~2. Correct the 2 "zero git+ssh" annotations~~ done — corrections in both archived files.
~~3. Re-run the staged commit for the 08-13 annotation batch~~ done — chain continued.

### 08-14 annotation batch (13 files, hash research in 15-24 report §f)
~~4. `08-23` boot-failure-qmd-activitywatch~~ done — archived.
~~5. `08-24` smart-audio-daemon-built-deployed-with-gaps~~ done — archived (audibility item lives on in TODO_LIST P2).
~~6. `08-24` twenty-crm-pg-role-investigation~~ done — archived.
~~7. `08-46` monitoring-gap-closures~~ done — archived (collector-hardening item in TODO_LIST P3).
~~8. `09-14` code-quality-audit-docker-hardening~~ done — archived (Dozzle hardening item in TODO_LIST P3).
~~9. `09-30` oidc-gate-helpers-qmd-cleanup~~ done — archived (gate-helper items in TODO_LIST P3).
~~10. `10-00` signoz-dashboard-v2-perses-migration~~ done — closed by the 2026-08-17 pass (v2 API shipped; dashboard migration executed by the 08-16 deep-integration session).
~~11. `10-04` registration-lock-oomd-threshold~~ done — archived.
~~12. `10-41` oauth2-gate-toctou-fix~~ done — archived (import_export gate hole in TODO_LIST P1).
~~13. `12-30` ssd-recovery-benchmarking~~ done — closed by the 2026-08-17 pass (SUPERSEDED banner).
~~14. `12-53` 5-item-go-nix-review-dsn-audit~~ done — archived.
~~15. `13-22` vendorhash-hardening-iowrap-gomemlimit~~ done — archived.
~~16. `13-44` hermes-registration-lifecycle-fixed~~ done — archived.

### Living-doc routing (verified-open items found this session)
17. TODO_LIST: disk 97% cleanup plan ← open — evolved into TODO_LIST P0 "Free root below 95%" (root hit 95% on 2026-08-17; pool migration changed the math).
18. TODO_LIST: add `file-and-image-renamer.inputs.go-nix-helpers.follows` ← open — TODO_LIST P3.
19. TODO_LIST: switch root `go-cqrs-lite` flake input from `git+ssh://` to `github:` ← open — TODO_LIST P3.
~~20. TODO_LIST: remove 2 em dashes from `audio.nix` comments~~ done — 0 em dashes in `modules/nixos/desktop/audio.nix` today.
21. TODO_LIST: add `alsa-utils` or `pw-cat` test-tone tooling ← open — TODO_LIST P5 (blocks the smart-audio audibility verification).
22. TODO_LIST: ADR for zram-only swap decision ← open — TODO_LIST P3.
~~23. TODO_LIST: eval-time check that gRPC OTel endpoints carry no `http://` scheme~~ done — `otel-endpoint-audit.nix` shipped (`1f7fc720`): gRPC 4317 ⇒ scheme REQUIRED, host allowlist, port registry.
~~24. TODO_LIST: CI check that `*_templ.go` files are committed wherever `*.templ` exists~~ done — `scripts/check-templ-committed.sh` in pre-commit + CI; plus go-nix-helpers `checks.templ-committed` eval-time throw.
25. TODO_LIST: vendor-hash CI for crush-daily, PMA, erraudit ← open — TODO_LIST P6.
~~26. TODO_LIST: Gatus alert for zram fill > 90%~~ done — `system_zram_fill_over_threshold` + Gatus "ZRAM Fill" check alerts Discord (AGENTS.md ZRAM section).
27. TODO_LIST: note in archived `2026-05-06_07-10` session-37 report ← open — TODO_LIST P6.

### Closure
~~28. ARCHIVE pass~~ done.
~~29. Quality gate: `nix flake check --no-build`~~ done — green 2026-08-17.
30. Inline health report ← open at annotation time — owed by the 2026-08-17 docs-health pass.
~~31. Final attributed commit of archive + remaining changes~~ done — daemon sweeps.

### Structural debt observed
32. AGENTS.md at ~72.6KB ← open — ~80 KB now; TODO_LIST P6 "AGENTS.md compression session".
33. 11 archived reports confirmed appendix-only annotated ← debt open, now TRACKED — TODO_LIST P6 "Annotate appendix-only ARCHIVED reports" (cites the authoritative lists).
~~34. `nix flake check --all-systems` Darwin eval~~ done — documented intentional in AGENTS.md ("Build & Deploy": aarch64-darwin skip EXPECTED, do not add --all-systems).
~~35. Pre-commit statix gate scope~~ resolved — hook lints STAGED `.nix` files only (AGENTS.md gotcha "Pre-commit statix lints STAGED .nix files only"); pre-existing debt no longer blocks commits.
36. Auto-git daemon sweeps mid-session ← process rule absorbed — per-batch commits are now the documented practice (AGENTS.md Git Workflow). No open action.

---

## g) Questions (Cannot Figure Out Myself)

### ~~1. The foreign SSD report — annotate or leave alone?~~ RESOLVED — annotated with a Decision Record + archived by the 2026-08-17 docs-health pass (the parallel session had long finished).

`docs/status/2026-08-14_13-15_ssd-repurposing-options.md` (338 lines) was written by a PARALLEL session (bundled into `61a2224b` by the daemon, still unread). It matches the `2026-08-1*` scope you gave me. Do I read + annotate it like the rest, or is it owned by a live session whose work is still in flight (annotating a moving target corrupts history)?

### 2. Disk is at 97% — aggressive cleanup now, or TODO_LIST only? ← OPEN owner decision — routed to TODO_LIST P0 "Free root below 95%" (disk sat at 95% on 2026-08-17). Annotation 2026-08-17.

27G free on 723G; deploys hard-fail at 95%. Automated GC only deletes >3d. A manual `nix-collect-garbage --delete-older-than 1d` freed ~23G last time but is a system-affecting action on your live machine (can trigger rebuilds of in-use paths and I/O on the QLC NAND). Should I run it during the next session, or just record the task and let you decide timing?

### 3. AGENTS.md compression (72.6KB) — schedule its own session now? ← OPEN owner decision — TODO_LIST P6.

Carried over unanswered from the 15-24 report. It needs a dedicated read-compress-verify pass (target ≤30KB without losing gotcha content) — too large to fold into this audit's tail. Schedule it as the immediate next session after this audit closes, or defer behind the 08-14 annotation batch and archive work?

---

*Report generated: 2026-08-14 16:20 CEST*
*Session delta: 9 reports annotated (~340 inline verdicts), 0 commits landed, 1 pre-commit blocker (buildcache.nix statix), 2 annotations needing correction*
