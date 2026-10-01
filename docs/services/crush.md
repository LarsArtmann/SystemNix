# Crush Configuration (interactive AI sessions)

How the `crush` AI assistant is configured on evo-x2: providers, keys,
models, LSPs, and the verification workflow for changing any of it.

- **Config**: HM-managed `~/.config/crush/crushrc` (Bash, loaded at every
  crush start) — source: `github:LarsArtmann/crush-config` (PRIVATE) via
  `programs.crush-config` (module `homeManagerModules.crush`). SystemNix's
  `platforms/nixos/users/home.nix` only sets host-coupled values:
  `golangciLintLspCommand` (the HM wrapper) and the `qmd` MCP entry.
  Provider/model/LSP changes happen in the crush-config repo → push →
  `nix flake lock --update-input crush-config`
- **Secrets**: sops `platforms/nixos/secrets/crush.yaml` → `/run/secrets/<name>`
  (lars:users 0400), injected at load via the `crush_key` helper rendered by
  the module
- **Auth store**: `~/.local/share/crush/crush.json` — machine-owned; ONLY
  hyper's OAuth state lives there (self-rotating, by design). Never manage or
  symlink this file; never put static keys back into it
- **Catalog**: `~/.local/share/crush/providers.json` — auto-updated by crush;
  provider definitions (base_url, model lists) merge with config ("yours win")
- **Deleted on purpose**: user-level `~/.config/crush/crush.json` (2026-08-31).
  Do NOT recreate it — config split-brain, and crush logs a merge warning when
  both exist

## Current Providers

| Provider      | Key source              | Notes                                                                                                                                                             |
| ------------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `synthetic`   | sops `crush-daily.yaml` | injected since 2026-08-18                                                                                                                                         |
| `zai`         | sops `crush.yaml`       | `glm-5.3-flash` declared via `model add` (not in catalog)                                                                                                         |
| `gemini`      | sops `crush.yaml`       |                                                                                                                                                                   |
| `minimax`     | sops `crush.yaml`       | **DISABLED** 2026-08-31: Token Plan exhausted (2056). `providers.minimax.disabled = true` in the crush-config repo; key stays rendered. Re-enable = flip the flag |
| `kimi-coding` | sops `crush.yaml`       |                                                                                                                                                                   |
| `llamacpp`    | none (local)            | `:8899`, ad-hoc llama-server; models auto-discovered                                                                                                              |
| `hyper`       | auth store (OAuth)      | stays store-owned: tokens self-rotate hourly                                                                                                                      |

## Adding a Provider Key

1. Encrypt it (public key only, NO sudo needed). Stage in RAM to avoid
   `.sops.yaml` path-rule mismatches:
   ```bash
   T=$(mktemp -p /dev/shm); cd /dev/shm
   echo 'newkey_api_key: "VALUE"' > "$T"; chmod 600 "$T"
   sops -e --age age133ckftlye8snhzga95fnl4np7npjry90qr3g84ya0kddctecx5hsx9uyh6 -i "$T"
   sops -d "$T" >> /dev/null  # (on a host with the private key) verify
   ```
   then merge the key into `platforms/nixos/secrets/crush.yaml` with
   `sops --set '["newkey_api_key"] "VALUE"' …` (needs the age PRIVATE key,
   i.e. a sudo session), or regenerate the file the public-key way.
2. Declare it in `modules/nixos/services/sops.nix` (the `crush.yaml`
   `mkSecrets` block): add `"newkey_api_key"` to the name list.
3. Declare the provider in the crush-config repo
   (`/home/lars/projects/crush-config`, `modules/home-manager/crush.nix`):
   `providers.<name>.apiKeyFile = "<name>_api_key";` in the module's
   defaults — then push and `nix flake lock --update-input crush-config`.
4. Test WITHOUT a deploy: `bash scripts/crush-rc-test.sh` (loads the rc in an
   isolated `XDG_CONFIG_HOME`; `EXTRA='…'` appends a candidate line;
   `--probe` + `PROBE_MODEL=provider/model` fires one real completion).
5. Deploy (`nix run .#deploy`), then verify `crush models` lists the provider
   and restart crush sessions — config loads ONLY at session start.

## Rotating a Key

`sops --set '["zai_api_key"] "NEW"' platforms/nixos/secrets/crush.yaml`
(sudo/age private key), then redeploy. Rotation — not relocation — is what
makes old plaintext residue in session DBs inert.

## Verification Suite for ANY crushrc Change

