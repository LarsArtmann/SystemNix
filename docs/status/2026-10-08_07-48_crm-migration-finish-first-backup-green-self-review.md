# CRM Migration Finish: First Pool Backup GREEN + Session Self-Review

**Session window:** 2026-10-07 16:50–17:01 (execution) + 2026-10-08 07:48 (morning verification)
**Author:** Crush session (continuation of `2026-10-07_15-50_*` and `2026-10-07_16-35_*`)
**Mandate:** "make sure we finish the crm migration properly so I can verify" — execute the agent-actionable finish ladder, then this report.
**Provenance labels:** `[live]` probed the running system · `[journal]` journalctl · `[eval]` nix eval/build · `[tree]` git state · `[file]` on-disk artifact · `[doc]` documentation claim

---

## Headline

**The backup chain is GREEN end-to-end and the T42 freeze precondition is SATISFIED.**

1. The crm-backup fix is **LIVE** — carried by gen-837 (switched 2026-10-07 16:30, discovered this session) `[live]`
2. **First pool artifact landed:** `/mnt/pool/backups/crm/ledger-2026-10-08.db` (23.3 MB, 03:47, journal-clean 422 ms run) `[file][journal]`
3. **Artifact verified:** `PRAGMA integrity_check = ok`, 29,053 journal events (live journal grew 28,714 → 29,053 overnight — consistent with active use) `[live]`
4. **Restore drill PASSED with the exact production binary** (store `nc237asy…ledger-crm-fe9da495…`, all 5 phases, 2.4 s total) `[live]`

What remains of the migration is **one owner decision** (T42 flip = `twenty.enable = false` + deploy) and the post-flip verify chain. Twenty still owns `crm.home.lan` until then `[tree: configuration.nix ~1014]`.

---

## Brutal Self-Review (asked: what did you forget / do better / improve)

1. **What did you forget?** I did not re-pin the **live system generation** at session start. I carried the previous session's "critical fact: live gen-836, everything undeployed" premise for ~30 minutes. It was already false — gen-837 had switched at 16:30, five minutes before the 16:35 report was authored, and that report's central framing ("the fix rides the next deploy") went stale within minutes of writing. I only caught it because `pgrep` showed PID 3425937 where I expected 2009, and I bothered to chase the anomaly. The project's own rule — _never assert service capability from a doc claim alone; verify live state first_ — was written for exactly this, and I skipped the cheapest probe (`readlink /nix/var/nix/profiles/system`) in my "content-pin" round. Luck caught it, not discipline. The 16-35 report gets an append-only correction (done this session, see Bookkeeping).
2. **What is stupid that we do anyway?** Verification probes that guess at HTML structure. My restore-boot check regexed for `class="…name…"` elements I had never looked at — it matched nothing, and the honest verdict line printed `CHECK-MANUALLY` while the wrapper job dangled in the background overnight. I proved HTTP 200 + 106,990 bytes + `/healthz`, but left the _content-level_ proof ("real contacts render") open — the strongest claim I wanted was the one my probe was weakest at.
3. **What could you have done better?** (a) Session-start probe checklist: tree pin AND `readlink /nix/var/nix/profiles/system` AND `pgrep -a <touched-services>` AND PSI — one command, kills the stale-premise class. (b) Assert structural facts, not regex guesses: count `/contacts/<id>` detail links or compare contact counts against live, never scrape by guessed class names. (c) Reap background jobs before yielding: the auto-backgrounded shell survived into the next morning; its crm-server child had already exited (`no ghost` at 07:48) but I should have confirmed that before yielding, not after.
4. **What could you still improve?** Close the contacts-render proof (one 10 s boot + link count); verify the `backup_healthy`/gatus freshness surface actually reads green (I verified the artifact, not yet the monitoring verdict); decide the identity.db backup gap (below).
5. **Did you lie to you?** No fabricated claims — but two statements were weaker than their framing: `CHECK-MANUALLY` was printed as a verdict line (correctly self-flagged, but should never have been reachable), and the inherited "next deploy carries the fix" narrative was asserted as current fact in a report instead of re-probed. Both are process lies of convenience; both corrected in this report.
6. **Ghost systems / split brains / scope?** No ghosts created. One stale-claim surface (16-35 report) — annotated, not rewritten. Scope held: I refused to `go mod tidy` the crm repo (go.mod drift, parallel sessions own it) and pivoted to the live store binary instead. Nothing useful removed. /tmp residue: `crm-backup-test/`, `crm-restore-boot/`, `shape-audit-selftest.nix` (cleanup queued).
7. **Testing?** The two proofs that matter both EXECUTED this session: script-BODY test (exact rendered unit script → /tmp artifact, integrity + 14-table row-parity + non-vacuous retention selector with aged decoys) and the 5-phase restore drill with the production binary. The open gap is one content-level render assertion.

