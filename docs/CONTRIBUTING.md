# Contributing to SystemNix

Cross-platform Nix configuration managing macOS (nix-darwin) and NixOS via a single flake.

## Quick Start

```bash
nix flake check --no-build   # Syntax check before committing
nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel  # Quick eval
nix run .#deploy             # Apply config (auto-detects platform via deploy.sh)
nix fmt                      # Auto-format all Nix files
scripts/health-check.sh      # System health check
nix run .#pre-deploy-check   # Catch boot-breaking issues before switch
```

**Note:** SystemNix used a `justfile` in the past. It has been removed; use the Nix flake apps and scripts above instead.

## Architecture

```
SystemNix/
├── flake.nix                    # Entry point (flake-parts)
├── modules/nixos/services/     # 35 NixOS service modules (flake-parts, auto-discovered)
├── modules/nixos/desktop/      # 6 desktop-environment modules (flake-parts, auto-discovered)
├── pkgs/                        # Custom package derivations + dms-plugins/
├── overlays/                    # Shared + Linux-only overlays
├── lib/                         # 10 helper files (harden, ports, systemd defaults, ...)
├── platforms/
│   ├── common/                  # Shared config (~80%), imported by both platforms
│   ├── darwin/                  # macOS (nix-darwin, user: larsartmann)
│   └── nixos/                   # NixOS (user: lars)
├── scripts/                     # 36 operational scripts (shell + Python)
└── docs/                        # Architecture decisions, status reports, runbooks
```

## Code Style

### Nix

- **2-space indentation** (enforced by alejandra)
- **Unused parameters**: Use `_:` when a function takes no arguments (satisfies both deadnix and statix)
- **Legitimate inputs**: Keep `{inputs, ...}:` when the module actually uses `inputs` (e.g., hermes.nix, signoz.nix)
- **Module options**: Every `mkOption` must have a `description` field
- **No inline secrets**: Use sops-nix for all sensitive values

### Go (custom packages in `pkgs/`)

- **Tab indentation** (per .editorconfig)
- Follow standard Go conventions

### General

- **LF line endings**, UTF-8, final newline enforced
- **Python**: 4-space indent
- **Shell scripts**: `set -euo pipefail`, use `lib.sh` helpers

## Pre-commit Hooks

Installed via `pre-commit install`. All hooks must pass before merge:

| Hook                  | Purpose                                                     |
| --------------------- | ----------------------------------------------------------- |
| commit-msg            | Reject commit subjects > 72 chars (house contract)          |
| gitleaks              | Detect committed secrets                                    |
| trailing-whitespace   | Clean trailing spaces                                       |
| deadnix               | Find dead/unused Nix code                                   |
| statix                | Detect Nix antipatterns (20+ rules)                         |
| alejandra             | Enforce Nix formatting                                      |
| nix-check             | Full `nix flake check --no-build`                           |
| flake-lock-validate   | Validate lockfile integrity                                 |
| shellcheck            | Shell script linting                                        |
| check-merge-conflicts | Catch unresolved markers                                    |
| protect-home-audit    | Warn when `harden {}` + `/home` lacks `ProtectHome = false` |

### Auto-fix Commands

```bash
nix fmt                              # Format all Nix files with alejandra
statix fix .                         # Auto-fix linting issues
deadnix --fail --no-lambda-pattern-names .  # Check for dead code
```

## Adding a New NixOS Service

Services are self-contained flake-parts modules in `modules/nixos/services/` (or `modules/nixos/desktop/` for desktop environment config):

1. Create `modules/nixos/services/<name>.nix` as a flake-parts module. The filename becomes the module name, so it must be unique across both `services/` and `desktop/`.
2. Import helpers via `import ../../../lib/default.nix lib` (required for standalone `nix flake check`).
3. Enable in `platforms/nixos/system/configuration.nix`.
4. Add a Caddy vHost in `modules/nixos/services/caddy.nix` if the service is web-facing.
5. Add a Gatus health check in `modules/nixos/services/gatus-config.nix`.
6. Add a Homepage tile in `modules/nixos/services/homepage.nix` if user-facing.
7. See `AGENTS.md` for the full service-adding checklist and non-obvious gotchas.

Module template:

