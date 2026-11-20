# Stalwart eval warning root cause attributed (extendModules throw-probe) + session self-review

**Date:** 2026-11-20 22:21 CET
**Session scope:** single question — "why does SystemNix emit the `stalwart` 0.15.5 pin eval warning when stalwart should only run on pbx-artmann?" — plus the attribution work, evidence, queue-row updates, and this self-review. No deploys, no service changes, no tree changes beyond TODO/library rows.

---

## Self-review (what did I forget / what could have been better)

**What I forgot / left undone:**
- The **companion `'system' has been renamed` warning** (25×/check) sat right next to the stalwart warning in every cluster and I left it unattributed. The same throw-probe overlay (`system = builtins.throw`) would have named it in one more ~4-min eval. Deferred, not done.
- I did **not challenge the premise** that SystemNix should carry the nix-email wrapper at all — the user's framing ("stalwart should only run on pbx-artmann") hints the wrapper might be dead weight (dmarc-monitor is disabled, the mail VPS target is unbuilt). Removal would kill the warning class instantly. That's an owner call; I queued it as a question instead of raising it mid-investigation.
- The **per-config warning breakdown** was incomplete when I first quoted numbers ("7+ pairs") and corrected only after the surface-attribution pass (final: 1× evo-x2 + 23× checks for stalwart; 1× + 24× for the system rename; **zfs-vm and rpi3-dns are clean** — they don't import the auto-discovered module set). Should have done the attribution pass before quoting any count.
- I initially trusted `tests/test-nix-email.nix`'s header ("the stalwart/parsedmarc nixpkgs modules evaluate") as ground truth — it's **stale** (upstream vendors its stalwart module; nixpkgs' `services.stalwart` module never enters that eval). The header misdirection cost me the first (wrong) hypothesis. Corrected-in-queue now.

**Process mistakes (honest):**
- **Third strike of the `rg -rn` trap** — typed the replace-flag form again; the hook blocked it. Documented in AGENTS.md since 2026-10-23; my fingers haven't learned it.
- **zsh-ism in mvdan/sh** — `(...N)` glob qualifier failed ("word list can only contain words"). Platform is mvdan/sh, not zsh.
- **nix flake metadata API fight** — 3 wasted calls probing the JSON schema (`KeyError: 'inputs'`) for the nixpkgs store path before abandoning it for GitHub API reads. Could have gone straight to `gh api` at the lock rev (which I had from flake.lock in one python3 call).
- **First hypothesis was wrong** — I framed the nix-email-contract check as the likely emitter (from FEATURES.md's "that IS the compat doctrine" comment) before testing. In fairness: I falsified it cheaply (single bounded eval, ~1 min) before asserting anything — but the decisive throw-probe technique existed from minute one and would have hit the real answer (migration.nix:377) on the first eval instead of the fourth.
- Nothing destructive happened: no deploys, no service touches, no `rm`/`mv`/`reset`, tree got only TODO/library row edits, gate green before and after.

---

## a) Fully done

1. **Root cause attributed with a call stack** (the session's actual ask):
   - nixpkgs pin `0bb82723` (2026-11-19) ships `stalwart_0_15` / `stalwart_0_16` / `stalwart_1`; plain `stalwart` is an alias pinned to 0.15.5 whose `warnAlias` carries the exact quoted text (`pkgs/top-level/aliases.nix:2614`); `stalwart-mail → stalwart` rename alias directly below (2615).
   - nixpkgs' `services.stalwart` module defaults `package` via `lib.mkPackageOption pkgs "stalwart"` (`nixos/modules/services/mail/stalwart.nix:44`) → the warned alias.
   - **evo-x2 imports every auto-discovered service module** (`systems/evo-x2.nix:107`), including the **disabled** nix-email wrapper (`modules/nixos/services/nix-email.nix` — kept for the future VPS mail target + pre-wired dmarc-monitor).
   - Upstream nix-email (input at `d09684c5`, 2026-11-18) vendors its stalwart module; **`modules/stalwart-module/migration.nix:377` guards its assertions with `lib.versionAtLeast cfg.package.version "0.16"` — evaluated even when the whole stack is disabled**. Every toplevel eval merges `config.assertions` (`nixos/modules/system/activation/top-level.nix:64`), forcing `services.stalwart.package`; with mail-server off, the option falls to the nixpkgs alias default → warning.
   - Chain proven by a throwaway `extendModules` + overlay-`throw` probe + `--show-trace` (never touched the tree; the sanctioned safe-verification pattern).
2. **Surface census from a full captured `nix flake check`** (`~/.cache/stalwart-warn/fc.err`, rc=0 "all checks passed"): stalwart warns 1× `nixosConfigurations.evo-x2` + 23× `checks`; system renames 1× + 24×; **zfs-vm / rpi3-dns clean** (they don't map all discovered modules).
3. **Contract check exonerated with a bounded eval** (`nix eval .#checks.x86_64-linux.nix-email-contract.drvPath` — no warning): its enabled cases force upstream's vendored 1.0 package (`mail-server.nix:1068` `mkDefault`), so the alias default never resolves there.
4. **Queue rows enriched with the real root cause** — `TODO_LIST.md:1797` + `docs/todo/services.md:692` now say "fix UPSTREAM nix-email (gate the assertion block on the migrate option's own enable)" instead of the stale "lift to 0.16 or suppress" framing; `check-todo-system.sh` gate green after every edit.
5. Evidence archived capture-once in `~/.cache/stalwart-warn/` (fc.out/fc.err, probe-stalwart.nix, probe.err with the full trace).

## b) Partially done

1. **Companion `pkgs.system` warning** — noticed, paired with the stalwart warns, unattributed (storage-collector's 2026-10 pin at `configuration.nix:2273` was supposed to kill this class; something else still forces `pkgs.system`). Row harvested; probe not yet run.
2. **Fix** — direction decided (upstream nix-email guard), zero code written. The upstream repo, the PR, the SystemNix lock float, and the verification battery are all ahead of us.
3. **Warning-count precision** — final counts attributed to surfaces, but the 23 checks-side stalwart warns are not yet broken down per test config (which makeTest evals import the wrapper).

## c) Not started

1. Upstream nix-email PR (migration.nix assertion gating).
2. SystemNix `nix-email` lock float + post-fix zero-warning verification.
3. pbx-artmann-side verification (mail-server is ENABLED there → vendored 1.0 wins → likely already clean; unverified).
4. Runbook note in `docs/services/nix-email.md` (warning state + fix pointer).
5. Zero-warning eval budget / nightly warning census (idea stage).

## d) Totally fucked up

**Nothing.** No data loss, no deploy, no service mutation, no tree damage, no secrets touched (probe threw on eval, wrote only to `~/.cache/`). The cost of this session was **time, not damage**: roughly 4 of ~25 tool calls were wasted motion (first-hypothesis detour, metadata-API fight, two shell-idiom stumbles). Every wrong turn was falsified cheaply and captured before being asserted.

## e) What we should improve (process)

1. **Decisive probe first.** For "where does warning X come from", the overlay-throw + `--show-trace` probe is a general, tree-safe, one-shot attributor — reach for it before grep-based hypothesis chains. (Harvested as a row: document it in `docs/agents/nix-flakes.md`.)
2. **`rg -n`, never `-rn`** — third strike; the hook caught it. No repo change needed; the rule exists.
3. **Distrust stale test/doc headers as load-bearing facts.** `test-nix-email.nix`'s header described an eval shape that no longer exists and cost a wrong hypothesis. (Harvested: header-correction row.)
4. **Quote warning counts only after surface attribution** — the count moved from "7+" to 24×(1+23) once I did the nearest-`checking`-header pass.
5. **mvdan/sh is not zsh** — no glob qualifiers, no `kill` builtin, no `-r` replace; platform quirks live in AGENTS.md and I still pay the toll occasionally.
6. The stalwart warning is **standing noise training sessions to ignore warnings** (original 2026-10-29 row's words, confirmed today) — the fix should be upstream and fast, and a warning-budget gate would keep the next such class visible.

## f) Next tasks (session-scoped; harvest status marked)

**Harvested this report (rows landed before writing):**
1. Upstream nix-email fix: gate `migration.nix:377` assertion block on the migrate option's own enable/disable — *[already-rowed: TODO_LIST:1797 + services.md:692]*
2. After upstream lands: float SystemNix `nix-email` lock, re-run `nix flake check`, assert zero stalwart warns — *[same row's dispatch scope]*
3. Verify pbx-artmann stays clean post-fix (mail-server enabled → vendored 1.0 should win) — *[same row]*
4. **Attribute the remaining `pkgs.system` renamed warning** (throw-probe overlay on `system`) — *[NEW row: TODO_LIST + services.md]*
5. **Correct test-nix-email.nix's stale header claim** (upstream vendors the module) — *[NEW row: TODO_LIST + pipeline.md]*
6. **Document the extendModules throw-probe recipe** in `docs/agents/nix-flakes.md` (getFlake + `--impure` mechanics, ~4-min cost) — *[NEW row: TODO_LIST + pipeline.md]*

**Deliberately not harvested (recorded reasons):**
7. Runbook warning-state note in `docs/services/nix-email.md` — *[folds into row 1's dispatch; same-commit runbook rule applies when the fix lands]*
8. Per-check-config breakdown of the 23 checks-side stalwart warns — *[verification detail of row 2's battery, not a standalone ask]*
9. Verify zfs-vm/rpi3-dns truly don't import discoveredModules (they're warning-clean; confirm the import shape) — *[one grep inside row 4's probe session]*
10. Zero-warning eval budget (capture-once fc.err warn census with a ratchet-style max, like `.docs-gates.json audit_max`) — *[idea stage; owner policy call — see §g Q3]*
11. Nightly CI eval-warning census workflow (fail on NEW warning patterns) — *[same idea cluster as 10]*
12. Toplevel-eval probe check: extendModules + grep for known standing warnings in CI — *[heavier variant of 11]*
13. `diskoConfigurations` "unknown flake output" warning (fc.err:12) — hygiene, pre-existing — *[unrelated to this session's fix path; noted for the next nix-hygiene pass]*
14. `zfs.latestCompatibleLinuxPackages` deprecation on zfs-vm — explicit kernel pin per the warning text — *[pre-existing, unrelated]*
15. `services.cv-server: settings.graphrag.store_dsn` warning (fc.err:32) — pre-existing — *[out of scope; unrelated domain]*
16. catalog paperless subdomain warning (fc.err:41/293) — pre-existing — *[out of scope]*
17. caddy ghost-entries: 36 subdomains (fc.err:330) incl. the retired-nsfw question — the 2026-11-19 report already carries this — *[already covered elsewhere; not re-rowed]*
18. Upstream dedupe candidate: nix-email vendors `stalwart_1_0` via callPackage while nixpkgs ships `stalwart_1` — *[upstream-repo hygiene, note for the nix-email maintainer loop]*
19. `stalwart-mail → stalwart` rename alias (aliases.nix:2615) — in-tree consumers: none (grep-verified today) — *[closed: verified-none, no row needed]*
20. Audit other evo-x2-riding input modules with `mkPackageOption` package defaults that can hit warned aliases (same class as stalwart; the storage-collector pin is the pattern) — *[candidate for row 4's probe session]*
21. Test-nix-email disabled-case toplevel probe (a fragment-eval contract can't catch assertion-time forces; a toplevel-class probe would have caught migration.nix:377 locally) — *[candidate idea; cost/benefit vs VM tests unclear — needs design, see §g]*
22. Generalize probe-stalwart.nix into a parameterized script (`--host`, `--attr`) if the recipe becomes routine — *[only after row 6 lands]*
23. `NIX_ABORT_ON_WARN=1` attribution variant — rejected today (the pin-audit `trace:` fires first and aborts); only viable with a trace-silencing pre-pass — *[noted so nobody retries it blind]*
24. Consider whether the checks-side 23× duplication (each VM-test eval re-forcing the alias) argues for a shared eval cache or fewer toplevel-importing tests — *[design question, bigger than this fix]*
25. After the upstream fix: close the 2026-10-29 task's original row (`docs/status/tasks/2026-10-29_03-17_…` §c/§f.7 citation) with a done-at verdict — *[mechanical close-out at fix time]*

*(25 items; the honest count. Padding to 50 would be fabrication — the rest of the fleet's work lives in TODO_LIST.md already.)*

## g) Questions I cannot answer myself

1. **Keep or kill the nix-email wrapper in SystemNix?** dmarc-monitor is disabled, the mail-server VPS target is unbuilt, and the wrapper's import (via the all-auto-discovered-modules map) is what drags the upstream stalwart module into evo-x2's eval. Removing the input + wrapper kills this warning class instantly; keeping it preserves the pre-wired dmarc plumbing + the contract-check compat doctrine for the future mail target. Which is it?
2. **Do the upstream nix-email fix NOW, or park it?** If now: I branch/PR LarsArtmann/nix-email (gate `migration.nix:377`'s assertion block on the migrate option), float SystemNix's lock after merge, and run the zero-warning battery — pbx-artmann consumes the same module, so it would ride the same wave. Or does this wait for a batched upstream session? And if now — is pbx-artmann the verification ground first, or SystemNix?
3. **What is the standing-eval-warning policy?** Today's check carries stalwart 24×, `system` renames 25×, plus the pre-existing pipewire/jack/stray-unit/cv-server/catalog/caddy-ghost warnings — and the 2026-11-19 task report explicitly declined to triage them as "pre-existing". Do you want a zero-warning budget (a captured fc.err warn census with a ratchet-style max that only moves DOWN, plus a nightly census workflow), or is warning noise acceptable and we only fix per-class when something attributes it?

---

**Evidence paths:** `~/.cache/stalwart-warn/fc.out` + `fc.err` (full check capture, rc=0), `probe-stalwart.nix` + `probe.err` (throw-probe + trace), `~/.cache/stalwart-warn/eval.{out,err}` (contract-check falsification eval).
**Key file:line:** `pkgs/top-level/aliases.nix:2614` (warnAlias) · `nixos/modules/services/mail/stalwart.nix:44` (mkPackageOption) · `systems/evo-x2.nix:107` (all-modules import) · upstream `modules/stalwart-module/migration.nix:377` (the forcing guard) · upstream `modules/mail-server.nix:1068` (vendored-1.0 mkDefault) · `modules/nixos/services/nix-email.nix` (the disabled wrapper).
**Queue surfaces touched:** `TODO_LIST.md` (1 enriched + 3 new rows) · `docs/todo/services.md` (1 enriched + 1 new) · `docs/todo/pipeline.md` (+2 new) — gate green throughout.
