# Takeout/Immich Key-Converger Batch — 5-Item Dispatch Status + Self-Review

**Session:** 2026-11-17 ~16:14 → 19:49 (single tq dispatch, task `000001a1e6539db907e725eba7a600000000`)
**Batch:** 5 services items (TODO_LIST rows 458–462 pre-session numbering) — Takeout/Immich key-converger consolidation, drive-paperless pairing, post-deploy battery leg, verify hardening trio, status one-liner.
**Verdict channel:** recorded via `tq verdict` (success, 5/5 items, 6 commits listed; `0f49231a5` and `9ac18370a` landed AFTER the verdict was written — see §d.9).
**Headline:** all 5 items closed, full `nix flake check --no-build --all-systems` GREEN, evo-x2 toplevel eval GREEN, takeout-selftests check GREEN at exactly 78 legs. One TWIN-EXECUTOR event (a sibling fire of the SAME task id worked the batch concurrently), one foreign eval-gate breakage (cvagent.nix, fixed by its own session), one OOM-137 on the first full flake check.

---

## a) FULLY DONE

### Batch items (all 5 ticked on both queue surfaces)

1. **Item 1 — Takeout/Immich key-converger consolidation** (discordsync + media-atlas onto `services.immich.apiKeys`).
   Landed by the PRIOR fire in `e30c08343` (00:03, footer-bearing): `apiKeys.discordsync-lookup` + `apiKeys.media-atlas-hub` onto the single root converger `immich-api-key-provision`; standalone discordsync converger unit+timer deleted; deploy.sh loop + runbooks + shape test follow.
   My session: re-dispatch verification (protocol steps 1–5) — `discordsync-immich-shape` check rebuilt GREEN (rc=0); both queue surfaces ticked with the verification narrative. Commit `0a0b66d40`.

2. **Item 2 — drive-paperless onto the shared Immich converger.**
   Landed by the 2026-11-16 parallel session via daemon commits `f392d564e`/`586d75b00` (NO footer — footless class). My session: verified on merits — `drive-ingest-fixture` check rebuilt GREEN (rc=0); `apiKeys.drive-paperless` (asset.read+asset.upload, ingest-owner file, restartUnits) confirmed in-tree; the ingest reads `/var/lib/immich-api-keys/drive-paperless.env` as its second EnvironmentFile with a loud key-reject preflight naming the rotate command; `drive_paperless_immich_api_key` sops option REMOVED from sops.nix (comment-only residue); `platforms/nixos/secrets/drive-paperless-immich.yaml` scaffold deleted. Both queue surfaces ticked. Commit `bed0deb60`.

3. **Item 3 — post-deploy battery: §25 Takeout Immich converger acceptance + dedup preflight.**
   IMPLEMENTED THIS SESSION (then swept + ticked through the twin-executor tangle, see §e.1). Five probes in `scripts/post-deploy-check.sh` §25:
   - converger unit active (`immich-api-key-provision.service`, oneshot RemainAfterExit);
   - `/var/lib/immich-api-keys/takeout-import.env` present + 0400 + `IMMICH_API_KEY=` line;
   - api_key DB row `takeout-import (nix-managed)` = 1 row / 16 permissions via `sudo -n setpriv --reuid postgres … psql` (WARN-skip without sudo, never a false FAIL);
   - journal markers: `minted takeout-import` <2h = "minted THIS deploy window", else mint-or-converge <30h (daily timer + 6h RandomizedDelaySec = 30h worst-case gap), regex-safe patterns (`--grep=` form; an unescaped `(` in the first pattern matched nothing — live-caught);
   - `takeout-dedup.sh balance --preflight` sweep over `scripts/takeout-accounts.tsv` (header row skipped; empty-zips = SKIP — import-time honesty stays with G2).
     EVERY probe live-verified against the host before landing: DB probe answers `1/16`; the mint journal line (15:12:13, gen-1012) matched by the corrected pattern; the registry loop SKIP/PASS verified on both accounts.
     **Four real bugs found and fixed in this leg before/just-after landing:** (1) SQL `count(*) || array_length(permissions,1)` mixed aggregate+non-aggregate → ERROR (fixed: `max(array_length(...))`, live-verified `1/16`); (2) unescaped-ERE paren in the converged grep matched nothing; (3) the 2h minted-window was too tight for the 30h jitter math (branch restructured to 2h/30h); (4) registry header row parsed as data; (5) empty-zips staging reported FAIL instead of SKIP. Fixes carried by daemon `0ba8ec7cb` (footless, traced post-hoc), the vacuous-cycle fix below by `0f49231a5`. Battery tick: sibling's `215e200c0`.

