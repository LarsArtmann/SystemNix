# cvagent dashboard deploy wiring + the pre-existing evo-x2 eval breakage (2026-11-10 14:59)

Session: cvagent dashboard (`cvagent serve`) deployment onto evo-x2 via SystemNix, triggered by the
owner directive "it must be deployed on SystemNix evo-x2". The session wired the dashboard
end-to-end at the config layer, chased an eval breakage that turned out to predate the session,
and handed off with the toplevel eval GREEN but nothing built or deployed.

## a) FULLY DONE

1. **Ask + upstream premise verified.** The dashboard was never deployed (site module had
   `serve.enable = false`); the upstream module ALREADY ships the full serve unit
   (`cvagent.service`, `cvagent serve`, loopback-only, `services.cvagent.serve.*` options) —
   verified at the locked rev `6ff68d3` AND the working tree `f41bfe6` (nix/module.nix:445-478).
   Zero upstream changes needed, zero lock changes needed (flake.lock already floats cvagent at
   `f41bfe6`).
2. **Port registered**: `cvagent-dashboard = 8787` in `lib/ports.nix` (the upstream CLI/module
   default; quotaboard precedent for registering an app-owned default; 8787 verified free).
3. **DNS subdomain added**: `"cvagent"` in `platforms/common/dns-local.nix` (the eval-time
   dnsMissing assertion requires it).
4. **Site module wired** (`modules/nixos/services/cvagent.nix`): `serve.enable = true` with
   `serve.addr = "127.0.0.1:${ports.cvagent-dashboard}"`, `serve.allowPublic` stays false (the
   binary refuses non-loopback without it); fleet layer on the serve unit (`onFailure`, `harden {
   ProtectHome = false; MemoryMax = mkForce "512M"; }`, `serviceDefaults { RestartSec = "10s"; }`,
   `ioTier.background`); `options` added to the module args; full `services.integration.cvagent`
   registry entry — subdomain `cvagent`, `vHost.layer = "protected"` (oauth2-proxy external, LAN
   bypass; journal-serve posture for an unauthenticated dashboard naming repos/authors/paths),
   `monitored = true`, two Gatus checks (`/` functional footer-body check
   `pat(*Nothing on this page mutates it.*)` + `/health` go-health aggregate), homepage tile
   `CV Agent` (Development, mdi-source-branch). The integration entry follows the documented
   pattern (`lib.mkIf cfg.enable` inside `lib.optionalAttrs (options ? services.integration)`,
   inside a `lib.mkMerge`-restructured config).
5. **go-health federation**: `cvagent=http://127.0.0.1:8787/health` added to
   `services.health-dashboard.remotes` (configuration.nix) — cvagent's `/health` is a real
   go-health document (internal/web/health.go mounts go-health via go-appkit probe), so the
   health-dashboard-rediscover sweep would have demanded it the day after deploy anyway.
6. **Runbook updated**: `docs/services/cvagent.md` gained the Dashboard section (vHost, listen,
   unit, checks, federation, security posture) and the daemon-less doctrine bullet now scopes
   itself to the SCAN unit.
7. **Float gate unstuck (locally)**: regenerated `flake/expected-locks.nix` rows from
   `flake.lock` (the audit had been RED on drifted inputs since ~2026-11-07; TODO_LIST rows
   3372/3386).
