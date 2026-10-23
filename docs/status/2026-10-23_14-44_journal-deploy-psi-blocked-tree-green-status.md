# Journal deploy PSI-blocked; lock-wave tree FULLY GREEN — Status (session continuation)

_2026-10-23 14:44 CEST · session: continuation of the journal-deployment session (first report: `2026-10-23_08-35_journal-deployment-and-lockfloat-casualties-status.md`). Scope: everything since that report + the deploy attempt. User demanded `.md` at this path (skill-HTML default overridden)._

---

## Headline

**The tree is FULLY GREEN again**: `nix flake check --no-build --keep-going` → **all checks passed** — all four 2026-10-23 lock-wave casualties are healed in-tree (crowdsec module rewrite, monitor365 start-limit collision, gitea-actions-runner removal, crowdsec-setup shape), journal-backup is enabled and eval-clean. **The deploy itself was BLOCKED by deploy.sh's own I/O-pressure entry gate** (PSI some avg10 66.3% + disk busy 101.4%, driven by interactive ghostty scopes at ~78–82% io.pressure — the same class the monitor365 deploy row has been waiting out since 01:42). Nothing was built, nothing switched: the gate fired before the validation battery. The deploy needs a PSI-calm window or an explicit owner override (`DEPLOY_FORCE_PRESSURE=1`); at report time the storm persists (avg10 50.8%, full 38.7%).

---

## a) FULLY DONE (since the 08:35 report)

1. **§f harvest landed (both surfaces, per TODO-system rules)** — TODO_LIST queue rows (7 new + 1 upstream + 1 pipeline), full library entries in `docs/todo/{services,pipeline,upstream}.md`, the pipeline `[decision]` lock-heal row annotated with the landed crowdsec fix + premise correction (root nixpkgs DID move — fe13242 → 02c087f, so it was never a "transitive ghost"), and the runner-registration row re-scoped to a carry-over verification after the identity-preservation step landed.
2. **forgejo-runner migration LANDED** (`modules/nixos/services/forgejo.nix` + `_forgejo-scripts.nix`) — the deepest of the four casualties, driven entirely by source-verified v13.2.0 facts (shallow-cloned to `~/.cache/runner-src`):
   - `daemon.go:57` — the daemon REQUIRES ≥1 `server.connections` entry; the `.runner`-only flow survives solely via `FromRegistration`, which ERRORS when the config already carries connections ("server connection conflict", registration.go:44).
   - `config.go:635` — `token_url` must be a `file:` URL (`ResolveSecretURL` rejects bare paths); uuid must parse as a UUID at config load.
   - `register.go:360` — `act_runner register` (deprecated, functional) still writes `.runner`.
   - Shape: `settings = daemonRunnerSettings` with `server.connections.default = { url; uuid = "@RUNNER_UUID@"; token_url = "file:/run/forgejo-runner/token.bare"; }` and `runner.file = "/nonexistent/.runner"` (so `FromRegistration` stays a no-op for the daemon). ExecStartPre chain: `+gen-runner-token` (now also writes the BARE token file) → `+forgejo-runner-carry-identity` (root; copies `.runner`/`.labels` from the old 0700 gitea-runner dir into `registration/` — **the uuid Forgejo knows is PRESERVED, no re-registration, no orphaned entity**) → `forgejo-register-runner` (rewritten: register only as fresh-host fallback, then sed-renders the uuid into a working-dir copy of the module config — the upstream nixos-test pattern). ExecStart → the rendered `config.yaml` (`${STATE_DIRECTORY}` expansion). LoadCredential stays mkForce-cleared; the dead `EnvironmentFile` TOKEN line dropped.
3. **crowdsec-setup house wiring LANDED** — `systemd.services.crowdsec-setup` gets `serviceOneshotDefaults` (bounded TimeoutStartSec) + `ioTier.background`; `crowdsec-setup` added to `scripts/deploy.sh`'s provisioner loop (directly multi-user-enabled → the is-enabled gate admits it).
4. **`nix flake check --no-build --keep-going`: `all checks passed!`** — full-tree green including evo-x2/zfs-vm/rpi3-dns + every check derivation. (Remaining log noise is pre-existing evaluation warnings: monitor365 mainProgram, stalwart pin, isLinux deprecations — none mine.)
5. **Scoped evals of the migrated runner unit** — ExecStart renders to `…forgejo-runner-13.2.0/bin/forgejo-runner daemon --config "${STATE_DIRECTORY}/config.yaml"`.

## b) PARTIALLY DONE

1. **Deploy — BLOCKED at the entry gate, unstarted otherwise.** `nix run .#deploy` exited at "ENTRY gates: pressure + guard-trip recency": I/O PSI some avg10 66.33% + disk busy 101.4% (REAL storm class; sdb 101.3%, top stalled cgroups = ghostty app scopes 78–82%). The freeze-history gate worked exactly as designed — nothing was built. At report time the storm persists (avg10 50.8% / full 38.7%, 4 ghostty processes live). Next attempt: PSI-calm window, or owner calls `DEPLOY_FORCE_PRESSURE=1`.
2. **Everything downstream of the switch** is staged but unverified: journal-backup timer active + forced run + idempotent re-run; crowdsec/monitor365 live smoke; runner carry/render/connect verification; deploy anchor check. All deploy-gated.
3. **Lint/format on my edited files not yet exercised** — no commit has run the pre-commit legs (alejandra, shellcheck on deploy.sh, todo-system checks) over this session's edits yet; the auto-commit daemon will sweep them and the legs will arbitrate.

## c) NOT STARTED