4. **Item 4 — verify hardening trio.** IMPLEMENTED THIS SESSION.
   - **Per-account manifest path:** the embedded 68-product `PRODUCTS_MANIFEST` block is GONE from `scripts/takeout-verify.sh`; it now lives as DATA at `scripts/takeout-manifests/racedriver8k.products.tsv` (69 lines = header + 68 rows, all 3-field, shape-validated). `--manifest <path>` validates existence + header line with clear die messages; the `racedriver8k` literal whitelist is deleted.
   - **Product-size band gate (G2.3):** a matched present-product's actual zip bytes must sit inside `size_band(expected)` (±15%; plain-integer = exact; new `<N unit` case for export-page "<1 MB" forms) — a stale/partial/wrong-size manifest now FAILS loudly instead of certifying completeness.
   - **Extras→FAIL under an explicit manifest:** a folder the manifest doesn't list = hard FAIL (manifest proven partial); WARN kept on the self-derived path (unreachable by construction).
   - **Selftest:** fixture products.tsv sizes corrected to actual fixture bytes; new legs `file-manifest` (path seeding passes), `partial-manifest` (some correct rows + one wrong size + one omitted product must STILL fail — via BOTH the size gate and the extras gate), `no-hash` (green, no SHA256SUMS written). 11 legs green (was 9: −manifest-optin +3). CI floor `want_pass=9→11`; `takeout-selftests` check BUILT GREEN with exactly 78 leg lines matching the new floors (11+21+14+7+9+8+8).
     Two lint blocks fixed: SC2034 (awk projection for the inventory bytes map), SC2100 false positives on hyphenated `leg=` assignments (renamed `leak-manifest`/`file-manifest`; queued the docs row rather than suppress).

5. **Item 5 — Takeout `status` one-liner.** IMPLEMENTED THIS SESSION.
   `scripts/takeout-status.sh` (259 lines): per-registered-account one-line truth — parts N/M (parts.tsv-declared names present in zips/), ledger rows+bytes (dedup ledger), `balance --preflight` verdict (PASS/FAIL/SKIP), last verify stamp (verification-report.md G2 GREEN/FAIL(n) + date). Table + `--tsv` + `--account` filters; read-only. Selftest 8 legs (parts count, ledger stats, preflight pass/fail/skip, verify stamps green+fail, missing staging, missing root) wired into `takeout-selftests` with a floor. **The selftest caught two real bugs pre-landing:** (1) a bare "unknown" cycle filtered the ledger to zero rows → balance reported a VACUOUS PASS (fixed: latest-ledger-cycle fallback); (2) fixture zips must be real archives (balance reads `unzip -l` listings). LIVE output reproduces the known fleet state exactly: racedriver8k 0/23 + preflight SKIP; helpless.ai 7/7 + 6582 rows / 19.41 GB + preflight PASS + G2 GREEN 2026-11-14 16:16. Closed by my `bca66b787`.

### Extra work this session

