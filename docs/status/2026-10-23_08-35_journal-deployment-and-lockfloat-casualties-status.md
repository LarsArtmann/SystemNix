# Journal deployment on evo-x2 + the 2026-10-23 lock-float casualties — Status

_2026-10-23 08:35 CEST · session: user asked "is `~/projects/journal` deployed on evo-x2?" → "Set it up!" · scope of this report: exactly this session's work and what it ran into. Format note: user explicitly demanded a `.md` at this path (skill default is HTML — override flagged in the closing message)._

---

## Headline

**journal was already half-deployed** (binary on PATH on both hosts since 2026-10-19 — my initial "not deployed" answer was wrong; I had checked service modules/ports but not `lib/lars-packages.nix`). What was genuinely missing is now built: the **books home `~/books/`** (config + initialized DB + doctor-verified first backup) and the **nightly GoBD backup timer** (`journal-backup.nix` module, eval-green, enabled). The **deploy did NOT run**: an 07:09 lock float (auto-commit `4cf457561`) broke the tree in four foreign places; two are fixed in-tree (crowdsec module rewrite migration, monitor365 start-limit conflict), **two remain** (forgejo-runner option removal, crowdsec-setup unit shape) and block `nix flake check` → block `nix run .#deploy`.

---

## a) FULLY DONE

1. **Deployment-shape research** — journal is a pure CLI accounting kernel (cobra, no serve command, no port, no daemon by design); upstream month-end runbook explicitly assigns the nightly backup timer to "the deployment (NixOS module)"; `docs/services/journal.md` (SystemNix) already documented the deliberate non-service design, including the flake input, CI deploy key, PATH wiring on both hosts, and the non-follower vendorHash class.
2. **Correction of my own wrong premise** — `journal --version` works live (`/run/current-system/sw/bin/journal` → `journal-ba60fe0d…`); package wiring (`lars-packages.nix` → `base.nix` `attrValues larsPackages`) predates this session (2026-10-19). My first answer ("deployed nowhere") was wrong and was corrected in-session with live evidence.
3. **Books home `~/books/` (evo-x2)** — created and verified:
   - `journal.yaml`: both real entities (artmann-technologies + artmann-holding), all 7 in-scope Wise balance mappings, account_defaults, matcher settings, `export.account_map: skr04-technologies.yaml` (the runbook §4 standing-home pattern).
   - Charts imported: technologies (18 accounts) + holding (9 accounts, expected VAT role-gap warnings — documented upstream behavior).
   - `entries/` (2 worked examples), `chart-*.yaml`, `skr04-technologies.yaml`, `exports/`, `out/`, `backups/`.
   - `journal doctor`: **healthy** (integrity ok, 2 events, 2 streams). `journal status`: clean (2 entities, 0 entries/exceptions/proposals).
   - First backup: `backups/journal-2026-10-23.db` (376,832 bytes) — `--verify` doctor battery passed on the copy. This is byte-for-byte the command the timer will run.
