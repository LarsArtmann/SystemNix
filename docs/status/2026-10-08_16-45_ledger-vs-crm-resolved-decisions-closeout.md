# 2026-10-08 16-45 — ledger-vs-crm resolved + three owner decisions closed out (follow-through)

Continuation of the 15-30 CRM follow-through session. The owner's unanswered
message was `~/projects/ledger vs /home/lars/projects/crm`; this session
resolved it, collected the three outstanding §g decisions via the question
tool, and executed them to their agent-side limit — including one stale-premise
discovery (CV lock) that converted a planned lock edit into row corrections.

## §a What was done

1. **Repo question answered** (see §b1): `~/projects/ledger` and
   `~/projects/crm` are two different sovereign repos with zero shared
   commits. The multi-RPID draft's home repo is CONFIRMED `crm` — no move
   needed. Annotated the pre-filing row (docs/todo/upstream.md:135) with the
   resolution so the filing session inherits it.
2. **Three §g decisions collected** (question tool, 16:40):
   residue = volumes-only tar then trash; CV lock = forward to e76d638;
   dedupe executor = agent via CRM API, dry-run first.
3. **CV lock decision executed as NO-OP with corrections** — the premise
   "hold at b3a9172" was stale: the live lock has sat at `b2cab45` since the
   10-08 09:11 wave, 52 commits PAST e76d638, and the 14:20 cutover deploy
   switched green on it (§b2/§b3). Re-pinning to e76d638 would have been a
   backward move; no lock edit performed.
4. **Rows updated** (queue + library, both surfaces per the no-drift rule):
   services.md 14 (disposition DECIDED), 285 (lock dependency resolved —
   fully dispatchable), 286 (executor DECIDED, re-tagged `[blocked:deploy]`),
   352 (CLOSED already-satisfied); TODO_LIST.md 91 / 139 / 391 synced;
   pipeline.md 378 (cv pin-back lift) CLOSED via the same wave evidence;
   AGENTS.md TODO-System rules extended with the question-time premise check.
5. **Watch baselines re-pinned** (16:29): identity.db main file unchanged
   since 10-03 16:12, WAL 0 B → owner has still NOT registered the passkey;
   `/mnt/pool/backups/crm/` holds today's ledger artifact only
   (03:47) → first DUAL (ledger + identity) artifact still due 2026-10-09
   ~03:40. SystemNix tree clean at `0b9108e6` after the daemon swept this
   session's upstream.md annotation.

## §b Findings

### b1 — `~/projects/ledger` vs `~/projects/crm` (the answer)

| | `~/projects/ledger` | `~/projects/crm` |
| --- | --- | --- |
| Remote | `git@github.com:LarsArtmann/journal.git` | `git@github.com:LarsArtmann/crm.git` |
| What | **journal — the accounting kernel**: double-entry bookkeeping, chart of accounts, bank reconciliation, VAT (README) | **The CRM product, branded "Ledger"** (README title): event-sourced contacts/pipeline/tasks |
| Binary | `cmd/journal` | `cmd/crm-server`, package pname `ledger-crm` (crm/flake.nix:80) |
| Identity/WebAuthn | none (internal/: app, clock, config, cqrs, domain, legalrules) | `internal/identity` + cqrs-htmx webauthn — the multi-RPID code |
| Shared commits | 0 (intersected full `log --format=%H` of both) | 0 |
| SystemNix input | not an input | flake input `crm` @ master `2bb5d8fd730c` = the deployed `crm.home.lan` service |

Naming is the only overlap — confusingly inverted: the LOCAL dir `ledger`
holds the repo named **journal**, while the repo named **crm** ships the
product named **Ledger** (whose event DB is `~/.local/share/crm/ledger.db`).
State: ledger master ahead 1 of origin; crm master ahead 6 (parallel CSP
session's commits; crm tree now CLEAN — their dirty CHANGELOG/TODO_LIST were
committed by the daemon).

### b2 — cv lock history (the stale premise)

Walk of every flake.lock commit (cv rev at each):

| When | cv rev | Note |
| --- | --- | --- |
| 10-07 16:13 | cdac11b | stale-vendorHash blocker |
| 10-07 16:22 → 10-08 02:12 | b3a9172 | sanctioned pin-back |
| 10-07 17:43–18:33 | acc099a → 339ca0 → **e76d638** | e76d638 briefly LOCKED, then rolled back (misdiagnosis) |
| **10-08 09:11** | **b2cab45** | 13-input wave (commit `5511390f`) — CURRENT |
| 10-08 10:21 → 10:36 | c47f6e0 blip | experiment, reverted (`68e0e522`) |

