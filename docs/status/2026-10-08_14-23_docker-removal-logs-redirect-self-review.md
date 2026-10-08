# Docker Removal + logs.home.lan Redirect — Session Self-Review & Status

**Date:** 2026-10-08 ~13:00–14:23 · **Scope:** THIS session only (owner directive: "Remove Docker. and what should we replace logs.home.lan with?")
**Verification receipts:** `nix flake check --no-build --keep-going` ALL-PASS (re-run after every wave, final after the self-review fixes), evo-x2 toplevel eval clean (3 fresh evals), `check-doc-links.sh` OK, `check-todo-system.sh` structure OK, `nix fmt` 0-changed. NOT run: VM tests (eval-only), deploy (owner-gated).

---

## a) FULLY DONE

1. **Daemon + plumbing removed** — `default-services.nix` deleted (data-root=/data/docker, journald log-driver, autoPrune, engine metrics-addr, the `mkForce multi-user` ordering); weekly `docker-prune` timer+unit gone from scheduled-tasks.nix; `docker`/`docker-compose` out of the shared base package list; `docker` group out of lars' extraGroups; `virtualisation.oci-containers.backend` line gone.
2. **Dead Docker-only modules deleted** (trash): `dozzle.nix`, `twenty.nix` (frozen since T42), `voice-agents.nix`, `lib/docker.nix` (`mkDockerService`), plus `lib/images.nix`, the `voice-agents.yaml` sops secret + its `sops.nix` block, and the `systemnix-voice-agent` DMS plugin (quickshell wiring + `pkgs/dms-plugins/` dir).
3. **Registry machinery pruned** — `serviceTypes.dockerImageTag` deleted from lib/types.nix + services README rows; 6 dead ports removed (`dozzle` 8084, `docker-engine-metrics` 9390, `signoz-cadvisor` 9193, `twenty` 3200, `whisper` 7860, `livekit` 7880 + UDP range); `scripts/check-image-updates.sh` + `.github/workflows/image-updates.yml` trashed (zero images remain).
4. **Monitoring cleaned** — SigNoz: cAdvisor component (option, unit, scrape job, registry tile) + docker-engine scrape job + "Docker Daemon Down" rule + `dashboards/docker.json` (provisioner convergence deletes the live copies on next deploy); system-health: `collectDockerRestarts` option + collector block + gatus "Docker Container Restarts" check + `pkgs.docker` runtimeInput; gatus-config: Dozzle UI button + cAdvisor check.
5. **Caddy** — voice-agents vHost gate removed; `dnsExemptSubdomains` emptied (voice/whisper); **`logs.<domain>` redirect vHost added (unconditional, verified placement): `redir * https://signoz.<domain>/logs{uri} permanent`** — the Dozzle replacement. Ghost-subdomain warning for `logs` resolved by it (eval warning gone).
6. **Forgejo runner** — `docker://node:22-bookworm` labels dropped, `native:host` only (live hub workflows already native; comment documents the queue-forever semantics for `ubuntu-latest` jobs).
7. **Scripts** — data-corruption-repair.sh de-dockerized (no more stop/start docker around the /data umount; /data/docker dropped from its walk lists); pre-deploy §3 split-brain guard left in place deliberately (defaults to pass, guards re-introduction).
8. **Docs synced** — README (rows + stack list), FEATURES (Dozzle/Twenty/Voice rows → Removed; new "Docker runtime" row; tile + backup-table + risk-table rows), AGENTS.md (critical rule replaced with removal note incl. the old image policy for any future runtime; Samsung section /data/docker prose → dormant-reclaim), sso-dns layer table, monitoring.md (scrape coverage, journald precedence historical note), storage.md (doctrine row + backup-tier prose), systemd.md Docker section marked historical-with-lessons, integration-registry.md Docker OTLP clause, services/README template marked removed, crm.md cutover paragraph, four runbooks trashed (dozzle.md, twenty.md, twenty-*.md ×2).
9. **TODO system** — ~15 Docker-era items closed MOOT across TODO_LIST + services/storage libraries (volume inventory/policy, provenance cross-check, dedupe-figure, prune-watch, image retention, mkDockerService follow-ups, json-file recreation, hardening helper, NOCOW, data-root relocation, Twenty key/pin decision, hot-db docker wave); new **`/data/docker` reclaim [blocked:user]** item in services.md + queue; T42 verify chain rewritten for the combined deploy (docker gone, logs redirect step 8).
10. **CHANGELOG** — full "Removed" entry with blast radius + verification receipts.
11. **Post-report self-review catches (fixed same session):** stale VM-test stubs — `services.voice-agents.enable` stub, `"twenty"`/`"voice-agents"` in enableStubs lists, `services.twenty.port` + `services.signoz.settings.cadvisorPort` portStubs in `test-integration.nix` + `test-caddy-mint.nix` — all removed, re-verified (fmt/check/eval green, zero residual grep).

