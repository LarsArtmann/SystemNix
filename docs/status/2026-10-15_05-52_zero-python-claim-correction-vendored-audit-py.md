# Status: Zero-Python claim corrected — vendored systemd-audit.py identified, disposition queued

**Time:** 2026-10-15 05:52 CEST
**Scope of this report:** THIS session's run — the resume after the zero-Python close-out, the owner's `scc` challenge (`Python 1 490 37 57 396 80????`), the investigation, and the correction wave. Not a whole-project inventory — per-domain state lives in `docs/todo/*` and `docs/services/*`.
**Prior report:** docs/status/2026-10-15_05-14_zero-python-execution-complete-close-out.md (its §h Correction is THIS session's work).
**Format note:** user explicitly demanded `.md` at this path — the status-report skill's HTML canonical format is overridden by instruction (same standing pattern as the 05:14 close-out).

---

## a) FULLY DONE

1. **The scc challenge answered in one tool round.** `glob **/*.py` + `git ls-files '*.py'` → exactly one hit: `pkgs/.systemd-timer-monitor/systemd-audit.py` (490 lines = scc's 1 file / 37 blank / 57 comments / 396 code / 80 complexity). The owner's "????" had a precise referent within minutes.
2. **Root cause established, every fact verified in-repo.** The file is the **vendored upstream runtime of cappy-dev/systemd-timer-monitor**, copied verbatim from the last successful build output on 2026-08-28 (`7e44ee2a`) because **upstream was deleted from GitHub** (rev `ff68e41`, tarball 404) — the vendor comment in `pkgs/systemd-timer-monitor.nix:10-13` says "replace with a maintained fork if one appears". It is NOT dead code: it powers the **live** `timers.home.lan` service (5-min oneshot, gatus HTML check, deploy.sh post-switch re-audit, referenced by two VM tests, integration-registered, own runbook). Upstream is **unlicensed** (`lib.licenses.unfree`) — material for the disposition (a translation port would be a derivative work of an unlicensed work).
3. **The claim failure root-caused.** The 05:14 close-out's "Python is gone from SystemNix" was false as stated; the plan's own asserts were `rg '\.py$' scripts/`-scoped (first-party scripts/ + ruff) while the goal line and the prose claimed repo-wide zero. The lint-static python3 guard was never a tracked-file gate — it guards Nix/shell python3 *usage*, and even documents this very file's 2026-08 exit-127 incident.
4. **All six claim surfaces corrected** (count-claim rule: name surfaces, show post-state): CHANGELOG `[Unreleased] → Removed` headline → "**First-party** Python is gone…" + precision note; the plan's EXECUTED banner → Residual 2 block; the 05:14 close-out → title fixed + new **§h Correction** section (daemon-swept into `722087f1`); `AGENTS.md` architecture block → 2-line pointer at the vendored dir (so it is never re-discovered); `[decision]` row queued on **both** queue surfaces (`TODO_LIST.md` + `docs/todo/services.md`, no drift).
5. **The queue decision row is decision-grade.** Option A: ratify the vendored exception (zero *first-party* Python stands; python3 stays in the closure). Option B: **clean-room Go behavioral reimplementation** (report.html + status.json + exit codes 0 ok / 1 args / 2 no-systemctl), vendored file deleted, python3 leaves the closure — service-affecting, needs deploy + `timers.home.lan` 200-with-html + fresh status.json verification. Translation explicitly forbidden (unlicensed upstream).
6. **Gates green after the correction wave:** `nix flake check --no-build` all-pass (exit 0); `check-todo-system.sh` → "OK: TODO queue/library structure clean"; scc recount = exactly the 1 documented file.
7. **Harvest discipline held:** the session's one genuinely-new actionable follow-up (tracked-`*.py` allowlist gate, see §f item 3) was queued into BOTH surfaces (`docs/todo/pipeline.md` + `TODO_LIST.md`) at authoring time; everything else in §f is pre-existing rows or dispositioned brainstorm.
8. **On-sight doc fix (owner's 2026-09-06 standing permission):** the runbook's dead upstream link (`docs/services/systemd-timer-monitor.md`) now states the deletion + vendoring instead of pointing at a 404 GitHub repo.
9. **Todo list recreated** (12 items from the summary context) and driven to completion.

## b) PARTIALLY DONE

1. **The vendored-Python disposition itself** — investigated, corrected, decision-queued; NOT executed. Options A/B need owner ratification before any file moves.
2. **The zero-Python goal** — first-party scope complete (4 sweepers + 4 UCR scripts + crush-daily backfill .py gone, ruff plumbing gone); repo-wide NOT achieved: 1 vendored 490-LOC `.py` remains + `python3` stays in the system closure until the decision lands.
3. **G3 of the resumed plan list** — was closed last session (gates, push, CI triage, close-out), but its close-out shipped the overbroad claim; correction only happened after the owner's external challenge. Closed-with-asterisk.
4. **Prior session's 3 open questions** — still unanswered by the owner (branching-flow CI auth, ucr-archive ambition, crush-daily red test). They gate §f items 4/5 and 8.

## c) NOT STARTED

1. **Option B implementation** (clean-room Go `systemd-audit` port) — blocked on the A/B decision.
2. **The tracked-`*.py` allowlist gate** (queued this session, §f item 3) — not implemented.
3. **All ucr-archive follow-ups** from the prior session — 2 stale AGENTS.md claims (says `scripts/` is empty when it holds `ucr-ffprobe-sweep.sh`; cites `nix run .#test`/`.#lint` apps that don't exist), ~10 golangci-lint findings, Actions CI, service-surface question. Zero progress this session (by scope instruction).
4. **CI un-red work** (`branching-flow` fetch 404 + statix leg) — blocked on owner input (§g Q2).
5. **crush-daily red test** `TestLegacySnapshotRow_DecodesUnderNewStack` — no dispatch; default = document-and-leave unless told otherwise.

## d) TOTALLY FUCKED UP

1. **The headline failure (last session's, caught by the owner, not by me):** a close-out titled "Zero-Python executed end-to-end" and a CHANGELOG entry "Python is gone from SystemNix" were published while a tracked 490-LOC Python file sat in the tree. Root cause: the verification answered a NARROWER question than the claim — scoped assert (`scripts/`) vs absolute claim (repo-wide) — which is the exact "a close-out must answer the question the item ASKED" failure class recorded 2026-09-18 (browser-history gate). A single `git ls-files '*.py'` — the command I ran within 60 seconds of the owner's message this session — would have caught it before publication. Worse: the PLAN ITSELF carried the mismatch (goal "zero Python", asserts scripts-scoped), so the drift was authored, not incidental.
2. **A month-old unanswered question about the exact same directory:** `docs/status/2026-09-15_04-29_repo-cleanup-pareto-sweep-brutal-self-review.md` item 20 asked "`pkgs/.systemd-timer-monitor/` hidden dir — what is it, still needed?" It sat unanswered while at least two sessions (the zero-Python plan authoring + execution) worked in the adjacent `pkgs/` and `scripts/` space. Neither report grepped prior review findings for its area before publishing.
3. **This session's editing process was sloppy at the start:** 5 of 6 first-batch edits failed on "modified since read" because I read the conflict surfaces with bash (`rg`/`sed`/`tail`), which does NOT register with the edit tool's freshness tracker — in an actively parallel-session tree, `view` is the only read that counts. Two wasted rounds; the discipline exists precisely for this tree and I didn't apply it.
4. **Commit-contents verification was initially truncated:** `git show --stat HEAD | head -8` cut off the file list of `722087f1`, so the parallel session's `flake.lock` rider was invisible in the first check and only surfaced on the second look. In THIS repo (daemon-race policy), the stat list is the check — truncating it defeats its purpose.

## e) WHAT WE SHOULD IMPROVE

1. **Absolute claims need absolute asserts — mechanically.** Any "gone/zero/all/N" claim in a report, CHANGELOG, or plan must be pinned by an enumeration over the claim's whole scope (`git ls-files`, `scc`), not a scoped grep. Cheap enforcement: the queued tracked-`.py` allowlist gate generalizes the lesson for this doctrine.
2. **Before publishing, grep prior reviews for your area.** Item-20 class: prior self-reviews already contain open questions about the same directories; a 30-second `rg` over `docs/status/*self-review*` would have surfaced the hidden dir a month earlier.
3. **Shared-tree editing protocol:** `view` the exact region immediately before every `edit`; bash reads don't refresh freshness tracking. (Also re-confirmed: daemon commit mod-time bumps are benign — content anchors survived both rounds.)
4. **Write the license constraint into decision rows at queue time** (done here): unlicensed upstream ⇒ behavioral reimplementation only — this prevents a future session from "just translating" the Python.
5. **Daemon-race checks must show the full stat list** — never pipe `git show --stat` through a truncating head.
6. **Self-review folded, not split:** the owner asked the brutal-self-review questions inside the status-report demand; both were answered in this single `.md` (the brutal-self-review skill's separate `docs/reviews/*.html` output was deliberately not produced — one file, as instructed).

## f) Up to 50 things we should get done next

*(Prioritized; ★ = queued/harvested this session; the rest are pre-existing rows — sources cited. Items 1–3 are this session's direct lineage; items 4+ carry the prior close-out's §f and the standing queue.)*

1. ★ **DECIDE: vendored `systemd-audit.py` — ratify exception (A) or clean-room Go port (B)** — the [decision] row in `docs/todo/services.md` + `TODO_LIST.md`; gates items 2–3.
2. *(if B)* ★ Clean-room Go behavioral reimplementation of the audit (report.html + status.json + exit codes 0/1/2), vendored file deleted, python3 leaves the closure; deploy in an IO lull + `timers.home.lan` verify battery.
3. ★ **Tracked-`*.py` allowlist gate** (lint-static/pre-commit leg, one-row allowlist shrinking to zero under B) — `docs/todo/pipeline.md`.
4. **Un-red the CI nix-check workflow** — branching-flow 404 (needs §g Q2) + statix findings — `docs/todo/pipeline.md` + `TODO_LIST.md`.
5. **ucr-archive: fix the 2 stale AGENTS.md claims + add the missing `nix run .#test`/`.#lint` extraApps** (only when that repo is quiescent — a parallel session was mid-edit there).
6. **ucr-archive: zero the ~10 golangci-lint findings.**
7. **ucr-archive: Actions CI + NixOS service surface** — needs §g Q3.
8. **crush-daily red test** `TestLegacySnapshotRow_DecodesUnderNewStack` — dedicated fix dispatch or document-and-leave (default: document).
9. **Commit `scripts/parity-check.sh` into ucr-archive** from the README-VERIFICATION.md parity method.
10. **ucr-archive `ucr root doctor` subcommand** (preflight: manifest/index/WAV presence, verdict census) — prior close-out §f item 38.
11. *(mooted, close it)* Upstream-reporting of the ucr-rag.py embed INSERT bug — upstream repo is deleted; record as moot (the plan banner already carries the note).
12. **Re-pin the hermes-agent flake input** — `.tq-verify` is tree-wide RED since 2026-10-14 eve; every dispatch's end-of-session verification fails on it — `docs/todo/pipeline.md`.
13. **Docs-scoped `.tq-verify`** so a red Nix eval cannot void a docs-only closeout — `docs/todo/pipeline.md`.
14. **Verdict-durability rule** (write `$TQ_RESULT_FILE` right after the report commit) into CONTRIBUTING — `docs/todo/pipeline.md`.
15. **[decision] Budget carve-out for closeout dispatches** — `docs/todo/pipeline.md`.
16. **CrowdSec stage-1 live verification** on the next switch (crowdsec-prereq redesign landed in-tree) — `docs/todo/services.md` [watch].
17. **CrowdSec stage-2** bouncer key (owner-interactive, sops) — `docs/todo/services.md` [blocked:user].
18. **`boot_phase_duration_seconds`: provision or delete the expectation** (pre-deploy phantom-metric red since 04:44) — `docs/todo/monitoring.md`.
19. **Deploy the hot-db bootstrap CAP_DAC_OVERRIDE fix** in an IO lull + probe battery — `docs/todo/services.md`.
20. **migrate-hot-db: pre-stop sqlite WAL checkpoint step + outcome-aware window branch** — `docs/todo/services.md`.
21. **browser-history stop-window re-attribution** of the 217 zero-user behavioural rows (owner-authorized op) — `docs/todo/services.md` [blocked:user].
22. **Render-proof the "firefox buried below the fold" claim** via the local repro harness — `docs/todo/services.md`.
23. **inboxclean-paperless: wire the wrapper as a flake app + fixture-test its unit-env extraction** (2 rows) — `docs/todo/services.md`.
24. **Fixture selftest for btrfs-gc-guard's space legs** + **fixture-test deploy.sh's entry gates beyond the trip leg** (2 rows) — `docs/todo/stability.md`.
25. **Identify the 30 s /health poller on :8099** (serves full HTML; not gatus) — `docs/todo/services.md`.
26. **Owner-reclaim decisions:** `/data/docker` (~15.5 GB) + (done: ollama models trashed; watch the pin-window free) — `docs/todo/services.md`.
27. **Sev1 chronic-storm latch implementation** (design is queued, docs/todo/stability.md) — implement the ACTIVE→CHRONIC state machine.
28. **48 h guard-trip re-baseline** post-Ollama-removal (Zone-6 cadence expected to drop) — stability watch.
29. **Vulkan llama.cpp experiment** (wedge-free iGPU path; `vulkanSupport` override verified on the pinned nixpkgs) — queued follow-up from the Ollama removal.
30. **Prior close-out §f items 3–40** (standing brainstorm: ucr web service surface, tq verify-gate GOEXPERIMENT, GPU GTT collector follow-ups, desktop-state snapshot collector, etc.) — deliberately NOT re-harvested; they live in docs/status/2026-10-15_05-14_…§f and the domain libraries until triaged.

*(Stopped at 30: items 31–50 would duplicate the prior report's standing brainstorm without new information from THIS session's run.)*

## g) Questions I can NOT figure out myself

1. **The vendored `systemd-audit.py`: A or B?** Ratify it as the sanctioned vendored exception (upstream deleted, works, guarded), or green-light the clean-room Go behavioral port (first-party package, vendored file deleted, python3 leaves the system closure — service-affecting, next IO-lull deploy)? If B: should it bundle with the other pending lull deploys (hot-db CAP_DAC_OVERRIDE, crowdsec-prereq verification)?
2. **`branching-flow`:** private repo (→ which CI secret name should the workflow use for the fetch) or simply an unpushed rev `aa1611d` (→ push it / repin to a pushed rev)? I cannot see the repo's visibility or your auth intent from here — this blocks all 6+ VM tests in CI.
3. **ucr-archive ambition:** real CI + NixOS service surface now (Actions on push + a module serving/regenerating the web archive), or a manual operator tool where flake apps + tags are enough? This decides items 5–7 and whether v0.1.1 needs a release checklist.

---

**Verification trail for this report's claims:** every fact was run or read live this session — `git ls-files '*.py'`, `scc` (before + after), `pkgs/systemd-timer-monitor.nix` vendor comment, `flake/parts/checks/lint-static.nix` guard + incident narrative, `docs/services/systemd-timer-monitor.md` runbook, plan asserts, `nix flake check --no-build` (all-pass), `check-todo-system.sh` (OK), `git show --stat 722087f1` (report §h + parallel `flake.lock` rider). Nothing taken from another session's prose without having run it myself.
