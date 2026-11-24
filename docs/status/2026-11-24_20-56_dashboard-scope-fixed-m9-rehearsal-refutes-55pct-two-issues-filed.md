# Status — 2026-11-24 20-56 — dashboard scope defect fixed, M9 rehearsal refutes my own 55% prediction, two issues filed

Session window: 2026-11-24 ~20:10 → 20:56 CET (continuation of the 15-47 report; the earlier window is `docs/status/2026-11-24_15-47_dashboard-scope-split-brain-and-nine-user-decision.md`).
Host `evo-x2`. Working repos: SystemNix, browser-history, cqrs-htmx (read-only there).

| repo | HEAD at report time | what this session did |
| --- | --- | --- |
| SystemNix | `ae5cde5c1` (+ a foreign `hermes.nix` edit left dirty by a sibling session) | queue + library rows, upstream annotation, status-report corrections |
| browser-history | `bba3081` (daemon-committed my four file groups) | `api/dashboard.go` fix, new regression test, oracle script, merge runbook, draft bodies |
| cqrs-htmx | `32b5cf12` + sibling dirt | one new P1 TODO row (release train), hygiene gate green |

No prod writes. No service restarts. No deploys. No pushes. DB work was read-only against the live file plus `.backup` copies under `~/.cache/bh-verify/`.

---

## 0. The answer in one paragraph

I turned the owner's question ("how can the scope change the scores but not the visits?") into a filed bug, a landed fix, and a test that would have caught it — **browser-history#28** (`?scope=all` kept the personal visit total and visit list while every other counter and the headline score unscoped; fixed by taking the filter's user from the scoped context, `api/dashboard.go:379`). Then I tried to close the *other* half (the stale anonymous buckets) by actually running the documented remedy on a copy, and it **refuted my own report's prediction**: `claim-orphaned` converges the scopes but count-adds the derived `domains` aggregate, so the headline score moves 54.72% → **43.65%** (not ~55%) and per-domain counters triple (`www.youtube.com` 334 → 1,878). That is filed as **browser-history#29**. Net: the scope defect is closed in code, the data defect is now correctly understood and blocked on a missing rebuild path rather than on a stop-window alone.

---

## a) FULLY DONE (evidence attached)

1. **Reproduced the defect at both relevant revs before touching anything.** `api/dashboard.go` is unchanged across the deployed `fa68d88..0b50d3f`, so every citation holds for the running binary and for master; verbatim quotes captured from `git show fa68d88:<file>`. Deployed rev confirmed an ancestor of HEAD (`merge-base --is-ancestor`).
2. **Wrote the failing test first.** `api/tenancy_scope_counts_test.go` (committed `4ef284b`): two users, one visit each to the **same domain with distinct paths** (so the unscoped domains table cannot satisfy the assertion), asserting the `Total visits` **stat card value**, not the page body. RED on the old code:
   `super admin ?scope=all: Total visits = 1, want 2` and `visit list: missing "plain-path-marker"`.
