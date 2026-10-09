# Status — Eval-Warning Sweep Follow-Through: Dead-Guard Close-Out, Signoz Scanner FP Fix, ZFS Voiding (2026-10-04 10:47)

**Session window:** 2026-10-04 ~06:45 – 10:47 (continuation of the eval-warning sweep session; this phase = the owner's three decisions executed)
**Concurrent session:** ACTIVE throughout (thermal-pstate-guard / hot-tier work; its `disko/samsung-tlc.nix` churn committed 10:08). Its files untouched. Auto-commit daemon swept shared edits (`716e3953` at 08:25 carries my 4 code files + 2 of theirs).

---

## a) FULLY DONE

1. **Owner decision 1 — dead-guard-lint 7 findings judged + fixed by intent** (owner picked "fix now"):
   - `cv.nix:590` (`leftover=$(find …)`) → `|| true`. Judgment: the whole cv-state-perms heal block is best-effort with `|| true` style throughout and an explicit "never fail the boot" doctrine — a find failure reads as "no leftover observed" → converged message.
   - `_forgejo-scripts.nix:335/346/360/379` (`n=$(echo … | jq …)`, identical shape ×4) → `|| n=""` rescue reassignment. Judgment: jq death previously = silent errexit death BEFORE the author's own `[[ -z "$n" || "$n" == "-1" ]]` error guard; `|| n=""` makes that guard REACHABLE — loud "GitHub/Forgejo listing failed" + exit 1, exactly the author's intent (the paperless `‖ TAG_NAME=""` precedent).
   - **Bonus site `:967`** — a fifth same-shape `n=$(… jq …)` the scanner NEVER flagged (its guard is `[[ "$n" == "-1" ]]` only, no `-z` form, so the scanner's guard-pattern search missed it). Found via my own `rg -c` verification (5 ≠ 4 expected). → `|| n="-1"` so its guard fires on jq death. This closes a real scanner blind spot: same-shape sites with non-`-z`/`-n` guard forms are invisible to dead-guard-lint v1.
   - `hermes.nix:164` (`stray=$(find …)` inside `tree_converged()`) → `# dead-guard-ok` with justification. Judgment: scanner FP — the function's ONLY call site is `if tree_converged; then` (grep-verified), and bash suppresses errexit body-wide inside a function called in a tested context. The line-based scanner cannot model call contexts; `|| true` there would MISLEAD readers into thinking errexit is live.
   - `btrfs-health.nix:320` (`scrub_started_raw=$(echo | awk …)`) → `# dead-guard-ok` with justification. Judgment: scanner FP — the enclosing `btrfsHealthMetrics` writeShellApplication text downgrades to `set -uo pipefail` (line 168, no `-e`), so the `-n` guard at 326 IS reachable; the scanner cannot model set-flag downgrades. (Also awk exits 0 on no-match, so the capture can practically never fail.)
   - Verified: `nix build .#checks.x86_64-linux.dead-guard-lint` GREEN; `scripts/negative-test-lints.sh` **26 passed / 0 failed** (progression: 18/5 at queueing → 24/2 mid-session → 26/0).

2. **Bonus repair — signoz-query-lint pristine-control failure** (root-caused + fixed while closing the harness): the `[controls]` and `[signoz/comment-ignored]` harness failures shared one root — `dashboards/gcp.json` metric names like `storage_googleapis_com_api_request_count` tripped the histogram-suffix rule. Scanner FP CLASS: GCP-native counters end in `_count` by GCP's own convention; they are not Prometheus histogram components and the rule's premise ("underscore form matches zero series") doesn't hold for them. Fix: `grep -v 'googleapis_com'` exemption in the flake.nix scanner rule (scanner-side per the lint-scanner-FP doctrine; NOT suppressed at the call site). Harness fixtures verified still-failing as designed (`dnsblockd_dns_resolve_duration_ms_sum` has no googleapis marker — no exemption weakening). `nix build .#checks.x86_64-linux.signoz-query-lint` GREEN.

3. **Owner decision 2 — ZFS advisories voided** (owner: "I do not use ZFS anymore"): the two rows harvested earlier the same day (zfs `latestCompatibleLinuxPackages` [ready] + `forceImportRoot` [decision]) were removed from `docs/todo/storage.md` and `TODO_LIST.md`; the sweep report §d.4/§e updated to record the voiding with an explicit do-not-re-harvest marker (the eval advisories remain as inert nixpkgs-default noise on a ZFS-less box).

4. **Owner decision 3 — hermes residual isLinux: upstream-TODO-only** (no action; row stays `[ready]` in `docs/todo/upstream.md` gated by verify-before-filing).

5. **Queue/lib/report surfaces closed in sync** (no drift): `TODO_LIST.md` row + `docs/todo/pipeline.md` row both `[x]`-closed with evidence and the fixed-sites enumeration; CHANGELOG `### Fixed` entry landed ("negative-test-lints harness fully green…") with the full judgment narrative; sweep report §d.2 + §e harvest record closed out.

6. **Verification chain (all actual runs this session):**
   - `nix build .#checks.x86_64-linux.dead-guard-lint` green (after fix)
   - `nix build .#checks.x86_64-linux.signoz-query-lint` green
   - `./scripts/negative-test-lints.sh` → 26/0
   - `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` → **TOPLEVEL BUILD GREEN**
   - Closure proof: the built toplevel references `forgejo-reconcile-mirrors` (z66vcmsn) containing the 4× `|| n=""` AND `forgejo-census` (wp1jzw6d) containing the 1× `|| n="-1"` — rendered-output verification, not just source grep
   - `./scripts/check-todo-system.sh` → structure clean (the 86 unharvested WARN is the standing fleet-wide count, not introduced here)
   - `nix-instantiate --parse flake.nix` OK

7. **Prior phase (earlier this session, already reported):** all five eval-warning classes fixed and certified (final count 1 = hermes-agent upstream isLinux only); `binary-coverage-lint` gate repaired (`pkgs.gawk` in crush-debug.nix — concurrent session's `7222daa5` breakage); technique doc + 4 upstream TODO rows queued.

## b) PARTIALLY DONE

1. **Full `nix flake check` certification** — eval side is green with my edits in tree (the check enumerated eval errors across all attributes; none from my files), but the BUILD side currently shows **6 failing VM tests** that pre-date / parallel my edits (see d/f). I verified my own scope positively (targeted checks + toplevel + harness) but a fully-green tree-wide check was NOT achieved this session — blocked on work that isn't mine.
2. **Scanner blind-spot class documented but not pinned**: the `:967` discovery (dead-guard-lint misses capture sites whose guard is not a `-z`/`-n` form) is captured in the CHANGELOG entry and the closed pipeline row, but dead-guard-lint v1 was NOT extended to cover `[[ "$var" == … ]]` guard forms — that's a real follow-up (f-list).
3. **The sweep status report** (`2026-10-04_06-45_*`) was updated with close-outs (§d.2, §d.4, §e) but its §verification table line 39 still describes the pre-cert snapshot ("dead-guard-lint failure §d, pre-existing") — historically accurate for that run, but a fresh full-check result line was not appended (blocked by the 6 foreign VM failures).

## c) NOT STARTED

1. dead-guard-lint v2: `[[ "$var" == "…" ]]` guard-form coverage (the `:967` class).
2. The 4 upstream rows queued earlier (crm follow [blocked:push], hermes-agent stdenv migration [ready], index + storage-collector pkgs.system [blocked:push]) — untouched this phase by design (owner decision + push gating).
3. stateVersion ×81 [decision] row (pipeline.md) — untouched.
4. The 6 pre-existing/concurrent VM-test failures — investigation NOT started (deliberately: not my files, concurrent session mid-flight).

## d) TOTALLY FUCKED UP (own errors, honestly)

1. **Sloppy background-job management**: the certification job ID changed twice across session interruptions (072 → 07E lost → 007), and one `job_output --wait` was interrupted. No damage (re-ran), but I ran the full check through a `grep | sort | uniq -c | head -20` pipeline whose `head -20` TRUNCATED the failure list — this directly caused the earlier session summary's wrong claim "only dead-guard-lint fails". The 6 VM failures existed at 07:03 and were invisible in the truncated tail. **Lesson: never assert "only X fails" from a head-truncated pipeline; enumerate failures to a file first.** (Same class as the AGENTS.md "assert WHICH entity served it" rule.)
2. **`replace_all` swept in a 5th site without noticing upfront** — my `_forgejo-scripts.nix` replace_all edited `:967` which I had never seen; I only caught it because my verification grep returned 5 instead of 4. The catch worked, and the fix landed BETTER than the originals (`|| n="-1"` matched that site's own guard), but editing unseen code by bulk-replace then post-hoc discovery is luck-shaped rigor. Should have enumerated all match sites BEFORE the replace_all.
3. **First `nix flake check` was wasted**: my re-run command ended `| tail -25; echo "EXIT:$?"` — the EXIT printed 0 (tail's status), masking the check's real failure. Meaningless exit-code capture on a pipeline.
4. **A wrong-provenance detour**: I briefly suspected my hermes edit broke the hermes VM test and burned several tool calls proving otherwise — when the log timestamp (07:03) vs my edit time (08:25) was checkable in one step. Correct instinct to verify, wrong order of cheap-vs-expensive checks.
5. Minor: `nix path-info --no-link` flag misuse and a broken-pipe `head` in the closure query — noise errors from rushing closure inspection; each self-corrected next call.

## e) WHAT WE SHOULD IMPROVE

1. **Full-check hygiene**: enumerate check failures to a file (`nix flake check >log 2>&1` then grep) — never judge from a truncated pipeline; make "which attributes failed" the FIRST output, warnings second.
2. **Bulk-edit discipline**: enumerate all match sites before any `replace_all`; the count-delta check that saved me here (expected 4, got 5) should be a pre-edit step, not a post-edit discovery.
3. **Background-job resilience across interruptions**: capture job output to a file (`… > /tmp/cert.log 2>&1`) so a lost shell ID never loses evidence; the 072→07E loss cost a full re-run.
4. **VM-failure triage ownership**: on a shared tree, a failing VM test needs a same-hour provenance check (log timestamp vs edit timestamps) as the FIRST step, not after deeper debugging — this session got there, but late.
5. **Scanner FP doctrine is working** — three for three now (`$((` arithmetic, `googleapis_com`, and the marker path for semantic FPs) — but each new FP class also revealed a MISS class (the `:967` blind spot). Every scanner exemption should trigger a sibling question: "what does this exemption now silently skip?"
6. **Exit-code capture**: `cmd | tail; echo EXIT:$?` reports tail's status — use `PIPESTATUS` or redirect before the pipeline.

## f) NEXT (up to 50, prioritized; owner-dispatched)

**High (unblock the tree gate):**

1. Triage the 6 failing VM tests with provenance (log timestamps vs commits): `disko-layout`, `hermes`, `hot-user-caches`, `crush-hot-db`, `browser-history`, `restic-app-dumps` — split concurrent-session in-flight vs genuinely pre-existing.
2. Coordinate with the concurrent session on `disko/samsung-tlc.nix` (10:08 commit) vs `tests/test-disko-layout.nix` expectations (`/mnt/hot` subvol list) — likely one side mid-refactor.
3. Investigate hermes `systemnix-workspace-doc: v2` assertion (workspace doc version mismatch) — new failure class, first observed 07:03 today.
4. Re-run full `nix flake check` to a log file once the concurrent session quiesces; append the fresh result line to the 06-45 sweep report.
5. dead-guard-lint v2: cover `[[ "$var" == … ]]` / `[[ -z $var ]]`-adjacent guard forms (the `:967` class) + a harness fixture pinning it.
6. Consider whether `if var=$(…); then` sites with delayed `-z` guards >8 lines deserve lint coverage (cv.nix:563 is safe today, unlinted by design).

**Medium (session follow-throughs):**
7. Push-gated upstream rows when pushes happen: crm follow, index pkgs.system, storage-collector pkgs.system (all [blocked:push] in upstream.md).
8. hermes-agent (NousResearch) stdenv migration [ready] — verify-before-filing gated.
9. Drop the SystemNix-side explicit pins for index/storage-collector AFTER their upstream pushes land (per the sweep report §d.6).
10. stateVersion ×81 [decision] row: silence via explicit stateVersion in the shared VM-test base vs accept — owner decision.
11. Prune the `[x]`-closed dead-guard rows from TODO_LIST/pipeline per the CHANGELOG-pruning pass cadence.
12. §5 harvest hygiene: 86 unharvested §f-bearing reports (standing WARN) — a sweep pass.
13. The `caddy-mutant` negative-test case (add or de-reference) — adjacent to today's harness work, still open.
14. The SSO-layer table refresh in `docs/agents/sso-dns.md` vs registry (fleet drifted) — still queued.
15. gcp.json: if/when the GCP receivers re-arm happens (containment-disabled since the 09-29 falsification), live-verify the GCP-native series names actually match the underscore forms the dashboards query.

**Low / worth considering:**
16. Extend dead-guard-lint scope to `scripts/*.sh` + `pkgs/` writeShellApplication texts (long-standing v1 out-of-scope).
17. Add `PIPESTATUS`-style exit-capture to the repo's ad-hoc verification scripts conventions (CONTRIBUTING note).
18. Consider a flake check that fails LOUD when a check's drv is stale relative to the tree (guard against cached-drv confusion like today's z66vcmsn detour — though nix semantics make true staleness impossible, the confusion cost an hour).
19. Sweep the sweep-report's §verification table for a fresh full-check append (folded into #4).
20. `docs/todo/upstream.md`: the 4 rows cite this session — after upstream landings, verify the eval warnings actually drop to 0 (re-run the five-classes grep).

(20 items listed — the remaining next-work lives in the domain libraries; this session's §f obligations are fully harvested.)

## g) QUESTIONS FOR THE OWNER

1. **The 6 failing VM tests**: want me to triage them now with full provenance (even though the concurrent session may still be mid-flight), or do you want the other session to finish its disko/hot-tier wave first and I re-check after?
2. **dead-guard-lint v2 guard-form coverage** (`[[ "$var" == … ]]` class exposed by `:967`): extend the scanner now (with harness fixture), or accept the documented blind spot until it bites?
3. **Hermes workspace-doc assertion** (`systemnix-workspace-doc: v2` failing at 07:03): do you know if the workspace doc content/version changed recently on purpose (another repo bump), or should I treat it as a real regression and root-cause it?

---

_Evidence anchors: CHANGELOG "negative-test-lints harness fully green" entry; `docs/todo/pipeline.md` closed row; `TODO_LIST.md` closed row; sweep report §d/§e; commits `716e3953` (my 4 code files, daemon-swept with the concurrent session's 2)._
