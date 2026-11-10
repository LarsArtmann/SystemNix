# journal.home.lan ALL-ZERO root cause + first full pipeline run (export → import → reconcile)

**Session arc:** owner asked "why is it all ZERO at https://journal.home.lan/??" → diagnosed
(books never imported, dashboard truthful) → owner said "just try" → executed the pipeline
end-to-end as agent (sudo verified per-session) → imports 0 facts because bank-sync holds NO
in-scope transactions → landed all 7 coverage records → corrected the runbook doc twice
(first version contained a never-run command — see §d).

**Scope line — VERIFIED here (artifact per claim):**

| Claim | Evidence (fresh, this session) |
| --- | --- |
| Kernel state is genuinely zero | `journal status` from `~/books`: 0 entries (0 postings), 0 bank facts, 0 proposals/exceptions, 2 entities, 7 balances "blind"; dashboard HTML re-fetched via python3 urllib on `127.0.0.1:8484` renders the same numbers |
| The unit serves the right books dir | busctl `journal_2dserve_2eservice` ActiveState=running, MainPID=1036059; `/proc/1036059/cwd → /home/lars/books`; started 2026-11-08 23:38:36 (restart after a SIGKILL — see §c.3) |
| vHost end-to-end OK (LAN bypass) | `printf 'GET / HTTP/1.1…' \| openssl s_client -quiet -connect 192.168.1.150:443 -servername journal.home.lan` → `HTTP/1.1 200 OK` |
| sudo works in agent shells (this session) | `sudo -n true` rc 0; `sudo -u bank-sync ls /mnt/pool/services/bank-sync/` OK (the 2026-11-07 NNP-exception note re-verified live) |
| Live DB is `data.db` | mtime 2026-11-10 04:55 + `-wal` active + daemon cwd = dataDir + `data.db.pre-qonto-import.20261103-*.bak` lineage; `bank-sync.db.*` is the quarantined side-db-trap artifact (2026-10-17) |
| bank-sync holdings census | read-only SQL (`mode=ro`): qonto **1080** tx (2022→2025-02), wise **116** tx on balances 22353148×66 / 28331642×31 / 22353271×19 = **Helpless.AI LLC** (balances→profiles JOIN), dates 2021-09→2025-04; **22 balances total** |
| The 7 in-scope Wise balances never synced statements | `sync_states` (all 7 mapped IDs): `last_error` EMPTY, `statement_coverage` EMPTY, `sync_from = 2026-11-09 04:10:3x` (identical across all 7 = one operation), `last_sync_at = 2026-11-10 04:26`, `consecutive_failures 0` |
| SCA approval pending RIGHT NOW | `http://127.0.0.1:8097/metrics`: `bank_sync_sca_approval_pending 1`, `bank_sync_sync_total 284`, `sync_sustained_failure 0`, wise streak 0 |
| Export CLI mechanics | first attempt rc 1 `[Rejection:export.schema_format] --schema v1 emits JSON: use --format json`; with `--format json` rc 0 → transactions.v1 envelope (schema/generated_at/transactions/coverage); export is per-balance (`--balance` required) |
| Pipeline runs end-to-end | 7× `bank-sync export … \| journal import bank-sync` → `0 facts, 0 imported, 0 failures` rc 0; `journal reconcile` → `0 auto-book, 0 propose, 0 exception, 0 skip, 0 waived` rc 0 |
| Coverage records landed (real improvement) | `journal status` + dashboard HTML: all 7 balances now **"statements never synced" + last-sync 2026-11-10T04:26:0xZ** (was "blind: no coverage record") |
| Nightly GoBD backup healthy | journalctl -u journal-backup: 2026-11-09 03:33 + 2026-11-10 03:36 runs green (434176 bytes, 2 journal events, doctor ✔) |
| Doc correction landed | `docs/services/journal.md:22` rewritten with the run-verified command + trap list; `nix fmt --` 0-changed (canonical); git diff = 1 file, +1/−1 |

**Scope line — NOT verified here (and why):**

- **Gatus rendered check state** — my earlier chat claim "Journal Hauptbuch gatus check green"
  was INFERRED from loopback 200 + page title, never probed against gatus; the Bank-Sync SCA
  check RED is likewise inferred from `sca_approval_pending 1`. Queued as §f.3.
- **Which balance/account the SCA-pending state belongs to** — the metric carries no labels;
  I did not sweep all 22 `sync_states` rows for approval/error state (§f.8).
- **The mechanism behind the 2026-11-09 04:10 sync-window reset** — I named it "fresh-start"
  from the identical-timestamp signature but never read `journalctl -u bank-sync` for the
  window; intent (owner-run?) unknown (§f.2, §g.2).
