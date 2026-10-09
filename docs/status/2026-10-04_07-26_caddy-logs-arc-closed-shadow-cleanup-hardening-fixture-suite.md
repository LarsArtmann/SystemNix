# Status Report — 2026-10-04 07:26: Caddy-Logs Arc CLOSED — Cutover Live, Shadow Retired, Hardening + Fixture Suite Shipped

**Session scope:** Continuation of the caddy-logs arc from the 2026-10-03_00-35 report. This session: discovered the cutover had gone LIVE via the Oct 4 04:35 deploy, closed every remaining leg (finalize owner-run, shadow-cleanup built + owner-run, doc flips), then — on explicit "I want this fully done" — closed all three leftover hardening rows incl. a 33-assertion fixture suite wired into `checks`. The caddy-logs surface now has ZERO open rows. Format note: `.md` at explicit user path demand (standing dispatch-report exception to HTML-canonical).

**Live context at authoring:** load ~15–36 window this session; one foreign `nix build` churned most of it; my own PSI gate refused a dry-run at IO PSI 80.06% mid-session (gate working as designed). Tree: only my last two doc edits uncommitted (`CHANGELOG.md`, `docs/todo/storage.md`); everything else daemon-swept into heuristic commits (latest `a5b6f998`).

---

## a) FULLY DONE

1. **Cutover discovery + verification (by-id through the enumeration swap).** `/var/log/caddy` = Samsung `caddy-logs` subvol (subvolid 264) via `/dev/nvme1n1p2` — nvme1 = Samsung on the 05:09 boot, the OPPOSITE of the day before. Root partition is runtime-derived wherever it matters now. Deploy evidence: `/var/log/systemnix-deploys/2026-10-04_04-35-39.log`, exit 0. Fix-forward won §g.1 (~10 vendorHash shims + nixpkgs `c59305ba`).
2. **Finalize leg closed** (owner-run): 33 recently-touched files on the mount; boot path already exercised by the 05:09 reboot — no reboot owed.
3. **`shadow-cleanup` mode authored + executed** (owner-run sudo): archive-then-delete of the QLC shadow via auxiliary `subvol=@,ro` mount — 108 files, 1,961,474,191 B → 227,236,252 B tar.zst at `/mnt/pool/backups/caddy/caddy-logs-shadow-final-2026-10-04.tar.zst`, exact-count verified; shadow emptied, mountpoint dir kept; archive existence + size agent-reconfirmed on the pool. **Owner explicitly overrode the 2-week soak** (insurance retired ~13 days early — owner call, recorded on every surface).
4. **Post-state verified:** QLC root 80% used / 146G free (92% at arc start); mount live; caddy pid 8011 untouched throughout.
5. **Doc surfaces consistent** (drift rule): AGENTS.md doctrine-C bullet (`live 2026-10-04`), TODO_LIST queue row `[x]`, storage.md library row `[x]`, CHANGELOG entry incl. numbers; `check-todo-system.sh` → `OK: TODO queue/library structure clean`.
6. **Hardening rows 172 + 173 closed:** finalize gate = `find -newermt "@$WINDOW_START"` (writes DURING the 35s window — no pre-window mtime/traffic dependence) + independent files-exist gate; both crash-safe traps now `INT TERM EXIT`; real-SIGINT mid-rsync fixture-proven to restart caddy.
7. **Hardening row 171 closed — `scripts/test-migrate-caddy-logs-hot.sh`:** 33 assertions, shellcheck clean (severity=warning), stable ×3 locally, GREEN inside the nix sandbox as `checks.x86_64-linux.migrate-caddy-logs-fixture` (BUILD-OK). Covers all four modes' happy paths AND every failure branch: verify-fail caddy restart, EXIT + real-SIGINT traps, PSI/already-migrated/non-empty-subvol refusals, dry-run no-mutation ×2, the three new finalize refusals, shadow-cleanup's detached-Samsung same-device guard, pool-missing refusal, archive-verify-fail-leaves-shadow-intact, aux-leak-on-failure (crash-safe trap), usage exit.
8. **10-03 report §f harvested** (decision-independent items): fix-forward items landed via the 04:35 deploy; nvmeX-audit verified MOOT by inspection (scripts by-id/swap-aware; the one doc hit is the historical trap narrative itself) — mootness recorded on the storage.md Source line, not queued.
9. **Env hooks shipped in the production script** (`CADDY_MIGRATE_*`, hot-db pattern) making every root-bound path fixture-injectable — documented in-script.

