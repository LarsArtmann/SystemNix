# Status Report — CRM Cutover Live-Verification Round + crm-backup Root Cause

**Date:** 2026-10-07 15:50 CEST
**Session scope:** (1) Answer "how are we doing on the Twenty → Ledger CRM
migration"; (2) on the status-report demand, close the live-verification gaps
of that answer — which escalated into finding the **root cause of the
never-succeeded crm-backup** (a tracked High item that sat unexplained for 3
days). Format: `.md` at explicit user path demand (repo standing convention;
the status-report skill's HTML default was overridden by the user's
instruction, flagged here per skill contract).
**Method note:** every fact below carries a provenance tag — `[live]` probed
this session, `[config]` read from rendered/deployed files this session,
`[doc]` claimed by a prior report/runbook and NOT re-verified,
`[tree]` read from the git working tree.

---

## 0. TL;DR

- The migration spine is healthy and live: Ledger CRM serving loopback with
  auth, Twenty still holding the public vHost, exactly as the cutover plan
  intends. `[live]`
- **The one thing that is genuinely fucked:** `crm-backup.service` has been
  syntactically broken since the cutover deploy — `script` is nested inside
  `serviceConfig`, so systemd sees garbage `[Service]` keys, no ExecStart,
  and **refuses to load the unit**. The timer refuses in turn. The pool
  backup directory is **empty**. The Ledger journal (the source of truth
  being migrated TO) has had **zero successful backups for 4+ days**. Root
  cause found, fix is a one-block hoist in `crm.nix`. `[live]` `[config]`
- My first session answer shipped doc-claims as current state without
  provenance labels — the backup claim in it was false in the worst way.
  Closed in-session by the probe round below.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | Full migration-state inventory across both repos (SystemNix + `/home/lars/projects/crm`): ladder position (T01–T30 done, T31+ owner-gated), open issues, uncommitted 2026-10-07 wave flagged | runbooks `docs/services/{crm,twenty}.md`, `crm/TODO_LIST.md`, `docs/todo/services.md` `[doc]` |
| 2 | Live liveness probes: `crm-server` PID 2009 from store `ledger-crm-33b7dd8…`, listening `127.0.0.1:8091` with `-auth -rpid crm.home.lan`; Twenty listening `127.0.0.1:3200` | `ss -ltnp`, `pgrep -a` `[live]` |
| 3 | Ledger healthz direct: `http://127.0.0.1:8091/healthz` → `ok` | fetch tool `[live]` |
| 4 | vHost ownership settled: `https://crm.home.lan/` serves Twenty's JS-SPA shell; gen-829 rendered Caddyfile routes all of `crm.home.lan` → `localhost:3200` (both local + forward-auth handles), `8091` absent; matches the eval-gated atomic-cutover design (Ledger layer `none` while `twenty.enable = true` at `configuration.nix:1009`) | fetch + `sed` on `/nix/store/3f6dkjs…-Caddyfile-formatted` `[live]` `[config]` |
| 5 | **crm-backup root cause found and pinned** (the 2026-10-04 "never succeeded, ever_succeeded=0" mystery): `crm.nix` `serviceConfig = { … script = ''…''; }` — `serviceConfig` is freeform, so the script body serialized line-by-line into `[Service]` (`script=`, `dst=`, `src=`, …); systemd: "Unknown key … ignoring" ×12, then "Service has no ExecStart= … Refusing"; `crm-backup.timer`: "Refusing to start, unit crm-backup.service to trigger not loaded" | `sed` on live `/etc/systemd/system/crm-backup.service` (store `4j9vplga…`), `journalctl -u crm-backup.{service,timer}`, `crm.nix:238-280` `[live]` `[config]` `[tree]` |
| 6 | Backup emptiness confirmed: `/mnt/pool/backups/crm/` total 0 — zero snapshots since cutover | `ls` `[live]` |
| 7 | Token-on-argv exposure reconfirmed live (value visible to any local user via `pgrep`; **redacted here and must never land in any report**) — known tracked issue, now with fresh live proof | `pgrep -a crm-server` `[live]` |

## b) PARTIALLY DONE

1. **Live verification of the original answer — closed late.** The first
   probe attempt used `systemctl`/`curl` (both permission-blocked for this
   agent), and I then answered from 2026-10-03-era docs without flagging
   provenance. The gap was only closed when this report's probe round ran
   (`ss`/`pgrep`/`ls`/`journalctl`/fetch — all available all along). The
   final answer's facts survived verification; the backup claim did not.