---

## a) FULLY DONE

| #  | Item                                                                                                                                                                                                                                                                                                                                                           | Evidence                                                                                                                                                   |
| -- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| a1 | **Script-BODY test** (top `[ready]` queue row): exact eval-rendered backup script executed 16:58 with dst→`/tmp/crm-backup-test/` against the LIVE journal — script ran clean, wrote `ledger-2026-10-07.db` 22.9 MB standalone (no `-wal`/`-shm` siblings)                                                                                                     | `[live]` 14 tables row-identical to live (28,714 `meta_stream_log` events — the 4.1 MB WAL was captured via the sqlite backup API); `integrity_check = ok` |
| a2 | **Retention dry-run, non-vacuous**: aged `ledger-old-decoy.db` (mtime 2026-08-01) + `identity-2026-08-01.db` + `ledger-notes.txt` decoys in the test dir — the `-mtime +30` selector matched ONLY the aged ledger file; identity and non-db files spared                                                                                                       | `[live]` find output captured                                                                                                                              |
| a3 | **crm-backup fix verified LIVE**: `/etc/systemd/system/crm-backup.service` now carries `ExecStart=/nix/store/5vmsc3p8…-unit-script-crm-backup-start/bin/crm-backup-start` — the garbage-keys unit (`script=`, `dst=` lines, "Refusing" journal entries at 16:03) is gone; timer loaded 16:29 (`Started Nightly Ledger CRM journal backup`), stamp file written | `[live][journal]`                                                                                                                                          |
| a4 | **Deploy premise corrected**: gen-837 switched 16:30 (profile symlink mtime + store path `2ddhb2w0…`); the fix, wave4 FOD re-pins, and shape-audit class 5 RODE IT. Live crm-server = `fe9da495` (store `nc237asy…`), PID 3425937 since 16:03 — the "33b7dd8 → fe9da495 rev jump" verify item from 16-35 is **already satisfied**                              | `[live]`                                                                                                                                                   |
| a5 | **Restore drill PASSED with the production binary**: `CRM_BIN=<live fe9da495 store path> bash scripts/restore-drill.sh` — journal round-trip, double-import refused, identity backup/restore + login render, call re-projection; boot 807 ms / seed 381 / export 73 / import 66 / verify 470 / identity 615, total 2.4 s                                       | `[live]` drill output; work dir `/tmp/tmp.jX0W4NL4DV`                                                                                                      |
| a6 | **First pool artifact + integrity**: `ledger-2026-10-08.db`, 03:47:11 (03:40 OnCalendar + ~7 min RandomizedDelay), 23,302,144 bytes, "Deactivated successfully", 45.1 M peak, 62 ms CPU                                                                                                                                                                        | `[file][journal]` `integrity_check = ok`, 29,053 events                                                                                                    |
| a7 | **Snapshot boot (HTTP level)**: live binary booted against a COPY of the /tmp snapshot on `:18091` — `/healthz` OK, `/contacts` HTTP 200 with 106,990 bytes; server SIGTERMed (confirmed gone at 07:48)                                                                                                                                                        | `[live]` (content-level proof open → b1)                                                                                                                   |
| a8 | **Ghost cleanup + tree pins**: dangling background shell reaped; no `:18091` process; morning tree pinned `8241a29e` clean                                                                                                                                                                                                                                     | `[live][tree]`                                                                                                                                             |