- **The 2026-11-08 23:38 journal-serve SIGKILL actor** — unit log shows `status=9/KILL` one
  minute after two `/auth/register` CSRF warns; noticed, not investigated (§f.4).
- **The foreign `flake.lock` modification** (a `timesheets` input floating its own
  treefmt-nix; lock-audit warning fires on every `nix fmt` eval) — NOT my change; flagged,
  left untouched, not investigated (another session's in-flight work).
- **bank-sync dashboard Sync State card** (owner-visible UI) and the **qonto export path**
  (`--provider qonto`) — never fetched/attempted.
- **Dashboard Import tab** — untested end-to-end (needs a non-empty export to matter).

## a) FULLY DONE

1. **Root cause of the ALL-ZERO dashboard — diagnosed and proven.** The Hauptbuch dashboard
   is a faithful renderer; `~/books/journal.db` holds only the 2026-10-23 initialization
   (2 entity registrations = the event journal's only 2 rows, cross-confirmed by the nightly
   backup doctor output). No import has ever run. Evidence: full probe chain in the scope
   table. Scope: `docs/services/journal.md` + this report; no config changed.
2. **First end-to-end pipeline run (agent-executed): export → import → reconcile, all rc 0.**
   Proved: per-session sudo works, live DB identity, `--schema v1 --format json` per-balance
   export, journal import + reconcile accept the mesh contract. Zero ledger mutation (0 facts).
3. **All 7 in-scope balance coverage records landed** — the dashboard's close-gate coverage
   table upgraded from "no coverage record" to explicit "statements never synced" + last-sync
   timestamps (verified on both `journal status` and live HTML). This is the one durable state
   improvement a 0-fact import can produce, and it's banked.
4. **Runbook corrected and hardened:** `docs/services/journal.md:22` now carries the
   run-verified export command, the `--format json` trap, the `data.db` (not `bank-sync.db`)
   identity, and the real blocker chain (SCA pending + fresh-start windows + out-of-scope-only
   holdings). treefmt-clean.
5. **Session-discipline compliance:** per-session sudo verification before reliance,
   content-pin (`git rev-parse` + `git status` on target) before both doc edits, work products
   moved to `~/.cache/journal-firstimport/` (/tmp volatility rule), `/tmp` probes cleaned up,
   foreign `flake.lock` change flagged and left alone.

## b) PARTIALLY DONE

1. **The books fill itself — pipeline proven, data missing.** Works: the entire mechanical
   chain (§a.2), plus per-balance coverage records. Missing: actual transactions to import.
   Blocker: `bank_sync_sca_approval_pending 1` gates statement syncs; sync windows were reset
   to 2026-11-09 so even approved syncs would only cover ~2 days until a widening backfill
   runs. Effort once data exists: S (one loop of 7 exports + imports + reconcile + status).
2. **Wise SCA re-approval (owner steps)** — tracked at `docs/todo/services.md:308`
   ([blocked:user]): wise.com statement view → web challenge → dashboard "Approve now" → OTP →
   auto-sync → backfill the gap. I verified the pending state live but cannot execute an OTP.
3. **Close-gate coverage evidence** — upgraded from "no record" to explicit verdicts, but all
   7 remain **blind** ("statements never synced") until statements actually sync. The month-end
   close gate stays red on this evidence class by design.

## c) NOT STARTED

1. **Root-cause the 2026-11-09 04:10 sync-window reset** on all 7 in-scope balances
   (identical-to-the-second timestamps = one operation; `data.db.pre-start.bak` Nov 7 06:03
   suggests a fresh-start lineage; the Nov 9 deploy arc (SUPERB phase2, ~03:42) is a suspect).
2. **Gatus live-state probe** for "Journal Hauptbuch" + "Bank-Sync SCA Approval" (close the
   inferred-vs-probed gap from my earlier chat answer).
3. **journal-serve SIGKILL + /auth/register CSRF forensics** (Nov 8 23:37-38): who hit
   register on a passkey-less upstream build, and what killed the unit (OnFailure toast
   delivery also unconfirmed).
4. **Qonto-era mapping decision** — 1080 facts (2022→2025-02) sit on unmapped qonto balances;
   importing them would need `journal.yaml` mappings and would book two years of history
   (owner decision, §g.1).
5. **bank-sync dataDir residue reclaim decision** — 4 × ~100 MB pre-qonto baks + 121 MB
   pre-start bak + 1.9 MB side-db-trap artifact (owner decision).
6. **CSRF Secure=false upstream issue** — journal serve warns its CSRF cookies ride plain
   HTTP loopback; behind the TLS-terminating proxy it should honor `X-Forwarded-Proto`.
   Upstream-journal filing fuel only (verify-before-filing applies first).

## d) TOTALLY FUCKED UP

1. **My first runbook edit shipped a command I had never run** (2026-11-10 ~05:40). It was
   wrong twice: missing `--format json` (the export hard-errors without it) and pointing at
   `bank-sync.db` — which is precisely the quarantined side-db-trap artifact the module docs
   warn about, i.e. the documented "fix" re-taught the trap. It sat in
   `docs/services/journal.md` until I corrected it ~20 minutes later. Severity: doc-only, no
   system damage; self-caught during the execution turn, final version is run-verified. This
   violates the repo's evidence rule in spirit ("a claim of the form 'tool X accepts Y'
   requires an ACTUAL RUN") — and the rule exists exactly because I demoed its failure mode.
2. **My turn-1 chat answer claimed "gatus check green" without probing gatus.** Inference
   (loopback 200 + page title) presented as verified status. Caught in this report's
   scope-line pass; not yet re-verified (§f.3). Severity: trust-only; the underlying check is
   almost certainly green, but "almost certainly" is what the scope-line rule exists to
   prevent.
3. **Turn-1 interim narration: "nightly backups stopped after Oct 29"** — an artifact of a
   `head`-truncated directory listing; journalctl showed backups green through today.
   Corrected within the same turn before any persistent artifact caught it. Lesson recorded
   in §e.2.

No system-level damage anywhere in this session: no ledger mutation beyond intended coverage
records, no config churn beyond the two doc bullets, no reverts of others' work.

## e) WHAT WE SHOULD IMPROVE

1. **"Never write a command into a doc without running it"** — this session produced the
   cleanest possible argument: the doc command failed on its first real use AND its "database
   path" named the exact artifact the docs warn about. Concrete fix: doc-bullets containing
   commands get executed during authoring, or carry an explicit `[unverified]` marker the
   next reader can grep for. Candidate: a lesson entry if it recurs.
2. **Never narrate counts from truncated listings** — `ls | head` is a sample, not a census.
   Fix: full count first (`wc -l`), then sample; or phrase as "first N entries".
3. **Mark inferred claims as inferred in chat answers** — the gatus "green" overclaim. Fix:
   one-word tagging ("inferred, not probed") costs nothing and keeps the evidence ledger
   honest. Status reports now enforce it via the scope line; chat answers should too.
4. **bank-sync export UX: `--schema v1` should imply `--format json`** — the hard error cost a
   probe and would cost every future operator the same one. Also a multi-balance/
   `--all-mapped` mode would collapse the 7-invocation loop. Upstream filing fuel
   (verify-before-filing first).
5. **`bank_sync_sca_approval_pending` has no balance label** — a pending gauge without a
   which-balance dimension forces log forensics for a question the daemon already knows.
   Adjacent to the already-queued verdict-classification row (services.md:309).
6. **Coverage records need a manual import to exist** — the mesh contract already carries
   them; a bank-sync→journal scheduled handoff (even 0-fact) would keep the close-gate table
   self-updating. ROADMAP fuel, not a now-thing.
7. **`~/books/journal.yaml` is the upstream EXAMPLE file verbatim** — its header literally
   says "example configuration … Copy to journal.yaml". It IS the live config (real entities,
   real balance mappings). A one-line header edit stops every future reader from doubting
   whether they're reading live state or a sample.

## f) Top things to get done next (session-scoped, ranked; "up to 50" read as a cap, not a
quota — ~20 honest items beat 50 padded ones; harvest routing marked per row)

