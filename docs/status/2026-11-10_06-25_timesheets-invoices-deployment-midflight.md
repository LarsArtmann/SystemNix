# Status Report — timesheets + invoices deployment to evo-x2 (MID-FLIGHT)

**Date:** 2026-11-10 06:25
**Session:** "deploy ~/projects/timesheets + ~/projects/invoices to evo-x2, integrate superbly"
**State:** wiring ~70% landed in-tree; NOTHING evaluated, NOTHING deployed yet. The lock-float gate currently BLOCKS every eval until `float-register.sh` runs (expected-locks.nix lacks the two new inputs).

---

## a) FULLY DONE (verified in this session)

| # | Item | Evidence |
|---|------|----------|
| a1 | **Deep research of both apps + SystemNix integration system** — serve modes, health endpoints, config contracts, data model, all integration surfaces (registry, caddy layers, gatus, tiles, ports, DNS, backups, CI keys, float gate) | read live in-session (integration-registry.md, integration.nix, caddy.nix, journal-serve/journal-backup/discordsync patterns, ports.nix, dns-local.nix, catalog.nix, papdashboard icon pack, go-ecosystem.md, float-register.sh) |
| a2 | **Upstream: `packages.default` added to timesheets flake** — buildGoModule (go 1.27.2 tarball pin), version-stamped via ldflags (`cmd.version`), vendorHash probed first-hand (`sha256-JgMgW7v+…`), fileset includes `schemas/` + `examples/` (parser conformance suite reads both — found via two failing probe iterations) | pushed upstream as `0304e2a` (3 daemon heuristic commits squashed via verified `git reset --soft`); package builds green WITH tests (`nix build path:.#default` → /nix/store/39lwb2ak…); `timesheet version` answers |
| a3 | **invoices package probe-built green** — baked vendorHash reproduces under its own lock; NO consumer shim needed (non-follower class) | probe at `03c7bcb0` (checkout) AND at the LOCKED rev `5c8c6b17` (detached worktree `~/.cache/invoices-lockprobe`, job 03E: LOCKREV-BUILD-GREEN) |
| a4 | **Live endpoint-shape probes of both binaries** (evidence for gatus conditions): timesheets `/readyz` 200 JSON domain-check, `/health` 200 HTML `<title>Timesheets</title>`, `/version` `{"version":"dev"}`; invoices `/health` 200 `{"status":"healthy","checks":[database,read-models]}`, `/` `<title>Invoice Dashboard</title>`, `/api/stats` JSON | python http.client probes against scratch instances (~/.cache/svcprobe), this session |
| a5 | **Discovered the invoices CWD-config boot contract**: `invoices dashboard` REQUIRES `config.yaml` in the working dir (viper ".", NO --config flag) and exits 69 without it → unit design carries WorkingDirectory=dataDir + production config of record in ~/invoices | live probe: exit 69 `[SYSTEM_CONFIGURATION_ERROR] stat: config.yaml: file does not exist` |
| a6 | **Discovered + debunked a false guard**: probe port 18099 answered "Domain Blocked · 127.0.0.1" — that was **dnsblockd squatting an arbitrary loopback port**, NOT an invoices host guard (invoices accepts any Host; verified with Host: invoices.home.lan → 200). First response was a wrong hostOverride theory, corrected by `ss -ltnp` | live probes this session |
| a7 | **SystemNix flake inputs** `timesheets` + `invoices` (git+ssh private, ref=master floating, non-follower class, deployment-intent comments) | flake.nix (daemon-committed) |
| a8 | **flake.lock: both inputs locked** — timesheets `0304e2ae` (= probed rev), invoices `5c8c6b17` (daemon had moved master past my first probe; re-probed AT the locked rev, green) | `jq` rev pull + worktree probe |
| a9 | **lib/ports.nix**: `timesheets = 8109`, `invoices-dashboard = 8110` (both verified free on-host via `ss`) with ownership comments | daemon commit ec71e7d8f |
| a10 | **dns-local.nix**: `timesheets` + `invoices` subdomains added | same commit |
| a11 | **modules/nixos/services/timesheets.nix** — full module: serve unit (primary user, ~/timesheets data dir, harden 512M + ProtectHome read-only + RW hole, ioTier.background, onFailure, loopback bind, --health-detail), pool backup unit + timer (sqlite -readonly .backup + quick_check + gzip + 14d retention, mkPoolDirUnit + RequiresMountsFor, 03:20 slot), integration entry (protected vHost, 2 gatus checks with evidence-backed BODY conditions, Finance tile solidtime.png, backup freshness, monitored) | written; daemon commit ec71e7d8f (initial ProtectHome comment/code mismatch on backup unit caught + fixed pre-eval) |
| a12 | **modules/nixos/services/invoices-dashboard.nix** — same shape for `invoices dashboard` (loopback-by-upstream-design, config.yaml ConditionPathExists clean-skip, 1G, 03:50 slot, invoiceplane.png tile, config.yaml snapshot rides the backup undated) | same commit |
| a13 | **configuration.nix**: both services enabled (journal-serve neighborhood) | daemon commit 95e5fe5d8 |
| a14 | **Icons verified present in the pinned dashboard-icons pack** (pack tree via gh api at rev 6d31345): `solidtime.png`, `invoiceplane.png` | gh api listing this session |