## b) PARTIALLY DONE

| #  | Item                                              | State                                                                                                   | Remaining                                                                                     |
| -- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| b1 | Snapshot-boot **content-level** proof             | HTTP 200 + 107 KB + healthz proven; name-regex probe missed (guessed class names)                       | one boot + structural count (e.g. `/contacts/` detail-link count > 0 vs live) — 10 s, no sudo |
| b2 | `backup_healthy` / gatus backup-freshness verdict | artifact satisfies the registry contract (filePattern `ledger-*.db`, maxAge 26 h — artifact is 4 h old) | read the actual gatus/textfile metric green post-flip window                                  |
| b3 | Migration ladder T41→T42                          | backup-green precondition **SATISFIED** (a1–a6)                                                         | the flip itself is owner-gated (§g Q1)                                                        |

## c) NOT STARTED

- **T42 freeze**: `twenty.enable` still `true` `[tree]` — Ledger CRM keeps loopback `:8091`, Twenty keeps `crm.home.lan` + the homepage tile. One-line diff + deploy + verify chain, ready to execute on authorization.
- Post-flip verify chain (vHost serves Ledger, Twenty containers down, `:3200` free, tile swap, passkey login e2e on `https://crm.home.lan`).
- Twenty retirement (final pg_dump export, data-retention window, module removal, port release).
- FEATURES.md / `docs/services/crm.md` post-flip state updates ("backup LIVE since 2026-10-08" runbook note).

## d) TOTALLY FUCKED UP!

Nothing production-broke in this window — the failures are process warts, listed with full honesty:

1. **Regex-guess verification** (b1): the one assertion I most wanted (contacts render from a restored snapshot) was entrusted to a guessed HTML class name. Verdict `CHECK-MANUALLY` — the probe design failed before the evidence could.
2. **Stale-premise carry-in**: ~30 min executing under "fix undeployed" when it had been live since 16:30. The 16-35 report's "Critical fact" section aged out in 5 minutes; nothing in my session-start pin would have caught it. (Annotated now.)
3. **Dangling background job**: the auto-backgrounded boot-check shell survived overnight; reaped at 07:48. The crm-server child had exited on its own — containment held by luck, not by me.
4. **Two dead build paths before the good one**: `go build` failed on go.mod drift (correctly refused to mutate), crm-repo `nix build .#default` failed on the known vendorHash dependency — the live store binary was the right FIRST choice for drilling anyway (highest fidelity, zero builds). I cost myself ~5 minutes by not reasoning "drill the binary that is actually serving" first.

## e) WHAT WE SHOULD IMPROVE!

1. **Session-start live-pin checklist** (tree rev + `readlink /nix/var/nix/profiles/system` + `pgrep -a` of touched services + PSI in one command) — encode in the session-discipline doc; the stale-generation class has now bitten twice.
2. **Structural assertions over scraping**: verify rendered data by counting detail links / API-readable counts, never by guessed CSS classes.
3. **Background-job reap-before-yield**: never yield a session with a `running` shell ID; kill or confirm-exited first.
4. **identity.db backup gap (decision needed)**: the nightly unit snapshots ONLY `ledger.db`. `identity.db` (passkeys, sessions) is recoverable-by-re-registration per the runbook — acceptable, but it is a deliberate unstated risk today. Either add a second sqlite-backup block to the unit or record the accepted risk in the runbook (§g Q2).
5. **Timer catch-up semantics**: a Persistent timer whose stamp was just written (16:29) does NOT catch-fire — first run waited for the next calendar slot (03:40). Worth one runbook line so nobody expects an immediate artifact after deploying this unit.
6. **Correction discipline worked** — annotate-don't-rewrite on the 16-35 report; keep doing exactly this.

