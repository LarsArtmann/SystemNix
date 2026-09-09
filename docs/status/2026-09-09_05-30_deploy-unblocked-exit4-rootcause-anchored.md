# 2026-09-09 05:30 — Deploy unblocked + exit-4 root cause + ANCHORED at system-762

Session arc: user ran `nix run .#deploy` (the P0 re-anchor from the 04:35 handoff) and it failed at the app BUILD (shellcheck). Three stacked root causes were peeled in sequence; the third was the true cause of the ENTIRE un-anchored-generation saga. Deploy is now clean and the profile is anchored.

## The chain (each fix surfaced the next blocker)

| # | Blocker | Root cause | Fix |
|---|---------|-----------|-----|
| 1 | `nix run .#deploy` dies at app build: SC2001 `echo "$manual_tq" \| sed` (deploy.sh:197) | Parallel session commit `a62b830b` (manual tq pool guard) shipped a sed-pipe into the shellcheck-gated `writeShellApplication` | `while IFS= read -r` loop (exact sed semantics for multi-line pgrep output) |
| 2 | Pre-deploy §10 BLOCKED: `cv_autoapply_passes`/`cv_autoapply_pass_errors` ABSENT (phantom metric) | New "CV Auto-Apply Metrics" gatus check references gauges the RUNNING cv-server predates. Locked cv rev `43b3f93` verifiably HAS them (`git grep` at rev) → transition false-block. Deeper: the gate's unauthenticated probe gets **401** from cv `/metrics` (X-API-Key gated) — it can NEVER see them | `KNOWN_NEW_METRICS` loan for the run, then durable: new `CV_ENDPOINT_UP` classifier branch in `scripts/lib/metrics-gate.sh` (monitor365/discordsync down-endpoint doctrine) + fixture F in `test-pre-deploy-metrics.sh`; loan entries retired after authenticated probe confirmed all five gauges live (don't forget `--compressed` — the metrics body is gzip) |
| 3 | Activation **exit 4 → "No new profile generation (system-761 unchanged)"** — the SAME signature as Sep-8 04:25 | **snapshots.nix churn (auto-commit `9f2008fe`, Sep-8) changed the `btrfs-verify-pool-backups` unit file → stc RESTARTED it at every activation → the unit runs the owner-decided chronic FAIL (no received /data backups since 2026-08-20, the /data EIO stance) → exit 4 → profile bump skipped.** A chronically-failing unit + any unit-file churn = every deploy un-anchored. This ALONE explains Sep-8 AND the 05:03/05:15 attempts | `/data` branch downgraded to WARN-only in the verify script (mount + device-stats + ROOT backup freshness still hard-FAIL; the /data gap keeps triple independent visibility: btrbk-data OnFailure, backup-coordination, Gatus backup_all_healthy). Restore hard-FAIL after the /data corruption repair (noted in the unit comment + TODO_LIST) |
| 3b | Attempt 2 also exit-4'd on `overview.service` (masked by #3's whack-a-mole) | overview (User=overview) exit-69 crash-loop: "no daemon at unix:///run/project-discovery/daemon.sock" — daemon socket was **0600 lars:users** because the LOCKED project-discovery-daemon rev `4f6e3c8` predates `PROJECT_DISCOVERY_SOCKET_MODE` (config asked 0666, binary ignored it). The wrapper's `+`-root ExecStartPre gate PASSED (root bypasses DAC) and masked the EACCES | `nix flake lock --update-input project-discovery-daemon` → `1a31c1a` (socket-mode verified at rev via git grep; upstream package builds hermetically). Daemon restarted 05:16, socket now `srw-rw-rw-` (0666), overview **200** + smoke PASS |

## Result — ANCHORED

```
current-system: pgvbfp20pkynz0akzxn4x7g3p4n7mw93-nixos-system-evo-x2-26.11.20260905.c043004
profile:        system-762-link → pgvbfp20…   (NEW generation — was stuck at 761)
boot default:   nixos-04e61773…  → pgvbfp20 (762)
menu:           nixos-04e61773… (762, default) + nixos-03171fd6… (761/zkaacn2a, renamed entry) + nixos-6ecddc08… (prior-era g9ghy625)
ladder pins:    /nix/var/nix/gcroots/boot-rollback-ladder/ intact (zkaacn2a + g9ghy625)
gcroots/profiles: resolves to /nix/var/nix/profiles (calamares fix held)
```

**A reboot now boots the Sep-9 build.** The pre-flip entry name `nixos-efc4051e…` was REPLACED by `nixos-03171fd6…` (same system `zkaacn2a`, regenerated entry hash) — the menu rung is equivalent, the gcroot pin is unchanged.

## Smoke verdict (attempt 3)

PASS: all core services incl. **Overview 200** (healed), CV 3/3 (binary `43b3f93`, pipeline-store healthy). FAIL (all pre-existing machine state, none regressions from this deploy):
- FastFlowLM :52625 — the EADDRINUSE corpse wedge; ONLY the reboot releases it
- llama.cpp :8848/:8849 → 503 — the amdxdna D-state corpse class; reboot clears
- Bank-Sync sync_errors_total > 0 — pre-dates this session (journal-dig belongs to the 9-chronics P1)

## Files changed (all staged; daemon commits)

- `scripts/deploy.sh` — SC2001 fix (while-read indent loop)
- `scripts/pre-deploy-check.sh` — CV_ENDPOINT_UP wiring; KNOWN_NEW_METRICS emptied (dstate retired as confirmed-live, cv pair superseded by the branch)
- `scripts/lib/metrics-gate.sh` — CV auth-gated-endpoint branch
- `scripts/test-pre-deploy-metrics.sh` — fixture F
- `platforms/nixos/system/snapshots.nix` — verify unit /data branch WARN-only
- `flake.lock` — project-discovery-daemon `4f6e3c8` → `1a31c1a`
- `AGENTS.md` — 2 new gotchas (chronic-FAIL + unit-file churn → exit-4; `+`-gate masks DAC denials)
- `TODO_LIST.md` — Phase 1 blocker marked RESOLVED + ANCHORED with the chain

## Open (unchanged decisions for the user)

1. Confirming reboot (now safe: anchored; clears flm + llama corpses) + post-boot verify + remove `loader.conf.bak-stuckboot` → starts the 3-day soak clock.
2. p1 ESP mirror fate (keep static / automate / drop) — still unanswered from 04:35.
3. Restore `btrfs-verify-pool-backups` /data hard-FAIL after the /data corruption repair (owner stance note in unit + TODO_LIST).
