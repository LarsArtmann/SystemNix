# SSH Banner Root-Cause + Fix, Git-Transport Matrix — Session Status Report

**Report:** 2026-11-11 13:03 CET · session: git-transport matrix question → forgejo SSH-banner hate → root-cause → in-tree fix
**Scope — VERIFIED this session (with artifact):** Forgejo runbook + integration-registry read (docs/services/forgejo.md, docs/agents/integration-registry.md); live listeners `ss -ltnp` (:22, :443 on 192.168.1.x, :3000 on `*`); SSH git handshake `ssh forgejo@forgejo.home.lan` (key auth → Forgejo banner reached, no interaction); HTTPS smart-HTTP probe via `openssl s_client` (`GET /lars/SystemNix.git/info/refs?service=git-upload-pack` → **200 anonymous**); app.ini (`RUN_USER=forgejo`, `DISABLE_SSH=false`, `SSH_PORT=22`, `ROOT_URL`), sshd_config (`Match User forgejo / AcceptEnv GIT_PROTOCOL`, `Banner /etc/ssh/banner`); banner provenance chain via `nix eval …settings.Banner` → `/etc/ssh/banner` → flake input `github:LarsArtmann/nix-ssh-config@8c083ed` `nixosModules.ssh` → `services.ssh-server.bannerText` default from its `modules/shared/banner.nix` (store prefetch read); fix landed `platforms/nixos/system/configuration.nix:353` (`services.ssh-server.bannerText = null;`), post-edit eval `settings.Banner = null` on **both** evo-x2 and rpi3-dns, both toplevel `drvPath` evals green, `nix fmt` 0-changed; daemon commit `6e49413ea` inspected (`git show --stat`).
**Scope — NOT verified, and why:** banner removal LIVE (needs deploy; deliberately not deployed — parallel session active, deploy-vs-executor race); macOS darwin host (different machine, never probed — the nix-ssh-config HM-module banner claim is UNVERIFIED); rpi3's import chain to configuration.nix (outcome eval-proved, path grep returned nothing — proof is the eval, not the wiring path); whether any script/automation parses or depends on the banner text (sweep not run); Match-block banner scoping feasibility inside nix-ssh-config's option surface (alternative mentioned, not checked); GitHub-side repo visibility (only the Forgejo side probed); git push round-trip over either transport (writes deliberately not performed).

---

## a) FULLY DONE

1. **Git-transport matrix for local Forgejo (Q1)** — delivered, every cell grounded in a live probe or repo read. SSH side: system sshd:22, user `forgejo`, keys declaratively synced from NixOS (`services.forgejo.sshKeys`, forgejo.nix:264, `forgejo-ssh-keys` oneshot) — key auth probed working. HTTPS side: Caddy :443 → :3000 (`plain` layer), smart-HTTP endpoint probed 200 for anonymous reads, token required for pushes. Recommendation: SSH for humans (zero new secrets, no rotation), HTTPS+token for machines (runner/mirrors already do this). Client-side `insteadOf` snippet supplied for frictionless HTTPS-URL copies.
2. **SSH banner root-cause (Q2)** — the "forgejo banner" is NOT Forgejo's: it is the system-wide OpenSSH `Banner /etc/ssh/banner`, authored by the first-party flake input `github:LarsArtmann/nix-ssh-config` (`nixosModules.ssh` imported at systems/evo-x2.nix:113), option `services.ssh-server.bannerText`, default = legal "AUTHORIZED ACCESS ONLY" text in that input's `modules/shared/banner.nix`. It rides every SSH connection — forgejo git fetch/push included, hence the noise.
3. **The fix, landed + eval-verified** — `services.ssh-server.bannerText = null;` in `platforms/nixos/system/configuration.nix:353` (shared config ⇒ covers evo-x2 AND rpi3-dns). Post-edit: `settings.Banner` evals `null` on both hosts; both toplevel drvPaths eval clean; pinned `nix fmt` reports 0 changed.
4. **Foreign-commit detection** — daemon commit `6e49413ea` carried my file **plus another session's** `docs/todo/services.md` diff (a row tick + new rows). Inspected, untouched, reported to owner per shared-tree discipline.

