# Status Report: Deploy Unblock — buildflow Lock Surgery + Miniflux Go-Live Prep

**Date:** 2026-09-11 01:38 CEST
**Session scope:** "fix deploy" — diagnose and repair the blocked evo-x2 deploy, complete everything short of the root-gated switch.
**Format note:** User explicitly requested `.md`; the status-report skill's HTML default is overridden for this report (skill divergence flagged, not propagated).

---

## Executive Summary

The deploy was blocked by **two independent, stacked causes** — neither was what the previous session's handoff summary claimed as the primary story:

1. **`platforms/nixos/secrets/miniflux.yaml` was never committed** (created last session, but `git add -f` was missed — the secrets dir is gitignored). The tracked-files trap made **every** evo-x2 toplevel eval fail with "make it visible to Nix" since commit `22bb08cb`. This was invisible in the previous session's verification because its VM test used `getFlake` on the tracked set only.
2. **The buildflow lock node sat at broken rev `9a8a350`**: its go.mod requires `github.com/larsartmann/go-finding/toolsdk v1.10.0`, but its flake.lock pinned go-finding at `232fe0ed`, which **predates** the toolsdk extraction into go-finding (`fc627fb` "feat(toolsdk): add toolsdk sub-module migrated from buildflow/tool-sdk"). The prepared-source FOD died: `reading _local_deps/go-finding/toolsdk/go.mod: no such file or directory`.

Both fixed. The deploy is now **fully built and fully gated, waiting only on the sudo-required switch**.

