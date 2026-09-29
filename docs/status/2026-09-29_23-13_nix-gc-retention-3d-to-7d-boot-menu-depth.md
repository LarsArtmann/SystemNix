# Status: nix.gc Retention 3d → 7d (Boot-Menu Generation Depth)

**Date:** 2026-09-29 23:13 CEST · **Scope:** single-session work only (per instruction) · **Format note:** user requested `.md` explicitly — overrides the status-report skill's HTML default, one-off.

**Session arc:** user asked why the boot loader shows only ~5 generations → root-caused to `nix.gc` retention (NOT the boot-loader limit) → changed retention 3d → 7d → eval-verified on both hosts → updated AGENTS.md → this report + self-harvest.

**Parallel-session context (attribution):** commits `31392dbf` (23:03, gatus-panic-storm work: memory-emergency-guard.md, gcp.json, AGENTS.md gatus bullet) and `2219d994` (23:16, journal-hot-gap-io-storm report) are OTHER sessions' work riding the shared tree tonight. My commits: `de0feb7e` (nix-settings 7d, 10:08:58) and `7cd35595` (AGENTS.md retention note, 11:51:53). The wall-clock spread between my edit (10:08) and the final eval verdict (23:06) is the background-eval churn on this box under five concurrent parallel evals/builds — the evals themselves were queued for hours, not broken.

---

## a) FULLY DONE

| # | What | Evidence | Scope |
|---|------|----------|-------|
| a1 | **Root cause: boot menu depth is set by GC retention, not the loader limit.** `configurationLimit = 50` (`platforms/nixos/system/boot.nix:36`) never binds — the daily `nix-collect-garbage --delete-older-than 3d` (`platforms/common/nix-settings.nix:55`, pre-change) deleted every system generation older than 3 days, and NixOS activation prunes boot entries whose generations no longer exist. Live profile held exactly 4 generations (797–800) = the ~5 entries seen. | profile listing (`ls /nix/var/nix/profiles/system-*`), config grep, AGENTS.md gcroots doctrine (2026-09-09 gcroots repair already fixed the historical never-GC-rooted class; retention was the remaining binding constraint) | diagnosis only |
| a2 | **Retention raised to 7d**, committed by the daemon. | commit `de0feb7e` (1 file, `platforms/common/nix-settings.nix:55`: `options = "--delete-older-than 7d";`) | nix-settings.nix |
| a3 | **Rendered-option verification on BOTH hosts** (the file is `platforms/common`, so darwin inherits). | `nix eval .#nixosConfigurations.evo-x2.config.nix.gc.options` → `"--delete-older-than 7d"` (rc 0); `nix eval .#darwinConfigurations.Lars-MacBook-Air.config.nix.gc.options` → `"--delete-older-than 7d"` (rc 0) | evo-x2 + Lars-MacBook-Air evals |
| a4 | **Stale-reference sweep + AGENTS.md update.** Repo-wide grep: every other `--delete-older-than 3d` hit is archived status reports / historical crash analyses (deliberately untouched — history is history). The only live-ish carrier was the AGENTS.md gcroots bullet; updated surgically with the change + tradeoff note. rpi3 already forces 7d (`platforms/nixos/rpi3/default.nix:189`). | commit `7cd35595`; grep sweep output in session | AGENTS.md |
| a5 | **Self-harvest at authoring** (AGENTS.md TODO-system mandate): 7 rows landed across 5 files — see §f marks "HARVESTED". | `TODO_LIST.md` (4 queue rows), `docs/todo/{storage,pipeline,stability,monitoring}.md` | todo system |

## b) PARTIALLY DONE

| # | What works | What remains | Blocker | Effort |
|---|-----------|--------------|---------|--------|
| b1 | The 7d retention change: config committed (`de0feb7e`), both-host render verified (a3). | **Not deployed** — the running host's `nix-gc.service` still executes `--delete-older-than 3d` until the next `nix run .#deploy`. Boot-menu depth effect unverifiable until then (agent sandbox blocks `sudo`; `/boot` listing and the profile lock file are root-only). No full `nix flake check --no-build` was run this session — targeted evals only (justified: one string literal in an existing `checkConfig = true` option; the daemon pre-commit hook ran the full gate on `de0feb7e` and passed it). | deploy is human-owned; `sudo` blocked in the agent harness | S (deploy) + S (verify) |

## c) NOT STARTED

All of these are planned follow-ups surfaced by this session, none started — each is queued or decided-against in §f:

1. **Deploy + post-deploy verification** (§f1, harvested as `[blocked:deploy]` in storage.md).
2. **1-week store-growth watch** — measure what 7d of retained closures costs on the Samsung `/nix` vs the old 3d baseline (§f3, harvested as `[watch]`).
3. **User/home-manager profile retention decision** — the root GC run applies 7d to ALL profiles, not just the system boot menu (§f4, harvested as `[decision]`).
4. **rpi3 `mkForce` redundancy cleanup** (§f5), **troubleshooting-doc annotation** (§f6), **boot-entry inventory verb** (§f7), **`/nix` monitor gap-check** (§f8) — all harvested as `[ready]` queue rows.
5. §f9–f12 (comment at definition site, configurationLimit headroom note, CHANGELOG entry, harness-quirk documentation) — deliberately not harvested (reasons inline in §f).

## d) TOTALLY FUCKED UP

Nothing from this session is broken — no eval failures, no test failures, no tree damage. The honest entries:

| # | What | Severity | Root cause | Mitigation |
|---|------|----------|-----------|------------|
| d1 | **The change is undeployed, and the loss is one-way.** Every day it sits, the 03:xx GC run keeps pruning generations under 3d — days that 7d *would have kept* are being destroyed daily and cannot be retro-recovered by deploying later. | Low (no functional break; just shallower rollback than intended) | deploy timing is human-owned | Deploy (§f1). Flagged prominently so the cost of waiting is visible. |
| d2 | **Harness anomaly (not SystemNix):** my first background eval invocation (stdout piped through `tail`) completed with ZERO output, and a chained `nix eval … > /tmp/f 2>&1; echo rc=$?; cat /tmp/f` inside ONE background command returned `rc=0` but `cat: No such file or directory` — the /tmp intermediate vanished mid-chain within a single shell. | Low (workflow friction; cost ~hours of wall-clock across re-runs) | Unknown — suspected Crush bash-harness/sandbox shim behavior; /tmp cleaners don't act in seconds | Print background-job output to **stdout** — worked 3/3 times. Never rely on /tmp intermediates in chained background commands. |

## e) WHAT WE SHOULD IMPROVE

1. **Background-job I/O discipline:** write eval/verification output straight to stdout. My piped-stdout and /tmp-file attempts both silently lost data and the silent-failure mode made me re-derive state instead of reading it. Same class as the AGENTS.md "print raw error context from the source" rule — extended to background shells.
2. **Harvest duty checked BEFORE finishing a change, not at report time:** the TODO-system self-harvest mandate is in AGENTS.md; I only re-read it during report authoring. Reading `TODO_LIST.md` tail immediately after any user-visible config change would have made this automatic.
3. **Considered and rejected — grep-gate for retention-figure echoes:** the root-window retention figures earned a grep-gate because 7 stale echo sites accumulated across sessions. GC retention has exactly ONE live config site; a gate is overkill. Revisit only if the figure changes again and echoes appear.
4. **Considered and rejected — post-deploy smoke for GC retention:** the contract is the rendered unit text (`nix eval`-verifiable, already done); a live smoke would assert nothing the eval doesn't.
5. **Agent-unverifiable root-owned state is a recurring verification gap:** boot-entry count and profile-generation listing both need root (`sudo` blocked in the harness). The house pattern already exists — self-elevating `pre-reboot-check` — and §f7 proposes reusing it. Also: the read-only fallback `ls /nix/var/nix/profiles/system-*` (used this session) is worth folding into the existing verification-verb-template row in pipeline.md rather than a new row (no-duplication rule).
6. **CHANGELOG/FEATURES ownership:** config changes like this are user-visible; the docs-health pass owns CHANGELOG — noted as §f12 instead of a drive-by edit during report authoring.

## f) Next tasks (honest set: 12 items — all session-derived; ≤50 asked, no padding)