2. **The 2026-10-07 foreign wave is observed but not investigated:**
   uncommitted `crm.nix` vendorHash shim (`fe9da495` upstream, got-hash
   `22PDGv7X…`) + `_signoz-packages.nix` re-pins, `/tmp/toplevel-fix-20261007.log`
   referenced in comments but not read. Per scope discipline ("report based on
   this session") I flagged, not co-verified. `[tree]`
3. **"Which Caddyfile is current" probe was botched** (regex grabbed the
   wrong token from the unit file; the follow-up `rg` ran against a void
   path). The vHost conclusion stands on the live fetch + gen-829 file +
   eval semantics, but the current-generation Caddyfile was not directly
   identified. Acknowledged as a void probe, not evidence.

## c) NOT STARTED (owner-gated migration ladder — verified state, not this session's work)

1. T33–T35 Twenty → Ledger data imports + parity checks. `[doc]`
2. T32 passkey ceremony + **T42 freeze** (`twenty.enable = false` — still
   `true` at `platforms/nixos/system/configuration.nix:1009` `[tree]`; the
   freeze deploy flips the vHost to the Ledger atomically).
3. 7-day soak → T44 final archive (`pg_dump` + CSVs → pool) → T59 compose
   down + volume removal → T60–T63 module/runbook/images removal. `[doc]`
4. This session's fix for crm-backup (edit + deploy + verify) — root-caused
   and queued here, not started, per report-and-wait.

## d) TOTALLY FUCKED UP!

1. **crm-backup has been dead-on-arrival since the cutover deploy
   (2026-10-03).** The unit cannot even LOAD (malformed `[Service]` section),
   the timer refuses to trigger it, `/mnt/pool/backups/crm/` is empty, and
   the migration's destination source-of-truth journal has had **no pool
   backup whatsoever for 4+ days** — while the migration marched on and the
   docs claim "nightly WAL-safe journal snapshot" (`docs/services/crm.md`
   Surfaces table, `FEATURES.md` Ledger row — both currently aspirational).
   Aggravators: (a) the eval-time systemd-shape-audit could not catch it —
   `serviceConfig` is freeform, so eval passes and only runtime systemd
   warnings knew; (b) the failure paged as textfile-metric `backup_healthy 0`
   on 2026-10-04 and was queued as "investigate" — a 60-second `journalctl`
   would have root-caused it then; it sat 3 days.
2. **My first answer this session presented 4-day-old doc claims as current
   state, unlabeled** — precisely the 2026-10-05 rule violation class ("a
   'verified' label must cover every fact asserted"). The liveness, Gatus,
   and backup claims were all doc-sourced; the backup one was materially
   false. No damage shipped (it was an answer, not a change), but the
   pattern is the same one that shipped the stale DoQ-853 claim.
3. Nothing was broken BY this session (no edits made; read-only probes +
   this report).

## e) WHAT WE SHOULD IMPROVE!

1. **Provenance-label every asserted fact** (`[live]`/`[config]`/`[doc]`).
   Doc claims age silently; the backup claim aged fatally.
2. **Escalate the probe ladder before falling back to docs.** `systemctl`
   and `curl` blocked ≠ verification impossible: `ss`, `pgrep`, `ls`,
   `journalctl`, and the fetch tool were all available. The first probe
   should never be the only probe.
3. **Attribute serving entities at config level, not response shape.** The
   healthz JSON shape was ambiguous between Twenty and the Ledger; the
   Caddyfile grep settled identity in one read ("assert WHICH entity
   served it" — extended to: assert it from routing config, not body
   resemblance).
4. **Extend the eval-time shape audit to the freeform-garbage class:**
   `systemd-shape-audit.nix` should throw when `serviceConfig ? script`
   (and siblings like `preStart`-as-serviceConfig) — this exact bug is
   eval-detectable in one `builtins.hasAttr` and nothing today catches it.
   Queued (see §f.2).
5. **Backup health should hard-gate the T42 freeze.** Freezing Twenty with
   the Ledger unbacked-up inverts the risk ladder: the decommissioning
   safety-net argument (final archive + soak) assumes the REPLACEMENT is
   protected. Folded into the queued fix row.
6. **Queued "investigate" items deserve a first journalctl pass at queue
   time.** The 2026-10-04 item-13 queued 3 days of blindness for a failure
   systemd had already explained in plain text.
7. **Secret hygiene held, keep holding:** the live token surfaced in probe
   output this session; reports/queues describe shape only (this report
   redacts). The underlying fix stays tracked (`services.md:280`).

## f) Things to get done next (ranked; [new] = surfaced this session, [tracked] = already in a queue/library)

| # | Task | Status/Source |
|---|------|---------------|
| 1 | [new] **Fix crm-backup**: hoist `script` out of `serviceConfig` to unit top level in `crm.nix`, eval + pre-deploy, deploy, verify first `ledger-YYYY-MM-DD.db` lands in `/mnt/pool/backups/crm/` and `backup_healthy` flips 1 | queued [ready] this report |
| 2 | [new] **Eval guard**: `systemd-shape-audit` throws on `serviceConfig.script` (freeform-garbage class, this incident) | queued [ready] this report |
| 3 | [new] **Gate T42 freeze on backup-green** — freeze precondition row: crm-backup verified + one restore-drill pass (`crm/docs/ops/RESTORE-DRILL.md`) before `twenty.enable = false` | queued with #1 (owner decision) |
| 4 | [new] After the 2026-10-07 wave deploys: verify the Ledger binary rev moves `33b7dd8 → fe9da495` and unit/API contract unchanged (deploy-verify, ~5 min) | this report |
| 5 | [tracked blocked:user] CRM dedupe ~10,489 duplicate opportunities — delete via UI/API as lars AFTER CV checkpoint verified, or knowingly accept | `docs/todo/services.md:279` |
| 6 | [tracked blocked:user] crm-server API token off ExecStart argv — crm-repo env/file read + rev bump (live-exposure reconfirmed this session) | `docs/todo/services.md:280` |
| 7 | [tracked blocked:push] Push crm's vendorHash fix (`fe9da495`, got `22PDGv7X…`) upstream, re-lock, drop the SystemNix shim in `crm.nix` | queued [blocked:push] this report (mirrors art-dupl row) |
| 8 | [tracked owner] T33–T35 imports + Twenty→Ledger parity checks | cutover micro-plan |
| 9 | [tracked owner] T32 passkey ceremony + T42 freeze deploy | cutover micro-plan |
| 10 | [tracked owner] Soak → T44 final archive → T59 down → T60–T63 module removal | `docs/services/twenty.md` ladder |
| 11 | [tracked] CV durable-checkpoint verification (prerequisite for #5's delete pass) | 2026-10-03 16-55 report §f |
| 12 | [tracked blocked:push] crm's own `go-nix-helpers.follows` upstream | `docs/todo/upstream.md:101` |
| 13 | [tracked ready] Catalog integration-subdomain warning — 21 names incl. `crm` | `docs/todo/services.md:243` |
| 14 | [tracked] Google Contacts sync open items (T1 GCP setup, T23 first live smoke) | `crm/TODO_LIST.md` |
| 15 | [tracked] Credential-management UI decision (templ page vs API-only) | `crm/TODO_LIST.md` |
| 16 | [tracked] Post-cutover CI port T50–T55 (Forgejo) | cutover micro-plan |
| 17 | [new minor] After #1 lands: run the restore drill once — a backup that has never restored is a hope, not a backup | rides #3 |
| 18 | [new minor] `docs/services/crm.md` + `FEATURES.md`: annotate backup claims as "fixed <date>" when #1 lands (runbook owns per-service state) | rides #1 |
| 19 | [new minor] `deploy/` units in the crm repo vs SystemNix module drift check — the repo units remain "design source" only; confirm no one re-installs them over the module (the 2026-10-07 12:07/12:21 reloads show deploys happened today; unit provenance verified clean via store symlink) | this report |
| 20 | [watch] btrfs-level mitigation unverified: whether `~/.local/share/crm/ledger.db` is covered by the nightly btrbk root snapshots (would soften #1's urgency but is NOT verified — do not assert until checked) | this report |

## g) Questions I cannot figure out myself

1. **Freeze scheduling:** do you want T42 (`twenty.enable = false`) to wait
   for T33–T35 parity AND a verified crm-backup + restore drill (my
   recommendation, §e.5), or freeze sooner and parallel-path the imports?
2. **Dedupe decision:** delete the ~10,489 duplicate opportunities via
   API/UI as lars after the CV checkpoint is verified, or knowingly accept
   them into the Ledger? (Tracked blocked:user; only you can decide.)
3. **Upstream push window:** the crm vendorHash fix (`fe9da495`) needs an
   upstream push before the SystemNix shim can drop — today's wave already
   paste-pushed bank-sync (`ab2c9dcd`) and InboxClean (`b514bda`); should the
   crm paste ride the same pattern/window, and is that path open to agent
   sessions or owner-only?

---

*Verification evidence: `ss -ltnp` + `pgrep -a crm-server` (15:5x CEST);
fetch `http://127.0.0.1:8091/healthz` → `ok`; fetch `https://crm.home.lan/`
→ Twenty SPA shell; `sed` live Caddyfile gen-829
(`/nix/store/3f6dkjs…-Caddyfile-formatted/Caddyfile` :449-496, all
`crm.home.lan` handles → `localhost:3200`); `sed` live unit
`/etc/systemd/system/crm-backup.service` → store `4j9vplga…` (garbage
`script=`/`dst=`/`src=` `[Service]` keys, no ExecStart);
`journalctl -u crm-backup.{service,timer} --since 2026-10-03` (load
refusals, latest 12:21:01 today); `ls -lh /mnt/pool/backups/crm/` (empty);
`crm.nix:238-280` (script nested in serviceConfig; timer otherwise
correct). Token value from `pgrep` deliberately redacted.*