**Fix chosen:** surgical re-lock of buildflow → `56c755f0e` — the newest **pushed** rev where (a) the go-finding input carries toolsdk (`fc627fbb`), AND (b) the committed `vendorHash.nix` is in sync (it was refreshed at that very commit for the golangci-lint-auto-configure v0.8.0 + gogenfilter v3.6.0 repins). Upstream master HEAD (`b693c505d`) was probed and is **itself broken** (stale vendorHash: specified `sha256-JxYt/NE7Ct5qM2fi0dnHsyxm+n00ZRr7qkTbAnLvq8g=`, got `sha256-0NQweZeM06UiN3AWkd033QpfTGAZp2Gte05+aaw2b+I=`) — so a plain `nix flake lock --update-input buildflow` would have "fixed" the lock into a NEW breakage. `56c755f0e` is 26 commits ahead of the broken `9a8a350`, so no meaningful features are lost vs. master.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **Root-caused the deploy blocker chain** (2 independent causes, both reproduced before touching anything) | FOD error log from `nix build .#buildflow`; `nix-store -qR` on the toplevel drv showed 4 buildflow derivations inside the closure; `nix eval toplevel.drvPath` reproduced the untracked-file error verbatim |
| 2 | **Fixed the untracked sops secret** — `git add -f platforms/nixos/secrets/miniflux.yaml` | Staged (`A` in git status); toplevel eval went from error → `/nix/store/0ccsfzn2…-nixos-system-evo-x2-…drv` |
| 3 | **Lock surgery: buildflow `9a8a350` → `56c755f0e`** with full subtree resync | Python diff of flake.lock vs. pre-change backup: **exactly 5 nodes changed** (`buildflow`, `go-finding_3`→`fc627fbb`, `go-checker-helpers`→`316c2a8`, `gogenfilter_4`→`b79a9d2`, `golangci-lint-auto-configure`→`1f653cb`), zero other nodes touched, zero node keys added/removed |
| 4 | **flake.nix left byte-identical** — temp rev-pin used only to force the re-lock, then URL and the lock node's `original` field restored to plain `?ref=master` | `git diff --stat flake.nix` → empty; `nix flake lock` re-run → no-op, rev stays `56c755f0e` (stable state, same shape as the pre-existing `9a8a350` node) |
| 5 | **Probe-before-lock discipline followed** — go-modules FOD built lock-free at `56c755f0e` via `builtins.getFlake` BEFORE moving SystemNix's lock | FOD produced `/nix/store/xpwp2pw…-buildflow-56c755f-go-modules` (hash matched) |
| 6 | **`nix build .#buildflow` green through SystemNix's follows** (nixpkgs + go-nix-helpers overrides applied — the authoritative shape, not the standalone probe) | `/nix/store/l4jc5cm3lbx9q3b3yw0vlkz55ljva1bm-buildflow-56c755f` |
| 7 | **evo-x2 toplevel builds green** with `--keep-going` | `/nix/store/gc4w2ziwhvkmz5z6lngdp3rafand3kqr-nixos-system-evo-x2-26.11.20260905.c043004` |
| 8 | **`nix flake check --no-build` — all checks passed** (sops-key-audit, gate-timeout-audit, port uniqueness, both hosts) | "all checks passed!" (aarch64-darwin omission warning expected per AGENTS.md) |
| 9 | **pre-deploy-check: 115 passed, 19 warnings, 0 failed** — "safe to deploy" | `nix run .#pre-deploy-check` output |
| 10 | **pre-reboot-check: 18 passed, 0 failed** — boot chain verified (default entry gc-rooted, 2-pin rollback ladder intact, booted-system gcroot present) | `nix run .#pre-reboot-check` — "SAFE TO REBOOT with notes above" |
| 11 | **Pressure gate pre-verified**: PSI memory some avg10 = 12.5% (<20), MemAvailable 67.4% (>10), zram fill 37.2% (correct `orig_data/disksize` formula) | Direct `/proc/pressure/memory`, `/proc/meminfo`, `/sys/block/zram0/mm_stat` reads |
| 12 | **Miniflux smoke section added to `scripts/post-deploy-check.sh`** (gated on unit presence): `/healthcheck` must answer 200; `/login` must carry the `/oauth2/oidc/redirect` route (proves OIDC wiring — the href only renders when `hasOAuth2Provider "oidc"` is true, verified against the **actual deployed binary's** embedded login template, not docs); unit must be active. `bash -n` clean | Binary grep of `/nix/store/6a7w97br…-miniflux-2.3.3/bin/miniflux` showing `routePath "/oauth2/%s/redirect" "oidc"`; stable FAIL-name prefixes per the § doctrine |
| 13 | **Upstream BuildFlow master breakage diagnosed and documented** (stale vendorHash at HEAD, exact specified/got hashes recorded) | Lock-free probe of `b693c505d` goModules FOD |

---

## b) PARTIALLY DONE

| # | Item | Works now | Remains open | Blocker | Effort |
|---|------|-----------|--------------|---------|--------|
| 1 | **The deploy itself** | Everything built, gated, smoke-wired | The actual `nh os switch` + post-switch steps | `sudo` is policy-blocked in agent sessions — deploy.sh is sudo end-to-end | S (one command, user-run) |
| 2 | **Post-deploy verification chain** | Smoke section written and syntax-verified | Never executed against a live system | Depends on #1 | S |
| 3 | **Miniflux go-live runbook** (previous session's §f steps) | Build/eval/VM-test/gates done; deploy.sh restart block + smoke wired | First-boot CREATE_ADMIN verification, live SSO login, Gatus green confirmation, backup-dir + first `pg_dump` verification, sops decrypt round-trip | Depends on #1 + sudo for sops | M |
| 4 | **BuildFlow upstream repair** | Root cause + exact fix value known (`0NQwe…` into `vendorHash.nix`) | Commit + push to `LarsArtmann/BuildFlow` master, then re-lock SystemNix off the interim pin | Push requires explicit owner authorization (never-push rule) | S |
| 5 | **Owed reboot** | pre-reboot-check passed 18/0; the reboot would land miniflux cleanly AND clear the flm corpse + D-state pile that only reboot reclaims | Reboot itself is an owner-timing decision (2026-09-09 AGENTS.md notes: owed reboot clears multiple wedges) | Owner timing | S |

---

## c) NOT STARTED

| # | Item | Why not started | Still wanted? |
|---|------|-----------------|---------------|
| 1 | **`OAUTH2_REDIRECT_URL` derivation verification** — confirm Miniflux's default matches the registered Pocket ID callback `/oauth2/oidc/callback` (previous session's "biggest unverified risk") | Requires reading goth/gothic derivation against the live flow; safest verified live post-deploy | Yes — High |
| 2 | **TODO_LIST HARVEST** from this report + the 2026-09-11 00:22 miniflux report (50-item backlog) | Report-then-wait instruction | Yes — next docs-health run |
| 3 | **AGENTS.md gotcha entries from this session**: (a) deleting a flake.lock node errors `lock file references missing node` — nix does NOT silently re-lock it; the supported surgical path is changing the input URL/original to force a re-lock; (b) `jq -S` unsupported in this environment's jq build — use python3 for lock diffs | Report-then-wait instruction; listed in (f) | Yes |
| 4 | **`nix build .#quick-go` batch after the lock move** | The toplevel build covers buildflow (in closure) but NOT the rest of the LarsArtmann Go set; the changed subtree nodes (`go-finding_3`, `go-checker-helpers`) could in principle be shared by other lars packages — quick-go is the one-command enumeration | Yes — before the next deploy touching those inputs |
| 5 | **Owner decisions** on Miniflux API requirement (native-only vs GReader/FreshRSS-class features) and auth posture (break-glass vs SSO-only) | Owner-only; asked in (g) | Yes |
| 6 | **CI green verification** for the new lock on the next push (nix-check.yml; the NIX_GITHUB_RO_TOKEN / private-`github:`-node class historically leaves CI dark silently) | No push happened this session (daemon batches) | Yes |
| 7 | Miniflux restore drill (dump → fresh PG), secret rotation drill, OPML import onboarding | Post-go-live items | Medium |

---

## d) TOTALLY FUCKED UP

1. **The deploy chain was dead-on-arrival from commit `22bb08cb` onward.** The untracked `miniflux.yaml` broke EVERY toplevel eval — any deploy attempt between that commit and this fix would have failed at eval with a confusing "make it visible to Nix" message. Root cause: the previous session knew the tracked-files trap (it's literally in its own gotcha list) and still missed the one file that MUST be `git add -f`'d because secrets/ is gitignored. Severity: total deploy block. Fixed this session. **Class improvement:** any session creating a file under `platforms/*/secrets/` should `git add -f` it IN THE SAME COMMAND as creation, not as a follow-up step.
2. **A broken rev (`9a8a350`) sat in the lock blocking all deploys** — moved there by a parallel session/daemon (exact origin unknown; the rev is an "auto-commit 40 changed files" batch that added the toolsdk requirement WITHOUT bumping the go-finding input). Severity: total deploy block for ~1 day. Fixed. The parallel session that moved the lock evidently did not run the quick-go batch that exists precisely to catch this class before it lands in the lock.
3. **Upstream BuildFlow master is broken RIGHT NOW** (stale vendorHash at `b693c505d`). Severity: high time-bomb — any `nix flake update` (or a plain re-lock triggered by a URL edit elsewhere) pulls the broken head and re-blocks every deploy. Mitigation currently in place: lock pinned at `56c755f0e`. Unresolved — needs the owner-authorized upstream push (see g/Q2).
4. **Honest accounting of my own wasted cycles this session (4):** (a) `builtins.getFlake "…".packages…` parse error (needs parens) — one cycle; (b) `github:` URL rejected the `?ref=master&rev=…` combo (`unsupported parameter 'ref'`) — one cycle; (c) deleting the lock node errored `lock file references missing node` instead of re-locking — restored from backup, one cycle; (d) `jq -S` unsupported — two attempted diffs before switching to python3. Each was caught and corrected within the same step; none produced a wrong state. Additionally, my FIRST zram-fill quick-calc was **wrong** (`$3*100/($3+$4)` on mm_stat = meaningless 100%) — I recomputed with the correct `orig_data/disksize` formula before it could mislead anyone (37.2%). The pattern in all five: single-command failures with immediate self-correction, but they cost ~5 extra round trips that a known-recipe (see (e) #1) would have avoided.
5. **The previous session's handoff summary was load-bearingly inaccurate** — it said eval was verified and attributed the deploy block to buildflow alone. The eval was broken by its own untracked file, and that was the FIRST thing every deploy would hit. Lesson recorded in (e) #5.

---

## e) WHAT WE SHOULD IMPROVE

1. **Codify the re-lock-at-rev dance as a script** (`scripts/relock-input-at-rev.sh <input> <rev>`): backup lock → temp rev-pin the input URL → plain `nix flake lock` → restore URL + fix lock node's `original` → diff-scope assertion (only the input's subtree changed) → print the changed-node list. This session performed it manually across 4 attempts; the recipe is now proven and one command away from being permanent. **Also document in AGENTS.md:** node deletion from flake.lock errors (`missing node`) — the URL-change path is the supported surgery.
2. **Process rule: run `nix build .#quick-go` after ANY flake input update.** The quick-go batch exists exactly to surface FOD breakage before it enters a deploy, and the 9a8a350 lock move proves it isn't being run by the sessions that move locks. Candidate: make deploy.sh's pre-switch path build quick-go when `git diff` shows flake.lock changed (cheap conditional, catches the class at the gate).
3. **Upstream CI for LarsArtmann flakes: each repo must build its OWN flake on push** (`nix build .#default` or `nix flake check`). BuildFlow master carried (a) a lock pin missing a required submodule and (b) a stale vendorHash — two consecutive breaks that a 5-minute CI job would have blocked at the push. This is the enforcement arm of the "vendorHash dances happen upstream" doctrine.
4. **`git add -f` in the same command as secret-file creation** — make it a hard sequencing rule (the file exists → it is tracked → then anything else). The eval-tracked-files trap has now bitten twice from the same shape.
5. **Handoff accuracy:** status summaries that claim "verified" must cite the exact command AND its evidence; and any handoff should re-run the two cheapest gates (toplevel eval + the blocking package build) before writing a "blocked by X" conclusion. This session spent its first steps re-deriving facts the summary got subtly wrong (the summary's buildflow attribution was right, but it omitted the untracked-file blocker entirely).
6. **python3 for lock diffs, always** — `jq -S` doesn't exist in this environment; the python node-diff (keys-changed / values-changed) is the reliable scope assertion and should go into the re-lock script from (e)#1.
7. **mm_stat arithmetic:** zram fill is field 2 / field 1 (`orig_data_size/disksize`). My bogus quick-calc nearly produced a false "zram 100%" claim in a summary. Any quick metric math should use the documented field map, not positional guesses.

---

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

Sorted by impact. Impact/Effort/Category per the harvest guide. **This section is the primary input for docs-health HARVEST** — items marked [R] are ROADMAP-fuel, not TODO_LIST commitments.

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Run `nix run .#deploy` (user; sudo-gated) | Critical | S | Feature |
| 2 | Run `nix run .#post-deploy-check` after the switch — Miniflux smoke + regression baseline diff | Critical | S | Quality |
| 3 | Verify deploy anchoring post-switch: `readlink /run/current-system` == newest numbered profile (exit-4 class guard) | Critical | S | Quality |
| 4 | Verify miniflux first boot: CREATE_ADMIN ran, admin creds work, unit active, journal clean | High | S | Feature |
| 5 | First live SSO login at rss.home.lan → Pocket ID → confirm user creation + callback works (retires the OAUTH2_REDIRECT_URL risk, c#1) | High | S | Feature |
| 6 | Confirm Gatus "Miniflux" + "Miniflux Login Renders" green in the DEPLOYED config | High | S | Quality |
| 7 | Verify miniflux-backup chain: pool dir postgres-owned, PGDMP-magic dump exists, backup-coordination green | High | S | Quality |
| 8 | Interactive sops decrypt round-trip on `miniflux.yaml` (user sudo; NEVER verified) | High | S | Quality |
| 9 | Fix BuildFlow upstream: paste `got: 0NQweZeM06UiN3AWkd033QpfTGAZp2Gte05+aaw2b+I=` into `vendorHash.nix`, commit, push (pending Q2) | High | S | Bug |
| 10 | After #9: `nix flake lock --update-input buildflow`, confirm subtree, drop the interim-pin posture | Medium | S | Cleanup |
| 11 | Add upstream CI to BuildFlow (build its own flake on push) — enforcement for the vendorHash-owns-upstream doctrine | High | M | Quality |
| 12 | Write `scripts/relock-input-at-rev.sh` (e#1 recipe) + AGENTS.md gotcha for the node-deletion trap | Medium | M | Quality |
| 13 | Adopt rule: `nix build .#quick-go` after any flake input update; consider a deploy.sh conditional for lock-diff builds | High | S | Process |
| 14 | Run `nix build .#quick-go` NOW to prove the rest of the Go set against the new lock subtree (shared `go-finding_3`/`go-checker-helpers` nodes) | High | M | Quality |
| 15 | Verify CI green on the next SystemNix push (new lock nodes are fetchable with existing tokens — the CI-dark class) | High | S | Quality |
| 16 | Decide Miniflux auth posture: keep admin break-glass vs `DISABLE_LOCAL_AUTH=true` SSO-only (Q3) | Medium | S | Decision |
| 17 | Decide Miniflux API requirement: native-only vs GReader-API/FreshRSS-class need (may flip reader choice) | High | S | Decision |
| 18 | HARVEST both miniflux status reports into TODO_LIST/ROADMAP (docs-health) | Medium | S | Documentation |
| 19 | Update AGENTS.md Miniflux section with post-deploy live-verified facts after #2–#7 | Medium | S | Documentation |
| 20 | Commit the working tree (flake.lock fix + smoke + secret + both reports) — explicit or daemon batch with pathspec discipline | Medium | S | Housekeeping |
| 21 | Investigate which session/daemon moved the lock to `9a8a350` and why quick-go wasn't run (coordination gap, low blame value) | Low | S | Cleanup |
| 22 | Schedule the owed reboot (clears flm :52626 corpse, D-state pile, old-generation drift); pre-reboot-check already 18/0 | High | S | Feature |
| 23 | After reboot: verify `/run/booted-system` == `/run/current-system` (doctrine) | Medium | S | Quality |
| 24 | Triage the 19 pre-deploy warnings (6 "unable to determine status" vendorHash checks; stale-sandbox count; network-local-commands layout) | Low | M | Cleanup |
| 25 | Miniflux restore drill: latest dump → fresh PG restore into a scratch dir | Low | M | Quality |
| 26 | Miniflux secret rotation drill (admin creds; document break-glass path in docs/services/miniflux.md) | Low | S | Quality |
| 27 | Verify network-local-commands ExecStart layout post-build (pre-deploy warning #12) | Low | S | Quality |
| 28 | OPML import + reader-client onboarding (user; API token via Miniflux UI) | Low | S | Feature |
| 29 | Confirm miniflux rides the nightly btrbk-pool snapshot correctly (it's outside pool services/ — its DB is on root @; verify snapshot coverage expectations are documented) | Medium | S | Quality |
| 30 | Consider SigNoz/Gatus coverage gap review for miniflux (no OTel upstream — is system-health + Gatus enough? documented answer) | Low | S | Documentation |
| 31 | Document the accepted FreshRSS-feature gap (XPath scraping, extensions) in docs/services/miniflux.md | Low | S | Documentation |
| 32 | [R] Lock-health monitoring idea: metric/gatus check detecting locked rev diverging from origin/master head for moving-ref inputs | Low | M | Feature |
| 33 | [R] Feed `relock-input-at-rev.sh` + quick-go-conditional into the deploy-pressure-gate PR as one coherent "lock hygiene" change | Medium | M | Quality |
| 34 | [R] Review whether other LarsArtmann flakes pin inputs their go.mod doesn't match (the buildflow class is unlikely unique; a cross-repo audit script) | Medium | L | Quality |
| 35 | Check `tests/test-miniflux.nix` stays green on next nixpkgs bump (mock-sops + btrfs pool recipe) | Low | S | Quality |
| 36 | Ensure the miniflux dumps join the offsite/backup review cadence (Google Drive leg) | Low | S | Quality |
| 37 | Record session gotchas: jq -S unsupported; getFlake paren precedence (extends last session's two-statement note) | Low | S | Documentation |
| 38 | Verify the parallel session's kernel-hardening + boot.nix/networking.nix changes deploy green TOGETHER with this tree (shared activation) | Medium | S | Quality |
| 39 | Re-run `nix fmt --no-update-lock-file -- --ci` on the final tree before the deploy commit | Low | S | Quality |
| 40 | Confirm deploy.sh miniflux restart block fires post-switch (LoadCredential re-bind path, is-active-gated) | Medium | S | Quality |
| 41 | After first login: review Miniflux default settings (refresh cadence, entry retention) vs. box doctrine (QLC IO) — feeds via dnsblockd anyway | Low | S | Quality |
| 42 | Consider `documentation`: add rss.home.lan to the services overview docs (if such an index exists — docs-health VERIFY) | Low | S | Documentation |
| 43 | Decide whether miniflux needs a `unfree`/license note (it's Apache-2.0 — likely no-op, verify once) | Low | S | Documentation |
| 44 | [R] Pocket ID client-secret rotation drill for miniflux (90d rotation monitoring exists — confirm miniflux is registered in it) | Low | S | Quality |
| 45 | Verify `niri`/quickshell unaffected by the nixpkgs warning noise seen in evals (`stdenv.isDarwin` deprecation — upstream nixpkgs, ignore unless it breaks) | Low | S | Cleanup |
| 46 | Update the sops-secret-management skill (or AGENTS.md) with "create + `git add -f` in one command" sequencing rule | Medium | S | Documentation |
| 47 | Confirm backup-coordination miniflux entry maxAge alerts fire correctly after first backup (or is silent-green) | Low | S | Quality |
| 48 | [R] Cross-flake: consider a `checks.lock-sane` that asserts every `github:`-type locked rev actually exists on origin (cheap API call, catches re-tag/poisoning + unreachable pins) | Medium | M | Quality |
| 49 | Post-go-live: flip docs/services/miniflux.md runbook from "expected" to "verified" statements with dates (docs-health ANNOTATE) | Low | S | Documentation |
| 50 | Close the loop: mark this report's blockers resolved after #1–#2 land (ANNOTATE mode, never rewrite) | Low | S | Documentation |

---

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

Asked via the interactive prompt after this report (answers will direct the next session):

1. **Deploy timing** — everything is built and gated; do you want to run `nix run .#deploy` now so I can run post-deploy verification, or defer?
2. **BuildFlow upstream push authorization** — may I commit + push the one-line vendorHash refresh to `LarsArtmann/BuildFlow` master? Without it, master stays broken and the interim lock pin stays load-bearing.
3. **Miniflux auth posture** — keep the local admin password as break-glass (current state), or flip `DISABLE_LOCAL_AUTH=true` for strict SSO-only before/after first login?

---

## Current Tree State (01:38 CEST)

```
M  flake.lock                              # buildflow subtree → 56c755f0e (5 nodes)
A  platforms/nixos/secrets/miniflux.yaml   # force-added (was breaking every eval)
M  scripts/post-deploy-check.sh            # Miniflux smoke section (+33 lines)
A  docs/status/2026-09-11_00-22_….md       # previous session's report (staged)
A  docs/status/2026-09-11_01-38_….md       # this report
```

Uncommitted by design (no explicit commit instruction; the daemon batches with pathspec risk noted in AGENTS.md Critical Rules).

**Waiting for instructions.**