## b) PARTIALLY DONE

1. **Banner fix rollout** — eval-complete in tree, **not deployed**: the live generation still prints the banner on every SSH/git op. Deploy is one command (`nix run .#deploy`) but was gated on the active parallel session (deploy-vs-executor race doctrine) and is awaiting owner instruction.
2. **Session follow-up queueing** — this report is the authoring step; the direct follow-ups are being harvested into `TODO_LIST.md` + domain libraries at authoring time per the TODO System rule (done alongside this file; the 50-item brainstorm in §f stays ROADMAP fuel, NOT harvested).
3. **Transport-policy documentation** — the matrix lives only in this session's chat + this report; docs/services/forgejo.md (titled "GitHub Mirror Sync Runbook") has no clone-URL/transport section yet.

## c) NOT STARTED

1. **Deploy of the banner fix** (see b.1) + post-deploy probes (banner absent, git push round-trip over forgejo SSH — would also be the first write-path test).
2. **`:3000` LAN exposure hardening** — Forgejo's plain HTTP listens on `*` (`ss -ltnp`), reachable LAN-wide bypassing Caddy TLS/logging. Candidate: bind to loopback; must verify Caddy proxy, gatus checks, VM tests, and the forgejo-runner's connection config survive.
3. **Orphan `platforms/nixos/users/ssh-banner`** — the raw banner file sits in the repo with ZERO nix consumers (commit `13c50dd16` moved the banner inline upstream-side long ago; git archaeology confirmed). Dead file, not yet trashed (and docs archived reports reference the topic — verify no refs before deletion).
4. **Upstream fix in `nix-ssh-config`** — flip `bannerText` default to null (or add opt-in/per-scope options), then drop the override here. Push-gated (different repo).
5. **Darwin banner check** — whether the nix-ssh-config HM module sets a macOS sshd banner at all is UNKNOWN; my "would need its own fix" line was an unverified claim.
6. **Forgejo HTTPS mirror visibility decision** — `/lars/SystemNix.git` serves anonymous reads over HTTPS on the LAN (probed 200). Intended public, or should mirrors default private? Owner decision.
7. **Forgejo `insteadOf` in managed gitconfig** — suggestion delivered in chat; not implemented in `platforms/common` gitconfig.
8. **Banner posture decision** — kill-everywhere (landed) vs Match-scoped (`Banner none` under `Match User forgejo`, keep legal text on interactive logins). The null is reversible in one line; owner may want the interactive banner back for audit-posture reasons.
9. **docs/agents SSH knowledge row** — AGENTS.md's routing table has no SSH row; this session's discovery cost (several blind module-system evals before finding the input) is exactly what a routing row + a short note would prevent.

## d) TOTALLY FUCKED UP

**Nothing.** No eval regression, no deploy, no prod mutation (all probes read-only; the one SSH handshake mutated nothing — no shell was opened, banner only). Two hazards adjacent to (not caused by) this session, both flagged:

