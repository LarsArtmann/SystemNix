# T-02 btrbk Excludes: Exclude-Rot Guard + Migration Runbook (Storage-Pareto Exec 1)

**Scope:** VERIFIED first-hand this session: `btrfs subvolume create` unprivileged on /data (live probe 22:43; delete EPERM — residue noted), btrbk config semantics (no per-directory exclude exists — nested-subvol mechanism, repo doctrine pre-documented in snapshots.nix + storage.md), PSI readings across the evening (IO 97 → 40 → 39), the tq/quotaboard parallel sessions' state (commits read, hook failure attributed), fixture build + 3/3 negative legs + shellcheck + evo-x2 toplevel drvPath eval (green, 1m30s). NOT verified: the deployed runtime (deploy intentionally handed to the armed watcher — see §b1), the migration itself (PSI-gated out tonight), root-side `btrfs subvolume list /data` (agent-blocked; the plan/audit premise covers it).

## a) FULLY DONE

1. **Plan marker + commit discipline held under heavy contention.** `docs/planning/2026-11-03_20-49_SUPERB-storage-pareto-plan.md` marked EXECUTING (22:37, HEAD 89d4046fe) and committed inside the T-02 slice `d315d3a3b`. Three index.lock collisions with parallel sessions (quotaboard commit, tq batch) resolved by poll-retry — no resets, no amends.
2. **T-02 premise-check CORRECTED the plan's mechanism.** "Draft excludes block" as btrbk config does not exist — btrbk operates at subvolume granularity. The owner decision ("NEVER pool-backup re-downloadable AI models") is implemented the way this repo already documents: nested subvolumes are silently skipped by `btrfs subvolume snapshot` AND `btrfs send` (migrate-nix-subvol precedent). All config/code legs landed in `d315d3a3b`:
   - `scripts/btrbk-data-gate.sh` — the btrbk-data ExecStartPre moved in-tree (root-prune-guard shape), preserving the EIO gate byte-for-byte and adding the exclude-rot guard: WARNING while EIO-gated (send is dead anyway — visibility only), HARD send-refusing tripwire once `/data/.repair-done` exists; a path absent entirely reads CLEAN (the T-12 purge shape — a purged gcs-staging must not brick the send).
   - `scripts/migrate-data-exclude-subvols.sh` — the calm-window migration: PSI<20 + Steam-closed self-gated, idempotent, zero-IO (`cp -a --reflink=always`), exact file-count + apparent-size parity verify, `.pre-subvol` rollback insurance kept (extent-shared ≈ free). Runs UNPRIVILEGED (verified live).
   - `checks.btrbk-data-gate-fixture` — 6 behavioral cases + the ExecStartPre wiring pin (stray-attrname class). Two fixture bugs caught by actually building it (sandbox shebangs → patchShebangs; `$3` full-path vs basename in the stub) — the negative-test discipline paying for itself.
   - `negative-test-lints.sh` datagate group — 3/3 green (script-content sensitivity, wiring-drop, comment-immunity control).
3. **Row updated, structure clean.** `docs/todo/storage.md` btrbk-data-excludes row carries the full UPDATE (landed/pending split); `check-todo-system.sh` structure OK.

## b) PARTIALLY DONE

1. **Deploy: deliberately NOT fired by this session.** The quotaboard session's `scripts/deploy-when-quiescent.sh --fire` watcher is ARMED and will carry `d315d3a3b` (HEAD) the moment the tree is clean + 300s-cold + green-eval — the tree was still hot with parallel-session dirt at session end (staged quotaboard float, dirty docs). Firing a second deploy beside the watcher would duplicate the exact race the watcher exists to prevent. Post-deploy leg owed: anchor verify + confirm the rendered unit carries `btrbk-data-gate`.
2. **Migration not run (PSI-gated).** IO PSI was 97 at start, 39-40 at end — never under the script's own 20 bar. The gate is now self-enforcing: from the next 23:30 run (post-deploy), the journal shows `EXCLUDE-ROT WARNING` until the migration lands — the tripwire is live.

## c) NOT STARTED

1. T-01 Phase F shadow reclaim — burn-in ends ≥2026-11-04 (plan gate; auto-go pre-approved). Tonight is deliberately early.
2. T-05 EIO repair — gated on calm window + owner T06a + T-02 migration (chain intact).

## d) TOTALLY FUCKED UP (avoid next time)

1. **My first negative-test leg failed as an "eval accident"** — the wiring mutation made `ExecStartPre` vanish entirely, so my throwIfNever guard never rendered its marker (attribute-missing eval error instead). The `or null` guard is the fix; the harness's own FAIL message taught the lesson before it shipped. Should have written the mutation-shape check before the check.
2. **I wrote a fixture heredoc with `${3##*/}` inside a Nix indented string** — Nix would have interpolated it; caught while reviewing my own edit, escaped as `''${`. Two minutes earlier via `nix build` would have been the honest path — build FIRST, not eyeball.

## e) WHAT WE SHOULD IMPROVE

1. The pre-commit hook's repo-wide textfile-tmp audit let ONE parallel session's in-flight line (`quickshell.nix` secrets-rendered path) block every OTHER session's commits for ~15 min. Consider scoping that audit leg to staged paths (like eval-relevant-paths gating) — the blast radius of an in-flight mistake should not be repo-wide.
2. `deploy-when-quiescent.sh` should log its fire decision somewhere greppable (journal or file) — post-deploy attribution for riding sessions currently depends on pgrep luck.

## f) Top things to get done next (self-harvested at authoring time)

1. Run `scripts/migrate-data-exclude-subvols.sh --dry-run` then real in the first calm window (IO+CPU PSI <20, Steam closed) — queued below.
2. After the watcher fires: verify anchor (`readlink /run/current-system` == newest system-N-link by NUMBER) + grep the rendered unit for `btrbk-data-gate` + watch the next 23:30 journal for the WARNING line (pre-migration) — folded into the queued row.
3. T-01 tomorrow (2026-11-04+): burn-in premise-check (10-28 plan Phase F ≥7d), then the 10-step ladder.
4. Owner ladder additions: root-delete `/data/.subvol-create-probe`; SMART check; T06a sign-off list (all already T-27 batch candidates — recorded in the row UPDATE).

*(Queue surface: TODO_LIST.md row "Run the /data exclude-subvol migration" carries items 1-2 with this report as Source; items 3-4 live in existing rows storage.md:226 [watch] and the T-27 pattern.)*

## g) Questions I can NOT figure out myself

1. None blocking. The quotaboard session's hook-breaking line was fixed by its own session mid-flight (verified absent); if it returns, the §e.1 scoping fix is the systemic answer.
