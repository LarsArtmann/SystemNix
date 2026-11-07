# Status — quick-wins batch: 13 queue rows closed, watch-row hygiene, 2 module fixes

- **Timestamp:** 2026-11-07 00:15 CEST (session start 2026-11-06 23:55; user-directed "Quick Wins" over TODO_LIST — scope: small, no-deploy / no-sudo / no-owner rows)
- **Tree:** shared with parallel sessions (daemon commits `e6d0c9bbb`/`da19aa39a` swept mid-session edits; all my landings verified via `git show --stat` — one awk-based single-line rewrite in docs/todo/storage.md was my own, detected by the edit tool's staleness check)

## §a Closed (13 queue rows, twins moved together)

1. **Retag / retire / header-hint trio (tmp-reclaim class)** — queue "Retag" row + pipeline.md 392/383/384 all verified ALREADY SATISFIED: the parent user-space-reclaim row has carried `[blocked:user]` + an explicit RETAG stamp since 2026-10-26 (live-verified), a non-harvestable tag per the queue header; remainders (runbook, trash-prune, batched owner runbook) live in their own rows. Bonus deliverable: the queue-header routing bullet now codifies the sudo-only-remainder rule ("retag `[blocked:user]`, never `[blocked:deploy]`").
2. **Superseded "Root-cause idle-disk/no-D-state IO PSI accounting"** (queue row + the old TODO_LIST:316 row, which had NO library twin) — closed via the re-dispatch protocol: live spot-check PASSED (3 tasks in `io_cqring_wait` under `app-niri-ghostty-*.scope` scopes on this boot = the exact phantom signature the verdict names); pointer corrected to stability.md "Deploy pressure gate" bullet (the row's ":31" line number was stale; no library twin existed anywhere).
3. **CONTRIBUTING ×3** — "Partially-landed branch" paragraph under the protocol's five steps (no tick on a half-landed item; BLOCKED note citing landed evidence + outstanding gate); no-op live-verify clause inside step 2 ("nothing to do" is still a claim about the world; the 13th /data fire's +76G catch cited); daemon-race clause (8) (empty/footer-only commits are pathspec-safe BY CONSTRUCTION for shared-tree no-op records).
4. **docs/agents/storage.md ×2** — "Hot-tier wave close-out discipline" paragraph (migrate-state marker citation mandatory at commit time, marker-path correction `/mnt/hot/hot/.migrate-state/`, §18 gate backstop) + the COMBINED owner reclaim runbook (trash-empty + `@cache-home.regular-dir-bak` delete in ONE sudo window, pre-delete inventory commands included; corrected the originating row's wrong `/data` post-verify — the subvol lives on the ROOT fs at `/mnt/btrfs-root/@cache-home.regular-dir-bak`, live-confirmed present). Closes queue rows 24+36 and library row 135.
5. **/data watch hygiene (4 rows)** — cap-at-3 implemented (whole-queue survey: ONLY the /data watch violated; queue row resynced 86%→67%, killing a live queue/library drift, and the storage.md library row collapsed from ~16 embedded dispatch stamps to cap shape with the task-report IDs preserved); self-gate tightened on BOTH surfaces (spot-check-contradiction = full dispatch + re-stamp; bookkeeping record lives ONLY in the footer-bearing commit); machine-readable baseline artifact `docs/todo/data-watch-baseline.txt` created (du -sb trio + df -B1 figures + diff-based compare one-liner). The missing pipeline.md twin for the cap row was backfilled — that row WAS the stale-cap DRIFT class row 56 flagged; the storm-aware row's citation was already correct.
6. **nsfw-classifier TimeoutStartSec** — moved from `unitConfig` ([Unit] — silently ignored per the 2026-11-05 07:36:48 switch journal) into the `serviceConfig` mkMerge block, comment corrected; SAME-CLASS on-sight fix: the `nsfw-immich-scan` sweep unit's `6h` had the identical bug (moved too).
7. **browser-history `pkceEnabled = true`** — one line in the integration-registration oidc block; the last fleet OIDC client now flags PKCE.

## §b Verification evidence

- **evo-x2 toplevel eval rc=0** (log `~/.cache/qw-eval2.log`). First attempt RED — my own duplicate-attr error: `serviceConfig.TimeoutStartSec = …` beside `serviceConfig = lib.mkMerge […]` in ONE attrset is a duplicate definition (module-system merging does NOT apply within a single attrset literal); fixed by moving the keys INTO the mkMerge blocks. Caught by eval before anything landed — the eval-first discipline working as designed.
- nsfw server: `serviceConfig.TimeoutStartSec = "10min"` ✓, `unitConfig.TimeoutStartSec` ABSENT ✓ (live-config eval). Sweep unit (mkIf-gated OFF on evo-x2): throwaway `extendModules` probe with a dummy `apiKeyFile` returns `"6h"` ✓ (safe-verification pattern — tree untouched). One probe-hygiene note: I initially stderr-suppressed a probe (`2>/dev/null`) and drew a conclusion from its silence — caught, re-run faithful per the truncation-safe clause.
- pkce: `nix eval --json .…pocket-id-config.provision.extraOidcClients` → `"clientId":"browser-history", … "pkceEnabled":true` ✓ (registry → extraOidcClients → IdP-flag wiring proven end-to-end).
- Formatting canonical across all 11 touched files (`fmt-cached.sh`, 0 changed); deadnix clean; statix shows only a PRE-EXISTING inherit-suggestion at browser-history.nix:765 (not my line — left).
- TODO gate after all edits: structure **OK**; 58 pairing drifts + 192 unharvested — both pre-existing chronic counts (the gate's new WARN lines spot-checked: all foreign rows).
- Re-dispatch protocol step-3 sweeps behind every tick: no un-landed Source follow-ups found (each tick note cites its landing).

## §c Findings

1. **Phantom evidence pointer, live specimen:** `docs/status/2026-10-14_02-10_io-psi-idle-disk-phantom-verdict.md` NEVER existed in git (`git log --all` — the diff-filter=A hits are other io-psi files), yet FOUR surfaces cite it (stability.md, the 10-14 05-03 report, the 10-15 03-29 report, CHANGELOG:1003). The LIVING surface (stability.md) is corrected to point at the two window-closeout roundups that actually carry the verdict narrative, plus today's live re-confirmation. Historical surfaces: §f.1.
2. **Near-miss of the correction-claim rule:** my first DONE note for row 28 claimed the report was "deleted from the tree / existed in git history" — a wrong premise (it never landed). Caught during close-out review and corrected in place on the same surface.
3. **PSI discipline held:** docs-first sequencing; evals deferred behind PSI polls; io PSI avg10 swung 60→22→31→86 across the session (parallel-session build load). The du re-baseline and the full flake check were NOT run into the storm.

## §f Follow-ups (self-harvest at authoring)

- **f.1 QUEUED** (TODO_LIST + docs/todo/pipeline.md): annotate the phantom 02-10 io-psi citation in the two HISTORICAL reports (2026-10-14_05-03 §2 + 2026-10-15_03-29 §2) — CHANGELOG left as-is (append-only).
- **f.2 Deliberately not harvested:** full `nix flake check --no-build` was PSI-deferred (io avg10 86% at decision time) — the pre-commit hook is the standing enforcement and runs it at commit time; the evo-x2 toplevel eval (rc=0) covers both module edits on their only consumer host.
- **f.3 Deliberately not harvested:** the du -sb MB-grain re-baseline stays owned by its existing open rows (queue + storage.md 162) with their calm-window gate; no new row minted.
- **f.4 Deliberately not harvested:** statix inherit-suggestion at browser-history.nix:765 — pre-existing, cosmetic, outside my edit scope.

## §g Remaining quick-win candidates NOT taken this pass

mutation-smoke.sh night-quiet semantics (script behavior change — deserves its own pass with the fixture battery); mkSqliteBackupUnit sidecar cleanup (lib/default.nix, multi-consumer surface); trash-prune timer (doctrine-adjacent); io-psi-crosscheck `--verdict` mode (row 29). All remain `[ready]` in the queue.
