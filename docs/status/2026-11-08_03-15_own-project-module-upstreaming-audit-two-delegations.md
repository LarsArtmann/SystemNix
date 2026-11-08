# Own-project service-module upstreaming audit + two delegations landed (mr-sync, nsfw-classifier)

**Date:** 2026-11-08 02:30–03:30 · **Trigger:** owner question — "`modules/nixos/services/` — all the ones for my own projects should probably be upstreamed into their OWN repos or not?!?!" · **Tree:** c32357809 → d8b141d46+ (daemon-committed mid-session, x3)

## Verdict (short)

**Yes — and it is already ~70% true.** The DiscordSync/Monitor365 pattern (upstream repo exports `nixosModules`, SystemNix layers only host specifics) is the ratified doctrine (docs/agents/integration-registry.md), and 16 of the ~30 own-project modules already follow it. This session closed the two delegation gaps that were executable now (mr-sync, nsfw-classifier — both upstream modules existed at the LOCKED rev, waiting), leaving 2 push-gated gap-fixes (cvagent, hermes) and 6 repos that export no module yet. Roughly half the directory is correctly SystemNix-native and must never move (host infra, audits, integration/sops/gatus plumbing, glue scripts with no product repo, third-party services).

## Method

1. Full inventory of `modules/nixos/services/*.nix` (~160 files) — binary-source scan (`inputs.X.packages` vs `inputs.X.nixosModules` vs `pkgs.*` vs in-tree scripts).
2. Cross-referenced every LarsArtmann flake input (52 repos in the lock) against its local checkout: does the repo export `nixosModules`? Is the module present AT THE LOCKED REV? (rev comparison via `jq < flake.lock` stdin form + `git show <rev>:<path>`).
3. Planning-layer pre-read: no prior plan/brainstorm doc owns this topic (rg over docs/planning + docs/brainstorming); the integration-registry pattern doc is the governing doctrine.
4. Executable delegations executed + parity-verified; everything push-gated or upstream-heavy queued with Source pointing here.

## Classification matrix

### Already delegated (16 — pattern-following, no action)
monitor365 (gold standard) · discordsync · browser-history (server+agent) · cv · inboxclean · pim-sync · storage-collector · tq-agent-pool (go-taskqueue) · overview · indexer-web (index) · file-and-image-renamer · nix-email · bank-sync · visionreviewd (vision-review-agent) · projects-management-automation · crush-daily (consumed via `systems/evo-x2.nix` imports). (emeet-pixyd follows the same shape for a third-party repo.)

### Delegated THIS session (2)
- **mr-sync** → `inputs.mr-sync.nixosModules.dashboard` (repo `module-dashboard.nix`, upstream VM-tested `checks.dashboard-vm`). SystemNix wrapper keeps: package+vendorHash float-shim, `ports.mr-sync`, primaryUser, sops GITHUB_TOKEN, onFailure, serviceDefaults, ioTier(idle M15) + harden bounds, integration entry. Upstream adds (verified improvements): git+gh PATH, cache persistence (`~/.cache/mr-sync` ReadWritePaths + prep oneshot), network-online ordering, full hardening table.
- **nsfw-classifier** → `inputs.nsfw-classifier.nixosModules.default` (repo `nix/nixos-module.nix`, extracted 2026-10-18 FROM our module explicitly "until it delegates here" — the delegation was pending since then). SystemNix keeps: port-catalog default, lars/users + live-checkout pinning (`protectHome = false`), calm-gate ordering, ~/projects mount gating, onFailure, ioTier, serviceDefaults, catalog + integration entries + gatus-coverage exemption, and the ENTIRE immichScan surface (ADR-061: deployment-only wiring, deliberately never upstream).

