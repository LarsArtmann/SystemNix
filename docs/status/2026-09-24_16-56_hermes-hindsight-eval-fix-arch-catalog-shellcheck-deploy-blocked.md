# Status: flake-update eval fix (hermes hindsight extra) + arch-catalog shellcheck — deploy still not landed

**Date:** 2026-09-24 16:56
**Session start:** 2026-09-23 ~14:10 (spans >26h — background build still running)
**Trigger:** user ran `nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`; deploy blocked at pre-deploy step 2 (`nixosConfigurations.evo-x2 evaluation failed`). Task: "fix".

---

## a) FULLY DONE

1. **Root-caused the eval blocker (hermes-agent bump).** `nix flake update` moved `hermes-agent` `6b9214b0` → `33a30fdd` (v0.21.4). Upstream commit `73c598e319` ("build: drop the hermes-agent[hindsight] extra") removed the `hindsight` pip extra — hindsight-client is now resolved by the catalog plugin installer via its `plugin.yaml`, and "every consumer that pre-installed the extra must stop naming it" (their words, naming the nix examples explicitly). SystemNix's `hermes.nix` `extraDependencyGroups` still named it → uv2nix eval aborts: `Extra/group name 'hindsight' does not match either extra or dependency group`. Verified against the locked rev's `pyproject.toml` (no `hindsight` in `[project.optional-dependencies]`; no `[dependency-groups]` at all).
2. **Fixed `modules/nixos/services/hermes.nix`:** removed `"hindsight"` from `extraDependencyGroups` (18 → 17 extras); refreshed the stale "extras set unchanged" packaging comment with the drop rationale.
3. **Verified eval:** `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` → clean store path; `nix flake check --no-build` → **all checks passed** (aarch64-darwin omission expected).
4. **Updated `AGENTS.md`** hermes section: extras inventory now 17 @ v0.21.4/`33a30fdd`, hindsight-drop documented, plus the lesson: an upstream extra removal breaks EVERY evo-x2 eval at `nix flake update` time with a named-extra error — diff `extraDependencyGroups` against the new rev's pyproject first.
5. **Root-caused the second blocker (build-time).** First deploy attempt failed in the build: `architecture-catalog-sync` (`writeShellApplication`) fails its build-time shellcheck — SC2012 (`ls -1d "$GENS"/* | sort | head`).
6. **Fixed `modules/nixos/services/architecture-catalog.nix`:** generation-cleanup loop rewritten `find "$GENS" -mindepth 1 -maxdepth 1 | sort | head -n -N` (identical semantics; find also exits 0 on empty dirs instead of dying under pipefail); `pkgs.findutils` added to `runtimeInputs` (find is NOT coreutils — the list-every-binary doctrine).
7. **Verified the fixed script builds clean** — built the derivation standalone via the documented context-error → `drv^out` route; shellcheck passes.
8. **Diagnosed the 3 failed units** from the pre-deploy report (all warnings, none deploy-blocking):
   - `inboxclean-sync`: `gmail.token_revoked` (`invalid_grant`) for account **main**, failing since **Sep 10 00:03** — 522 failed syncs in 21 days. Known class (testing-mode/7-day refresh-token expiry / revocation). Fix is the interactive OAuth runbook (`inboxclean auth` in a desktop browser) — user action, cannot be automated.
   - `nix-build-cleanup`: `btrfs-gc-guard` ABORT — metadata utilization **91–92%** (>90% = the 2026-06-26 ENOSPC-precursor hard block). Live probe: metadata DUP 26.16/28.47 GiB used, device unallocated 38.40 GiB (allocation headroom exists; not imminent ENOSPC, but in the guard's red zone). The weekly `btrfs-balance-metadata` has been **guard-skipped under IO PSI** (Sep 21 04:00 run skipped at PSI 62%).
   - `service-health-check`: pure collateral — it reports the two above.
9. **All edits committed** (auto-commit daemon batch: `295cad59`…`8b051f30`); working tree clean at report time.

## b) PARTIALLY DONE

1. **The deploy itself — NOT landed.** Attempt 1 (bg shell 00C, 2026-09-23 14:23) died at the architecture-catalog shellcheck failure ("nh os switch FAILED — config NOT activated"). The fix is in and single-drv-verified, but a full toplevel build on the fixed tree has **not completed**.
2. **--keep-going enumeration build (bg shell 015) STILL RUNNING** — started 2026-09-23 ~14:25, now >26h with zero visible output (piped through `tail`, which buffers until exit). Either a legitimately massive rebuild wave (hermes v0.21.4 uv2nix env + every bumped Go FOD: bank-sync, buildflow `6617d65`, go-cqrs-lite consumers, mr-sync, nix-email, PMA + signoz pnpm) or wedged — **unverified which**. This is the single most important open item.
3. **Post-deploy smoke + profile anchoring check** — never reached (deploy didn't activate).

## c) NOT STARTED

- **Signoz bump migration review.** The plain `nix flake update` moved `signoz-src` `370b278f` → `cad93a80`. Doctrine (AGENTS.md, proven 2026-09-18) requires a migration review (ClickHouse schema migrator diff, config-surface check) BEFORE a signoz bump ships. None happened — the user's blanket update rode it in.
- **Watching the other bumped inputs' FODs** (buildflow vendorHash, go-cqrs-lite consumer hashes, bank-sync, hermes uv2nix env) — the keep-going build was supposed to enumerate these; results unseen.
- inboxclean `main` re-consent (user, interactive browser).
- `btrfs-balance-metadata.service` run in a quiet window (user — `systemctl` is blocked in the agent sandbox).
- `cv` :8098 metrics endpoint not responding (pre-deploy warning) — cv-server health unverified this session.

## d) TOTALLY FUCKED UP

- **My first SC2012 fix comment was itself a two-layer bug:** (1) it contained em dashes → shellcheck's Haskell runtime died printing them (`commitBuffer: invalid argument (cannot encode character '\8212')`); (2) one comment line started with `# shellcheck …` → shellcheck parses any such line as a DIRECTIVE → SC1072/SC1073 parse failure. Both are documented repo rules (no em dashes in source code; I wrote them anyway). Cost one extra build cycle; fixed with an ASCII comment that never starts a line with "shellcheck".
- **Deploy output visibility:** piped the whole deploy through `| tail -150` → zero incremental progress for a 25-min build+ deploy attempt. Should log inline or poll the journal.
- **Minor flailing** building the fixed drv: tried `nix build <output-path>` (fails: "don't know how to build these paths") before using the documented context-error → `.drv^out` route.
- Not mine but worth recording: **the architecture-catalog module landed unbuilt** (first writeShellApplication build ever was this deploy) — a pre-authoring standalone build would have caught SC2012 for free.

## e) WHAT WE SHOULD IMPROVE

1. **Build new `writeShellApplication` derivations standalone before they ride a deploy** (one `nix build` of the script drv at authoring time; shellcheck runs at build time, invisible to `flake check --no-build`).
2. **AGENTS.md gotcha candidates from this session:** the `# shellcheck`-directive comment trap; non-ASCII (em dash) in shellcheck'd script text → `commitBuffer` encoding death. Neither is in the gotchas yet.
3. **Blanket `nix flake update` vs governed bumps:** it bypassed the signoz migration-review gate and the hermes extras contract in one shot. Consider `--update-input` per governed input, or a pre-update contract check (hermes extras vs pyproject, signoz migration diff) in pre-deploy.
4. **Long builds need journal-polling, not buffered `tail`** (already doctrine for pollers; I violated it for the deploy itself).

## f) NEXT (ordered)

1. Check bg shell 015: alive or wedged (journal nix-daemon activity); kill + restart fresh `nix build …toplevel --keep-going` on the fixed tree if stale.
2. Re-run `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`; expect the arch-catalog failure gone; watch remaining FODs.
3. If FOD failures: refresh vendorHashes upstream per doctrine (probe got-hash at exact rev; never paste from dirty worktrees).
4. Signoz `370b278f→cad93a80` migration review (or roll signoz inputs back to reviewed pins before deploying).
5. Post-deploy: smoke verdict (rc=3 = new failures), profile anchoring (`readlink /nix/var/nix/profiles/system` vs `/run/current-system`), generation number.
6. Verify `architecture_catalog_fresh` / `architecture_catalog_scrape_errors` metrics land (retire the §10 loan).
7. User: inboxclean `main` re-consent (13 days dark, main-account Gmail archiving stale).
8. User: `sudo systemctl start btrfs-balance-metadata.service` in a quiet window; confirm metadata drops below 90%; nix-build-cleanup then self-heals + 4 stale sandboxes clear.
9. Check `cv` :8098 metrics endpoint after deploy (pre-deploy warning, unexplained).
10. Hermes: confirm hindsight memory provider (now lazy/plugin-installed) degrades gracefully in the sealed uv2nix venv — or explicitly accept its loss if unused.
11. Add the two shellcheck gotchas to AGENTS.md (§ Nix & Nixpkgs or a new Shell & DevTools bullet).
12. CONTRIBUTING: add "build new writeShellApplication drvs standalone" to the module-authoring checklist.
13. Verify daemon commits didn't sweep foreign files into mine (`git show --stat` on `8b051f30`, `cd21e218`, `d3143bc8`, `8220d2ca`) — multi-agent discipline.
14. After deploy settles: confirm `hindsight` removal has no runtime fallout in hermes journal (no new ImportError class).
15. Gatus sweep after deploy: new-baseline comparison for all bumped services (bank-sync, buildflow consumers, mr-sync dashboard, nix-email).

## g) QUESTIONS (cannot resolve myself)

1. **InboxClean `main`** has been token-dead since Sep 10 (522 failed syncs). Re-consent needs your browser (`inboxclean auth` runbook). Has the Google OAuth consent screen EVER been flipped to "In production" — or is it still Testing (the 7-day expiry recurrence strongly suggests Testing)? I cannot see Google Cloud from here.
2. **Btrfs metadata ~92%** with the weekly balance guard-skipped under PSI: OK to run `sudo systemctl start btrfs-balance-metadata.service` in a quiet window after this deploy? (`systemctl` is banned in my sandbox — your hands or an approved path needed.)
3. **Signoz rode in on the blanket update** (`370b278f`→`cad93a80`) without the required migration review — proceed with it in this deploy, or roll the signoz inputs back to the reviewed pins first?