6. **Follow-up harvest (3 rows + library entries)** — commit `8a79b83e2`: size_band real-range check (the 04-11 report's unharvested §f20, now doubly load-bearing), converger mktemp debris sweep (5 orphan 0400 files live in `/var/lib/immich-api-keys` from the gen-1010 mint crashes), shellcheck SC2100 hyphenated-leg false positive.
7. **Battery vacuous-cycle fix** — commit `0f49231a5` (see §d.2): the §25 sweep got the same latest-ledger-cycle fallback as the status script (live-verified: helpless.ai resolves 2026-11-13).
8. **docs/services/takeout.md**: new "Fleet status (one command)" + "Post-deploy battery (§25)" sections; step-6 rewritten for the manifest path, size bands, extras-FAIL semantics, `--no-hash`.
9. **Session-wide gates:** full `nix flake check --no-build --all-systems` GREEN (warm retry, see §d.8); `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` GREEN (the foreign cvagent breakage had blocked this mid-session; its session fixed it in `c1cb80ebd`).

## b) PARTIALLY DONE

1. **§25 has never run END-TO-END inside a real battery invocation.** Every probe is piecewise live-verified and the loop was live-tested, but the full 2,700-line battery was deliberately not fired mid-session (it restarts services — signoz-coverage-metrics, monitor365 — and the box had parallel sessions). First real run rides the next deploy's smoke.
2. **Item 4's size gate is fixture-proven only.** The real racedriver8k manifest (±15% bands vs actual zip bytes) reconciles at its G2 — which is owner-blocked (0/23 clicks). The `size_band` real-range row (harvested §f20) covers the pre-check.
3. **helpless.ai has no account manifest yet.** The mechanism exists (`scripts/takeout-manifests/<account>.products.tsv`) but has exactly one resident; account #2's G2 stays on the self-derived UNPROVEN path until its exports page is saved into a manifest.
4. **Attribution chain for items 3–4 is indirect.** My implementation rode footless daemon sweeps (`1962977a1`, `026ebc835`, `0ba8ec7cb`); the queue-surface ticks for those items were written by the sibling fire (`215e200c0`, `9ac18370a`) on top. My own footer-bearing evidence commits exist (`0f49231a5`, `bca66b787`, `8a79b83e2`) but the item-3/4 tick hunks themselves are not in my footed commits. Re-dispatch protocol step-4 is satisfied in spirit (footer-bearing evidence exists per item) not in letter (tick hunks footless).
5. **The verdict JSON's commit list predates two commits** (`0f49231a5` cycle fix, sibling's `9ac18370a`). The verdict channel is single-shot; the correction lives in this report.
6. **docs updates:** runbook sections landed, but the takeout runbook is still not linked from the AGENTS.md knowledge-routing table (pre-existing open row — out of batch scope, untouched).

## c) NOT STARTED