### Gap-fixes queued, not executable now (2)
- **cvagent** — upstream `Code-To-CV-Agent/nix/module.nix` declares the SAME `services.cvagent` namespace with a DIFFERENT deployment model (discovery `scan --all` + dashboard + dedicated user + /var/lib) vs our live one (importance-ranked curated list + `mesh` export into the CV checkout + AI model/baseurl/daily-spend-cap + primaryUser + 90min budget). Both cannot be imported (option collision). Needs an upstream capability merge first. → §f.1
- **hermes (hermes-agent)** — upstream `nix/nixosModules.nix` (shared with its HM module) exists in the local checkout but is UNPUSHED (HEAD 686193c0 not contained by any remote branch) and the lock sits behind it (0ea6ea9). Re-lock needs the push + probe-before-lock; delegating hermes.nix (1076 lines) is the single biggest remaining extraction. → §f.2

### Repos exporting no module yet (6, queue) → §f.3
crm (543-line SystemNix module) · media-atlas (908) · papdashboard (968 — only the service unit would move; the tile/icons-pack layer is SystemNix-internal dashboard infrastructure) · journal (`journal-serve`/`journal-backup`; repo is rev-pinned on the templ wave) · project-discovery-daemon (216) · go-health-dashboard/health-dashboard (302). dnsblockd already has its own `[blocked:user]` migration row (TODO_LIST 2026-11-08, upstream module exists at the locked rev) — not duplicated.

### Correctly SystemNix-native (stays — the "or not?!" half of the answer)
- **Host infra / the platform itself:** every `*-audit.nix`, integration.nix, sops*, gatus*, signoz*, buildcache, pool-recovery, memory-emergency-guard, system-health, backup-coordination, hot-db/hot-user-caches, post-crash-calm-gate, boot-*, dns-failover/dual-wan/wifi-failover, agent-unit-control, sev1-escalation, tq-agent-pool's SystemNix layer, etc.
- **Glue automation with no product repo:** geometrikks (sqlite+scripts art-business tooling), google-sync, drive-paperless, audible-sync (audible-cli), github-auto-assign, pim-sync's remainder, media pipelines.
- **In-tree BY DESIGN:** ai-meter (`pkgs/ai-meter.nix` header: "homelab-specific infrastructure, deliberately NOT a separate repo" — zero-dep, no FOD ever).
- **AI stack daemons:** llama-chat/llama-rag/llama-vlm/fastflowlm (llama.cpp wrappers + host GPU posture; llama-rag tracks upstream nixpkgs pin, not a LarsArtmann repo).
- **Third-party services:** caddy, forgejo, immich, paperless, paperless-gpt, miniflux, searxng, pocket-id, oauth2-proxy, signoz, netbird, opencloud, attic, crowdsec, minecraft, emeet-pixyd, dns-blocker wrapper, monitor365 wrapper, etc.

## Execution detail (what the delegations changed, with verification)

- **mr-sync:** eval tripped `io-tier-coverage-audit` on the NEW upstream `mr-sync-dashboard-prep` oneshot (boot-started, untiered) — layered `TimeoutStartSec = mkDefault 5min` (class-7 floor) + `ioTier.background`. Parity verified by rendered-unit diff pre vs post (worktree at the true pre-delegation commit): all deltas are upstream improvements except three SystemNix `harden{}` contributions the first cut dropped (CPUQuota 200%, MemoryHigh 429496729 = 80% watermark, ProtectHostname) — harden layer restored, re-diff shows all three identical to pre-deployment. ExecStart/EnvironmentFile/MemoryMax/Restart/IOScheduling* byte-identical.
  - **Near-miss (baseline contamination):** the first "old" worktree eval was taken at HEAD~1, which a daemon commit had already advanced past my v1 write — the empty diff was v1-vs-v2, not pre-vs-post. Caught because the old render contained `git/gh` in PATH (a pure-upstream addition); re-baselined at `aa4db843b~1` (`git log -S "DELEGATED to the upstream module"`). Lesson: for parity baselines, find the LAST commit NOT containing your marker, never assume HEAD~N.