Ancestry: e76d638 = revCount 7475; b2cab45 = revCount 7527 (both master) →
b2cab45 is 52 commits past the "forward" target.

### b3 — the 09:11 wave also resolved the bank-sync FOD blocker

The wave moved bank-sync `ab2c9dcd` → `84adc5a` (plus cv, dankMaterialShell,
go-cqrs-lite, herdr, hermes-agent, nur, signoz-src, and 5 more). The 14:20
CRM-cutover deploy built and switched GREEN on exactly this lock (gen 845,
live per the 15-30 pin) — so cv b2cab45 AND bank-sync 84adc5a are
deploy-proven. The 15-30 handoff's standing "bank-sync FOD deploy blocker"
backlog item was already stale at handoff time.

### b4 — crm repo

Tree clean; the multi-RPID draft intact at `docs/drafts/2026-10-08_multi-rpid-webauthn.md`
(2,838 B, mtime 15:20); parallel CSP session no longer has uncommitted files.

## §c Verification

- `git -C ledger log --format=%H | sort` ∩ same for crm → 0 shared commits.
- `git log --format=%h -- flake.lock` walk (25 commits) → §b2 table; cv
  node read at `5de4ff20` (e76d638, revCount 7475) vs current lock
  (b2cab45, revCount 7527).
- `5511390f` old/new lock diff → 13 moved inputs incl. bank-sync + cv.
- Live deploy evidence: 15-30 handoff pin (gen 845 @ 14:21, crm-server
  restarted 14:20:02, running binary rev == flake.lock crm rev) — the
  toplevel that switched includes cv b2cab45 and bank-sync 84adc5a.
- Identity/backup baselines: `ls -la ~/.local/share/crm/`,
  `ls -la /mnt/pool/backups/crm/` (§a5).

## §d Failures and self-critique

1. **Q2 was asked on a stale premise.** The question presented "hold at
   b3a9172" as the live status quo; the live lock was b2cab45. Caught during
   execution (premise live-verified BEFORE editing the lock), so no damage —
   but the owner answered a question whose framing was ~7.5 h out of date.
   Lesson extended into AGENTS.md (question-time premise check). Root cause:
   rows 352/391 + the 15-30 handoff encoded lock state as of 02:12 and no
   session between 09:11 and 16:40 re-pinned it.
2. **The 15-30 handoff's "bank-sync FOD deploy blocker" item was stale** at
   handoff time (§b3). Flagged here + recorded in the row 352 close-out;
   deliberately not hunting down which row owned it — the deploy-green
   evidence covers the operative claim.

## §e Assumptions

- revCount is used as the ancestry proxy (no local cv clone; the GitHub
  compare API is anonymous-404 for this private repo; `ls-remote` gives refs
  only). Both revs were locked off master; master history is
  daemon-commit-linear. The deploy-green evidence independently settles the
  question that matters (the current lock builds and runs live).
- identity.db "no users yet" remains file-level inference (WAL 0 B + mtime
  unchanged) — the sqlite-count check stays on the existing watch row.

## §f Follow-ups (self-harvested at authoring time)

- Row 285 (CV durable checkpoint) is now FULLY dispatchable — it was already
  queued; its "rides the cv lock decision" clause updated in both surfaces.
  No new row needed.
- Residue disposition + dedupe executor were recorded INTO their existing
  rows (services.md 14 / 286 + queue mirrors); execution remains owner-sudo
  (residue) and post-deploy sequenced (dedupe) — both deliberately stay out
  of the harvestable queue per the split rules.
- Dual-backup verification (10-09 ~03:47) + post-login identity check stay
  on the existing watch row — nothing new to harvest.
- Deliberately not harvested: none. Every §f item above landed in an existing
  row in this session's edits — HARVESTED at authoring.

## §g Open questions for the owner

None — all three §g decisions were collected this session. One cosmetic,
owner-only suggestion (no row, no action taken): renaming
`~/projects/ledger` → `~/projects/journal` would make the local dir match its
remote and prevent exactly the confusion that prompted the question.
