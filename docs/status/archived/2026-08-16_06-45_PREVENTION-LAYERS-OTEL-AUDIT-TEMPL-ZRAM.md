# Session Report: Prevention-Layer Batch (OTel Endpoint Audit, templ-Committed Enforcement, ZRAM Fill Alert)

**Session:** 2026-08-16, ~04:00–06:45 CEST
**Scope:** The 3-item TODO batch from the 16-20 docs-health report (§f.23, §f.24, §f.26) + user-directed go-nix-helpers escalation of the templ check
**Outcome:** All 3 items code-complete and verified; 1 deployment gap (phantom-metric allowlist) caught in self-review and fixed; upstream enforcement committed but NOT yet rolled out via lock bumps; nothing deployed.

---

## What was built

### 1. Eval-time OTel endpoint audit — `modules/nixos/services/otel-endpoint-audit.nix` (NEW)

Catches the browser-history startup-hang class (`parse "127.0.0.1:4317": first path segment in URL cannot contain colon`, 2026-08-14 outage) at `nix flake check` time.

- Scans ALL of: `systemd.services.<name>.environment` (attrset form), `.serviceConfig.Environment` (K=V list form), `virtualisation.oci-containers.containers.<name>.environment` — auto-discovers, no hardcoded service list
- Matches `OTEL_EXPORTER_OTLP_ENDPOINT` + `_TRACES/_METRICS/_LOGS_ENDPOINT` variants
- **Generic rules** (apply to unregistered services too): gRPC port 4317 ⇒ `http://` scheme REQUIRED (the incident class); scheme ∈ {none, http} — https rejected (plaintext localhost receiver); host ∈ {localhost, 127.0.0.1, host.docker.internal} (traces must not leave the machine); port ∈ {signoz-otlp-grpc, signoz-otlp-http} derived from `lib/ports.nix`; no path components
- **`expectations` registry** (per-service enum): `grpc-url` (Go otlptracegrpc / Rust tonic — tonic and URL-parsing SDKs need scheme), `http-url` (Python/Node/Docker), `http-host-port` (Go otlptracehttp — scheme corrupts its self-built URL). All 9 current OTel services registered: browser-history (grpc-url), monitor365-server (grpc-url), hermes (http-url), discordsync/crush-daily/overview/PMA/renamer×2 (http-host-port)
- Assertions carry the full convention text + incident reference in the message

**Verification:** 8 distinct bad-endpoint classes caught in a minimal eval (bad-grpc, https, bad-port, remote-host, path-suffix, scheme-on-Go-http via serviceConfig.Environment form, schemeless `_TRACES_ENDPOINT` variant, container env with wrong expectation); good Go/gRPC endpoints pass; live evo-x2 config → zero assertions fired.

### 2. `*_templ.go` committed-enforcement — three layers

The AGENTS.md gotcha (untracked templ-generated file → Nix build fails `undefined: someFragment`) went from documentation-only to enforced:

- **Layer 1 (SystemNix):** `scripts/check-templ-committed.sh` — git-index based (`git ls-files`), works in any repo, catches a staged `.templ` without staged `*_templ.go`. Shellcheck-clean. Negative+positive tested in a temp repo. Wired into `.githooks/pre-commit` (fast guard, before gitleaks) and `.github/workflows/nix-check.yml` (new CI step)
- **Layer 2 (upstream, user-directed):** go-nix-helpers `modules/go-standard.nix` — `checks.templ-committed` eval-time `builtins.throw` in EVERY go-standard consumer's `nix flake check`. Mechanism: the flake source contains only TRACKED files, so a recursive `readDir` walk for `.templ` + `pathExists` sibling check sees exactly the committed set. Zero cost for repos without templ files. 3 new module tests (no-templ → no check emitted; committed pair → no check; orphan `.templ` → throws). 117/117 module tests pass. Committed by the auto-git daemon as **`eca72e1`** with CHANGELOG entry
- **Layer 3:** Both CHANGELOGs + AGENTS.md document the layering

### 3. ZRAM fill monitoring + Discord alert

