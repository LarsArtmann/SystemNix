# Hermes Hardening — Follow-up Session (Gates + Follow-ups)

**Date:** 2026-08-20 ~12:00–21:00 CEST · **Trigger:** user re-issued "execute everything" · **Machine:** evo-x2 · **Base:** clean @ `7c15ed73`

---

## Gates answered (via `question` tool — fixing the previous session's malformed call)

| Gate | Decision | Consequence |
|------|----------|-------------|
| **Q1** private-repo creds | **Yes — read-only fine-grained PAT** | T14 SCAFFOLDED end-to-end, inert until the user pastes the token |
| **Q2** workspace disk layout | **Defer** | T7 SKIPPED; workspace stays on snapshot-pinned `@`; revisit trigger recorded in TODO_LIST (root >90% or clones >20G) |
| **Q3** write-back policy | **Permanently read-only** | Locked into runbook + module option doc; no push creds ever |

## Shipped this session

| What | Where | Verification |
|------|-------|--------------|
| **T14 scaffolding** (read-only GitHub token): sops `hermes-github-token.yaml` (placeholder, public-key-created — `hermes.yaml` needs the private key, so a separate file was required); `HERMES_GITHUB_READ_TOKEN` in `hermes-env`; `hermes-git-credential` store helper (answers GitHub HTTPS queries only for real `github_pat_/ghp_/gho_` tokens — placeholder is fully inert; store/erase no-ops so git never persists it); `[credential "https://github.com"]` in the safe-directory gitconfig; `hermes-github-verify.service` auth canary (boot + every deploy, DNS-gated, skip-cleanly on placeholder, unit-fails on a dead real token) | `hermes.nix`, `sops.nix` | flake check green; VM test asserts skip-path + unit-absent on bare node; **LIVE**: canary journal `read token not set (placeholder) — skipping` ×6 boots/restarts |
| **LSP exec-bit fix (f.23 — turned out to be OUR bug)**: the perms walk's `chmod 0660 -type f` stripped every executable under stateDir — agent LSPs dead with `PermissionError` since 2026-08-16. Walk is now exec-preserving (`chmod u=rwX,g=rwX,o=`); `hermes-lsp-bin-heal` ExecStartPre restores already-stripped `lsp/bin` + `node_modules/.bin` binaries | `hermes.nix` | VM test (exec preserved, plain files still 0660, heal idempotent); **LIVE: `restored execute bit on 6 LSP binaries` at 20:35:47 — agent pyright/bash-language-server fixed** |
| **Workspace doc v2 + marker versioning (f.24)**: line-1 `<!-- systemnix-workspace-doc: vN -->`; missing → install, older marker → upgrade, same/agent-rewritten → untouched. Marker-less files byte-compare against a pinned v1 copy: unmodified v1 upgrades, agent-modified stays. v2 content fixes the WRONG "/tmp is private and ephemeral" line (write_file is DENIED outside /home/hermes — teach `./scratch/`) + documents private-repo cloning + never-push | `hermes.nix` | VM test: marker upgrade, agent-edit survival, marker-less migration both branches; **LIVE: `upgraded marker-less AGENTS.md (was unmodified v1) -> v2` at 20:43:48** |
| **Restart-churn monitoring (e.7)**: `system_service_restart_churn{service}` (cumulative NRestarts ≥5 since last explicit start; resets on deploys) + `system_any_service_restart_churn` composite + Gatus "Service Restart Churn" check — closes the gap under the 3-in-2min crash-loop detector (hermes exit-75 drain chains) | `system-health.nix`, `gatus-config.nix` | script syntax-checked; **LIVE: all monitored services emitting `0`** in system_health.prom |
| **deploy.sh active-session WARN (e.1)**: journal greps the last 10 min for agent/cron activity before `nh os switch`, non-blocking WARN | `deploy.sh` | **LIVE-fired in deploy #2: `⚠ hermes shows agent activity (3 lines…)`** |
| **Smoke fixes (e.3 + e.4 + a pre-existing false-negative)**: stateDir derived from the deployed unit's `WorkingDirectory` (no hardcoded `/home/hermes`); workspace-doc presence via journal; **both hermes and papdashboard ingest checks converted from `journalctl \| grep -q` pipes to journalctl `--grep`** — the pipes SIGPIPE'd (141) under pipefail on the multi-MB journal, the exact AGENTS.md-documented trap (the papdashboard "no ingest 200s" WARN was a FALSE NEGATIVE from this bug) | `post-deploy-check.sh` | standalone `nix run .#post-deploy-check`: **67 PASS / 0 FAIL / 5 SKIP / 1 WARN** |
| **Docs**: runbook (T14 go-live block with the exact `sops --set` command, RO-forever policy, LSP landmine, CDP KillMode noise, scratch semantics); AGENTS.md Hermes section (perms-walk rule, T14 wiring, versioning); TODO_LIST (Q-decisions, SSH-key item superseded); 09-15 report annotated; plan gate outcomes | docs, AGENTS.md, TODO_LIST | committed |