1. The 3 harvested follow-up rows themselves (size_band real ranges, converger mktemp sweep + selftest leg, SC2100 idiom doc) — queued as `[ready]`, not implemented.
2. Any deploy — nothing in the batch required one (all changed surfaces are repo-side scripts/docs; the §25 leg activates with the next natural deploy's post-deploy run).
3. Manifest files for accounts #2+ (needs their exports pages, owner-blocked).
4. The `--emit-floor` selftest ergonomics idea (existing `[decision]` row, not mine, not touched).
5. An interim status report mid-session — I only write this final one now (the 17:46 sibling-conflict discovery would have been the right checkpoint).

## d) TOTALLY FUCKED UP (honest list)

1. **I structurally broke `takeout-verify.sh` mid-session.** One multiedit's `old_string` boundary swallowed the `leg=raw-names` opener and injected a stray `if [ "$rc" -eq 0 ]; then` → PARSE-BROKEN (`bash -n` failed, dangling `fi` arithmetic). Repaired in the next tool call. **The working tree carried a broken file while the daemon swept every few minutes** — I verified afterwards that the swept snapshot (`2108d3f94`) contained the PRE-edit version, so no broken state landed. Luck, not process. A large single multiedit on a shared-tree file with a live daemon is the anti-pattern; per-symbol `lsp_replace_symbol` or split edits were the right tools.
2. **I shipped the §25 battery leg with the exact vacuous-PASS bug I had just fixed in `takeout-status.sh`** — cycle fallback "unknown" → ledger filtered to zero rows → balance PASSes vacuously. Found it during THIS report's self-review, not during the item work. Fixed same-hour (`0f49231a5`), but the fix application discipline (one lesson → all sibling surfaces in the same pass) failed.
3. **Race losses, repeatedly:** item-1 commit swept before my add (empty-staged "nothing to commit"); two tick edits rejected on mod-time checks; my services.md item-3 tick CLOBBERED by the sibling's file write; the TODO_LIST item-5 tick hunk rode a footless daemon commit while my pathspec commit carried only services.md. Each was repaired, but the aggregate cost was ~30–40 min and three attribution scars. I polled AFTER failures instead of establishing a quiescence check BEFORE shared-file edits.
4. **Twin-executor detection was LATE.** The sibling fire of my exact task id was visible from ~16:23 (its commits) and I still discovered the collision only at 17:46 — when my edit hit "old_string not found" against a §25 block I hadn't written. I then spent real effort on provenance forensics (whose §25?) instead of an immediate ownership handshake. The plan-marker discipline (`EXECUTING (instance, ts, HEAD)`) exists for plan files; the batch had no equivalent marker.
5. **Over-investigation of the shellcheck SC2100 quirk:** ~30+ min of bisecting a parser false-positive AFTER a rename test had already proven the workaround. Should have been: repro → rename → move on, doc the quirk in the follow-up row (done) — total 5 min.
6. **Flake check OOM (rc=137):** I launched the known ~20 GB full check while multiple parallel sessions were committing, without a memory-pressure glance. Warm retry passed; the first attempt was avoidable load on a busy box (the documented hook-OOM class).
7. **Under-used a verified capability:** `sudo -n true` returned 0 in this shell (17:46 probe) — I could have cleaned the 5 orphan `.immich-api-key.*` tmp files with one command and instead queued the row (the unit-side sweep leg is still the durable fix, but the one-time hygiene was in reach and I deferred it).
8. **`/tmp` for bisect scratch** (`/tmp/tv-*.sh`, `/tmp/ts-cut.sh`) — doctrine says multi-step pipeline intermediates live under `~/.cache/`. Zero loss (cleaned up, nothing died mid-pipeline), but a doctrine miss on exactly the volatile-path rule.
9. **Verdict written before the last two commits existed** (`0f49231a5`, sibling `9ac18370a`) — the single-shot verdict channel now understates the final state by two footed commits; this report is the correction.
10. **Bug-attribution laziness:** the carrying commit for my §25 fixes (`0ba8ec7cb`) was only traced during this report — during the session I knew the fixes were in HEAD but not WHICH commit owned them.

## e) WHAT WE SHOULD IMPROVE

1. **Same-lesson-same-pass rule for shared logic:** when a fix (the ledger-cycle fallback) lands in one consumer of a contract (status script), sweep ALL consumers written in the same session (battery leg) before committing. One grep for `cycle` across the two files would have caught it.
2. **Batch-item execution marker:** extend the plan-marker discipline to tq batches — write `EXECUTING (instance, ts, HEAD)` into the batch's queue-section header (or a `docs/status/tasks/` claim file) BEFORE item work, so a sibling fire sees ownership in seconds instead of via edit-collision archaeology.
3. **Shared-queue-file edit protocol:** before editing TODO_LIST/services.md, check `git status --short` + file mtime AND re-grep the row text; after a mod-time rejection, re-read + re-apply + commit in ONE tool call (I converged on this by the end — it should have been the opening move).
4. **Large structured edits under a live daemon:** prefer `lsp_replace_symbol` (exact symbol boundaries) or several small `edit`s over one giant multiedit with far-apart boundaries — the boundary swallow that broke verify.sh was a direct consequence. <!-- format:allow -->
5. **Live-probe-first for battery legs:** this session's §25 bugs (SQL aggregate, paren grep, header row, empty-zips) were ALL caught by running the probes against the live host before commit. Make "run the new leg's probes standalone against live state" a required step for every battery leg (it caught 5 issues; zero false alarms).
6. **Selftest-before-land for every new script:** the status script's 8 legs caught 3 real bugs (registry env injection, NR assumptions, fake-zip fixtures) + 1 design bug (vacuous cycle). The pattern held; codify it as the default for new fleet scripts (it already is de facto for takeout scripts).
7. **Time-box parser forensics:** when a lint finding survives its first targeted fix attempt, fix-by-workaround + queue the doc row; do not bisect a third-party parser for 30 minutes inside a dispatch.
8. **Memory-pressure glance before heavy evals:** `free -g` / PSI check before `nix flake check` when sessions >1 are active; prefer the warm retry path.
9. **Attribution tracing at commit time, not report time:** after any daemon-swept landing, `git log -S'<marker>'` once to name the carrying commit while the context is fresh.
10. **Doctrine reminder — scratch under `~/.cache`, never `/tmp`** (self-violated once this session; zero damage, pure luck of no mid-session wipe).

## f) NEXT (up to 50, from THIS session's observations only)

**Immediate (this batch's loose ends):**

1. One-time cleanup of the 5 orphan `.immich-api-key.*` tmp files in `/var/lib/immich-api-keys` (sudo -n works in this shell class; verify ages >1 day first).
2. Run the FULL `post-deploy-check.sh` at the next deploy window — prove §25 end-to-end in a real invocation (piecewise-verified only so far).
3. size_band real-range check against racedriver8k's live parts.tsv (queued row) BEFORE its G2 — the product-size gate makes a wrong unit parse fail-closed at verify time.
4. Converger mktemp sweep leg + selftest leg in `lib/immich-api-key-provision.nix` (queued row).
5. SC2100 idiom note in docs/agents/shell-devtools.md (queued row) + a committed minimal repro file.
6. Take the battery §25's inline balance-sweep loop and extract it to a fixture-tested lib (the verdict mapping — SKIP/PASS/FAIL — is untested as a unit; house pattern: pressure-report.sh style).
7. §25 journal-marker window: derive "this deploy window" from `/var/log/systemnix-deploys/<ts>.log` timestamps instead of the hardcoded 2h.
8. Assert the OTHER converger consumers' env files in §25 (discordsync-lookup.env, media-atlas-hub.env, drive-paperless.env exist + 0400) — the leg currently checks takeout-import only while the converger mints 4 keys.
9. Extend the §25 DB probe to per-key permission counts pulled from each declaration (today only takeout-import's 16).
10. Pair-drift audit across items 1–5: confirm every queue one-liner tick text and its library row carry the same DONE narrative (items 3–4 were sibling-ticked; I audited 1/2/5 only).
11. helplesss.ai exports page → `scripts/takeout-manifests/lars-helpless-ai.products.tsv` (its G2 upgrades from UNPROVEN self-derived to manifest-proven).
12. Manifest template + how-to for new accounts in docs/services/takeout.md (header shape + size-band semantics + `<N unit` forms).
13. Verify-script: reject duplicate product rows in a manifest at seed time (today a dup row double-evaluates in the coverage loop).
14. Verify-script: validate 3-field row shapes at seed time, not just the header line.
15. accounts.tsv: add a `manifest` column (machine-readable per-account manifest path) + verify-script auto-discovery option.
16. Battery §25: WARN when the registry parses to zero usable rows (degenerate-registry guard).
17. Battery §25: on preflight FAIL include the first mismatch detail lines, not just the verdict line (tail -n1 loses the MISMATCH product list).
18. takeout-dedup balance: richer preflight tail line with COLD count ("N COLD") so the one-liner consumers show why a PASS is only partial.
19. Verify: WARN when products.tsv mtime predates the newest zip mtime (stale-expectation surfacing — the exact-size re-run trap is documented but invisible).
20. takeout-status.sh: `--json` output mode for automation consumers.
21. takeout-status.sh: surface the registry `status` gate column (g1-owner-clicks etc.) per row — pipeline truth should include WHERE each account is in the gates.
22. takeout-status.sh: include the staging root path in `--tsv` rows (machine consumers need the path).
23. takeout-status.sh: surface cadence/retain columns in the table.
24. takeout-status.sh: die message when `TAKEOUT_REGISTRY` points at a missing file (currently generic).
25. Battery §25: pull the immich DB name from the integration manifest instead of the hardcoded `immich` (manifest-bridge doctrine).
26. Add a band-edge selftest leg (actual bytes exactly at lo/hi) to lock the ±15% gate's inclusive bounds.
27. Ledger scale note: ledger_stats is O(rows) per account — fine at 6.6k, add an index-by-account pass if the fleet ever crosses ~100k rows.
28. §25 leg ordering: consider moving it before the long HTTP sections for faster deploy-failure feedback (minor).
29. Env-file token shape check in §25 (base64-ish 32-char length sanity) — cheap extra assertion.
30. `_tk_mode` in the battery registry loop is parsed but unused — micro-cleanup.
31. AGENTS.md routing table: add docs/services/takeout.md (pre-existing open row, still open after this session).
32. Fleet-plan §CI: document the four (now six) selftest batteries + leg floors (report §f21/§f35, partially done via selftests.nix comments).
33. Plan-file hygiene: prune the takeout plan's completed rows into an EXECUTED block (report §f36).
34. `Takeout/` prefix schema decision: still awaits the owner's §g2 answer (report §g2/§f37) — blocks the ledger normalization work.
35. Confirm media-atlas's apiKeys declaration has shape-test coverage of its own (discordsync does; media-atlas rides the evo-x2 eval + my probes only).
36. Shellcheck: repo-wide grep for hyphenated `leg=` assignments in other selftest drivers (pre-empt the SC2100 class elsewhere).
37. Add the flake-check OOM-137 datapoint (parallel sessions, warm retry green) to the hook-OOM row's evidence.
38. tq verdict channel: support an amend/append (this session's two late commits could not be reflected).
39. Queue derivation: count a sibling-fire's footed tick as THIS fire's evidence (the 5-item batch closed cleanly despite twin execution — worth encoding rather than relying on luck).
40. Interim status reports at conflict-discovery points (my §d.4 lesson, process not tooling).
41. Verify: hint "wrong staging root?" in the die when a manifest is present and failures > 50 (the empty-staging + full-manifest shape).
42. takeout-verify: self-derived products.tsv staleness — if the derive file exists AND manifest mode is requested, WARN that seeding is skipped (file wins).
43. docs/agents/shell-devtools.md: also document that `local` + arithmetic-looking assignments interact with shellcheck in selftest contexts (adjacent to SC2100).
44. Battery: consider a `--section-25-only` fast path for iterating takeout legs (pattern exists for §11/§16).
45. status script: cap ledger read with a tail window option for speed on huge ledgers (paired with 27).

**Deliberately NOT queued (owner-gated / out of scope):** racedriver8k G1 clicks, G4/G5 gates, OpenCloud decisions — all live in their own rows.

## g) QUESTIONS (cannot answer myself)

1. **Was the second concurrent fire of task `000001a1e6539db907…` intentional?** A sibling instance worked items 3–4 in parallel, ticked them on top of my daemon-swept implementation, and was still closing rows at 19:34 (`9ac18370a`). If twin fires are expected queue behavior, I'll keep the verify-not-redo posture; if not, I'd add a claim/lease marker to my batch-start ritual (and we should look at the dispatcher-side lease row that already exists for this class).
2. **§25's DB probe without sudo: WARN-skip (current) or FAIL?** Inside `deploy.sh` sudo always exists; standalone `nix run .#post-deploy-check` from an agent shell may not. Current behavior degrades to WARN-skip so the battery stays runnable anywhere — do you want the deploy-context run to hard-FAIL instead (stricter, and the leg is then always authoritative at the moment that matters)?
3. **The 5 orphan `.immich-api-key.*` tmp files: one-time `sudo rm` now, or leave them for the queued converger sweep leg?** They are 2026-11-15 mint-crash debris (root-owned 0400, unreferenced by any current key). Cleaning now is one command from a shell where sudo works; the sweep leg fixes the CLASS but only lands at the next deploy.

---

_Awaiting instructions._
