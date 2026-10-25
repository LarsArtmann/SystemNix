# PapDashboard Follow-Ups: Opt-Out Contradiction Gate + vHost⇒Registry Blind-Spot Gate

**Created:** 2026-10-25 09:46 CET · **Session:** resume of the 07:40 tile-coverage session (owner dispatch: "execute the outstanding steps") · **HEAD at start:** `f4a965767` → work rode daemon batches through `26b6b086e`
**Scope:** the two `[ready]` rows queued by `2026-10-25_07-40_papdashboard-tile-coverage-enforcement.md` §f.3/§f.6, deploy-window assessment, owner questions. Nothing else.

---

## a) FULLY DONE (verifiably)

1. **Row §f.6 — `noDashboardTile` + `homepage` contradiction fails eval.** `contradictoryOptOuts` filter + assertion in the papdashboard-gated branch of `modules/nixos/services/integration.nix` (message names the entry and both fixes); `noDashboardTile` option description documents the contradiction. Tests at both layers: pure-eval `optoutContradictionFires` (ghost-optout fixture) in `tests/test-integration.nix` (failure ladder extended), harness leg `tilecoverage/optout-with-tile` (sed plants the flag beside miniflux's live tile). Verified live: `CASES=tilecoverage` **4/4 PASS** (control + 3 legs), `checks.x86_64-linux.integration-registry` built green.
2. **Row §f.3 — registry blind-spot audit + mechanical class closure.** Enumeration from LIVE EVAL, not grep: 37 named `*.home.lan` vHosts vs 30 registry subdomains → **7 blind**: `alerts` + `logs` (redirect/alias infra: dash alias, SigNoz logs-explorer redirect), `auth` = pocket-id, `seo` = openseo, `tasks` = taskchampion-sync-server (caddy.nix:546), `dnsblock`/`dnsblockd` = dns-blocker's hand-written pair (its registry entry deliberately carries `subdomain = null`, vHost.layer "none"). Closure: `registryBlindSubdomains` table (7 justified names, per-name comment) + **vHost⇒registry assertion** in `modules/nixos/services/caddy.nix` — no NEW hand-rolled vHost can appear silently; registration is the preferred fix. Verified on a HEAD-locked copy: control eval green (allowlist exactly covers the blind set), mutation leg (allowlist `"alerts"`→`"alerts-typo"`) fails eval with **single attribution** — only the new audit throws (the dns-local assertion stays quiet because alerts has a DNS entry). Harness leg `vhostregistry/blind-vhost` wired + control-filter extended.
3. **Four registrations queued `[blocked:user]`** (TODO_LIST.md + docs/todo/services.md): pocket-id / openseo / taskchampion-sync-server / dnsblockd-subdomain — each gated on the §g answers, each deletes its allowlist row when done.
4. **All queue/doc surfaces synchronized**: both `[ready]` rows flipped `[x]` with DONE narratives in BOTH TODO_LIST.md and docs/todo/services.md (no drift); report §f rows 3/4/6 annotated (#4 = foreign upholds test, fixed by owning session `050567953`); CHANGELOG entry at head; `docs/services/caddy.md` (gate documented); `docs/agents/integration-registry.md` (both the contradiction and the reverse-direction gate); `bash scripts/check-todo-system.sh` → "OK: TODO queue/library structure clean".
5. **Deploy decision made and defended**: NOT deployed. Live conditions at assessment (09:44): k10temp **95.5°C** (>85 doctrine line), io PSI avg60 **56%** (>30 line), driven by a 210%-CPU nix `compile` (exec-2's float verification) + nsfw-classifier churn; PLUS the working tree is mid-lock-float (`flake.lock` drifted vs `flake/expected-locks.nix` on 11 inputs — exec-2's deliberate float procedure incomplete) and the quickshell dead-guard red is still open, so full-tree validation is impossible. Deploying into freeze-adjacent heat would violate the freeze-#33/#34 doctrine the repo just ratified. The tile batch rides the existing `[watch]` row on exec-2's storm-gated batch; anchor state verified consistent in the meantime (`readlink /run/current-system` == system-942 == newest gen by number).

## b) PARTIALLY DONE

1. **`vhostregistry` harness leg: proven equivalent-but-not-in-harness.** `CASES=vhostregistry` FAILED in the harness — not on the audit, but because `make_copy` copies the working tree's drifted flake.lock and every eval dies at the lock-float gate. I proved the exact mutation+marker on a manual HEAD-locked copy (rsync tracked files, `git show HEAD:flake.lock` override), but the leg has **never run green through the harness itself** (spec parsing, no-op detection, marker grep as wired). Re-run rides the tree-settled pass — noted in the library row.
2. **Foreign-red triage (flagged, not fixed — deliberately):** dead-guard red on `platforms/nixos/desktop/quickshell.nix:50` is STILL RED as of 09:3x. I diagnosed it to FP-grade precision (a `$(ls … | head -1)` capture cannot propagate failure under errexit without pipefail, so the guard IS reachable — the lint's premise is wrong for pipe-to-head) and wrote that into the report §f.5 annotation, but did not touch the owning session's file or the scanner (doctrine says scanner FPs get fixed in the SCANNER — tension flagged in §e.3).
3. **Live matrix re-verified only on the HEAD-locked copy** (30 web-facing / 28 tiles / 2 opt-outs unchanged); the working-tree eval path is unusable mid-float, so no fresh working-tree confirmation exists. Harmless (deploy builds whatever the tree is when it settles), but honest bookkeeping.

## c) NOT STARTED (deliberate, this session)

1. **The deploy itself + post-deploy tile eyeball** (Forgejo/Development, Paperless/Productivity, Immich/Media; dot sanity: 302/401 fine, ≥500 down; no accidental default-"Services" group) — blocked on the storm + tree settle; the `[watch]` row owns it.
2. **The four registrations** — owner-gated by design (§g).
3. **§7–#12 long-tail from the 07:40 report** — deliberately unharvested by the prior session pending owner triage; I did not preempt.
4. **`nix flake check` full-tree** — impossible mid-float (lock gate red) until exec-2 lands expected-locks.nix; not attempted beyond the named per-check builds.

## d) TOTALLY FUCKED UP (radical honesty — all caught in-session, none shipped)

1. **Hit the `rg -r` hook trap MYSELF** — typed `rg -rn "tasks.home.lan"` (intending recursive+line-numbers); the hook blocked it (third-strike class on this host, documented in AGENTS.md, and I had just re-read that rule this session). Retried correctly with `rg -n`. The guard worked; my fingers didn't.
2. **Pipe-eaten exit codes, TWICE:** (a) `nix build … | tail -5; echo "rc=$?"` printed `rc=0` while the dead-guard check had FAILED (rc was tail's) — the prior session's summary documents this EXACT class ("grep matched warning lines → 4 green checks reported FAIL briefly; fix: exit-code-first") and I still wrote it; caught because the FAIL text was in the output. (b) `pgrep -af … | head -3; echo "pgrep-rc=$?"` — rc was head's; noticed inline, but only after writing it.
3. **Misattributed a tool failure to the wrong layer:** the first `nix eval --apply` null-out failure got blamed on the working-tree lock float (because `tail -5` showed the lock warning); the copy's identical-looking failure was actually `attribute 'filterAttrs' missing` in the `--apply` scope. Burned ~4 extra eval cycles (each a full evo-x2 eval) before pivoting to raw-JSON + jq filtering. Root cause of the `--apply` scope quirk: **still unknown** (§f.4).
4. **Ran eval-heavy verification DURING the storm:** PSI was already ~50% and rising when I ran the 4-leg negative-test suite + multiple toplevel evals; k10temp hit 95.5°C mid-session (partly my load on top of exec-2's compile). I treated the PSI/temp doctrine as deploy-gating only and evals as exempt — wrong call in hindsight; the samplers exec-2 just shipped exist precisely because evals/builds ARE the storm. Should have batched evals tighter and checked temp BEFORE the negative-test run, not after.
5. **Introduced a stray backtick typo** in a TODO_LIST.md strikethrough (`tile`**~~`) — caught and fixed one edit later.
6. **Mid-race edit collision on CHANGELOG.md** (`file modified since read` — exec-2 added entries at 08:42): handled by re-reading, but my first attribution of the mtime was wrong (assumed my earlier bash `sed` read counted; it doesn't — only `view` registers).

## e) WHAT WE SHOULD IMPROVE (process, not bugs)

1. **Exit-code discipline needs a mechanical guard, not memory.** Two pipe-rc mistakes in one session AFTER the class was documented repo-wide. Candidate: a tiny pre-commit/harness lint for `; echo "rc=$?"` following a pipe, or just a session-habit rule: rc only from `if cmd; then` forms.
2. **Heavy-eval gating should mirror deploy gating.** The repo now has PSI/temp doctrine for deploys; nothing gates `nix eval`/negative-test storms. A cheap pre-flight (`cat /proc/pressure/io`, k10temp) before any eval batch would have caught #d.4. Could fold into the harness (WARN + confirm) — queued §f.5.
3. **Scanner-FP doctrine vs session-ownership doctrine can collide.** The dead-guard quickshell finding is a scanner FP by my diagnosis; the 2026-09-19 rule says fix the SCANNER, but the file/finding belongs to a live parallel session. I chose ownership discipline (diagnose + document, don't touch). The repo needs a tie-breaker rule for "FP in shared scanner, red on foreign file, owning session absent" — queued §f.6.
4. **`make_copy` is lock-fragile.** The harness copies the working-tree flake.lock verbatim, so ANY mid-float tree zeroes every eval-based case with an error that looks like a case failure. Either fail-fast with a distinct "tree mid-float, rerun later" message or auto-pin the copy's flake.lock to HEAD when the working tree's lock is dirty vs expected-locks — queued §f.7.
5. **The `nix eval --apply` builtin-scope quirk should be root-caused once** (filterAttrs "missing" while attrNames works) — either a real nix/pipe-operators behavior worth documenting in shell-devtools notes, or my misuse worth a one-line convention. Unexplained tool behavior that cost 10 minutes will cost the next session the same.

## f) Next tasks (session-derived; honest count 7 — not padded to 50)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Deploy the tile+follow-up batch when the storm clears (PSI<30 AND k10temp<85 AND lock settled AND dead-guard green): `nix run .#deploy`, readlink anchor discipline, then the post-deploy tile eyeball — ALREADY QUEUED as the `[watch]` row, listed here for completeness | Critical | S | Feature |
| 2 | Re-run `CASES=tilecoverage` + `CASES=vhostregistry` on the settled tree — the vhostregistry leg has never run green through the harness as wired (proven equivalent on a HEAD-locked copy only) | High | S | Testing |
| 3 | Answer §g → then register the four blind services (each deletes its `registryBlindSubdomains` row; openseo/tasks registration drags gatus port-coverage probes + §16 icon inventory) — ALREADY QUEUED `[blocked:user]` | High | M | Feature |
| 4 | Root-cause the `nix eval --apply` scope quirk (`builtins.filterAttrs` "missing" while `attrNames` works) and document the working pattern | Low | S | Tooling |
| 5 | Pre-flight PSI/temp check before eval-heavy batches (harness WARN or session habit) — the deploy doctrine extended to evals | Medium | S | Stability |
| 6 | Tie-breaker rule: shared-scanner FP on a foreign-owned red file with the owning session absent (fix-scanner vs leave-red) — the quickshell dead-guard case is the live example | Medium | S | Process |
| 7 | `make_copy` lock-fragility: distinct fail-fast on mid-float trees (or HEAD-pin the copy's flake.lock) so harness cases stop phantom-failing during deliberate floats | Medium | S | Testing |
| 8 | One cheap rpi3-dns toplevel eval after settle to confirm the caddy.nix assertion is structurally inert there (expected: caddy not enabled → mkIf inert; verified by construction only) | Low | S | Verification |
| 9 | Check `services.catalog` coverage for seo/tasks (the audit was integration-scoped; catalog is the "what exists" registry — openseo may be catalog'd but integration-blind) | Low | S | Quality |

*Harvest status: #2, #4, #5, #7 harvested to TODO_LIST.md + docs/todo/pipeline.md; #8, #9 to TODO_LIST.md + docs/todo/services.md. #1 and #3 already existed as queue rows ([watch] / [blocked:user]) — referenced, not duplicated. #6 is a [decision] row (pipeline.md) — the rule choice is owner-shaped.*

## g) Questions I cannot answer myself

1. **§16 severity:** should the pre-deploy monogram-tile BLOCK soften to warn-and-continue (matching the eval-side WARN policy you set for icons), or stay the hard logo bar at deploy? (Queued `[decision]` since the 07:40 session; the eval now warns while §16 still blocks, so an icon-less tile can pass eval but never ship.)
2. **The web-facing line:** is `subdomain != null` the permanent definition of "must be on the dashboard"? This single answer decides the registration SHAPE of dnsblockd (give its existing layer-"none" entry a subdomain + tile?) and whether openseo/taskchampion get standard entries.
3. **Pocket-id's registry absence:** deliberate circularity avoidance (the OIDC provider provisioning OIDC clients for itself?) or an oversight to fix by registering it like any other service? All four registrations in §f.3's spawn row are gated on this + Q2.

---
*Session verification evidence: `CASES=tilecoverage` 4/4 PASS (09:0x); `checks.x86_64-linux.integration-registry` green (post-assertion); vhost⇒registry control green + mutation single-attribution fire on HEAD-locked copy (09:3x, `/tmp/vhost-leg2.txt` rc=1, dns-local assertion count 0); shellcheck harness delta 9→10→9 SC2016 (pre-existing only); `check-todo-system.sh` OK. Storm at close (09:46): io PSI avg60 70%, k10temp 87.0°C — window still closed.*