4. **`modules/nixos/services/journal-backup.nix`** — new module (git-added immediately, tracked-files trap): nightly 03:30 + 10m jitter, `Persistent`, `Type=oneshot` as the primary user, `harden { ProtectHome=read-only; ReadWritePaths=[booksDir]; MemoryMax=1G }` + `serviceOneshotDefaults` + `onFailure` toast, `unitConfig.ConditionPathExists` clean-skip on missing books, `WorkingDirectory=booksDir` (config DB path is CWD-relative — verified in `config.AbsoluteDatabase`), same-day re-run no-op guard, `IOSchedulingClass=idle`/`Nice=10` (background-citizen doctrine). Package pin = `inputs.journal.packages…default` (identical store path to the PATH binary).
5. **Enable switch** — `services.journal-backup.enable = true` in `platforms/nixos/system/configuration.nix` (scoped eval green: timer `{ OnCalendar = "*-*-* 03:30:00"; Persistent = true; RandomizedDelaySec = "10min"; }`, service `User = "lars"`).
6. **Runbook updated** — `docs/services/journal.md`: new integration-surface row (nightly GoBD backup), Ops section rewritten (books home documented; "no system state" replaced by the accurate books-home + deploy-owned-timer split; CWD-relative DB caveat recorded).
7. **Lock-float casualty #1 — crowdsec module rewrite (FIXED)**: nixpkgs PR #446307 renamed `settings.general.*` → `settings.config.*`, `settings.lapi.credentialsFile` → `settings.config.api.client.credentials_path`, and removed `localConfig` (→ `settings.{acquisitions,parsers}`). Migrated `modules/nixos/services/crowdsec.nix` (config block + `repairConfig` yaml source) and `tests/test-crowdsec-render.nix` (`localConfig.acquisitions` → `settings.acquisitions`). External surfaces checked: only `geometrikks.nix` references the LAPI **port** (`ports.crowdsec-lapi`), not the option path — unaffected.
8. **Lock-float casualty #2 — monitor365 start-limit conflict (FIXED)**: upstream (locked rev `d651704e`, verified via `git show` in the monitor365 checkout) now sets the typed top-level `startLimitIntervalSec = 1200; startLimitBurst = 5;` itself with a documented rationale (150s secret-retry cycles). Removed SystemNix's now-conflicting workaround (600/5 + `serviceConfig.StartLimit* = mkForce null`) — the workaround's own comment said it existed only until upstream moved the keys.
9. **Lock-float casualty #3 — geometrikks eval (RESOLVED)**: `geometrikks-0.19.0-src.drv is not valid` was a stale eval-cache entry; `nix flake check --refresh` cleared it. No source change needed.

## b) PARTIALLY DONE

1. **flake check green** — crowdsec + monitor365 + geometrikks legs are fixed; **two eval blockers remain** (see c) #1–2). Scoped evals of MY surfaces are green; full `nix flake check --no-build --keep-going` still fails on the two foreign blockers.
2. **forgejo-runner migration (researched, not written)** — full plan exists (see c) #1): option rename to `services.forgejo-runner`, no-connections instance shape preserving the legacy `.runner` registration flow, unit-override rename, StateDirectory-rename consequence understood. Zero lines landed.
3. **Deploy + live verification of journal-backup** — module is enabled and eval-green but NOT deployed; timer not yet active; no busctl StartUnit end-to-end run yet.

## c) NOT STARTED