1. **Daemon commit swept foreign work** (`6e49413ea`: my configuration.nix + another session's docs/todo/services.md). Standing shared-tree hazard; amend was correctly skipped (amend would have absorbed the other session's file into a rewritten commit).
2. **My own near-miss, caught by the hook**: typed `rg -rn` (the replace-not-recursive trap, third documented strike on this host) — blocked by the hook before damage. Discipline note, not breakage.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-read discipline was applied late.** The `rg -l 'AUTHORIZED ACCESS'` sweep surfaced `docs/status/archived/2025-12-07_11-31_SSH-HARDENING-STATUS.md` mid-investigation — but only AFTER ~6 blind nix evals chasing the option's declaration. The session-start rule (grep docs/status/ + docs/todo/ BEFORE diagnosing) would have pointed at the SSH-hardening lineage immediately. Cost: ~6 wasted eval round-trips.
2. **Unverified claims slipped into answers.** Two: the darwin banner claim (never probed) and the Match-scoping alternative (option surface not checked). Both are now §c rows instead of assertions — but they should never have left chat as implied facts.
3. **Discovery not recorded at discovery time.** The AGENTS.md memory rule is update-at-moment-of-discovery; the nix-ssh-config provenance + the orphan file sat unrecorded until this report. (Deliberate exception recorded here: harvesting mid-wait while a parallel session edits the same todo files is its own race.)
4. **Forgejo runbook drift noticed, not fixed** — title still "GitHub Mirror Sync Runbook" while the service now hosts canonical repos, push mirrors, release shadowing. Stale-title row queued (§f).
5. **Probe hygiene was good and should stay standard**: every number in the matrix came from a live probe (`ss`, openssl raw HTTPS, ssh handshake, eval), not doc claims — this is the pattern that caught "the banner is not Forgejo's".

## f) 50 THINGS TO GET DONE NEXT (brainstorm — ROADMAP fuel unless tagged)

**Direct follow-ups of this session (harvested to the queue):**
1. Deploy the gen carrying `bannerText=null` at a quiescent window (poll: clean tree + no eval-relevant file <5min mtime, then `nix run .#deploy`); `[ready]`
2. Post-deploy probe: banner absent on `ssh forgejo@…` + real git push round-trip over forgejo SSH (first write-path test); `[ready]`
3. Trash orphan `platforms/nixos/users/ssh-banner` after a full repo sweep (incl. docs/tests/scripts) proves zero refs; `[ready]`
4. Upstream `nix-ssh-config`: default `bannerText` to null (opt-in), then drop the override + re-lock; `[blocked:push]`
5. Bind forgejo HTTP `:3000` to loopback; verify Caddy proxy + gatus + runner config + VM tests; `[ready]`
6. Owner decision: kill-everywhere banner (landed) vs Match-scoped `Banner none` for forgejo only, legal text kept interactive; `[decision]`
7. Owner decision: forgejo mirror visibility — SystemNix anonymously readable over HTTPS today; `[decision]`
8. Add `[url "forgejo@forgejo.home.lan:"] insteadOf = https://forgejo.home.lan/` to managed gitconfig (all hosts); `[ready]`
9. Verify darwin: does the nix-ssh-config HM module set a macOS sshd banner; apply same kill if so; `[ready]`
10. AGENTS.md knowledge routing: add an SSH row (nix-ssh-config module surface, banner provenance, Match block); `[ready]`