3. **Fixed the handler.** `api/dashboard.go:375-390` (committed `99a3fa9`): the visit filter's user now comes from the scoped context (`scopeUser := visit.UserIDFromCtx(ctx)`), with the multi-user clear retained because `tenantScopeCtx` wraps `userReadCtx` and the single-user id survives beside the multi-user scope. Byte-identical behaviour for the default and tenant scopes.
4. **Verified.** New test GREEN; `TestTenancy_SuperAdminAllScope`, `TenantAdminScope`, `CrossTenantInvisible` GREEN; **full `go test ./api/` green in 56.5 s**; `go vet ./api/...` rc=0; `gofmt -l` clean; `scripts/check-lint.sh --changed` → **0 issues**.
5. **Filed browser-history#28** (7,985-byte body, verified by re-reading `gh issue view --json body`): symptom table, what breaks, source-level cause quoted at `fa68d88`, why the existing body-grep test hides it, the suggested two-line fix, an explicit "out of scope" section for the data residue, and a `## To verify` checklist. Gates 1–5 of `verify-before-filing` run first; no existing open/closed issue covered it.
6. **Filed browser-history#29** (5,559 bytes, #29): the rehearsal-measured defect above, with the honest note that the CLI's additive merge is a documented, deliberate choice whose premise ("would silently drop the newer aggregate") is true but which over-counts duplicate buckets, plus the ask (rebuild/delete mode) and the existing behavioural numbers it must not disturb.
7. **Promoted the oracle into the repo.** `scripts/dashboard-scope-oracle.sh` (committed `b1ce2d8`): reproduces every dashboard card from SQL per scope from a DB path argument, prints the user buckets, and warns when anonymous `domains` rows exist. Verified against `~/.cache/bh-verify/live-copy.sqlite` — it reproduces the pre-claim state exactly (6,943 / 167 / 335 / 100 / 56 / 54.72% vs 6,943 / 301 / 750 / 225 / 114 / 31.81%).
8. **Built the server from HEAD** (the morning's three build failures are gone now that `go.work` reads 1.27.3) and ran the M9 **dry run** on the copy: 138,805 events scanned / **135,035 rewritten**, sessions 415, domains 240, search 125, downloads 58, bookmarks 7, omnibox 2, form_history 20, permissions 5 — identical to the 2026-10-15 rehearsal.
9. **Ran the M9 rehearsal to completion on a throwaway copy.** Scopes converge (All == Personal: 6,943 / 301 / 750 / 136 / 58); re-run is an idempotent no-op (all zeros); domain counters triple; score 43.65%. Measured the source-of-truth comparison too (`visits` rows per domain), which is what proved the counters are not reconcilable by addition.
10. **Corrected my own record.** The 15-47 report's "166 + 162 + 78 = 406" partition added *rows* while `CountDomains` is `COUNT(DISTINCT domain)`; the true split is **171 + 134 = 305**. Report annotated, queue row and library row rewritten with the corrected arithmetic, both now `[blocked:push]` with the fix reference.
11. **Converged every surface that carried the stale story:** SystemNix `TODO_LIST.md:450` and `docs/todo/services.md:13` (both rewritten), `docs/todo/services.md:14` (claim-orphaned row now carries the rehearsal numbers and the owner-order warning), `docs/todo/upstream.md:13` (`MergeUsers` is no longer "nothing shipped upstream" — it is in-tree and unshippable until the train), browser-history `docs/runbooks/merge-duplicate-users.md` (decision of record + step 7 marked DEFERRED), browser-history `TODO_LIST.md:153` (M9 row now names the blocked domains leg), SystemNix `docs/services/browser-history.md` (stale `database has 5 users` example → `reads 9 live 2026-11-24`; plus a live-read recipe correction).
12. **Added the missing cqrs-htmx row.** The wave landed M08–M25 but `TODO_LIST.md` had no row saying "run the train, then this is consumable" — now the top P1 row names the sequence, the by-construction red gates, and the #46/#47 closure. `nix run .#check-todo-hygiene` → `clean (TOTAL rows=135 dead=0 violations=0 preamble=570)`.
13. **SystemNix todo gate green** after every edit: `OK: TODO queue/library structure clean` (the 99 unharvested-report WARNs are the pre-existing fleet condition, not from this run).

---

## b) PARTIALLY DONE

1. **Issue #28's "in the working tree, unpushed" sentence is now half-stale.** The auto-commit daemon committed `dashboard.go` + the test six minutes after filing, so the body says "working tree" where the code is now committed-but-unpushed. The claim stays true (nothing is pushed); the wording is now softer than reality.
2. **Two-scope rendering under a *genuinely* multi-user database is verified only at body level.** Today's prod DB has one `visits` bucket, so the pre-fix bug was invisible in the visit table; my test creates a real second user, but only in the fixture DB. No end-to-end proof exists against a two-user production-like snapshot (none exists to test against).
3. **The oracle script is a tool, not a gate.** It reproduces the cards, but nothing runs it in CI and it has no selftest — a change in `CountDomains` semantics would not fail anything.
4. **The `domains.visit_count` semantics are now understood but undocumented in the repo.** I inferred "one increment per new visit event" from `projection/visit_projection.go:227-240`; the card, the CLI merge and the score all depend on that meaning and no doc states it.
5. **`docs/services/browser-history.md`'s pool-backup section is corrected but not restructured.** I appended the 2026-11-24 live-read recipe; the older "use an OLDER backup (Oct ≤23)" advice still sits there as if it were the primary path.

---

## c) NOT STARTED (deliberately, with the reason)

1. **No CHANGELOG entry in browser-history for the scope fix.** The repo has an `[Unreleased]` section and the sibling cqrs-htmx wave wrote entries; this fix has none. Deliberately left for the next pass because the owner asked for a report first.
2. **No `docs/status/` report inside browser-history.** The evidence lives in the issue bodies plus this SystemNix report; that repo's own session-record convention has not been honoured.
3. **browser-history docs gates not run** (`scripts/check-docs-archive.sh`, `check-templ-canonical.sh` etc.). The runbook edit is prose and the templ tree is untouched, so the risk is low — but "low risk" is not "verified".
4. **The `domains` rebuild itself.** #29 asks for it; writing the subcommand is a code change in a repo that is push-gated, and it needs a decision on semantics (per-event counts vs per-URL) before implementation.
5. **`compact-visit-journal` rehearsal.** The half of the M9 window I did not rehearse on the copy; only `claim-orphaned` was measured. So the "202.9 MB → 19.8 MB" figure is still the 2026-10-07 number for the 2026-11-24 dataset.
6. **No push, no deploy, no tag.** Everything is committed locally and unpushed by policy.
7. **Did not touch** `modules/nixos/services/browser-history.nix:859` (the `browser_history_users 9` gatus literal) — correct per the decision of record, and it stays untouched until the merging deploy.
8. **Did not touch** the cqrs-htmx `adminui` compile surface or the sibling's in-flight files, beyond reading the sibling's status report. The `adminui/tenant_surface_test.go` dirt at report time belongs to them.

---

## d) TOTALLY FUCKED UP (honest ledger)

1. **I ran the built server binary with no subcommand.** `./bh-server` (no args) starts the server; it created `~/.cache/bh-verify/browser-history.db` (380 KB) and then failed to bind `:8080` and shut down cleanly after the 60 s timeout. No prod effect, no port held, no state touched — but it is exactly the "never execute the server binary to probe" class I had written into the service doc *in the same session*, minutes earlier. The correct probe was `grep os.Args cmd/browser-history-server/main.go`, which I then used.
2. **My previous report shipped an unverified number.** "Unique domains 166 → 406, partition 166 + 162 + 78" mixed row counts with a `COUNT(DISTINCT domain)` card. The owner read that table; I had to retract it tonight. This is the AGENTS.md quote-scrutiny rule violated in its exact shape: I quoted a number from a pipeline it never ran through.
3. **I predicted "score back to ~55%" and it was wrong.** The prediction was in two SystemNix surfaces and one browser-history row before the rehearsal. Measured answer: 43.65%. Had I not actually run the procedure on a copy, the owner would have applied `claim-orphaned` to production expecting 55% and found 44% plus tripled domain counters — a self-inflicted "the fix made it worse" incident.
4. **I wrote a broken shell script twice.** `group_concat(user_id || "=" || n, ", ")` failed twice on this shell's SQLite (double quotes are identifiers): first on `"="`, then on `", "`. Fixed by switching to `printf('%s=%s', …)` inside a double-quoted bash string. Two wasted iterations that a single `sqlite3 ':memory:' "select 1||'='||2"` probe would have avoided.
5. **I let a test file name the wrong helper in my head** (`statValue(t, fx.dashboard(...), "label")`) and only relaxed after compile-checking — minor, but it is the second time this session I trusted a transcription over a compiler.
6. **I filed #28 before the daemon committed the fix**, which cost a wording correction that cannot be edited without breaking the banner's review ledger (the box is unchecked, so an edit would be honest — but the sentence is now weaker than the code).

---

## e) WHAT WE SHOULD IMPROVE

1. **Rehearse the documented remedy before quoting its expected outcome.** The single highest-value thing this session was running `claim-orphaned` on a copy; the single worst thing was having published "~55%" without it. Any row that says "expect X after op Y" should carry a receipt from a copy, or be marked "predicted, unverified".
2. **Distinct-count cards need distinct-count arithmetic.** A dashboard that mixes `COUNT(*)` cards with `COUNT(DISTINCT …)` cards will keep producing row-sum partitions in reports. The oracle script should be the canonical way to quote these numbers, and the report should cite the script's output, not hand-assembled arithmetic.
3. **Derived aggregates need a rebuild path or they rot.** `domains` is derived, edited by three different code paths (projection increment, CLI merge, override handler), and has no recompute. That is the structural reason tonight's second defect exists.
4. **A body-grep dashboard test is not a scope test.** `TestTenancy_SuperAdminAllScope` passed for months while the visit list was personal-scoped, because the unscoped domains table satisfied the string. Counter values, not page text, must be asserted for counter behaviour.
5. **The repo has a buildable-server path again; use `go build` + copies, never the deployed store binary.** Today's `go build ./cmd/browser-history-server` worked first try; the morning's three failures were a stale `go.work` reading 1.27.4.
6. **Queue/library/report convergence is a three-surface job.** Tonight I had to touch `TODO_LIST.md`, `docs/todo/services.md`, and the source report for one correction; the "assert WHICH surface the fix touched" rule exists precisely for this, and it still took four edits.

---

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

**Immediate (close the loop on tonight's work)**
1. Add a browser-history `CHANGELOG.md` `[Unreleased] → Fixed` entry for the `?scope=all` fix (one paragraph, issue #28).
2. Re-read #28's body and decide whether to soften "in the working tree" now that `99a3fa9` committed it (the banner's review box is still unchecked, so an edit is legitimate).
3. Decide the M9 order (see g.2) and, whichever way it goes, rewrite the `~55%` expectation in every remaining doc that still implies it. Four surfaces were updated before this report; the fifth — the "stop-window CLI recipe" bullet in `docs/services/browser-history.md` — was FIXED ON SIGHT while writing it (it now carries the 43.65%/tripled-counter warning). Re-grep for the figure once #29 lands, because the 55% baseline itself changes with the rebuild.
4. Rehearse `compact-visit-journal -yes -vacuum` on the same throwaway copy and record the real 2026-11-24 size delta beside the 202.9 MB → 19.8 MB historical figure.
5. Wire `scripts/dashboard-scope-oracle.sh` into a selftest or a flake check (a fixture DB with two users, assert the printed table).

**browser-history code**
6. Implement `rebuild-domain-stats` (delete derived rows for a user, re-seed via `CountVisitsForDomain`) — the real fix behind #29.
7. Or add `claim-orphaned -domains=merge|delete|rebuild` and print the chosen mode in the dry run.
8. Document `domains.visit_count` semantics (per visit event, not per URL, not `sum(visits.visit_count)`) in DOMAIN_LANGUAGE/AGENTS.
9. Decide whether `WeightedProductivity` should weight by visit events at all; if yes, the rebuild must preserve that meaning.
10. Add a two-user end-to-end dashboard test asserting all five counters AND both productivity cards move together under `scope=all`.
11. Consider updating `TestTenancy_SuperAdminAllScope` to assert the counter value rather than the body string (it passes today for the wrong reason).
12. Add a tenant-scope counter assertion (two members, one visit each ⇒ tenant scope counts 2) — existing tests only assert list membership.
13. Check whether the `searchQuery` client-side filter's `visitCount = len(visits)` override (`dashboard.go:869-873`) should also re-scope pagination under `scope=all` (it silently redefines the card).

**cqrs-htmx (owner-gated train)**
14. Answer Q1 and run `nix run .#wave-tag` for identity-model, then root, then the rest.
15. Sweep consumer requires between train steps (bump-dep), then `.#push-and-watch`.
16. Re-run the five by-construction-red gates after the train; expect green with zero code changes.
17. Close #46/#47 with the landing evidence once CI is green.
18. Fix the `adminui` imports the sibling flagged (`handler_users.go:8`, `handler_audit.go:6`) — or confirm the sibling session owns them.

**browser-history consumption of `MergeUsers`**
19. Bump browser-history's cqrs-htmx input to the tagged rev once the train lands.
20. Then run the real merge on the 9-row `users_view`, and only in that deploy move the gatus `browser_history_users` literal from 9.
21. Decide what happens to the local `merge-duplicate-users` CLI once the native path exists (delete, or keep documented as a fallback as the runbook now says).

**SystemNix records**
22. Reduce the 99 unharvested-report WARNs (pre-existing; the gate's `CHECK_TODO_HARVEST=strict` mode is unreachable today).
23. Reconsider the `[blocked:push]` tag on the two scope rows — once pushed, they become `[ready]` for the deploy step.
24. Add the two filed issues (#28/#29) to `docs/todo/upstream.md` as their own rows, not only as annotations on the existing ones.
25. Check whether the `docs/services/browser-history.md` pool-backup bullet should be split into "current path" + "historical workarounds".

**Process**
26. Make "predicted, unverified" a required label for any expected-outcome claim in a queue row.
27. Add a lint/hook idea: report tables that cite dashboard cards should name the producing SQL function beside the number.
28. Keep the `.backup` + `chown` live-read recipe the doc now carries (it worked first try, twice).
29. Delete `~/.cache/bh-verify/bh-server` (69 MB) when no longer needed; keep the two DB copies until #29 is resolved.
30. Delete the accidental `~/.cache/bh-verify/browser-history.db` (380 KB, from d.1).

**Watch-items**
31. If `claim-orphaned` is run on prod before #29 lands, the Top-domains table will show tripled counts — a reviewer will call it a regression; pre-empt it in the window checklist.
32. The rehearsal copy's journal grew (201 MB → 211 MB) after the claim; confirm that is WAL/journal rewrite growth, not a leak, in #29's thread.
33. Re-probe the anonymous bucket counts before the window; they move with browsing (167 → 171 owner rows in one day).
34. Re-confirm the 8 duplicate accounts still own zero rows before any merge deploy.
35. Confirm `browser_history_users 9` is still the live metric value at merge time.
36. Watch for a sibling session editing `adminui` while the train runs (the sibling status report warns about this).
37. Re-run `scripts/check-todo-system.sh` after the daemon commits tonight's rows (it was green pre-commit).
38. Re-run `nix run .#check-todo-hygiene` in cqrs-htmx after the sibling's next wave.

**Optional hardening**
39. Give the oracle script a `--json` output so future reports can quote it mechanically.
40. Add a `--diff` mode printing pre/post-claim state side by side (that comparison was done by hand twice tonight).
41. Consider a `domains` consistency check: per domain, compare `visit_count` against the event count derived from the journal; report drift.
42. Consider surfacing the same check in `/doctor`.
43. If the score is meant to be "share of productive browsing", verify the weight semantics against a hand-computed sample (I did not).
44. Add the two issue URLs to the 15-47 report's harvest disposition block (I annotated the report but not its harvest list).
45. Verify that the `scopeUser` change did not alter the `?search=` path's page count (full suite green, but no dedicated test).
46. Confirm the `qmd`/docs tooling indexes the new status file (out of scope tonight).
47. Consider whether `?scope=all` should also unscope the *sessions* table rendering (it already does; note it in the UI copy).
48. Consider a UI hint on the dashboard naming the scope of each card ("personal" vs "all users") — that would have made the original bug self-evident.
49. If #29's rebuild lands, re-baseline the productivity-score expectations in any doc that quotes 55%/32%.
50. Archive the 15-47 report once its two political items (the decision of record, this correction) have landed in the library rows — it is now fully harvested.

---

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. **What should `?scope=all` mean for the visit list and visit total?** I implemented the coherent reading — the whole page follows the scope, so "All tenants" shows every user's visits and their sum. The alternative reading is "All tenants" = aggregate counters only, with the visit table staying personal. Nothing in the code or docs states the intent; the UI copy says both ("All tenants" as a selector, "Total visits" as a card). Your call decides whether `99a3fa9` stands or becomes a narrower fix.
2. **Given the rehearsal (43.65%, tripled counters, scopes converged), what is the M9 order?** (a) hold `claim-orphaned` entirely until #29 ships a rebuild mode; (b) run it with the journal + behavioural legs only and rebuild `domains` afterwards; or (c) apply as-is and accept 44% with visibly inflated Top-domains counts. Only you can decide a stop-window shape for prod.
3. **Tag and push authority for the cqrs-htmx identity-merge wave.** The code is workspace-green but nothing is consumable: five hermetic gates are red by construction and browser-history cannot merge a single row until the modules are tagged. Do you want the train run now (`nix run .#wave-tag` + sweep + push + CI watch), or does it stay held behind a quieter window?

---

## Harvest disposition (self-harvested at authoring time)

| §f item | landed where |
| --- | --- |
| 1, 2 (CHANGELOG, #28 wording) | **not harvested** — 2–4 line edits in another repo, deliberately deferred to the owner's go-ahead after this report |
| 3, 4, 5 (M9 order, compact rehearsal, oracle gate) | folded into `docs/todo/services.md:14` (already annotated with the rehearsal + #29) and #29's body ("To verify") |
| 6, 7, 8, 9 (rebuild, flags, semantics, weighting) | #29 body, asks 1–2 + out-of-scope section |
| 10, 11, 12 (scope tests) | #28 body, `## To verify` + this report's b.2 |
| 13 (`searchQuery` override) | this report §f.13; not queued (needs a correctness judgement first) |
| 14–18 (cqrs train, adminui) | cqrs-htmx `TODO_LIST.md` P1 row (added tonight) |
| 19–21 (consumer merge) | SystemNix `docs/todo/upstream.md:13` annotation + `docs/todo/services.md:13` |
| 22, 23, 24 (SystemNix records) | `docs/todo/services.md` rows already rewritten; 22 is the standing fleet WARN, 24 noted here |
| 25 (`docs/services` split) | not queued — cosmetic, no owner decision needed |
| 26–30 (process, cleanup) | 29/30 are cache hygiene (see d.1); 26 is a doctrine suggestion for AGENTS.md, not a row |
| 31–38 (watch-items) | 31 folded into `docs/todo/services.md:14`; 33–35 belong to the merge/claim window checklist (already in the runbook) |
| 39–50 (optional) | not queued — no evidence they are needed yet |

## Session receipts

```
# browser-history
4ef284b  api/tenancy_scope_counts_test.go            (+111)
99a3fa9  api/dashboard.go + 2 draft files            (+154 −5)
b1ce2d8  docs/runbooks/merge-duplicate-users.md + scripts/dashboard-scope-oracle.sh (+96 −1)
bba3081  TODO_LIST.md + claim-orphaned draft         (+99 −1)

# SystemNix
de109e514 TODO_LIST.md + docs/todo/services.md
f49895897 docs/todo/services.md
53977f7b9 docs/todo/upstream.md
cc6853e6a docs/status/2026-11-24_15-47_… (correction block)

# cqrs-htmx
TODO_LIST.md — one P1 row (release train); hygiene: 135 rows, 0 dead, 0 violations, preamble 570

# verification commands that produced the numbers above
sudo -n sqlite3 -readonly /var/lib/private/browser-history/data.db "…"
bash scripts/dashboard-scope-oracle.sh ~/.cache/bh-verify/{live-copy,rehearsal-2026-11-24}.sqlite
go test ./api/ -run TestTenancy_AllScopeCountsEveryUser   # red before, green after
go test ./api/                                            # ok 56.5s
go vet ./api/... ; bash scripts/check-lint.sh --changed   # 0 issues
~/.cache/bh-verify/bh-server claim-orphaned -db <copy> -user-email …   # dry run, then -yes on a copy
bash scripts/check-todo-system.sh                         # OK structure clean (99 pre-existing WARNs)
nix run .#check-todo-hygiene                              # clean
```