```nix
_: {
  flake.nixosModules.my-service = {
    config,
    lib,
    pkgs,
    ...
  }:
  let
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure ports;
    cfg = config.services.my-service;
  in
  {
    options.services.my-service = {
      enable = lib.mkEnableOption "My Service";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port for the service";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services.my-service = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig =
          harden {
            MemoryMax = "512M";
          }
          // serviceDefaults {}
          // {
            ExecStart = "${pkgs.my-service}/bin/my-service --port ${toString cfg.port}";
          };
      };
    };
  };
}
```

## Shared Configuration

Place cross-platform config in `platforms/common/`. Both platforms import `common/home-base.nix`, which pulls in program modules from `common/programs/`.

Platform differences use:

```nix
if pkgs.stdenv.isLinux then "..." else "..."
```

Only override in platform dirs for things that genuinely differ.

## Verification

```bash
nix flake check --no-build                      # Fast syntax-only check (forces ALL assertions)
nix fmt --no-update-lock-file -- --ci           # Formatting gate (never plain `nix fmt` — re-locks inputs)
nix build .#checks.x86_64-linux.<test-name> --no-link --print-out-paths  # Build+run ONE negative test
nix run .#pre-deploy-check     # Pre-deploy validation
nix run .#post-deploy-check    # Post-deploy smoke test
scripts/health-check.sh        # System health check
scripts/verify-deployment.sh   # Deployment readiness validator
```

### Verification conventions (2026-09-15, window-closeout harvest)

**Deploy verdicts: read them from the source, never from memory (2026-09-28, SUPERB F14.3).** Every deploy's outcome lives in exactly two places: `journalctl -t systemnix-deploy-tail` (tagged lines, fastest) and `/var/log/systemnix-deploys/<timestamp>.log` (world-readable full log). Exit-code semantics: **0** = clean switch + smoke green; **3** = post-deploy smoke regression (`grep -E '❌|FAIL' <log>` names the legs); **12** = PRE-deploy pressure-gate refusal (the switch never ran — check `journalctl -u memory-emergency-guard` for the trip window before re-trying; a refused deploy is not a code regression). The smoke's per-service verdict contract is documented in `scripts/post-deploy-check.sh` (e.g. Browser History `/health` 503 = agent-freshness decay = WARN, not FAIL; FastFlowLM unreachable while the guard holds the socket down = FAIL by design until O2 policy lands).

**Store-GC eviction trap (2026-09-28 23:30, live):** a store GC evicted nested input source trees, and `nix flake check`/pre-commit/deploy now fail with `error: path '…-…-source' is not valid` — a DIFFERENT path per run (observed: the nixpkgs source behind the go build-support import, and the hermes `…-python-source` IFD output). This is NOT a code regression. `nix flake prefetch github:NixOS/nixpkgs/<locked-rev>` repairs the direct fetch but NOT the double-hash nested-input wrappers; the documented repair is re-locking the affected inputs with `--refresh` — which BUMPS floating inputs (nixpkgs is on `nixos-unstable`), so it is a dependency decision for the repo owner, not a mechanical fix. Whoever runs the next deploy: expect this error class first; name this note instead of re-diagnosing.

**The 3-step probe — every "verified" claim names its depth.** A claim that something works is one of exactly three levels; record which steps ran and never skip silently:

1. **Code exists** — the fix/config is present in the tracked tree.
2. **Regression test executed** — the check/VM test was BUILT AND RUN against the change in this session (a passing eval-cache hit on an unchanged store path is NOT execution — a negative-test derivation always has the same store path; hand-probe new cases via `extendModules` once).
3. **Deployed-generation parity** — the DEPLOYED system actually carries the change (`readlink /run/current-system`, `grep` the rendered unit/config, the live metric).

Write "VM-tested" only for step 2, "deployed + verified live" only for step 3. The 2026-09-15 Zone 6 closeout needed all three re-proven because the original run claimed step 2 from a parallel session's build without fresh evidence.

**Git-state claims carry the verification transcript at write time.** Any status-report/commit-message/TODO claim about git state (ancestry, reachability, rewrite landing, "rebase done") MUST include the commands AND their output from the same session — e.g. `git merge-base --is-ancestor <new> HEAD && echo OK`, `git log --all --grep=<text>`, `git for-each-ref | grep <old-sha>`. The 2026-09-14 "rewrite landed" claim (false) cost a full reviewer loop because it asserted an exit code instead of transcript evidence. Re-run all three checks after ANY later rebase onto origin history — an unpushed rewrite lineage is silently abandoned by rebasing.