## b) PARTIALLY DONE

1. **Live-host state** — everything is deploy-pending: the running evo-x2 still has dozzle up (26h uptime at session start), dockerd, the prune timer, and the old SigNoz rules/dashboard until `nix run .#deploy` + provisioner convergence run. No live verification of the redirect or the docker.service removal exists yet.
2. **Verification depth** — eval-tier only for VM tests; CI will be the first to actually RUN integration-registry/caddy-mint post-stub-cleanup (watch item).
3. **`logs` UX** — redirect wired and DNS entry kept, but no gatus UI "Logs" button (Dozzle button removed, SigNoz button remains) and no SigNoz saved-view curating a "Dozzle-like" default logs query.

## c) NOT STARTED (deliberate, with routing)

1. `/data/docker` (~15.5 GB; volumes may hold the pre-Ledger Twenty PG DB) — owner archive-then-trash decision → docs/todo/services.md reclaim item (queued).
2. Gatus UI "Logs" button → monitoring domain (queued).
3. `runnerSettings.container.network = "host"` in forgejo.nix — inert with no container labels; stale key (queued trivial).
4. pre-deploy-check.sh §3 reword for the no-docker world (queued trivial).
5. SigNoz: consider a saved logs view filtered to `severity_number >= 8` or per-service defaults — idea-class, not queued.

## d) TOTALLY FUCKED UP (all caught + fixed in-session)

1. **system-health.nix brace break (worst)** — a 6-edit multiedit replaced the docker collector block but ALSO consumed the metric-emission block's opening `{` and inserted a stray duplicate comment; the script would have been syntactically broken (unmatched `}`). Caught 1 tool-call later by grep-verify, fixed, eval-verified. Root cause: I hand-built a replacement whose new_string was a comment from a DIFFERENT file region — sloppy copy assembly, not whitespace.
2. **`rg -rn` replace-flag misuse (3×)** — `-r n` is ripgrep REPLACE, not "recursive+line-numbers"; it silently rewrote matched text in my terminal output (`whisper`→`n` etc.). I worked from mangled output once before noticing. No repo damage (files/line numbers were correct), but I then re-derived text with sed when it mattered. Same trap class as the repo's own "lint-scanner FP" lesson: know your tool's flags.
3. **Two eval round-trips a pre-edit grep would have killed** — the first `flake check` failed on `gatus-config.nix` cadvisorPort + `caddy.nix` voice-agents gate. I had NOT grepped for those consumers before editing signoz.nix. `--keep-going` (per AGENTS rule) enumerated both at once, but the omission is the finding: my consumer sweep grepped `ports.*` references, not `config.services.signoz.settings.*` / `config.services.voice-agents.*` attribute paths.
4. **Edit-before-read gate failures (~6×)** — tried multiedit on files I'd only sed-viewed; the tool correctly refused. Friction only, but each was an avoidable round trip (README, FEATURES, backup.nix, base.nix, storage.md, boot.nix).
5. **"1 of 2 edits failed" misread** — in monitoring.md the failed-listed edit had actually landed; my retry burned a cycle on a not-found error before re-grepping. Verify-by-grep BEFORE retry, not after.
6. **VM-test blind spot until the user forced self-review** — `tests/` was never in my sweep. The stubs were harmless-at-eval, so every check stayed green and the miss was invisible — exactly the "green ≠ complete" class. The user's "what did you forget?" prompt found it in 2 minutes.

## e) WHAT WE SHOULD IMPROVE (process, durable)

1. **Add a "consumer attribute-path" sweep step to removal playbooks** — when deleting a module/option, grep not just `ports.X` and `X.nix` but `config.services.<name>` and `<optionPath>` across modules/ AND tests/ BEFORE the first edit. This session paid 2 eval cycles + shipped a near-miss to tests/.
2. **`tests/` belongs in every blast-radius map** — module auto-discovery + eval guards cover modules/platforms; nothing sweeps test stubs. A tiny eval-check "no stub declares an option that no module defines" would have caught d)6 mechanically (stub-registry reverse assertion — same shape as signoz-coverage).
3. **Stop using `rg -rn`** — muscle-memory flag collision with `--replace`. Use `rg -n` (or `grep -rn` where provenance matters).
4. **Big multiedits on embedded-shell nix files deserve a brace-balance sanity pass** — the system-health.nix class (nix string → bash script) hides syntax errors from `nix fmt` and only surfaces at unit start. A `bash -n` on the rendered script (or shellcheck leg, which pre-commit runs only on staged .sh) would catch it; consider a check that extracts+`bash -n`s every `writeShellApplication` text at eval time.
5. **Redirect placement semantics** — hand-written vHosts in caddy.nix are unconditional; fine for single-host evo-x2 but worth a one-line comment convention marking "host-shaped assumptions" if a second NixOS host ever appears.