- **nsfw-classifier:** upstream module carries `unitConfig.TimeoutStartSec = "10min"` — wrong section ([Unit]), systemd ignores it (our own 2026-11-05 switch-journal incident) AND it trips shape-audit class 9. Neutralized SystemNix-side: `unitConfig.TimeoutStartSec = mkForce null` (renders absent; class 9 skips null keys — verified in audit source) + real `serviceConfig.TimeoutStartSec = "10min"`. Upstream fix queued to ride the next push wave (§f.4). Upstream's `self.packages` reference is safe when consumed — it closes over the nsfw-classifier flake's flake-parts `self`, not the consumer's (lexical closure, not a module arg).
- **Verification:** `checks.x86_64-linux.nsfw-classifier` pure-eval test GREEN (all 14 contract cases: ensemble ExecStart, TimeoutStartSec in serviceConfig, port 8104 + extension drift-guard, ROCm package, state-root flags, start-limit, onFailure, /readyz latency condition, disabled-no-unit, unconditional catalog entry). evo-x2 toplevel eval GREEN (drv `60j01a8w…`) at d8b141d46 state; final eval re-run after the last harden-layer edit was BLOCKED by a parallel session's mid-edit in `indexer-web.nix` (duplicate `serviceConfig` at their lines 114/119 — NOT this session's file; eval of shared surfaces only at quiescence) — re-verified at 03:1x once settled (see Close-out).
- Worktree artifacts cleaned: `~/.cache/systemnix-pre` removed.

## Close-out

- **Verification chain (final):** (1) evo-x2 toplevel eval GREEN at d8b141d46 (both delegations); (2) `checks.x86_64-linux.nsfw-classifier` pure-eval test GREEN; (3) the main-tree eval went RED at 03:00 from a PARALLEL session's uncommitted mid-edit in `indexer-web.nix` (duplicate `serviceConfig` key, file stale since 03:00:20 — foreign file, flagged to the user, deliberately untouched); (4) isolation proof: worktree at d8b141d46 (clean indexer-web, today's nixpkgs 26.11.20261105.f9a75f4) + the final mr-sync (harden layer) → FULL toplevel eval **EXIT:0** (drv `8pbcxmxz…`). My content is fully verified; the residual tree-red is exclusively the foreign edit.
- No deploy performed (module-structure change; both affected services: mr-sync-dashboard live — next deploy picks it up; nsfw-classifier currently owner-disabled in the tree).
- CHANGELOG entry added; integration-registry.md reference-implementation list updated to include the two new delegates; 4 follow-up rows harvested to docs/todo/upstream.md; all worktrees (~/.cache/systemnix-pre/-verify/-proof) removed, scratch JSON/logs cleaned.

## §f Direct follow-ups (self-harvested at authoring time)

1. **cvagent upstream capability merge** — fold the SystemNix deployment model (curated repo list, mesh-export target, AI model/baseurl/daily-cap, run-as primaryUser, 90min budget) into `Code-To-CV-Agent/nix/module.nix` options, then delegate `modules/nixos/services/cvagent.nix`; today the two `services.cvagent` namespaces collide and both cannot import. [blocked:push] → docs/todo/upstream.md
2. **hermes delegation** — push hermes-agent (HEAD 686193c0 unpushed, contains `nix/nixosModules.nix`), probe-build, re-lock past 0ea6ea9, then delegate the 1076-line `hermes.nix` (biggest remaining extraction; upstream module shares options/renderers with its HM module). [blocked:push] → docs/todo/upstream.md
3. **Six repos exporting no nixosModules yet** — crm, media-atlas, papdashboard (service unit only; tile/icons layer stays SystemNix), journal (journal-serve; rev-pinned), project-discovery-daemon, go-health-dashboard. Extract per the nsfw-classifier 2026-10-18 precedent (extract from the live SystemNix module, document deltas, keep SystemNix layer thin). [blocked:push each] → docs/todo/upstream.md
4. **nsfw-classifier upstream: move `unitConfig.TimeoutStartSec` to `serviceConfig`** — wrong-section key, systemd ignores it with a journal warning; SystemNix carries a `mkForce null` neutralization that should be dropped once upstream fixes it. [blocked:push] → docs/todo/upstream.md