zram is the ONLY swap (28 GiB, no disk fallback) — when full, the kernel falls back to page-cache reclaim = the documented BTRFS I/O storm precursor. Nothing watched it.

- `system-health` collector: reads `/sys/block/zram0/mm_stat` + `disksize`; emits `system_zram_swap_fill_percent` (orig_data_size/disksize), `system_zram_swap_orig_data_bytes`, `system_zram_swap_disksize_bytes`, `system_zram_mem_used_bytes`, and pre-computed `system_zram_fill_over_threshold` (≥90% — Gatus `pat()` cannot do numeric comparison)
- **Fail-closed design** (the nvme phantom-zero lesson): metrics are ONLY emitted when `/sys` is readable — an absent metric makes the Gatus condition fail, never a phantom green from zero defaults
- New `collectZram` option, auto-disabled on hosts without `zramSwap` (same `options ?` pattern as the other collectors)
- Gatus "ZRAM Fill" check: 2m interval (matches collector cadence), conditions = liveness `[STATUS]` + fill-percent presence + `over_threshold 0`, Discord alert with the page-cache-reclaim context and remediation

**Verification:** logic shellchecked + executed against the LIVE `/sys/block/zram0/mm_stat` (fill 19.9% → flag 0; simulated 95% → flag 1). Full evo-x2 toplevel build passed (`writeShellApplication` runs its built-in shellcheck), `nix flake check --no-build` passed, deadnix/statix clean.

---

## a) FULLY DONE