**Deploys:** #1 aborted (lock collision with a concurrent session deploying the IDENTICAL tree — activation no-op); #2 landed everything (67/0 smoke after SIGPIPE fix). VM test **82 assertions green** (43 → 82), flake check green after every change.

## User actions remaining

1. **Go-live for T14**: create a fine-grained PAT (github.com → Settings → Developer settings → Fine-grained tokens, **Contents: Read-only**, scoped to the LarsArtmann private repos), then the one-liner in `docs/services/hermes.md` (`sops --set` + deploy). The canary flips from `skipping` to `private-repo read auth OK` in `journalctl -u hermes-github-verify`.
2. **U1 Discord E2E** (unchanged from the 10-45 report): read `projects/SystemNix/flake.nix` via the bot; `git -C ./projects/SystemNix log -1`; `git clone ./projects/SystemNix ./systemnix-clone`.
3. `sudo bash scripts/hermes-state-audit.sh` (T8, 58G breakdown).
4. Push decision (nothing pushed; commits sit on master).

## Own mistakes this session (own it)

1. **`serviceOneshotDefaults { }` unparenthesized inside `lib.mkMerge [...]`** — in a Nix list it parses as TWO elements (the function + the set); cost three eval rounds until bisecting on the error's `<function, args: {Restart?, RestartSec?}>`. The repo's own style (`(serviceDefaults { … })` parenthesized at line 600) existed as the clue.
2. **Re-implemented the repo's #1 documented bash trap** — `journalctl | grep -q` under pipefail SIGPIPEs on large journals. The AGENTS.md bullet (2026-08-19, bank-sync) describes the exact class. Silver lining: fixing mine exposed and fixed a pre-existing false negative in the papdashboard ingest check.
3. **Python-heredoc quoting corrupted a Nix string** (`'''` opening where `''` intended) — caught by inspection before eval; Nix multi-line strings via shell heredocs are fragile, prefer the edit tool.
4. **Deploy #1 collided with a concurrent session's activation** (exit 11 lock) — mitigated going forward by checking `pgrep -f switch-to-configuration` first (did so before deploy #2). The tree was identical anyway (they had deployed my staged work — the auto-commit daemon had staged everything).

## Not done (deliberately)

- T7 workspace subvolume — user chose defer.
- `chown-vs-bind-audit` promotion to FAILING — dated ~2026-08-27 (one clean CI week), TODO stands.
- T13.2 acl-revoke deletion — time-gated ≥2026-09-03.
- f.31 docs index, f.32 CI cold-runner confirmation, f.16 upstream dry-run case — backlog.
- Upstream T14 note: the `hermes-git-credential` + canary pattern should ride the planned upstream `projectsDir` module proposal (TODO_LIST item).

## Environment notes for the next session

- The auto-commit daemon STAGES aggressively (foreign `qmd` flake input changes sat staged mid-session — left untouched, not committed by me).
- Store outputs of VM tests get GC'd fast on the 95%-full root; use `nix build -L` fresh runs for log evidence, not `nix log`.
- A concurrent session is ACTIVE in this repo (qmd work); my commits below deliberately exclude their files.