## b) PARTIALLY DONE

| # | Item | Missing |
|---|------|---------|
| b1 | **lib/lars-packages.nix PATH binaries** (`timesheets`/`invoices` CLIs on PATH, same-store-path-as-module single source of truth) | insertion points grepped; edit NOT applied |
| b2 | **probe-before-lock ceremony** | both probes green (a3), but the formal float-register (registry regen + toplevel proof + paired commit) not run |
| b3 | **integration-registry doc reference additions** | planned, not written |

## c) NOT STARTED

- c1 `scripts/float-register.sh` (expected-locks regen + keep-going toplevel proof + commit) — **BLOCKER: every eval is dead until this runs** (lock-float gate sees 2 unknown revs)
- c2 First `nix flake check --no-build` + audit-fix loop (systemd-shape, port-registry, tile-coverage, gatus-coverage, io-tier, memory-watermark, mount-gating)
- c3 Registry-matrix regeneration (`nix build .#registry-matrix` + commit the table)
- c4 CI private-input auth: deploy keys ×2 (keygen + `gh api repos/…/keys` read-only), **NIX_DEPLOY_KEYS_BUNDLE_2** workflow extension (5 auth blocks in nix-check.yml ×2, negative-tests.yml, go-deps-audit.yml, flake-update.yml) + `gh secret set` — the original bundle's private keys were trashed 2026-10-29, appending is impossible, second-bundle is the sanctioned-ish path (needs the workflow edit the recipe said you'd never need)
- c5 Pre-deploy battery (`scripts/pre-deploy-check.sh`, incl. §11 real FOD builds of both inputs, §16 tile icons)
- c6 Bootstrap production state: `~/invoices/config.yaml` (copy of repo config.yaml, environment PRODUCTION, debug false), `~/timesheets/` dir (tmpfiles covers dirs; config copy is manual)
- c7 Deploy (`nix run .#deploy`, quiescence-gated) + anchor verification (pgrep nh empty → readlink current-system == newest system-N-link BY NUMBER) + `post-deploy-check.sh`
- c8 Runtime verification: ss loopback listeners, openssl TLS probes via LAN IP + SNI for timesheets/invoices.home.lan, gatus endpoints green, tiles render on dash.home.lan, SSE spot-check, first manual backup runs (`systemctl start *-backup` → files in /mnt/pool/backups/), unit hardening spot-check
- c9 Docs: runbooks docs/services/timesheets.md + invoices-dashboard.md, data-ownership.md rows (Timesheets truth / Invoices truth), CHANGELOG, upstream AGENTS.md deployment notes in both product repos
- c10 Cleanup: remove `~/.cache/invoices-lockprobe` worktree (`git worktree remove`), ~/.cache/svcprobe scratch

## d) TOTALLY FUCKED UP

Nothing irrecoverable. Honest missteps, all self-corrected:

- d1 **Two wasted build iterations on the timesheets fileset** (schemas/, then examples/ missing) — should have grepped test fixture paths BEFORE choosing the fileset.
- d2 **openssl s_client against plain-HTTP loopback** (empty outputs), then **/dev/tcp** ("unsupported redirect fd" in mvdan/sh), then fd-redirect python — three probe-mechanism attempts before the working one. Should have started with python http.client.
- d3 **False "Domain Blocked" guard theory** (a6) — nearly designed a hostOverride around a dnsblockd squatter. `ss -ltnp` before theorizing would have saved the detour.
- d4 **First flake.lock override attempts failed** (wrong URL forms: `repo/rev` path-append, then `?rev=` on a ref-pinned input) — resolved by plain `nix flake lock` + rev verification against probes.
- d5 **Locked invoices at a rev I hadn't probed** (daemon moved master mid-session) — caught immediately, re-probed AT the locked rev in a worktree (green). Process gap: should have fetched origin right before locking.

## e) WHAT WE SHOULD IMPROVE

- e1 **Loopback plain-HTTP probe recipe**: the verified working set is python http.client (openssl s_client = TLS only; /dev/tcp + fd redirects = unsupported in mvdan/sh). This belongs in the shell-tooling notes (AGENTS.md live-probe set) — it cost 3 attempts.
- e2 **dnsblockd loopback-port squatting is a probe trap**: it binds arbitrary high loopback ports and answers a "Domain Blocked" HTML page — a probe against an unverified listener can look like an app-level guard. `ss -ltnp` FIRST. Also worth a services.md row (does it bind a RANGE? unverified).
- e3 **Fileset design for Go flakes**: grep the test suite for relative fixture reads (`../../schemas`, `examples/`) before pruning the source set. Two FOD iterations ≈ 10 min.
- e4 **Lock-then-verify is backwards**: fetch origin + compare rev immediately BEFORE `nix flake lock` in daemon-active repos; the lock landed on an unprobed rev and needed a worktree re-probe.
- e5 **The CI bundle-append recipe has a hole**: go-ecosystem.md says "append the key via gh secret set — NO workflow edit", but the bundle's private material was trashed by design, so append is impossible without regenerating keys for ~47 repos. The doc should state the second-bundle extension as the sanctioned path when bundle material is gone (this session will need it, c4).

## f) NEXT — up to 50, in execution order