**Cite REACHABLE SHAs; annotate dangling ones.** Cite `message + date + short-rev` where possible, and verify reachability before citing: `git merge-base --is-ancestor <sha> HEAD`. If you must cite a dangling SHA (pre-rewrite work), annotate the citation with its reachable counterpart (found via reflog: `git reflog | grep <subject-fragment>`) at first discovery, not at review time. Unpushed work on this box rewrites frequently (auto-commit daemon + rebases) — a bare dangling SHA in a task description forces every verification session to redo the archaeology.

**Re-dispatch verification protocol (2026-09-25, task-queue harvest).** When a dispatched queue item arrives already done (re-fire class — the queue re-fired 4 task IDs 7 times in the 2026-09-23/24 window), do NOT blindly redo and do NOT blindly skip. Execute four steps and record the outcome in the run's report:

1. **Verify footers + queue-surface closure** — the landed work's commits exist under the exact `Task-Queue-ID:` footer (`git log --format=%B`), and BOTH queue surfaces (`TODO_LIST.md` one-liner + the `docs/todo/<domain>.md` library entry) are `[x]` with no drift between them (house rule: the pair moves together).
2. **Spot-check ONE load-bearing claim of the landed work live** — re-run a command, re-read a file, re-verify a chain, independently of the prior run's report. Bookkeeping checks (footers, `[x]` marks) are not execution; without this step a MISDIAGNOSIS-class verdict ships unverified. A verification probe that cannot fail loudly is not a probe — never stderr-suppress one (`2>/dev/null`) and make its success condition explicit (2026-09-27 clause, after a re-fire ran `git log -1 <foreign-repo> 2>/dev/null`, produced nothing, and moved on).
3. **Sweep the Source report's §f for un-landed follow-ups** — a `[x]` mark covers only the item's own scope, never the Source report's follow-up obligations. The 2026-09-25 00-39 re-fire found 5 un-landed follow-ups behind a closed `[x]`; under the self-harvest convention (AGENTS.md "TODO System" Rules) a clean sweep is the expected state, and a dirty one is itself a finding — harvest it at authoring time, do not just report it. The verification record STATES the sweep's scope — item-derived obligations vs full-table (2026-09-27 clause; the 08-21 re-fire stated its item-scope boundary ad hoc — the next auditor must not re-litigate it).
4. **Land SOMETHING footer-bearing** — a verification-only dispatch still commits with the `Task-Queue-ID:` footer (a `docs/status/` report, or re-run evidence appended to the touched doc), so the dispatch is attributable in `git log` and the queue's footer-based completion derivation sees it.

Steps 2-3 separate a useful re-fire from dead queue churn. If every step is clean, the original run's verdict STANDS — record "verified, verdict unchanged" instead of re-deriving it. Cross-project variant (the protocol generalizes beyond this repo): crush-config `references/lessons.md`.

Foreign-repo landings annotate closure narratives as SOURCE-LEVEL delivery (2026-09-27 clause): work landed in a consumed repo (crush-config, library repos) is delivered when committed THERE — the installed copy (read-only nix-store symlinks rendered by HM activation) rides the next input bump + owner deploy. Never write "ships to every host" for a source-only landing: re-fire-2 proved the gap live (lesson source-landed crush-config `8fbc677` while the SystemNix lock still pinned `031c7c48`; the installed `~/.config/crush/references/lessons.md` had zero `re-dispatch` matches).

**Status-report filenames are MEASURED, never guessed (2026-09-27 clause, fire-3 harvest).** Derive the filename timestamp by running `date +%Y-%m-%d_%H-%M` immediately before creating the file — never reconstruct it from context or memory (fire-3 shipped `2026-09-27_09-12_…` while its commit landed 08:56:06, a 16-minute lie in the timestamped audit trail). Before creating ANY `docs/status/` report, list the existing reports for the task ID first (`ls docs/status/ | grep 'task-<ID>'`): the write tool silently overwrites, so a same-name report from a parallel session would be clobbered with zero warning. On a collision, bump the minutes — never overwrite. Convention, not tooling — a guard script was considered and deliberately skipped as overkill.

**Verify-gate triage runbook (2026-09-28, task-queue harvest).** A verify failure landing across MULTIPLE unrelated tasks is a gate problem, not a task problem — probe in order, and only suspect the dispatched work after every environmental step is clean:

1. **`/run/binfmt` exists** — `ls /run/binfmt`; if missing, every sandboxed nix build dies `getting attributes of path "/run/binfmt"` (the 2026-09-24 boot-cycle class). Heal: `sudo systemd-tmpfiles --create --remove --exclude-prefix=/dev`, and probe whether the DURABLE fix has landed (boot ordering + `boot.binfmt.preferStaticEmulators`) before retrying — a boot-ephemeral heal re-dies at the next reboot.
2. **Clean-HEAD flake check** — re-run the failing gate at a clean worktree of pre-change HEAD (`git worktree add /tmp/baseline <pre-change-rev>`) to separate PRE-EXISTING (gate-dead, not the task's fault) from INTRODUCED (counts against the task).
3. **nix-daemon restart** — the daemon's in-memory fetch cache can serve STALE source trees for an already-locked rev (`sudo systemctl restart nix-daemon`; the stale-fetch class).
4. **IO pressure vs the verify budget** — the queue's verify gate budget is ~30 min (measured 2026-09-25); a cold eval cache under an IO storm exceeds it. Check `node_psi_io_some_avg60` / disk busy and retry from a warm cache when pressure drains. Note gate-slow classification is deadline-killed-with-progress (exit 0, evaluation advancing) — retry, not task failure.

Only if all four probe clean does the failure count as INTRODUCED (the only shape that burns task attempts — see the classification row in `docs/todo/pipeline.md`).

**Heal-attribution breadcrumb convention (2026-09-28, task queue).** Any MANUAL system heal — `systemd-tmpfiles --create`, a `nix-daemon` restart, a manual socket/service start, any other hand-run recovery — leaves ONE breadcrumb so forensics can attribute the recovery: `bash scripts/heal-breadcrumb.sh "<what was healed> <how>"` (one `logger -t systemnix-heal` journal line + one stamp in `~/.local/state/systemnix-heals.log`; works unprivileged; never put secret VALUES in the text). Deploys already breadcrumb implicitly (profile trail + deploy.sh journal lines) and module-managed heals are journaled by their own units — this covers only the hand-run gap. Probe: `journalctl -t systemnix-heal`. Motivation: the 2026-09-25 05:32 `/run/binfmt` heal was verified real but its actor was UNKNOWABLE (owner manual heal vs parallel session vs nix-daemon-restart side effect), hanging two task attempts and the gate-row annotations on an unattributed recovery.

## Eval-Time Guards (audit modules)

Most documented incident classes are ENFORCED at eval time — `nix flake check`
fails with a fix-it message instead of letting the bug reach a host. Current
guards (all in `modules/nixos/services/`, all with negative tests in `tests/`):

| Guard                                                                                                                                  | Catches                                                                                                                             | Escape hatch                              |
| -------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| `systemd-shape-audit`                                                                                                                  | oneshot+invalid Restart; timer+Restart race; PathExists path units; `$HOME` in user-unit Exec lines                                 | `allowTimerRestart`                       |
| `port-registry-audit`                                                                                                                  | port literals in unit Exec*/Environment outside `lib/ports.nix`                                                                     | `allowPorts`                              |
| `mount-gating-audit`                                                                                                                   | ReadWritePaths under /mnt/ without RequiresMountsFor/ConditionPathIsMountPoint (226/NAMESPACE + shadow-dir contamination)           | `allowUnits`                              |
| `gatus-coverage-audit`                                                                                                                 | in-use registered ports never probed by gatus; loopback gatus URLs with unregistered ports                                          | `allowPorts`                              |
| `deploy-restart-audit`                                                                                                                 | converger oneshots (*-storage-dir/-provision/-setup/…) and oneshot+RemainAfterExit+restartTriggers missing from `scripts/deploy.sh` | `allowUnits` (upstream defaults built in) |
| `gate-timeout-audit`                                                                                                                   | gate units without the TimeoutStartSec floor                                                                                        | —                                         |
| `otel-endpoint-audit`                                                                                                                  | OTLP endpoint contract violations                                                                                                   | `expectations`                            |
| `sops-key-audit`                                                                                                                       | sops secrets declared but absent from encrypted files                                                                               | —                                         |
| `dynamic-user-audit`                                                                                                                   | DynamicUser services owning sops secrets directly                                                                                   | —                                         |
| `timeout-audit` / `start-limit-audit` / `udev-block-letter-audit` / `session-boot-audit` / `chown-vs-bind-audit` / `tmp-cleaner-audit` | see module headers                                                                                                                  | various                                   |

Plus the `harden {}` lifecycle-key THROW in `lib/systemd.nix`, and static
scanners: `scripts/audit-serviceconfig-merge.sh` (pre-commit + CI),
`audit-shell-nullglob.sh`, `audit-textfile-tmp.sh`, `check-templ-committed.sh`.

### Adding a new guard

1. **Probe the live config FIRST** — write the probe as `/tmp/probe-*.nix`
   (NEVER repo root: the auto-commit daemon picks up untracked files) and run
   `nix eval --impure --json --expr 'builtins.fromJSON (import /tmp/probe-*.nix)'`
   against `builtins.getFlake (toString /home/lars/projects/SystemNix)`. Size
   the false-positive risk before writing the assertion.
2. **Module shape** — a bare attrset (NOT a lambda), auto-discovered by
   filename into `flake.nixosModules.<name>` and imported into every NixOS
   host: `{ flake.nixosModules.<name> = { config, lib, ... }: { options… ; config.assertions = […]; }; }`.
   Assert with a message that names offenders AND the fix, including the
   escape-hatch option.
3. **Negative test** — `tests/test-<name>.nix` following
   `test-mount-gating-audit.nix`: `nixosSystem` with the audit module +
   fixtures, filter `!a.assertion && hasPrefix "<guard>:" a.message` (minimal
   evals carry 2 unrelated base assertion failures), list cases, pass/fail
   derivation. Wire it into `tests/default.nix`.
4. **`git add` every new file IMMEDIATELY** — flakes see only tracked files;
   an untracked module fails every evo-x2 eval with "attribute missing".
5. **Verify**: `nix flake check --no-build`, build the check derivation,
   `nix fmt --no-update-lock-file -- --ci`, and HAND-PROBE one new case via
   `extendModules` on evo-x2 — a passing negative-test derivation always has
   the same store path (pass/fail is chosen at eval), so an identical output
   path cannot distinguish "new cases pass" from "stale eval cache".
6. **Set justified allowlists ADJACENT to the offending definition site**
   (e.g. `fastflowlm.nix` sets its own `gatus-coverage-audit.allowPorts`),
   with a comment explaining WHY — not centrally.

## Key Patterns to Know

### Infinite Recursion Avoidance

Never wrap config in `lib.mkIf config.services.<nixpkg-option>.enable` AND set attributes under `services.<nixpkg-option>` inside the same `mkIf`. Create a separate custom option instead.

### Systemd Hardening

Use the shared `lib/systemd.nix` harden function for consistent security. Lifecycle keys (`Exec*`, `Type`, `RemainAfterExit`, `Restart`) inside `harden {}`/`hardenUser {}` THROW at eval — merge them via `lib.mkMerge`, never `//` (shallow merge discards `mkDefault`/`mkForce` priority; rejected by `scripts/audit-serviceconfig-merge.sh`):

```nix
serviceConfig =
  lib.mkMerge [
    (harden {
      PrivateTmp = true;
      MemoryMax = "512M";
    })
    (serviceDefaults {})
  ];
```

### Secrets

All secrets managed via sops-nix with age encryption. See `modules/nixos/services/sops.nix` and `AGENTS.md` for the Sops + Age workflow.

### Native OIDC vs Forward-Auth

SystemNix has two SSO layers:

- **Layer 1 — Native OIDC**: Apps integrate directly with Pocket ID (Forgejo, Immich, Gatus). Caddy uses plain `reverse_proxy`.
- **Layer 2 — oauth2-proxy forward-auth**: Apps without native auth; Caddy uses `protectedVHost`.

Never put a native-OIDC service behind `protectedVHost` — it causes a double-auth redirect loop. See `AGENTS.md` for the full SSO architecture.

## Documentation

When you learn something non-obvious, update the relevant doc immediately:

- `AGENTS.md` — AI assistant guide, conventions, gotchas
- `FEATURES.md` — Feature inventory and status
- `ROADMAP.md` — Long-term direction
- `TODO_LIST.md` — Dispatch queue: agent-actionable open work (one-liners linking into the domain libraries)
- `docs/todo/*.md` — Domain libraries: every open item (incl. blocked/watch/decision), tagged by lifecycle — see AGENTS.md → "TODO System"
- `docs/adr/` or `docs/architecture/` — Architecture decisions

See `AGENTS.md` → "Project Documentation Files" for the full ownership table.