## f) NEXT (prioritized, ≤50; [h] = harvested to queue+library this session)

1. [h] [blocked:user] **DEPLOY** — `nix run .#deploy` carries Docker removal + T42 flip + identity-backup; then the T42 post-deploy verify chain (docs/todo/services.md: docker.service gone, :3200 free, logs redirect live, Ledger on crm.home.lan, passkey registration).
2. [h] [blocked:user] **/data/docker reclaim** — final Twenty-DB archive decision → `sudo trash /data/docker` (~15.5 GB; frees after the /data pin window).
3. [h] [watch] **CI green on the stub cleanup** — integration-registry + caddy-mint VM tests post-removal (first actual RUN vs eval).
4. [h] [ready] **Gatus UI "Logs" button** → `logs.home.lan` (gatus-config.nix ui.buttons).
5. [h] [ready] **forgejo.nix: drop stale `runnerSettings.container.network`** (no container labels remain).
6. [h] [ready] **pre-deploy-check.sh §3 reword** — "oci backend vs docker split-brain" guard now guards a removed world; reword to a docker-reintroduction tripwire.
7. **Owner: confirm no mirrored/flipped Forgejo repo needs `ubuntu-latest` runners** (they queue forever now) — see §g Q3.
8. **SigNoz post-deploy**: confirm provisioner DELETED the live "Docker Daemon Down" rule + docker.json dashboard (convergence) and no orphan route policy remains for the deleted ruleId (the tag-filtered orphan pass should handle it — verify once).
9. **`bash -n` eval-time check for writeShellApplication texts** (e-class hardening; negative-test via negative-test-lints.sh).
10. **Stub-registry reverse assertion** — fail eval when a test stub declares an option no module defines (d)6 class).
11. **SigNoz saved logs view** — severity-based default for the logs.home.lan muscle-memory landing (idea; owner taste).
12. **starship `docker_context.disabled` line** — now fully dead config; drop for cleanliness (cosmetic).
13. **darwin shells.nix OrbStack comments** — mention a docker CLI that no longer ships from nix; reword (cosmetic, macOS-only).
14. **`docs/agents/README.md` provenance map** — sanity-check no mapping row still names dozzle/twenty docs (check-doc-links passed, but the map's prose wasn't re-read).
15. **Live journal probe post-deploy** — `journalctl -u docker` should show the unit gone, `systemctl list-units 'docker*'` empty, cAdvisor/port 9193/9390 closed (`ss -ltnp`).
16. **Verify forgejo-runner picks up label change** — runner re-registers with native-only labels; check the runner page/API post-deploy.
17. **Re-run `docker system df` equivalent on the residue before trash** (du/compsize for the archive decision) — folded into item 2's owner steps.
18. **CHANGELOG [x]-row pruning pass** — the session's MOOT closures in TODO_LIST/services/storage are due for their CHANGELOG sweep per house rules (the removal entry covers the narrative; rows still [x]-marked).
19. **Watch /data space after reclaim** — post-trash `df` lags by the pin window (~4-5w); log the projected free date when it happens (doctrine-row caveat).
20. **Consider reserving vs freeing the 6 dead ports** — freeing is done; if any future service wants 8084/9390 etc. it must re-register (port-registry-audit enforces) — nothing to do unless a collision surprises.

(Deliberately NOT harvested because idea/cosmetic-class or owner-taste: f8–f20 subsets marked idea — the directly-actionable follow-ups f1–f6 ARE harvested; f1/f2 pre-existed from the removal session and were updated, not duplicated.)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy window:** the next `nix run .#deploy` carries Docker removal + the T42 Ledger flip + crm identity-backup together. Deploy now, or do you want a specific window (it stops docker/dozzle mid-flight and restarts a dozen units)?
2. **Twenty data:** before trashing `/data/docker`, do you want a final Twenty Postgres dump archived to the pool (the volumes may hold the pre-Ledger CRM history — 66 companies were live in August), or is the Ledger's own green backup chain + restore drill enough history and I should queue the straight trash?
3. **Forgejo CI scope:** do any of your mirrored/flipped repos' workflows still use `runs-on: ubuntu-latest`/`ubuntu-22.04` (they now queue forever with no matching runner)? If yes I should re-add a label strategy or convert them; if no, native-only stands.

---

*Self-review honesty note: the session's headline quality gap is d)6 — every automated gate stayed green while a real residue class sat in `tests/`. The user's forced self-review, not the pipeline, found it. That's the improvement that matters (e)2/e)4).*