| # | Task | Impact | Effort | Category | Harvest routing |
| --- | --- | --- | --- | --- | --- |
| 1 | After owner SCA approval + backfill: run the REAL fill (7× export → import → reconcile), verify non-zero entries/facts + `journal doctor` + dashboard | Critical | S | Feature | [blocked:user] → services.md (gate = services.md:308) |
| 2 | Root-cause the 2026-11-09 04:10 sync-window reset on the 7 in-scope balances (journalctl -u bank-sync Nov 7-10; pre-start.bak Nov 7 lineage; SUPERB deploy arc suspect) | Critical | S | Bug | [ready] → TODO_LIST + services.md |
| 3 | Probe gatus LIVE for "Journal Hauptbuch" + "Bank-Sync SCA Approval" rendered states (close this session's inferred-green gap) | High | S | Quality | [ready] → TODO_LIST + services.md |
| 4 | Forensics: Nov 8 23:37-38 `/auth/register` CSRF warns + journal-serve SIGKILL actor + OnFailure toast delivery | High | S | Bug | [ready] → TODO_LIST + services.md |
| 5 | Sweep all 22 `sync_states` rows to identify which balance the SCA-pending gauge refers to (feeds services.md:308 execution) | Medium | S | Bug | [ready] → TODO_LIST + services.md |
| 6 | Qonto-era facts: import into books (needs `journal.yaml` qonto balance mappings) or keep Wise-era scope? | Medium | S | Decision | [decision] → services.md only (owner, §g.1) |
| 7 | Decide + reclaim bank-sync dataDir residue: 4 × ~100 MB pre-qonto baks, 121 MB pre-start bak, 1.9 MB side-db-trap artifact | Low | S | Cleanup | [decision] → services.md only (owner) |
| 8 | Check journal-backup retention: append-only since 2026-10-23, unbounded 434 KB/day — confirm no prune, set retention if wanted | Low | S | Cleanup | [ready] → services.md only (tiny) |
| 9 | `~/books/journal.yaml` header: replace "example configuration" with a live-config note | Low | S | Documentation | [ready] → services.md only (tiny) |
| 10 | Test the dashboard Import-tab path once a non-empty export exists (UI import is untested surface) | Medium | S | Quality | fold into #1's verify steps (blocked on data) |
| 11 | Upstream fuel: bank-sync `--schema v1` should imply `--format json`; consider `--all-mapped` multi-balance export | Low | S/M | Feature | ROADMAP (verify-before-filing before any upstream filing) |
| 12 | Upstream fuel: journal serve CSRF Secure=false should honor `X-Forwarded-Proto` behind TLS-terminating proxy | Low | S | Bug | ROADMAP (same gate) |
| 13 | Upstream fuel: `bank_sync_sca_approval_pending` balance-label dimension (with services.md:309 verdict-classification theme) | Medium | M | Feature | ROADMAP |
| 14 | Consider bank-sync→journal scheduled handoff so coverage records stay self-updating (mesh contract already carries them) | Medium | M | Feature | ROADMAP |
| 15 | Post-approval watch: coverage verdicts must flip from "statements never synced" once statements sync — verify in the #1 run | Medium | S | Quality | fold into #1 |
| 16 | Archaeology (optional): what wrote journal.db on Oct 29 19:48 (376832→434176 growth, 0 new events — coverage-era write?) | Low | S | Documentation | deliberately not queued: no drift risk, pure context |
| 17 | Foreign `flake.lock` change (timesheets treefmt-nix follow warning) — belongs to another session; reconcile when that session lands | High | ? | Bug | deliberately not queued by THIS session (not my change; flagged to owner in chat) |
| 18 | When upstream T16 passkey auth lands: revisit vHost layer (plain+native OIDC vs forward-auth; RP ID already fixed) | Low | M | Decision | already tracked: 2026-10-26 report §f.9 — reference only |
| 19 | Month-end runbook cross-link: upstream `docs/runbooks/month-end.md` could cite the 0-fact-import-lands-coverage trick | Low | S | Documentation | ROADMAP (upstream PR fuel) |
| 20 | After first real close: re-verify README journal-serve table row against live behavior (2026-10-26 report §f.10 follow-through) | Low | S | Documentation | deliberately not queued: no drift known today |

**HARVEST note:** rows 2, 3, 4, 5 are queued into `TODO_LIST.md` + `docs/todo/services.md` at
authoring time (this session, below). Rows 1, 6, 7, 8, 9 land in `services.md` only
(blocked:user / decision / tiny-library items — the tq pool harvests [ready] queue rows only,
and TODO_LIST is deliberately kept to agent-actionable work). Rows 10, 15 fold into row 1.
Rows 11-14, 19 are ROADMAP fuel, not tasks. Rows 16-18, 20 are reference-only with reasons.

## g) Questions I can NOT figure out myself

1. **Qonto-era facts (1080 tx, 2022-01→2025-02): ever into the books?** I verified they exist
   on unmapped qonto balances and that importing them needs `journal.yaml` mappings plus the
   decision to book two years of pre-journal history. Whether the books' scope is
   Wise/current-era-only or should eventually swallow the Qonto years is bookkeeping policy
   only you can set.
2. **The 2026-11-09 04:10 sync-window reset on all 7 in-scope balances — intentional?** A
   single operation reset all 7 windows to that instant, and `data.db.pre-start.bak` (Nov 7
   06:03) suggests a fresh-start lineage around then. If you ran a bank-sync fresh-start or
   backfill attempt Nov 7-9, I'll treat the reset as intended and only document it; if not,
   it becomes a §f.2 forensics bug with an unknown writer.
3. **Is the two-entity scope (Artmann Technologies + Artmann Holding, per journal.yaml
   decision #2) final — Helpless.AI LLC, personal, Astride permanently out?** All currently
   synced Wise transaction history (116 tx) belongs to Helpless.AI LLC; if that profile is
   ever in scope, the mapping story (and this session's "0 in-scope facts" conclusion)
   changes materially.