## b) PARTIALLY DONE

1. **Full `nix flake check --no-build` after my `flake.nix` edit** — RESOLVED at authoring time: **all checks passed** (shell 027; only the expected aarch64-darwin incompatibility warning). Targeted `nix build .#checks.x86_64-linux.migrate-caddy-logs-fixture` also BUILD-OK.
2. **Upstream vendorHash pushes (the shim-drop path)** — still `[blocked:push]` in `docs/todo/upstream.md`; never authorized this session. The ~10 local shims persist with documented drop conditions until a re-lock past upstream-fixed revs.

## c) NOT STARTED

1. Boot-mirror first-reboot verification status — AGENTS.md says "first reboot pending" as of 2026-09-30; the Oct 4 05:09 reboot may have satisfied it. Not investigated (adjacent surface, not this arc's ask).
2. QLC space-settling recheck — @ snapshots still pinning pre-cleanup log extents expire over coming days; `df` will drift down without action.
3. Any monitoring for the wants-not-requires degradation path (detached Samsung → silent QLC shadow fallback) — nothing alerts on that class today (noticed mid-arc; unqueued until now — in §f).

## d) TOTALLY FUCKED UP

1. **The question-tool call (start of session) — interrupted, zero decisions captured**, and it was a REPEAT of an already-recorded lesson (answer in prose at turn boundaries). Consequence: the user had to drive the arc manually ("do it then", "I want this fully done"). Nothing was damaged; a round-trip was wasted.
2. **Two premature-narration micro-failures, both repeats of known lessons:** (a) "enumeration still running" while `RC_TOP=1` sat in the log tail (tail before narrating); (b) framing an open "finalize delta-rsync" gap BEFORE reading the migrate script — finalize rsyncs nothing by design; the "gap" is the documented log-gap insurance window. Both corrected within the same turn; both still said wrong first.
3. **Fixture bring-up took 5 iterations** for avoidable design reasons (see e.2) — the suite is green now, but the first version shipped with state-coupled cases and an arg-shape-blind tar stub.

## e) WHAT WE SHOULD IMPROVE

1. **Per-case fixture isolation from the start:** the first fixture version threaded state across cases (append-only findmnt map, mountpoint-list carry-over) — case N+1 broke on case N's leftovers. Rewrite state explicitly per case (`>` not `>>`; strip/re-add list entries adjacent to the case that needs them). The hot-db template already modeled this; I copied its stubs but not its per-case hygiene.
2. **Stubs must match on arg SHAPE, not just mode env:** the tar stub fired its truncated branch on `-tf` verify calls (empty `$5` → `tar (child): : Cannot open`). Guard transformed branches on the call signature (`[ "$1" = "-C" ]`).
3. **Timestamp-boundary races in mtime assertions:** with the sleep stub there is no 35s separation, so "just-written" files false-positive as "during the window" on same-second truncation. Pin mtimes (`touch -d '1 hour ago'`) in any quiet-window assertion.
4. **Read heredoc GENERATOR text, not mental models of stub content:** my edit failed because the file (generator with `\$` escapes) didn't match my imagined stub content; `sed -n` on the verbatim block resolved it in one step. View verbatim before theorizing about escaping.
5. **`shellcheck` lives behind `nix shell nixpkgs#shellcheck`** in this sandbox (first attempt: "executable not found"). Remember it; it's the repo's severity=warning gate.
6. **Carried todo-list discipline:** handoff step 1 said re-create the todos list; skipped all session (single-question turns felt too small). It compounds — this report had to reconstruct state from memory.
7. **`set -e` harnesses die on unanticipated case coupling** (case 11's re-prepare hit case 10's still-mounted stub state). A `run_migrate ... || true` harness wrapper for ARRANGEMENT commands (distinct from the command under assertion) would have localized it.

## f) Next tasks (ranked; ⏳ = user-gated)

| #  | Task                                                                                                                                                                                 | Impact  | Effort | Cat          | Note                                           |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- | ------ | ------------ | ---------------------------------------------- |
| 1  | ⏳ Authorize upstream pushes: 11+ vendorHashes + crush-daily `go-sse` flake input → re-lock → drop ~10 local shims                                                                   | High    | M      | Upstream     | the arc's only standing debt                   |
| 2  | Mount-degradation probe: alert when `/var/log/caddy` (and journal-hot) fall back to the QLC shadow (detached Samsung, wants-not-requires path) — textfile-collector + gatus pattern  | Medium  | S      | Monitoring   | noticed this arc; nothing watches the fallback |
| 3  | Verify shell 027 (`nix flake check --no-build`) result; fix anything in MY attrs only                                                                                                | High    | S      | Verification | closes b.1                                     |
| 4  | Verify the daemon-swept commits carry my fixture/flake/row edits intact (content greps, not messages)                                                                                | Low     | S      | Hygiene      | standing rule                                  |
| 5  | Boot-mirror: did the Oct 4 05:09 reboot exercise the Samsung ESP? Check NVRAM ordering + boot source; flip AGENTS.md "first reboot pending" if proven                                | Medium  | S      | Verification | adjacent, not mine this arc                    |
| 6  | QLC `df` recheck after @ snapshot expiry settles the freed extents                                                                                                                   | Low     | S      | Cleanup      | informational                                  |
| 7  | ⏳ The 06:33 deploy aborted on the pressure guard (exit 12) — retry in a quiet window if that intent was yours                                                                       | Unknown | S      | Deploy       | foreign intent                                 |
| 8  | The 06:25 deploy aborted in pre-check (2s) — unknown failing check; read that log before any retry                                                                                   | Medium  | S      | Bug          | foreign                                        |
| 9  | The 04:35 deploy logged "⚠ Some smoke checks failed — review above" — triage those smoke failures                                                                                    | Medium  | S      | Bug          | foreign deploy, noticed                        |
| 10 | Archive retention decision: the 227M shadow tarball has no expiry policy on the pool (other pool backups carry 30d-style retention)                                                  | Low     | S      | Decision     | product call                                   |
| 11 | Consider restoring/merging the Oct 1→4 gap entries from the archive anywhere, or ratify archive-as-final                                                                             | Low     | S      | Decision     | see §g.3                                       |
| 12 | Foreign `[ ]` rows seen in checker output: geometrikks.service FAILED, inboxclean-sync.service FAILED, service-health-check report-don't-fail semantics — owners' queue, not touched | Medium  | S      | Bug          | foreign                                        |
| 13 | Fixture-suite follow-on (optional): port the INT/TERM + verify-fail patterns back into `test-migrate-hot-db.sh` if the hot-db script lacks equivalents                               | Low     | M      | Quality      | cross-pollination                              |

## g) Questions I cannot answer myself

1. **Authorize upstream pushes to the LarsArtmann repos?** (11+ corrected `vendorHash` commits + the crush-daily `go-sse` flake input.) Without them the ~10 local shims in `lib/lars-packages.nix` persist until the repos happen to be fixed and a re-lock moves past those revs — push credentials and policy are yours alone.
2. **Was the 06:33 pressure-guard-blocked deploy yours, and should it be retried?** I can see it aborted (exit 12, "DEPLOY_FORCE_PRESSURE=1 nix run .#deploy" hint) but not WHAT it intended to carry — the 06:25 pre-check abort (2s in) is likewise opaque from logs alone; both predate my session's visibility.
3. **Is the 227M shadow archive final, or should the Oct 1→4 gap entries be restored/merged somewhere?** The tarball on the pool preserves everything; whether that history has downstream value (analyzer, compliance, curiosity) is a product judgment I can't derive from code.

---

_Point-in-time snapshot. Auto-commit daemon sweeps this file; verify by content. The caddy-logs arc is closed — items above are the arc's tail debts (upstream, monitoring) and foreign observations only._