1. `otel-endpoint-audit.nix` module — written, negative-tested (8 classes), live-config-verified (0 false positives), `nix flake check --no-build` green
2. `scripts/check-templ-committed.sh` + pre-commit wiring + CI step — written, shellcheck-clean, temp-repo negative/positive tested, live run on SystemNix (0 templ files → pass)
3. go-nix-helpers `checks.templ-committed` + 3 module tests + CHANGELOG — committed upstream (`eca72e1`), 117/117 tests, `nix flake check --no-build` green
4. ZRAM metrics + Gatus check — code complete, toplevel builds, live-logic verified
5. Pre-deploy phantom-metric gap — `KNOWN_NEW_METRICS` populated with the 5 zram metrics (deploy-friction fix, pattern-conformant; concurrent session's edits untouched)
6. Docs: TODO_LIST §f.23/§f.24/§f.26 closed with DONE annotations; SystemNix CHANGELOG (3 Added entries); go-nix-helpers CHANGELOG (1 Added entry); AGENTS.md updated at 5 touchpoints (procedure step 10, prevention-layers table ×2, zram gotcha, templ gotcha enforcement note)
7. `/tmp` test leftovers cleaned; all changed files pass repo linters (deadnix, statix, shellcheck, alejandra)

## b) PARTIALLY DONE

1. **Upstream templ enforcement NOT LIVE for consumers** — SystemNix's flake.lock pins go-nix-helpers at `e6d392b9`, one commit BEHIND `eca72e1`. Needs `nix flake lock --update-input go-nix-helpers` here, and each of the ~20 LarsArtmann go-standard consumers needs its own lock bump before `checks.templ-committed` fires there. Not done — release/rollout strategy is a user decision (see questions)
2. ~~**Nothing deployed**~~ **resolved** — deployed across the 2026-08-16 deploys; AGENTS.md records live verification ("Live-verified: 19.9% fill → 0, simulated 95% → 1") and the OTel audit + templ checks are active (pre-commit + CI).
3. **Audit registry maintenance gap** — a NEW service setting `OTEL_EXPORTER_OTLP_ENDPOINT` without an `expectations` entry only gets generic rules. The Go-http-with-scheme class (corrupts otlptracehttp's self-built URL) is ONLY caught when registered. An eval-time "service sets OTel var but is not in expectations" warning would close this — not implemented

## c) NOT STARTED

1. Deploy (`nix run .#deploy`) — blocked on sudo/decision
2. Permanent test for the audit module — the negative eval test lived in `/tmp` and is now trashed; nothing committed to `tests/`
3. CI negative-path fixture for `check-templ-committed.sh` — CI only exercises the happy path (repo has 0 templ files)
4. manifest OTel env scannability — env vars are baked into a generated docker-compose file, invisible to the audit (documented in-module as a limitation; no fix attempted)
5. Consumer-repo lock sweep for go-nix-helpers

## d) TOTALLY FUCKED UP (all caught + fixed in-session)

1. **`walkTempl` v1** — used `lib.concatMap` over `builtins.readDir` output; readDir returns an ATTRSET, not a list → `expected a list but found a set` build failure. Caught immediately by the module test, fixed with `mapAttrsToList` + `concatLists`
2. **Pre-commit hook v1** — invoked the check script twice on failure (once discarded, once for output). Cosmetic waste; replaced with a single captured invocation
3. **MISSED the pre-deploy phantom-metric interaction until this self-review** — I cited the prevention-layers table (which documents "phantom metrics" in Pre-deploy) in my own AGENTS.md edits and STILL forgot that my new Gatus conditions reference metrics that don't exist on the RUNNING system. Next deploy would have flagged all 5 `system_zram_*` metrics as phantom (fail lines + missing-metrics warning). Fixed by populating `KNOWN_NEW_METRICS` per the documented pattern. This was the biggest miss of the session — found by reflection, not by process
4. Left `/tmp/otel-audit-test.nix` behind after "finishing" verification — cleaned now
5. First lock-rev lookup (`rg` pattern) failed; recovered via a python read of flake.lock — no user impact, but sloppy

## e) WHAT WE SHOULD IMPROVE (process lessons)

1. **Read the downstream consumers of a new check BEFORE declaring it done.** The phantom-metric miss happened because I treated pre-deploy-check as out of scope. A new Gatus `pat()` metric is a contract with THREE consumers: gatus, pre-deploy-check, and post-deploy-check — verify against all three in the same session
2. **Commit verification artifacts as tests.** The 8-class negative eval for the audit module is exactly the kind of regression net `tests/` exists for; leaving it in /tmp means the next person re-derives it from scratch
3. **Lock-bump immediately after upstream commits.** The go-nix-helpers commit landed at 06:35 via the daemon; the SystemNix lock bump should have been the very next action, not an open item
4. **Concurrent-session coordination is word-of-mouth.** Another session is editing signoz/pre-deploy/test-ksm + HTML docs in the same tree. My edits are disjoint (verified per-file diffs), but nothing enforces that — worth a note in the session-report convention, not just luck
5. **Fail-closed metric design is now the house style** (gatus sqlite, nvme keys, zram) — the audit module's expectations registry is the one place still relying on humans keeping a list current; consider generating the warning (b.3) as the standard closing move for all registry-style guards

## f) NEXT TASKS (session-derived, prioritized)

1. Bump SystemNix go-nix-helpers lock: `nix flake lock --update-input go-nix-helpers` (picks up `eca72e1`)
2. Deploy (`nix run .#deploy`), then verify: `system_zram_swap_fill_percent` in `/metrics`, Gatus "ZRAM Fill" green, collector journal clean
3. After deploy verification: REMOVE the 5 `system_zram_*` entries from `KNOWN_NEW_METRICS` (allowlist entries mask real regressions once live — documented rule)
4. Roll out go-nix-helpers `eca72e1` across the ~20 go-standard consumer repos (per-repo `nix flake lock --update-input go-nix-helpers` — scriptable sweep)
5. Add eval-time warning to otel-endpoint-audit: service sets an OTel endpoint var but is absent from `expectations` (the b.3 gap)
6. Commit the 8-class negative eval as `tests/otel-endpoint-audit.nix` (or a flake check like `gatus-pattern-lint`)
7. CI: temp-repo fixture test exercising `check-templ-committed.sh`'s failure path
8. Teach the audit to read generated compose files (manifest) OR migrate manifest env to a scannable location — closes the documented blind spot
9. Decide the go-nix-helpers release vehicle: tag v1.0.0 (CHANGELOG says templ-committed ships in first tagged release) vs ref=master drift
10. expectations registry: consider moving per-service entries INTO each service module (`services.X.otelExpectation`) instead of the central attrset — colocated with the env wiring it guards
11. ZRAM: add fill-rate (slope) alerting — a fast-climbing 70% is worse than a stable 85%; mm_stat deltas are already collectable
12. ZRAM ADR (TODO §f.22) — now has live metrics to cite; write `docs/adr/` with the fallback strategy
13. Sweep expectations for dead entries: monitor365-server is `enable = false` in configuration.nix (discovered during research) — registry entries reference services that don't exist on the live system
14. Verify post-deploy-check.sh doesn't also need zram awareness (it checks functional outcomes; the collector is a timer, likely no HTTP surface — confirm)
15. Consider `system_zram_same_pages_filled`/`huge_pages` mm_stat fields for the collector (dedup visibility) — only if a use case appears; YAGNI until then
16. The concurrent session's pre-deploy-check edit and mine now coexist — sanity-read the full script once before the next deploy to be sure the two diffs compose as intended
17. Generic: add a "new Gatus check ⇒ update KNOWN_NEW_METRICS" line to AGENTS.md procedure step 9 (the rule exists in the script comments but not in the procedure where the check is written)

## g) QUESTIONS (cannot figure out myself)

1. **Deploy now or batch?** The audit module + zram metrics + Gatus check + lock bump want a deploy (needs sudo). Bundle with the concurrent session's signoz work in one deploy, or run `nix run .#deploy` independently and let their work ride along if committed?
2. **go-nix-helpers rollout strategy:** sweep all ~20 consumer repos' locks myself now (ref=master drift), or hold until you tag a v1.0.0 release and bump consumers against the tag? (Affects reproducibility vs. speed of enforcement.)
3. **Audit registry architecture:** keep the central `expectations` attrset in otel-endpoint-audit.nix (single place to see the fleet, but drifts from service modules), or refactor to per-module declarations colocated with each service's env wiring (self-maintaining, but scattered)? I lean central-with-warning (f.5) — your call.

---

**Files touched this session (SystemNix):** `modules/nixos/services/otel-endpoint-audit.nix` (new), `system-health.nix`, `gatus-config.nix`, `scripts/check-templ-committed.sh` (new), `scripts/pre-deploy-check.sh`, `.githooks/pre-commit`, `.github/workflows/nix-check.yml`, `AGENTS.md`, `CHANGELOG.md`, `TODO_LIST.md`
**Files touched (go-nix-helpers):** `modules/go-standard.nix`, `test-module.nix`, `CHANGELOG.md` (committed as `eca72e1`)
**Untouched concurrent-session files:** `_signoz-alerts.nix`, `_signoz-scripts.nix`, `signoz.nix`, `test-ksm.nix`, HTML status docs

---

## Resolution (2026-08-17, docs-health pass)

b.2 resolved (struck above). b.1 → TODO_LIST Priority 6 (go-nix-helpers `eca72e1` consumer rollout + release-vehicle decision). b.3 → untracked (expectations-registry warning idea). c-section: c.1 resolved (deployed); c.2 → P3 (CI negative-path fixture — folded conceptually with the templ CI item); c.3 untracked (manifest compose scannability — documented limitation); c.4 → covered by the b.1 rollout item; c.5 → part of b.1. f-list: f.1 → the b.1 rollout item; f.2 resolved (deploy + live verification); f.3 resolved — TODO_LIST's allowlist rule applies; the `system_zram_*` entries were retired once metrics confirmed live (pre-deploy allowlist pruned per CHANGELOG); f.4 → b.1; f.5 untracked (registry warning); f.6 → P3 (commit the negative eval as a check); f.7 → P3-adjacent (CI fixture); f.8 untracked (manifest blind spot); f.9 → folded into b.1 (release vehicle); f.10 untracked (per-module expectations); f.11 untracked (zram slope alerting); f.12 → TODO_LIST zram ADR item; f.13 → folded into monitor365 G7; f.14 resolved (post-deploy-check needs no zram HTTP surface — confirmed collector-only); f.15 YAGNI (declined by the report itself); f.16 resolved (subsequent deploys composed both diffs cleanly); f.17 untracked (AGENTS procedure line). g.1 resolved (deployed); g.2 → the b.1 decision; g.3 untracked (registry architecture). Archived as resolution-complete.