1. **forgejo-runner option migration** (the blocker): `services.gitea-actions-runner` is REMOVED upstream (assertion at eval). Migration decided during research, minimal-risk shape: `services.forgejo-runner.instances.${hostName} = { enable = true; settings = runnerSettings; }` — **no** `url`/`labels`/`name`/`tokenFile`: the rename-compat `url`/`labels` shims would create a `server.connections.default` entry that hard-requires a token secret (incompatible with SystemNix's `LoadCredential = mkForce []` tmpfs fix from 2026-10-16); the daemon keeps using the legacy `.runner` file registered by the existing `forgejo-register-runner` ExecStartPre (`act_runner register --instance <url>` carries the URL; `runnerSettings.runner.labels` already carries the labels — the house comment says config is the source of truth). List options (path/after/wants) merge by concat — no conflicts expected. Unit override block renames `gitea-runner-${escapeSystemdPath hostName}` → `forgejo-runner-${…}` (new module unit name, verified in module source line 472).
2. **crowdsec-setup house wiring** (the other blocker): the new nixpkgs crowdsec module ships `crowdsec-setup.service` (oneshot in the boot transaction) which trips THREE house audits: systemd-shape-audit (unbounded TimeoutStartSec — needs explicit timeout or allowlist), io-tier-coverage-audit (needs an ioTier fragment), deploy-restart-audit (`-setup$` converger pattern — needs a `scripts/deploy.sh` provisioner entry or a justified allowUnits). None wired yet.
3. **Deploy** (`nix run .#deploy`), deploy-anchor check, timer-active verification, forced first timer run.
4. **CHANGELOG entries** for the crowdsec/monitor365 migrations + journal-backup module.
5. **Post-deploy live verification of the two migrated foreign services** (crowdsec config.yaml shape change rides a possible binary bump; monitor365 start-limit semantics now upstream-owned).

## d) TOTALLY FUCKED UP!

1. **My opening verdict was wrong.** I answered "journal … deployed nowhere" after checking only service modules, ports, and processes. The packaging surface (`lib/lars-packages.nix` → `base.nix`) — the documented single source of truth for LarsArtmann Go tools — was never checked before answering. The user then commissioned a "Set it up!" that was half already done. Caught and corrected ~20 minutes in, but the wrong first answer is exactly the "verified label must cover every fact asserted" class this repo already codifies.
2. **The tree was already broken when I arrived — and nothing gates that.** The 07:09 auto-commit (`4cf457561`) landed a lock float that breaks `nix flake check` in FOUR places (crowdsec module rewrite, gitea-actions-runner removal, monitor365 start-limit collision, crowdsec-setup shape) with no eval gate between "lock floated" and "committed". Any deploy by anyone was dead on arrival this morning. My session paid ~90 minutes into foreign-module triage because of it (two fixed, two queued). The lock-float pipeline lacking a flake-check gate is the systemic fuck-up — this class will recur on every float until gated.
3. **First books-setup command chain was sloppy** — a `cp` with a trailing directory arg failed and the `&&` chain silently skipped the `journal.yaml` copy; entry examples landed loose in `~/books/` root. Caught on the very next `ls`; cleaned + re-copied. No lasting damage, but the same "check the whole chain's output before proceeding" lesson.

## e) WHAT WE SHOULD IMPROVE!

1. **Eval gate on lock floats**: the flake-update/auto-commit path should run `nix flake check --no-build` (or at minimum the evo-x2 toplevel eval) before a floated lock is committed. Today's 4-way breakage shipped silently at 07:09.
2. **"Is X deployed?" needs a checklist, not intuition**: for any LarsArtmann tool the answer lives in `lib/lars-packages.nix` + `base.nix` + the service modules + `docs/services/<name>.md`. I should have read the runbook FIRST (it existed and answered the question authoritatively).
3. **Runbook split-brain (now healed)**: SystemNix's journal.md said "no systemd unit" while the upstream month-end runbook said the backup timer "belongs to the deployment". Two runbooks owned one deployment story with opposite claims — the SystemNix one is now corrected, but this is the docs-health drift class.
4. **Stale eval cache after lock moves**: the geometrikks "drv not valid" phantom cost a debugging cycle; `--refresh` after any lock float should be reflex (worth a line in `docs/agents/nix-flakes.md`).
5. **Upstream-module rewrite detection is reactive**: three of the four casualties are "nixpkgs rewrote an upstream module under us". The house audits caught the shape problems (good!) but only at the next eval — a compat-matrix note per consumed upstream module (crowdsec, forgejo-runner, monitor365) in `docs/agents/nix-flakes.md` would shorten next time's triage.

## f) NEXT — things to get done (from this session's findings)

**Unblock + ship (this session's mission):**
1. Land the forgejo-runner migration (c.1 shape) in `modules/nixos/services/forgejo.nix`.
2. Wire crowdsec-setup: TimeoutStartSec + ioTier + deploy.sh provisioner entry (or justified allowUnits) in `crowdsec.nix`.
3. `nix flake check --no-build --keep-going` → green.
4. `nix run .#pre-deploy-check` → `nix run .#deploy`.
5. Verify deploy anchor: `readlink /run/current-system` == newest `system-N-link` (2026-10-14 exit-14 class).
6. Verify `journal-backup.timer` active + NextElapse via busctl.
7. Force one `journal-backup.service` run via busctl `StartUnit`; verify output + `journalctl -u journal-backup`.
8. Re-run the same unit once more → must no-op ("already exists — idempotent no-op").
9. Post-deploy smoke: crowdsec.service active, LAPI on `127.0.0.1:<port>`, acquisitions parsed; monitor365-server active with upstream start-limits.
10. Verify the migrated runner registers (first start writes `.runner` under `/var/lib/forgejo-runner/evo-x2`) and a CI job actually runs.

**Harvested follow-ups (also queued per TODO-system rules):**
11. Owner: delete the OLD offline "evo-x2" runner registration in the Forgejo UI after re-registration (lingering duplicate).
12. CHANGELOG entries: journal-backup module + books home; crowdsec PR #446307 migration; monitor365 start-limit drop; forgejo-runner migration (when landed).
13. Queue eval-gate-on-lock-float work (pipeline domain) — pre-commit or flake-update workflow leg running `nix flake check --no-build`.
14. Document "run `--refresh` after lock floats" + the three upstream-module rewrites in `docs/agents/nix-flakes.md`.
15. Decide the `gitea-runner-cache` group/tmpfiles naming (now references a legacy unit family name — cosmetic, rename or leave with a comment).
16. Check `system-health` census output renders the new escaped unit name `forgejo-runner-evo\x2dx2.service` correctly (logic is generic; one live look post-deploy).
17. Confirm the `forgejo-family-condition-audit` family matcher (`hasPrefix "forgejo"`) covers `forgejo-runner-*` — it does by prefix; verify at eval.
18. Owner decision: fate of `~/projects/journal/dogfood.db` (dev/dogfood DB, Oct 9) vs the new `~/books/journal.db` — archive or declare it dead.
19. First real month-end pass through `~/books` (bank-sync export → import → reconcile → close per upstream runbook) — the books are initialized but hold zero real postings.
20. Watch journal-backup disk growth (~0.4 MB/night now; GoBD keep-all — fine for years, note stands).
21. books home is evo-x2-only (MacBook has the binary but no books) — deliberate; note in runbook if the owner ever wants parity.
22. Add `journal doctor`/`journal status` to the owner's periodic pass (runbook now documents them).

**Smaller adjacent items noticed in passing (not blocking):**
23. `getExe` deprecation warning: `monitor365-server-0.1.0` lacks `meta.mainProgram` (upstream-owned; surfaces in every check log).
24. `TODO_LIST.md` + `docs/services/inboxclean.md` were dirty from parallel sessions at report time — not mine, untouched.
25. The `nix flake check` tail noise (eval warnings) could be triaged into a house "known warnings" list to keep real errors visible.

## g) QUESTIONS (cannot figure out myself)

1. **Books home location**: I chose `~/books/` (config + DB + charts + backups). Once real months are booked this is expensive to move (CWD-relative DB path). Right place, or do you want it elsewhere (e.g. `~/finance/`, a pool path)?
2. **Old Forgejo runner registration**: the migration's StateDirectory rename (`gitea-runner/` → `forgejo-runner/`) orphans the existing `.runner` identity — the runner will re-register as a NEW entity and the old "evo-x2" registration will sit offline in the Forgejo UI until deleted (I have no admin API access from this shell). Delete it yourself, or should I leave both?
3. **crowdsec upgrade depth**: the module rewrite may ride a crowdsec binary bump with it on this deploy (config.yaml shape `general:` → `config:`). Is deploy-time smoke (post-deploy-check + gatus CrowdSec check) sufficient verification for you, or do you want a dedicated pre-deploy look at the crowdsec changelog vs. the live DB (crowdsec.db) before the switch?

---

**Working-tree state at authoring time (all uncommitted; daemon will sweep — amend-forward policy applies to my surfaces):** `modules/nixos/services/journal-backup.nix` (staged/A), `platforms/nixos/system/configuration.nix` (enable), `modules/nixos/services/crowdsec.nix` + `tests/test-crowdsec-render.nix` + `modules/nixos/services/monitor365.nix` (migrations), `docs/services/journal.md` (runbook), this report. Parallel-session files (`TODO_LIST.md`, `docs/services/inboxclean.md`, earlier `fastflowlm.nix`/docs churn) NOT mine, untouched.

**Verification receipts:** scoped evals (timer/service) green; `journal doctor/status` output captured in-session; crowdsec/monitor365 fixes verified by successive `nix flake check --keep-going` error-list shrinkage (4 classes → 2); upstream shapes verified against the nixpkgs store source (`PR #446307` module) and the monitor365 checkout at the locked rev (`d651704e`).