8. **The pre-existing eval breakage root-caused enough to hand off**: the
   `Module ':anon-2290:anon-1:anon-1:anon-1:anon-1' has an unsupported attribute 'services'`
   error exists at `865e40703^` (BEFORE this session's first edit) — proven via a git worktree
   eval. Built a 3-iteration isolation harness (`/tmp/mod-bisect.sh`: full NixOS module-list +
   per-candidate `evalModules`, `attrNames` forcing so only declaration/shape errors classify) —
   ALL 36 consumed upstream nixosModules evaluate CLEAN in isolation (only artifact: nix-email
   wants `services.stalwart-mail` from a sibling module — harness-only).
9. **FINAL STATE: evo-x2 toplevel eval is GREEN** at current HEAD with the dashboard wiring in:
   `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` →
   `/nix/store/shwh4nvr8fc3cqdbczyind0axz844kny-nixos-system-evo-x2-26.11.20261107.f4a03c0.drv`.
   The eval warnings CONFIRM the entry is live (`catalog: integration subdomain(s) without
   catalog entries ... cvagent ...`).
10. **Parallel-session collision survived**: commit `06079542e` (21 files, incl. a 362-line
    cvagent.nix rewrite by a sibling session) landed mid-session; verified my serve wiring +
    integration entry SURVIVED at current HEAD (grep evidence lines 82-84, 208-237).

## b) PARTIALLY DONE

1. **Deployment**: eval green, but the toplevel is NOT built (`nix build` of the drv not run),
   NOT switched, and the dashboard is NOT verified live. Deploy requires the fleet deploy flow
   (scripts/deploy.sh — agent shells cannot sudo; NoNewPrivileges, live 2026-11-05).
2. **Registry-matrix contract**: the service matrix in
   `docs/agents/integration-registry.md` is a byte-exact eval-truth contract
   (`checks.registry-matrix-drift`) and has NOT been regenerated after adding the cvagent
   integration entry — `nix flake check` WILL fail on it until
   `nix build .#registry-matrix --print-out-paths` is pasted in.
3. **Catalog entry missing**: the eval warning names cvagent among "integration subdomain(s)
   without catalog entries — they will vanish from derived DNS once dns-local.nix is deleted"
   (25 pre-existing services share the gap, but a NEW service should land WITH its catalog row
   per the health-dashboard endpoint-domain enforcement chain precedent). CRITICAL follow-up:
   if dnsblockd derives `*.home.lan` records from the CATALOG (not dns-local), `cvagent.home.lan`
   may not resolve at all until the catalog row lands.
4. **Attribution of the green eval**: WHO/WHAT fixed the pre-existing shape error between
   `865e40703^` (RED) and HEAD (GREEN) is unattributed — candidates: my registry regen (the
   gate change alone should NOT fix a module error), the parallel sessions' 21-file commit wave
   (06079542e rewrote lib/default.nix, several services, systems/evo-x2.nix), or 9b189b414-era
   lock surgery replay. Needs a `git bisect`-style attribution if anyone cares.
5. **Float ceremony**: my manual expected-locks regen was superseded by the sibling session's
   proper refresh (79b6b817c "refresh expected lock revs") — the file's current state vs
   flake.lock was NOT re-verified after their commit (the GREEN eval implies they match, but the
   formal float-register proof+commit cycle has not been re-run cleanly).
6. **Docs cadence**: AGENTS.md (SystemNix) has no dashboard note; CHANGELOG has no entry;
   TODO_LIST harvest of this report not done (user asked report-then-wait).

## c) NOT STARTED

1. Toplevel build + deploy + anchor verification (`readlink /run/current-system` = latest
   `system-N-link`), pre/post-deploy checks.
2. Live battery: `systemctl status cvagent` active, `ss -ltnp` loopback :8787,
   `https://cvagent.home.lan` 200 with the footer body, Gatus "cvagent Dashboard"/"cvagent
   Health" green, homepage tile renders, health hub shows the cvagent card (9 remotes),
   dashboard pages show the real scanned repos from the production db.
3. First reader/writer coexistence proof: dashboard (serve) + scan+mesh unit against the same
   sqlite WAL db under real load (pragmas say safe — never proven live on evo-x2).
4. `docs/todo/` routing of the pre-existing rows noticed this session (below §f).
5. Cleanup: `/tmp/sn-bisect` git worktree, `/tmp/mod-bisect.sh`, `/tmp/trace-full.log`,
   `/tmp/expected-locks-body.nix`, background shells.
6. treefmt/nixfmt pass over my module edits (the daemon committed them as-is; formatting
   unverified).

## d) TOTALLY FUCKED UP (own mistakes, no varnish)

1. **Eval-before-edit discipline inverted**: when the eval broke, I assumed MY edits and spent
   ~6 tool rounds building isolation harnesses before running the decisive 1-minute check
   (eval the pre-change tree). The worktree eval answered it instantly: pre-existing. Cost:
   most of the session's mid-section.
2. **Two syntax-broken edits** to cvagent.nix (the mkMerge restructure: opened a merge list,
   closed the wrong braces twice) — three fix attempts with parse errors, including an
   edit-tool old_string mismatch from my own earlier mangling.
3. **Hand-rolled registry surgery**: regenerated expected-locks with a sed+python hack that
   produced a confusing diff (net +blank line vs HEAD while the file held new revs) and RACED
   the sibling session's proper regen (79b6b817c) minutes later. Should have used
   float-register's own regen step only, or waited.
4. **Ran the expensive float-register proof without pre-evaluating my own changes** — burned a
   full keep-going toplevel proof on an error that predated me, then had the script revert its
   own registry rows.
5. **Ignored the multi-session reality**: did not probe for live parallel executors (fresh
   commits <30min old, running crush sessions) before editing shared fleet files; a sibling
   session rewrote the same cvagent.nix (362 lines) mid-flight. Got lucky — the rewrite kept my
   content.
6. **Left a git worktree** (`/tmp/sn-bisect`) and temp artifacts behind, violating my own
   cleanup bar.
7. **The registry-matrix contract was not in my original plan** — it is a mandatory fan-out of
   ANY `services.integration` entry addition and would have been caught only at `nix flake
   check` time, late.

## e) WHAT WE SHOULD IMPROVE

1. Adopt a hard rule for shared-repo debugging: FIRST establish "does HEAD-minus-my-changes
   fail too?" before any hypothesis-driven investigation.
2. Fleet sessions should CLAIM surfaces (or at least re-read target files immediately before
   editing) when daemon-commits younger than 30 minutes exist in the same area.
3. Use the repo's own mechanical ceremonies (float-register regen) instead of ad-hoc scripting
   for eval-gated registries.
4. Integration-entry additions carry a fixed fan-out checklist: ports + dns-local + catalog +
   registry entry + registry-matrix regen + runbook + CHANGELOG. The catalog row and matrix
   regen were missed; codify the checklist (docs/agents/integration-registry.md step 6 already
   lists most of it — follow it in order next time).
5. Pre-evaluate personal changes in isolation (regen gate locally, eval the affected unit
   render) BEFORE invoking any proof/commit ceremony.
6. Status-report pre-read probe (live executor check) at session start in this repo.

## f) NEXT (ordered, evidence-backed; the §f harvest source)

1. **Add the `services.catalog` entry for cvagent** and re-eval — the warning
   "integration subdomain(s) without catalog entries: ... cvagent ..." means derived DNS may
   not resolve cvagent.home.lan; a deploy without this risks a dead vHost. (modules/nixos/
   services/catalog.nix; precedent: health-dashboard subdomain `health`.)
2. **Regenerate the registry matrix** (`nix build .#registry-matrix --print-out-paths`) and
   paste over the table in docs/agents/integration-registry.md — `checks.registry-matrix-drift`
   is byte-exact and WILL fail flake check with the new cvagent row.
3. **Re-verify expected-locks vs flake.lock at HEAD** (post-79b6b817c), then run the official
   `scripts/float-register.sh` proof+commit cycle for the current floats.
4. **Build the toplevel**: `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel`
   (or let float-register's proof do it).
5. **Deploy evo-x2** via the documented flow (scripts/deploy.sh / deploy-when-quiescent.sh —
   needs the owner or the tq/deploy wrapper since agent shells cannot sudo); then anchor-verify
   `readlink /run/current-system`.
6. **Live battery**: unit active + loopback bind (`ss -ltnp | grep 8787`), `https://cvagent.home.lan`
   200 + footer body, `/health` 200 go-health doc, both Gatus checks green, homepage tile
   renders, health hub card lists cvagent (9 remotes), pages show real repos from the
   production db.
7. **Attribution**: identify which commit fixed the pre-existing shape error (worktree-eval
   commit walk over fd737eb85..06079542e) and record it — an unattributed eval fix in this
   fleet becomes tomorrow's ghost.
8. **AGENTS.md (SystemNix)**: add the cvagent dashboard row (vHost, protected layer, port,
   federation) to the service notes; CHANGELOG entry for the dashboard deployment wiring.
9. **Harvest this §f into TODO_LIST.md** (docs-gates freshness gate requires the newest
   report's open items routed).
10. **Cleanup**: `git worktree remove /tmp/sn-bisect`, delete /tmp/mod-bisect.sh,
    /tmp/trace-full.log, /tmp/expected-locks-body.nix.
11. **Format check**: run the treefmt/nix fmt scope over modules/nixos/services/cvagent.nix +
    lib/ports.nix + platforms/common/dns-local.nix + platforms/nixos/system/configuration.nix.
12. **Prove reader/writer coexistence live**: after deploy, dashboard reads while the 05:53
    scan+mesh writes the same WAL db (sqlite BUSY/LOCKED classification silently defaults to
    Transient upstream — watch for it in the journal).
13. **Post-float rows**: tick or re-scope TODO_LIST rows 3372/3386 (the 16-input lock-float
    registration) against the now-green eval.
14. **Pre-existing row, touched surface**: cvagent §-leg in scripts/post-deploy-check.sh
    (docs/todo/services.md; the dashboard now gives the check a real HTTP probe surface — the
    leg shape improves: vHost 200 + unit last-result).
15. **Pre-existing row**: cvagent unit preflight `cvagent health` before the scan loop
    (docs/todo/services.md).
16. **Pre-existing row**: route cvagent GLM traffic through the ai-meter proxy
    (docs/todo/pipeline.md; the dashboard makes z.ai spend visible per-day via /facts — still
    not metered).
17. **Pre-existing row (upstream)**: make MaxCommitSample config-tunable
    (docs/todo/upstream.md).
18. **Pre-existing row (upstream)**: module-level VM assertion that the generated YAML parses
    (docs/todo/upstream.md / TODO_LIST).
19. **Pre-existing row**: system-health extraMonitoredServices semantics for oneshot units
    (docs/todo/monitoring.md) — the dashboard entry now rides `monitored = true` (long-running,
    well-covered), the scan unit row remains the open question.
20. **Pre-existing row**: week-one AI-facts quality review + keyword promotion into the curated
    CV base (TODO_LIST) — the dashboard makes this review browsable instead of CLI-only.
21. **Pre-existing row**: String-ExecStart sweep ~35 units (docs/todo/services.md).
22. **Pre-existing row**: eval-time runtimeInputs audit for writeShellApplication scripts
    (docs/todo/pipeline.md).
23. **README counts**: the gatus check count grew by 2 (cvagent Dashboard + cvagent Health) —
    the README's re-derived count needs a re-stamp on the next docs sweep.
24. **Decide + record the exposure decision**: protected vHost chosen by journal-serve
    precedent without an explicit owner sign-off — record it (or flip) in the runbook's owner
    decisions.
25. **Dashboard niceties upstream** (Code-To-CV-Agent): the SSE-observe feed (AGENTS.md open
    question 4, option A+C) remains unbuilt; the deployed dashboard is the first real consumer
    argument for it.

## g) Questions for the owner (cannot self-answer)

1. **Exposure posture**: the dashboard is wired as a PROTECTED vHost (oauth2-proxy for
   external, LAN bypass — journal-serve posture) because the pages name repositories, file
   paths, and authors. Confirm, or do you want a different layer (plain LAN, or no vHost)?
2. **Deploy now or park?** Config is eval-green but nothing is built/switched. Deploying needs
   the sudo-capable deploy flow (my shells cannot) — do you want me to prepare everything and
   hand you one command, or wait for explicit go?
3. **The unattributed eval fix**: the pre-existing toplevel breakage (unsupported attribute
   `services`) went RED→GREEN during the session while at least one sibling session was
   committing. Do you know which session owned that fix (so I can annotate instead of
   bisecting it later)?