1. Apply lars-packages.nix additions (timesheets + invoices PATH binaries, non-follower comments)
2. `bash scripts/float-register.sh` — regen expected-locks, prove toplevel (keep-going), paired commit
3. `nix flake check --no-build` (capture-once-then-grep to ~/.cache/fc.log)
4. Fix whatever the eval audits flag (expect: systemd-shape on backup units, io-tier, maybe tile/papdashboard, gatus-coverage, memory-watermark, port-registry on Exec strings)
5. `nix eval` spot-render BOTH new units + timers as JSON; eyeball serviceConfig merge (harden layers, ReadWritePaths, User)
6. Regenerate registry matrix (`nix build .#registry-matrix --print-out-pages`) and commit the table into integration-registry.md
7. keygen + `gh api -X POST repos/LarsArtmann/timesheets/keys` (read-only, systemnix-ci-readonly)
8. Same for invoices
9. Extend all 5 workflow auth blocks: read NIX_DEPLOY_KEYS_BUNDLE_2 (empty default) + concat into the split loop
10. `gh secret set NIX_DEPLOY_KEYS_BUNDLE_2 -R LarsArtmann/SystemNix` with both keys under @REPO headers
11. Update go-ecosystem.md bundle recipe with the second-bundle path (e5)
12. Local workflow YAML validation (python yaml.safe_load ×4-5 files)
13. `bash scripts/pre-deploy-check.sh --section-11-only` — real FOD builds of both new inputs
14. Full `scripts/pre-deploy-check.sh` (19 sections; §16 icon inventory will gate solidtime/invoiceplane)
15. Create ~/invoices/config.yaml (repo config.yaml + environment PRODUCTION + debug false; NO secrets inside — engagement data already lives unencrypted in the repo checkout)
16. Verify ~/timesheets + ~/invoices tmpfiles shapes (dirs created post-deploy; config is the only manual piece)
17. Quiescence check (eval-relevant mtimes ≥5min stable, tree clean, no parallel session mid-edit)
18. `nix run .#deploy`
19. Anchor discipline: pgrep -f 'nh os|switch-to-configuration' EMPTY → compare readlink /run/current-system vs newest system-N-link BY NUMBER
20. `scripts/post-deploy-check.sh`
21. `ss -ltnp`: 127.0.0.1:8109 (timesheet) + 127.0.0.1:8110 (invoices) listening
22. openssl TLS probe (LAN IP + SNI): https://timesheets.home.lan/health → 200 Timesheets title; https://invoices.home.lan/ → 200 Invoice Dashboard
23. Probe /readyz (timesheets) + /health (invoices) JSON via TLS
24. gatus: endpoints visible + green on status.home.lan (or gatus API probe)
25. Tiles on dash.home.lan: Finance group, Timesheets + Invoices with icons (not monograms)
26. SSE spot-check: GET /api/events (timesheets) + /events/facts (invoices) — headers + first bytes, timeout-bounded
27. `systemctl start timesheets-backup invoices-dashboard-backup` → verify /mnt/pool/backups/{timesheets,invoices}/ files + quick_check log lines
28. journalctl -u timesheets -u invoices-dashboard: no error spam; verify hardening live (systemctl show -p ReadWritePaths,MemoryMax,…)
29. browser smoke via LAN from owner's desk (auth bypass on LAN, oauth2 gate from WAN)
30. Write docs/services/timesheets.md runbook (port, unit, data dir, CLI --db contract, backup/restore drill, gatus checks)
31. Write docs/services/invoices-dashboard.md runbook (config.yaml contract!, DB, backup+config snapshot, restore)
32. data-ownership.md: add Timesheets + Invoices rows (truth, restore path = pool backup, drill PENDING)
33. CHANGELOG entry (both services live, upstream package addition)
34. Upstream: timesheets AGENTS.md deployment note (port/unit/data path/serve flags)
35. Upstream: invoices AGENTS.md deployment note (config.yaml CWD contract, dashboard unit)
36. Run one RESTIC/restore drill? (gunzip backup → sqlite3 open → count tables) — the data-ownership "restore path you have actually run" test
37. Trash ~/.cache/invoices-lockprobe worktree + svcprobe scratch
38. Negative-check: `nix eval` that a DISABLED timesheets (extendModules throwaway expr) doesn't fan out tiles/checks — safe-verification pattern, never force-enable in-tree
39. Confirm systemd-shape-audit passes the two backup oneshots + two serve daemons (part of 3/4 but call it out)
40. Verify backup-coordination freshness entries appear (systemd timer + registry backup row)
41. Watch first NIGHTLY backup window (03:20/03:50) next morning — Persistent timers, files dated
42. Post-deploy memory sweep (§17) clean for both new units
43. Consider otel wiring=wupstream registration IF the binaries gain OTel later (they have none today — deliberately skipped)
44. Owner question pack answers (see g) folded into runbooks
45. If owner wants LAN-auth too: flip vHost layer to always-forward-auth variant (needs caddy.nix change — currently LAN bypass is baked into "protected")

(45 items — the honest full remainder.)

## g) QUESTIONS (cannot be answered from the tree)

1. **Invoices config truth**: production `config.yaml` will live in `~/invoices` (dashboard REQUIRES it CWD-resident; repo copy stays environment: DEVELOPMENT). OK to treat ~/invoices/config.yaml as the editable config OF RECORD (runbook-documented), or do you want the repo checkout's config.yaml to stay the single truth (unit would need WorkingDirectory=repo-checkout instead)?
2. **LAN exposure posture**: both vHosts are layer "protected" = oauth2-proxy for OFF-LAN clients, BYPASS on LAN (journal-serve/bank-sync posture). Billing/timesheet data will be reachable from any LAN device without login. Keep LAN bypass, or should these two require auth even on LAN?
3. **Deploy pin for invoices**: invoices master is being actively churned by a parallel session (45 files since my first probe). The lock sits at probed-green `5c8c6b17`; I will NOT float it again before deploy. Confirm: deploy at `5c8c6b17` and leave re-floating to the next lock wave, even if master moves again mid-deploy?

---

**Honest bottom line:** research + upstream packaging + all declarative wiring are DONE and committed (by the daemon, heuristic messages — the flake.nix/modules/ports/dns/configuration edits ride ec71e7d8f/95e5fe5d8f-era commits); both inputs are probe-verified at their locked revs; ZERO evaluation has run (lock-float gate intentionally blocks until float-register), ZERO deployment, CI auth for the two new private inputs not yet wired — a push to GitHub right now would redden CI (missing bundle-2 secret). Session paused mid-list at f-1/f-2 per owner instruction.