| # | Task | Impact | Effort | Category | Harvest |
|---|------|--------|--------|----------|---------|
| f1 | Deploy the 7d retention change (`nix run .#deploy`), then verify: `nix eval .#nixosConfigurations.evo-x2.config.systemd.services.nix-gc.serviceConfig.script`-style unit grep shows 7d, and boot entries accumulate toward ~7d of deploys as generations survive (4 gens/3d observed → expect ~8–12 entries steady-state). | **Critical** — the whole point of the change; undeployed days permanently lose rollback depth (d1) | S | Feature | **HARVESTED** → storage.md `[blocked:deploy]` |
| f2 | (folded into f1's verify step) — listed separately only to note the boot-menu check needs `pre-reboot-check` or sudo; no standalone action. | — | — | — | folded |
| f3 | After ~1 week deployed: measure `/nix` store growth attributable to 7d retention (7d of full closures vs prior 3d baseline); owner decides keep vs tighten (5d). The `min-free = 5GB` GC trigger is the existing backstop; each generation's closure on this box is large (shared but pinned while referenced). | High | S | Decision | **HARVESTED** → storage.md `[watch]` |
| f4 | Decide whether user/home-manager profile generations need their own (deeper or shallower) window — the root GC run applies 7d to ALL profiles (`/nix/var/nix/profiles/per-user/*` included), so HM rollback depth silently changed too. | Medium | S | Decision | **HARVESTED** → storage.md `[decision]` |
| f5 | Verify rpi3 imports `platforms/common/nix-settings.nix`; if yes, drop the now-value-identical `mkForce` on `nix.gc.options` (`platforms/nixos/rpi3/default.nix:189`) — or document why rpi3 must pin independently. | Low | S | Cleanup | **HARVESTED** → pipeline.md `[ready]` |
| f6 | Annotate `docs/troubleshooting/STORAGE-OPTIMIZATION-PLAN.md` (4× `--delete-older-than 3d` commands): standing config is now 7d; manual 3d cuts are emergency-only deeper sweeps. | Low | S | Documentation | **HARVESTED** → pipeline.md `[ready]` |
| f7 | Boot-entry inventory verb: extend `pre-reboot-check` (or add a small self-elevating app) to print the systemd-boot entry list + per-entry generation mapping — agent sessions can then verify boot-menu depth without raw `sudo` (the exact check this change needs post-deploy). | Medium | M | Feature | **HARVESTED** → stability.md `[ready]` |
| f8 | Gap-check: does `/nix` (Samsung tlc) have ANY usage monitoring? (7d retention makes store growth the cost side of the tradeoff; `min-free` only acts at 5 GB free.) If nothing exists, add a textfile metric + Gatus check. Verify-no-existing-monitor first. | Medium | M | Feature | **HARVESTED** → monitoring.md `[ready]` |
| f9 | Add a one-line tradeoff comment at the `gc` block in nix-settings.nix (closures pinned on unsnapshotted Samsung `/nix`; AGENTS.md note is the interim carrier). | Low | S | Documentation | not harvested — trivial on-touch task; avoid queue noise |
| f10 | configurationLimit headroom note: observed cadence 4 gens/3d → 7d ≈ 8–12 gens, far under the 50-entry cap; `/boot` + 4G Samsung ESP mirror unaffected. Record-and-close, no action expected. | Low | S | Documentation | not harvested — closes itself with this report |
| f11 | CHANGELOG entry for the retention change (user-visible behavior: ~1 week of boot-menu rollback instead of ~3 days). | Low | S | Documentation | not harvested — docs-health pass owns CHANGELOG; drive-by edits during report authoring are the anti-pattern |
| f12 | Document the d2 harness quirk ("background jobs: stdout only, never /tmp intermediates") — belongs in the crush-config repo's lessons, not SystemNix. | Low | S | Documentation | not harvested — out-of-repo target (crush-config), needs a separate touch |

**Harvest summary:** f1–f8 harvested at authoring (7 library rows + 4 queue one-liners, per the queue↔library no-drift rule). f9–f12 deliberately not harvested, reasons inline. Items are a brainstorm seed per the skill's >25 rule — none committed beyond what the todo files now carry.

## g) Questions I cannot answer myself

1. **Deploy timing:** deploy the 7d change now, or ride the next regular deploy window? (Every undeployed day keeps the 3d GC destroying generations that 7d would have kept — d1 — and that depth is unrecoverable after the fact.)
2. **Scope of "rollback depth":** is boot-menu (system generation) depth the only goal, or do you also want deeper home-manager/user-profile rollbacks? The root GC run just silently moved ALL profiles to 7d, not only the system profile.
3. **Revert threshold:** what `/nix` (Samsung, shared with the hot tier + borg cache) growth would make you revert to a shorter window? The only automated backstop today is `min-free = 5GB`; I can't know your space tolerance, and a week of 7d-retention data is needed before the number is measurable.

---

*Evidence anchors: config `de0feb7e` · AGENTS.md note `7cd35595` · evo-x2 + darwin evals rc 0 · profile gens 797–800 at diagnosis. Parallel-session commits tonight (NOT this session's): `31392dbf`, `2219d994`.*