1. The deploy (see b.1) + the full post-deploy verification chain.
2. CHANGELOG entries (journal-backup + books home; the four lock-wave migrations).
3. `docs/agents/nix-flakes.md` --refresh-after-lock-float note (queued in pipeline library; trivial on-sight fix still unclaimed).
4. Report #1 close-out annotations (its §c.1/§c.2 are now done-in-tree; correction claims must name surfaces).
5. Queue `[x]` close-outs for the two migration rows (done-in-tree, deploy-gated) — deliberately deferred until post-deploy verification so the receipts can be complete.

## d) TOTALLY FUCKED UP!

1. **I launched the deploy without reading PSI first.** The repo's own doctrine (and the monitor365 [watch] row, and deploy.sh's gate) says check pressure before heavy builds — one `cat /proc/pressure/io` would have shown the storm. deploy.sh caught my omission by design, so the cost is only a wasted attempt and this honest paragraph — but the check was MINE to make.
2. **My first forgejo-runner shape was wrong.** I wrote a "settings-only, no connections" instance assuming the daemon would keep the legacy `.runner` flow — the module's eval-time assertion ("requires at least one connection") rejected it, and only then did I source-verify the daemon (which PROVES connections are mandatory at runtime too). I researched AFTER writing instead of before — the exact verify-before-filing discipline this repo already codifies, applied to config migrations. The final shape is better for it (identity preserved, all mechanics source-verified), but the sequence was backwards.

## e) WHAT WE SHOULD IMPROVE!

1. **Pre-deploy PSI read belongs in the agent ritual, not just the script gate.** The gate is the backstop; the operator (me) should never hand it a doomed attempt.
2. **Upstream-module migrations: source-verify FIRST.** Every fact that shaped the final runner migration came from 30 minutes of reading v13.2.0 source — after a failed eval. Cheap before, expensive after.
3. **Lock-float eval gate** (already queued, pipeline.md): today proved the class again — four silent eval breaks shipped at 07:09; only this session's deploy attempt surfaced them.
4. **The ghostty interactive-scope IO storm is now the single biggest deploy blocker on this box** (blocked monitor365 at 01:42, journal at 14:44). It deserves its own root-cause row rather than being re-attributed per incident.

## f) NEXT (session-relevant, ordered)

1. Re-attempt `nix run .#deploy` in a PSI-calm window (gate: io some avg10 < 20% without disk-busy corroboration — or owner override).
2. Post-switch anchor check: `readlink /run/current-system` == newest `system-N-link`.
3. `journal-backup.timer`: active + NextElapse via busctl.
4. Force `journal-backup.service` via busctl `StartUnit` → journalctl verification ("backup written … verified"); re-run once → must no-op.
5. crowdsec live smoke: service active, LAPI 127.0.0.1:<ports.crowdsec-lapi>, acquisitions parsed, repair units green.
6. monitor365-server live: start-limit now upstream-owned (1200s/5) — confirm active, no watchdog churn.
7. Runner verification: "carried .runner …" journal line once, config.yaml rendered with a REAL uuid, daemon connected under the SAME uuid (Forgejo UI/API), one CI job executes on the hub repo.
8. `post-deploy-check.sh` full pass (17 checks).
9. The monitor365 volume batch rides the same switch — its rendered-TOML spot-check (keystrokes/mouse `false`, fs_event `60`) per its [watch] row.
10. Tick the two migration queue rows `[x]` with receipts (edit queue + library, both surfaces).
11. CHANGELOG entries (see c.2).
12. Annotate report #1's §c.1/§c.2 as landed (name the surfaces).
13. `docs/agents/nix-flakes.md`: --refresh note + the three upstream-module rewrites (crowdsec/forgejo-runner/monitor365) as compat-matrix lines.
14. Verify formatting/lint of this session's edited files once the daemon sweeps (re-run skipped legs standalone per the daemon-race policy).
15. Root-cause row for the ghostty interactive-scope IO storm class (monitoring/stability domain).
16. Durable rows already harvested stand: eval gate on lock floats (pipeline), dogfood.db fate + gitea-runner-cache naming + first month-end pass (services), monitor365 mainProgram (upstream), runner carry-over verification (services, closes with f.7).

## g) QUESTIONS (cannot figure out myself)

1. **Deploy override decision**: the storm is INTERACTIVE load (ghostty scopes), not build load — the freeze history bans deploying into storms, but waiting may mean waiting out your own active sessions. Wait for calm, or do you want `DEPLOY_FORCE_PRESSURE=1` now?
2. **Carried from the 08:35 report, still unanswered**: `~/books` as the permanent books home — confirm (it gets expensive to move once real months are booked).
3. **crowdsec upgrade depth**: the module rewrite rides a possible crowdsec binary bump on this switch (config.yaml `general:` → `config:` shape change against the live crowdsec.db). Is post-deploy smoke + the gatus CrowdSec check sufficient, or do you want the changelog-vs-live-DB reviewed before the switch?

---

**Working tree at authoring time (uncommitted; daemon will sweep):** journal-backup.nix (staged earlier), configuration.nix, crowdsec.nix, monitor365.nix, forgejo.nix, _forgejo-scripts.nix, test-crowdsec-render.nix, deploy.sh, docs/services/journal.md, TODO_LIST.md + docs/todo/{services,pipeline,upstream}.md (harvest), both status reports. Parallel-session files untouched.

**Verification receipts:** flake check #3 log `/home/lars/.cache/journal-setup-flake-check3.log` ("all checks passed!"); runner ExecStart scoped-eval output; deploy gate output (this file's headline quotes it verbatim); PSI readings 14:4x; books backup `journal-2026-10-23.db` still present (07:45, 376,832 bytes).