**Transport/auth hardening (adjacent, from the matrix work):**
11. Gatus coverage for the SSH git path (TCP :22 or `git ls-remote` probe) — today likely HTTPS-only
12. Write the transport-policy ADR: ssh-for-humans, https+token-for-machines; link from docs/services/forgejo.md
13. Document clone URLs (`forgejo@forgejo.home.lan:lars/x.git` + HTTPS) in the forgejo runbook
14. Forgejo token lifecycle: expiry policy + rotation automation for HTTPS push creds
15. Push-mirror auth review (forgejo→GitHub): token vs SSH deploy key tradeoff
16. Pull-mirror `GITHUB_TOKEN` expiry: add age-alert before it dies silently
17. CI runner checkout audit: confirm forgejo-runner clones via internal HTTPS+token, not vhost
18. Verify GIT_PROTOCOL v2 end-to-end (`AcceptEnv GIT_PROTOCOL` Match block passes through; `git -c protocol.version=2 ls-remote` probe)
19. `forgejo-ssh-keys` sync cadence: keys added at activation only? new key → needs re-run? document the path
20. Sweep repo scripts for banner-text dependence (`grep -r 'AUTHORIZED' scripts/`) before the deploy lands
21. Census: which machines/agents clone from forgejo today (crm, cvagent, …) — input to insteadOf rollout
22. LFS parity check ssh vs https (if any repo uses LFS)
23. Post-deploy-check candidate: cheap SSH-banner-absence smoke (or fold into #2's one-time probe)
24. Eval guard: assertion/`config.warnings` if `settings.Banner` ever regresses to non-null (input-default drift protection)

**Service-surface hygiene (noticed during the runbook/module reads):**
25. Stale title: docs/services/forgejo.md "GitHub Mirror Sync Runbook" → scope is now canonical repos + push mirrors + release shadowing
26. Integration-registry manifest bridge: SSH git surface undocumented (registry covers vHost/gatus/tile only) — decide if it belongs
27. Verify `:3000` plain-HTTP UI behavior (redirects to https? serves login?) — informs #5's risk assessment
28. Audit-trail parity: Caddy logs capture git smart-HTTP ops — confirm, so HTTPS ops stay auditable post any SSH shift
29. sshd MaxStartups/rate-limit posture for a LAN box — one-line nit, decide
30. Confirm `KbdInteractiveAuthentication=false` + `PasswordAuthentication` posture is intentional (settings dump showed it) and document
31. rpi3-dns: confirm the import chain to configuration.nix (eval proved the outcome; the wiring path grep came back empty — 10-min record fix)
32. fastfetchOnLogin interplay: after banner removal the login greeting is fastfetch-only — confirm that's the desired UX
33. Archive annotate: 2025-12-07 SSH-HARDENING-STATUS report now stale re banner (docs-health ANNOTATE pass)
34. Add the nix-ssh-config module surface to a docs/agents note (discovery cost was high; never re-derive)

**Broader (ROADMAP fuel — most from standing observations, not this session):**
35. insteadOf also on rpi3/darwin gitconfigs for parity (#8 scope decision)
36. Benchmark ssh vs https clone on LAN (low value; only if policy doc wants numbers)
37. Clone-URL cheat sheet: README/docs one-pager for first-party projects
38. Consider `AllowUsers` audit cadence (currently `lars forgejo`) — new service users need explicit add
39. IPv6 sshd path (`[::]:22` listening; DNS is v4) — decide ignore-or-document
40. Forgejo release-shadow + push-mirror interplay docs: which repo is truth for tags (release origin vs GitHub download surface)
41. Backup restore-path doc: git state lives in forgejo + GitHub twins — verify restore runbook names both
42. Dead-code sweep: any other orphan files like ssh-banner (config files with zero consumers) — generalize #3
43. Forgejo runner ↔ forgejo connection: localhost:3000 vs vhost — confirm internal (cosmetic + latency)
44. secrets.md: note that forgejo tokens (FORGEJO_TOKEN/GITHUB_TOKEN) never appear in remote URLs (policy enforcement grep)
45. Monitoring: alert if forgejo SSH git path fails while HTTPS stays green (split-visibility failure mode)
46. AGENTS.md routing: services row already points at integration-registry — add the manifest-bridge degrade contract cross-ref for SSH-only surfaces
47. Consider exposing a read-only git mirror protocol (git daemon / bundle snapshots) — probably YAGNI, record the rejection
48. vm-test: forgejo clone-over-ssh leg in checks (currently VM tests cover HTTP surfaces)
49. Rename/route: docs gotchas-archive entry for "banner is system sshd, not the service" (the misattribution cost two questions here)
50. After upstream default flip (#4): remove the nix-ssh-config pin-surface note from flake-input-pin-audit if it ever pins (pre-register the LIFT condition)

## g) QUESTIONS FOR THE OWNER (cannot figure out myself)

1. **Banner posture:** is kill-everywhere final, or do you want the legal banner kept for *interactive* logins (Match-scoped, `Banner none` only for `forgejo` git)? I assumed "hate it ⇒ remove everywhere" and landed that.
2. **Forgejo mirror visibility:** `lars/SystemNix.git` (and possibly other mirrors) are anonymously readable over HTTPS on the LAN. Intended? If not, should mirrors default private and canonical repos stay public?
3. **Deploy timing:** deploy the banner fix now (I'll verify quiescence against the parallel session first), or batch it into the next deploy window you're driving?