1. `bash scripts/crush-rc-test.sh` — load-safety (a bad statement aborts the
   ENTIRE config load: all providers/LSPs/MCPs vanish)
2. `crush models | diff` before/after — WHICH entities exist; a deleted
   config source may own entities nothing else provides (the 2026-08-31
   glm-5.3-flash lesson)
3. `bash scripts/crush-rc-test.sh --probe` + `PROBE_MODEL=provider/model` —
   one real completion through the key (auth + model both proven)
4. `crush models` asserts model IDENTITY in any smoke run — never trust a
   reply without knowing which provider/model served it (silent fallback to a
   pricier default is a real, observed failure mode)

## Gotchas

- The flake input is `github:`-type for a PRIVATE repo — works locally
  (user gh token in `~/.config/nix/nix.conf` access-tokens) but CI needs
  `NIX_GITHUB_RO_TOKEN` (same pending fix as the other private `github:`
  lock nodes) — until then CI stays dark for this input
- `nix flake lock --update-input crush-config` is a NO-OP while the repo's
  default branch ref (`?ref=master`) hasn't moved — push first, then re-lock
- `model add` has NO `reasoning_levels` flag (source:
  `internal/shellconfig/model.go`) — tier lists come from the catalog or
  crush's default handling; `--reasoning-effort` is an unvalidated string
  (`xhigh` works, the usage text's `low|medium|high` is aspirational)
- `discover_models` defaults to TRUE — llama.cpp/ollama-class providers need
  no hand-maintained model lists
- Session DBs (`~/.{config,local/share}/crush/.crush/crush.db`) snapshot
  provider configs per session: store-era keys sit there until rotation;
  crushrc-injected keys are never snapshotted
- `crush_key` skips absent secrets AND `PLACEHOLDER*` values — a provider
  with a placeholder ships inert, not broken

## Session DBs live on the Samsung hot disk (2026-09-15; first migration ran 2026-09-18)

`services.crush-hot-db` relocates each `~/projects/**/.crush/` dir to `/mnt/hot/crush/<relative path>`
(Samsung TLC) and leaves a symlink. NESTED checkouts are covered too (`archived/<repo>`,
`games/<repo>`, … — bounded `find -maxdepth 3`, names map relatively, parent dirs are created;
the 2026-09-16 review fix for the 35 nested dirs the original top-level-only glob missed).
The `crush-hot-db-migrate` unit is enabled via
`multi-user.target` — a static unit would silently skip deploy.sh's is-enabled-gated provisioner
loop — and runs at boot + daily 04:10 + every deploy.

**First migration: RAN 2026-09-18** (started 15:41 inside the freeze-#6 recovery window,
interrupted ~2/3 by the crash, converged across reboots — `~/projects/.crush →
/mnt/hot/crush/projects-root` exists since 16:09 that day). Live state 2026-09-21:
279 symlinks, `/mnt/hot/crush` = 45 GiB, `PRAGMA integrity_check` OK on a migrated DB.
One straggler (`legal-cases/.crush`, untouched since Sep 8) sat unmigrated for 13 days —
root cause: the old blanket `pgrep -x crush` skip made EVERY run self-skip while any session
was live (16-21 always are on this box). Fixed by the per-project guard below.

**Guard semantics (LIVE on the deployed 2026-09-22 generation, verified 2026-09-29):**
a project is skipped iff a `comm=crush` process holds an fd or its cwd under THAT project's
`.crush` (post-migration sessions hold fds on `/mnt/hot` targets and never match — their dirs
are already symlinks); DBs written <10 min are left one more cycle; per-dir `mv` failures
exit non-zero → OnFailure (Discord) + system-health `extraMonitoredServices` paging; a
depth-4 `.crush` (below the discovery cap) logs a WARN; `CRUSH_HOT_DB_DRY_RUN=1` rehearses
a run without moving anything (e.g. `systemctl set-environment CRUSH_HOT_DB_DRY_RUN=1`).

**Expected journal lines while sessions are live (all benign — the run still converges
everything not held open):**

```text
skip <project>: live crush session holds it open
skip <project>: crush.db written in the last 10 minutes
crush-hot-db: N project(s) relocated
WARN: .crush deeper than discovery depth 3 (stays on the QLC root): <path>
```

The legacy whole-run line `skip: crush session(s) active (N) — next run converges` belongs
to the pre-2026-09-21 blanket guard and no longer appears on the deployed 2026-09-22+
generation (the deployed script carries only the per-project skip lines above).

Verify after deploy:
`find ~/projects -mindepth 1 -maxdepth 3 -type d -name .crush | wc -l` (expect 0 real dirs;
a fresh project's QLC-root `.crush` is converged by the next run) and io PSI avg60 vs the
pre-move baseline.

**Measured follow-through (2026-09-29, full evidence + ledger:
`docs/status/2026-09-29_00-45_crush-db-baseline-followthrough-io-psi-zone6-verdict.md`):**
the crush attribution is gone — pre-migration storm windows had crush session scopes moving
~630 MB/min (5 of the top-10 cgroup movers, worst single crush process 50 GB cumulative,
#3 on the box); post-migration windows show crush sessions at ~9 MB/min (≈70× down, absent
from the top-10) while the current storm drivers are clickhouse, nix-daemon builds, and the
guard's btrfs-scrub stop/re-arm churn. Zone 6 still trips 22–130/day and still cycles flm —
the residual drivers are NOT crush. Two real `.crush` dirs remain: `go-daemon` (legit
live-session skip, self-converges) and `legal-cases` (blocked by a root-owned EMPTY target
`/mnt/hot/crush/legal-cases` from the interrupted first run — heal: `sudo rmdir` that empty
dir, the next run converges it). NOTE: the review-fix batch (per-project guard, depth WARN,
DRY_RUN, OnFailure) is LIVE on the deployed 2026-09-22 generation — verified 2026-09-29
(deployed migrate script greps + `crush-hot-db-migrate` present in BOTH the rendered
`services.system-health.extraMonitoredServices` and the DEPLOYED system-health collector).

Runbook/source: `modules/nixos/services/crush-hot-db.nix`; see the `services.hot-db` Phase-2 plan
(`docs/planning/2026-09-14_13-27_SAMSUNG-PHASE2-HOT-DB-NATIVE-PARETO-PLAN.md`) for the long-term home.

## crush-debug (error-to-agent launcher, 2026-09-29)

`Mod+Ctrl+D` (or `crush-debug` in any terminal) turns a system error into a crush session.
Picker = failed system units + failed user units + the active sev1 alert (`/run/systemnix/sev1/alert`),
fzf preview shows status + journal. On selection the script bundles evidence to
`~/.local/state/crush-debug/<ts>-<unit>/evidence.txt`, then runs a headless `crush run` fix pass in
`~/projects/SystemNix` (model + autonomy from the repo `.crushrc` tq block) and opens the SAME session
interactively with `crush --continue` when the pass ends — review, ask follow-ups, or let it continue.

- Flags: `crush-debug <unit>` (skip picker), `--review` (no auto pass, prompt printed for pasting),
  `--yolo` (auto-accept everything), `-` (pipe extra evidence via stdin, e.g.
  `journalctl -u x -n 500 | crush-debug -`).
- The seeded prompt forbids deploying: fixes land in the flake, you run `nix run .#deploy` after review.
- Sessions inherit SystemNix's `.crushrc` (glm-5.3-flash xhigh, bash/edit allowlisted) — the auto pass
  needs no yolo.
- Evidence dirs may contain log secrets (flm echoes request bodies to journald); user-only perms,
  newest 20 kept.
- Source: `platforms/nixos/desktop/crush-debug.nix`; known gap: Gatus-red-but-active checks are not
  picker sources yet (root-only sqlite) — docs/todo/desktop.md.

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Crush Session DBs on the Samsung hot disk (`services.crush-hot-db`, 2026-09-15)

Per-project `~/projects/**/.crush/` session DBs (2-5 GB + WALs each) were the 2026-09-14 boot IO storm's main sustained driver (QLC-root seeky SQLite; guard Zone 6 cycled flm). New module `modules/nixos/services/crush-hot-db.nix`: `/mnt/hot` mounts the Samsung TLC toplevel (`by-label/tlc`, `subvolid=5`, `nofail` — hardware-configuration.nix) and `crush-hot-db-migrate` (ENABLED via `wantedBy = multi-user.target` so deploy.sh's is-enabled-gated provisioner loop actually restarts it — a static unit silently skips that gate, the dnsblockd-bridge trap class; runs at boot + daily 04:10 timer + every deploy) moves each project's `.crush/` dir to `/mnt/hot/crush/<relative path>` leaving a symlink — discovery is a bounded `find -mindepth 1 -maxdepth 3 -type d -name .crush -prune` so NESTED checkouts are covered too (`archived/<repo>`, `games/<repo>` → `/mnt/hot/crush/archived/<repo>`; 2026-09-16 review fix for the 35 nested dirs the original top-level glob missed; the unit also declares `path` explicitly — flock is NOT on the default unit PATH (procps was dropped together with the pgrep guard, 2026-09-21)). Guards (module ≥ 2026-09-21, LIVE on the deployed 2026-09-22 generation — verified 2026-09-29: deployed script carries all four fixes and `crush-hot-db-migrate` sits in the rendered AND deployed system-health `extraMonitoredServices`): PER-PROJECT live-writer skip — a project is skipped iff a `comm=crush` process holds an fd/cwd under ITS `.crush` (the old blanket `pgrep -x crush` skip starved convergence: 16-21 sessions are ALWAYS live on this box, so `legal-cases/.crush` sat unmigrated 13 days after the freeze-interrupted first run; post-migration sessions hold fds on /mnt/hot targets and correctly never match); DBs written <10 min left one cycle; flock single-flight; idempotent; per-dir mv failures exit non-zero → OnFailure (Discord) + system-health `extraMonitoredServices` (wired behind an `optionalAttrs (options ? services.system-health)` guard — the module is standalone-imported in its VM test, so the attrpath must never appear there); depth-4 `.crush` WARN tripwire; `CRUSH_HOT_DB_DRY_RUN=1` rehearsal. nofail mount degrades to "crush recreates fresh dirs" — never a dead boot. **INTERIM mechanism**: fold into the ratified `services.hot-db` Phase-2 module — do not run both; the fold is still pending and is a separate queue item. DEPLOYED 2026-09-16 20:57 (generation `bbb931a8`, module carries all four review fixes + the green `tests/test-crush-hot-db.nix`); **FIRST MIGRATION RAN 2026-09-18** (started 15:41 inside the freeze-#6 recovery window, interrupted ~2/3 by the crash, converged across reboots — `~/projects/.crush → /mnt/hot/crush/projects-root` since 16:09 that day): 279 symlinks live, `/mnt/hot/crush` = 45 GiB, `PRAGMA integrity_check` OK on a migrated DB (2026-09-21). Expected journal lines + runbook: `docs/services/crush.md`.

### crush-debug (error-to-agent launcher, Mod+Ctrl+D, 2026-09-29)

**Module:** `platforms/nixos/desktop/crush-debug.nix` (HM module, `programs.systemnix-crush-debug`, default on, imported by `home.nix` next to niri-wrapped) — one keybind turns a system error into a crush agent session: `Mod+Ctrl+D` opens a FLOATING ghostty (existing `app-id = "^floating$"` window rule) running the `crush-debug` picker over failed SYSTEM units, failed USER units, and the active sev1 alert file. Selection bundles evidence (`systemctl status`, `systemctl cat`, 300-line journal tail; for sev1: the alert file + guard journal) into `~/.local/state/crush-debug/<ts>-<unit>/evidence.txt`, then runs a HEADLESS `crush run` fix pass in `~/projects/SystemNix` and reopens THAT session interactively via `crush --continue`. Direct invocation: `crush-debug <unit>` (scope auto-detected), `--review` (no auto pass), `--yolo` (full auto-accept), `-` (capture piped stdin as evidence). Runbook: `docs/services/crush.md` "crush-debug".

- **Prompt contract**: the agent fixes the Nix CONFIG in the flake (never hand-patches the live system), reads AGENTS.md first, verifies with `nix flake check --no-build`, and must NOT deploy (`nix run .#deploy` stays human-owned — the prompt forbids it; .crushrc-permitted bash makes this a soft guard, the user watches the run). Sev1 entries name the owning modules (sev1-escalation.nix + memory-emergency-guard.nix).
- **Why no `--yolo` by default**: SystemNix's `.crushrc` tq-managed block already allowlists the fix toolset (`bash edit write fetch ...`); the auto pass runs unattended for exactly those tools while anything unusual still prompts.
- **Interactive `crush` IGNORES positional prompts** (source-verified `internal/cmd/root.go` — args never reach the TUI) — that is WHY the seeded prompt rides `crush run` and follow-up rides `crush --continue`. Do not "simplify" to `crush "<prompt>"`.
- **Evidence bundles can contain secrets** (journald carries flm request bodies) — they are user-only under `~/.local/state/crush-debug/`, same trust domain as crush session DBs; pruned to the newest 20 bundles on each run (find+trash).
- **Error surface v1 is failed-units + sev1 ONLY**: Gatus-red-but-active incidents (the majority incident class in this file) are NOT picker sources — gatus.sqlite is root-only and the API is OIDC-gated. Root-side dump file or token'd API read is the queued follow-up (docs/todo/desktop.md).

