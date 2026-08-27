# Monitoring Stack Hardening, Round 2 — Lint Layer + Wedge Forensics

**Session:** 2026-08-27 ~17:25–18:15 · follows `2026-08-27_16-08_self-review-signoz-phantom-purge.md`
**Scope:** execute the self-review's ranked next-items; decide the 3 open policy questions autonomously (user directive: execute until done).
**Outcome:** all actionable items shipped and deployed (system-730 generation series); 1 major new lesson discovered (stdenv nullglob → phantom-green flake check).

---

## Decisions on the 3 open questions

| Q | Decision | Rationale |
|---|----------|-----------|
| 1. SIGQUIT runbook vs restart-first | **Capture-then-restart — shipped** | `scripts/dnsblockd-goroutine-dump.sh` (root): SIGQUIT IS the restart (Go runtime dumps every goroutine to the journal, then exits; systemd restarts). `GOTRACEBACK=all` baked into `dnsblockd.service` Environment — default `single` mode shows only the signal-handling goroutine and would say nothing about a mutex deadlock. Zero added MTTR: the dump costs one signal. |
| 2. Deploy-window alert noise | **Accept transients; no grace mechanism** | Deploy restart-churn is bounded (~minutes) and self-resolves; an activation-gated grace adds cross-unit state (deploy marker ↔ rule evaluator) for marginal value. Instead the NEW long-firing WARN surfaces every >24h firing alert at each deploy — ongoing incidents become per-deploy visible rather than silenced. |
| 3. Alert layering | **Keep complementary (de-facto codified)** | SigNoz = unit-state/resource/frequency rules; Gatus = HTTP/functional outcomes. The `signoz-query-lint` scope (alerts file + dashboards) encodes this boundary. Mirroring both layers doubles maintenance for the exact duplicated-signal class the PapDashboard design already avoids. |

## Shipped

1. **`signoz-query-lint` flake check** (`flake.nix`, next to `gatus-pattern-lint`) — rejects at eval time:
   - `job=` label matchers (the phantom-green class — no series ever carries `job`; OTel receiver stores it as `service.name`)
   - underscore histogram suffixes (`metric_sum`/`_count`/`_bucket` — stored DOTTED; query `{__name__="metric.suffix"}`)
   - bare `up{service_name=` selectors without `count(...) or vector(0)` (label-flip staleness — returns empty exactly during the outage)
   - dead-metric blocklist (`node_amdgpu_gpu_temp_celsius`; extensible `deadMetrics` list, verification command in the comment)
   - Surfaces: `_signoz-alerts.nix` (comment lines stripped) + `dashboards/*.json`. Failure messages explain mechanism + fix + incident pointer, per repo lint convention.
2. **post-deploy-check hardening** (`scripts/post-deploy-check.sh`):
   - `signoz-provision.service` Result assertion — closes the phantom-green where the rule-COUNT stays green off stale rules while the provisioner hard-failed (my own 18-min regression last session)
   - >24h-firing alert surfacing via `/api/v1/alerts` `startsAt` (WARN — ongoing incidents are legitimate; the point is visibility)
3. **pre-deploy-check §1b** — untracked-files warning under `modules/`+`platforms/` (the tracked-files trap that aborted a deploy last session; comments explain the concurrent-agent variant)
4. **dnsblockd wedge detection stack**:
   - `system_dnsblockd_metrics_fresh` textfile gauge (system-health collector; 5s curl probe of `:9090/metrics`, 200→1; emitted only when probed → Gatus presence check fails closed)
   - Gatus "DNS Blocker Stats API Fresh" (Infrastructure, anchored pat forms)
   - `GOTRACEBACK=all` in dns-blocker.nix service Environment
   - `scripts/dnsblockd-goroutine-dump.sh` runbook (wedge confirm → pre-kill snapshot → SIGQUIT → restart verify → journal extraction command)
5. **GPU dashboard**: duplicate "Temperature by Card" panel (identical query to "GPU Temperature") converted into "Temperature Sources (hwmon vs ClickHouse)" — two-series overlay that makes the fragile PCI-address-keyed hwmon chip label VISUALLY auditable (one series flatlining = that source broke; the alert survives via the OR)

## The nullglob discovery (new repo gotcha — the session's biggest find)

The first `signoz-query-lint` version used `strip="grep -v '^[[:space:]]*#'"` + unquoted `$strip "$file"`. **stdenv setup.sh enables `shopt -s nullglob`**: at expansion the single quotes are DATA (word-splitting never re-parses them), the pattern word contains glob chars, matches no file, and nullglob silently DELETES it → `grep -v <file>` with no pattern → every trap's grep reads EMPTY input → check passes while guarding nothing. `nix build .#checks...signoz-query-lint` exited 0 — a phantom green in the phantom-green detector itself.

Debugging path (reusable): extract the real buildCommand via `nix derivation show` → run identical text standalone (bash, no nullglob) → FAILS → instrument a `runCommand` probe (`printf '[%s]\n' $strip`) → words list shows the pattern word missing + `shopt nullglob: on`. Fix: command indirection via shell FUNCTIONS (`stream() { grep -v '...'; }`) — quotes parse at definition.

Negative-testing lesson (hit twice): fixtures at `/tmp` paths DON'T EXIST in the build sandbox → greps read nothing → the mutated "failing" test silently passes. The working pattern (committed in this report for reuse): `runCommand` over `builtins.replaceStrings`-mutated extracted script + `writeText`/`linkFarm` store fixtures + `--impure --expr 'import /tmp/....nix'`. Final matrix: mutated fixtures → 5 correct FAILs (comment correctly ignored, correct forms pass); clean tree → pass; both under REAL stdenv semantics.

## Verification

- `nix build .#checks.x86_64-linux.signoz-query-lint` — green on tree; mutation-tested through nix (above)
- `nix flake check --no-build` all-passed (incl. other session's staged inboxclean); toplevel evals
- Deploy via `nix run .#deploy` — one abort (writeShellApplication shellcheck SC2001 on a sed pipe → read-loop fix), one bootstrap abort (new metric absent pre-deploy → `KNOWN_NEW_METRICS` one-deploy window, retired after confirming live)
- Post-deploy: provisioner "OK 5 dashboards provisioned, exact desired set / 0 errors"; `system_dnsblockd_metrics_fresh 1` live; Gatus endpoint first cycle fail (metric not yet scraped) → second cycle green, exactly the fail-closed-then-heal design
- 8 post-deploy FAILs = pre-existing DAS-outage baseline (Immich/Bank-Sync 502 etc.) — unchanged, physical recovery pending
- Two-source temp query live-verified (both series at 39°C) BEFORE deploy

## Not done (with reasons)

- **Wedge-rule Discord delivery proof** — needs a controlled dnsblockd stats stop on the live resolver (root); declined autonomously: risk-to-value poor. The rule's QUERY was verified returning 0 during the live wedge (last session); delivery plumbing is shared with 25 proven rules.
- **emeet/niri gate live verification** — needs a graphical session (SSH-only right now).
- **DAS recovery / nixpkgs go_1_26 bump** — external/context, tracked in TODO_LIST.

## Flags for other sessions

- `website-deploy-monitor.service` sits in FAILED state (SigNoz critical firing since 14:43) — belongs to the session that shipped it (commit 6b6f0bbe). Not touched here.
- The auto-commit daemon will batch this work with the inboxclean session's staged tree — attribution per AGENTS.md concurrent-session rules.