## f) Things to get done next (prioritized, not padded — 27 real items)

**Owner-gated now:**

1. T42 flip decision (§g Q1) — `twenty.enable = false`, one line
2. T42 deploy (PSI window — currently 53/61/70, storming `[live]`)
3. identity.db in nightly backup? (§g Q2)
4. PSI gate policy clarification (§g Q3) — advisory or hard?
5. Dedupe decision (~10,489 dups) after CV checkpoint verify
6. Upstream push window: crm `fe9da495` + 4 others + nsfw `46f02bb`
7. forgejo G1 finalize

**Post-flip verify chain (agent-actionable once deployed):**
8. `crm.home.lan` serves Ledger (fetch; expect Ledger UI, not Twenty)
9. Twenty containers stopped, `:3200` free (`ss -ltnp`)
10. Homepage tile swapped to "Ledger CRM"
11. Gatus "Ledger CRM" check green; backup-freshness green; `backup_healthy` → 1
12. Passkey login e2e on `https://crm.home.lan` (WebAuthn `-rpid` already correct)
13. CV-sync / webphone consumers still resolve (they hit loopback `:8091` directly — verify once)
14. T42 rollback plan sanity (crm.md ladder ordering)

**This-session residue (agent-actionable, no sudo):**
15. b1 contacts-render structural proof (10 s boot + link count)
16. /tmp cleanup: `crm-backup-test/`, `crm-restore-boot/`, `shape-audit-selftest.nix`, drill work dir
17. Runbook note: stamp/Persistent no-catch-fire semantics (docs/services/crm.md)
18. Runbook note: backup LIVE since 2026-10-08, first artifact hash/size
19. FEATURES.md CRM rows post-flip (migration DONE state)

**Watch cadence:**
20. Second artifact lands 2026-10-09 03:40 ±10 min (confirms steady-state)
21. Retention fall-off proof ~2026-11-07 (first file ages past 30 d)
22. Restore drill quarterly re-run due 2027-01 (runbook cadence)

**Adjacent, existing tracked work:**
23. crm repo go.mod tidy drift (owning session)
24. crm repo flake vendorHash (`[blocked:push]` upstream.md row)
25. Twenty final pg_dump export before any retirement step
26. Twenty retirement window decision (rollback soak length)
27. Post-retirement: twenty module removal + `:3200` release + TODO row

## g) Questions I can NOT figure out myself

1. **T42 flip now or soak first?** Backup-green, drill-green, artifact-verified. Flip `twenty.enable = false` today (next deploy), or hold for N more green nightly artifacts (e.g. 3 nights) before the vHost moves?
2. **identity.db into the nightly backup?** Journal-only today; losing identity.db costs a passkey re-registration (no CRM data loss). Add it to the unit, or accept + document the risk?
3. **Was the 16:30 deploy (gen-837) an intentional PSI-gate override?** IO-PSI was ~35-60 around it and is 53/61/70 now. Should the T42 deploy also ride regardless of PSI, or actually wait for <15/20? I cannot infer the policy from the tree.

---

## Bookkeeping (this session)

- `TODO_LIST.md` script-BODY row → `[x]`; `docs/todo/services.md` rows 327/328 → `[x]` with evidence (closes [blocked:deploy] activation — deployed via gen-837, artifact landed, drill passed, T42 precondition satisfied)
- Append-only annotation added to `docs/status/2026-10-07_16-35_*.md` (stale gen-836/"undeployed" premise corrected)
- `scripts/check-todo-system.sh` re-run after edits
- No config changes this morning; no manual commits (daemon owns)

_Evidence index: profile symlink `system-837-link` → store `2ddhb2w0…` (16:30); live ExecStart `5vmsc3p8…`; `/proc/2009/exe` mismatch → PID 3425937 `nc237asy…fe9da495…`; timer stamp mtime 16:29; artifact `ledger-2026-10-08.db` mtime 03:47:11 + journal run lines; drill timings table; tree `8241a29e` clean at 07:48._
