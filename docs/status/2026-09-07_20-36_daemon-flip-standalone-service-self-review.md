# Status Report: Daemon Flip — standalone project-discovery-daemon service, with brutal self-review

- **Date:** 2026-09-07 20:36 CEST
- **Session scope:** Continuation of the PMA→pdd daemon role-flip ("do it" + "think about good names"). Two repos changed: `project-discovery-daemon` (pdd) and `SystemNix`. This report covers ONLY this run, on top of `2026-09-07_17-55_nix-quality-review-pdd-flake-and-systemnix-self-review.md`.
- **State at write time:** all gates green in both repos; flip is code-complete and verified; **NOT deployed** — blocked on push (pdd master is ahead 1) + deploy decision.
- Markdown per explicit user instruction (status-report skill's HTML default overridden, as before; brutal-self-review folded in).

---

## a) FULLY DONE (verified green)

### pdd (project-discovery-daemon)

1. **`EnvSearchPaths` / `EnvSocketMode`** (`PROJECT_DISCOVERY_SEARCH_PATHS`, `PROJECT_DISCOVERY_SOCKET_MODE`): constants in `constants.go`, `parseSearchPaths`/`parseSocketMode`/`clientOptions` in `cmd/.../main.go`, octal parsing with warn-and-fallback, PATH-style colon splitting, usage text. Named per existing `EnvCacheTTL` conventions — no new vocabulary.
2. **Table tests** for all three new funcs (unset/valid/invalid cases, existing `t.Setenv` style) — cmd package test suite green (18.4s, race).
3. **go-nix-helpers hard-pinned** to known-good `58f72570` via `?ref=master&rev=...` (same pattern as the SDK input) — master tip `2a74b8b4` is broken (undefined `mod` in mkPreparedSource.nix:258). pdd `nix flake check`: **all checks passed** (exit verified unmasked).
4. Full pdd gates re-run: `go build`, `go test` (cmd green; root package had a load-flake `TestHandleTraceSnapshot_AutoTriggerOnSlowRequest`, isolated `-count=3` passes clean — pre-existing timing sensitivity, not my change), `go vet`, lint scoped to my files: **0 findings**.

### SystemNix

5. **New module** `modules/nixos/services/project-discovery-daemon.nix` (auto-discovered `flake.nixosModules.project-discovery-daemon`): options `enable/package/user/socketPath/socketMode/searchPaths/cacheTTL/extraEnvironment`; unit with `harden { MemoryMax=8G; CPUQuota=400%; ProtectHome=read-only; }` + `serviceDefaults` + top-level `startLimitBurst/IntervalSec` + `onFailure` + `Type=notify` + `WatchdogSec=30s` (verified sd_notify WATCHDOG sender, per the repo's own rule) + `RuntimeDirectory=project-discovery`. `user` defaults to `config.users.primaryUser` (no hardcoded username — discovery must read a 0700 home).
6. **Flake input** `github:LarsArtmann/project-discovery-daemon?ref=master` with `nixpkgs`/`flake-parts` follows + **`go-nix-helpers.follows`** (deliberate insulation from the broken master tip). `lib/lars-packages.nix` entry added (single source of truth for LarsArtmann Go tools).
7. **The flip in `configuration.nix`:** `services.project-discovery-daemon = { enable=true; searchPaths=[~/projects]; cacheTTL="24h"; socketMode="0666"; extraEnvironment.PROJECT_DISCOVERY_REFRESH_INTERVAL="60s"; }` (24h/60s/0666 = exact PMA-era parity) and **`projects-management-automation.enableDiscoveryDaemon = false`** with a bind-conflict rationale comment.
8. **`pma-daemon-watchdog` gated** on `enableDiscoveryDaemon` — with the standalone service owning the socket, restarting PMA could never heal it (it would have restart-looped PMA every 5 min). Eval-verified: the timer attribute no longer exists.
9. **Verification (the lesson from last time, applied):** statix clean · deadnix clean · scoped `nix fmt` · evo-x2 **and** rpi3-dns toplevel evals · **FULL `nix flake check` incl. VM tests AFTER my edits: all checks passed** · full evo-x2 toplevel **builds** with the env-var binary via `--override-flake project-discovery-daemon <local>`.
10. **Urgency discovered during recon:** SystemNix's already-locked PMA rev includes the off-by-default daemon commit — meaning the NEXT deploy would have killed the embedded daemon socket (and overview with it) even without my flip. The standalone service shipping in the same activation is therefore not just desirable but REQUIRED to keep overview alive. Deploy-order dependency is wired, not documented-wishful.

### Naming decisions (user asked to think about good names)

- Module/service/option namespace: `project-discovery-daemon` (filename = module name = unit name, repo convention).
- Env vars follow the existing `PROJECT_DISCOVERY_*` family; constants `EnvSearchPaths`/`EnvSocketMode` match `EnvCacheTTL`.
- `user` (not `userName`/`runAs`), `socketMode` (not `permissions`), `searchPaths` (matches PMA/overview's vocabulary — one concept, one name across three repos).

## b) PARTIALLY DONE

1. **The flip itself:** code-complete + verified, **not deployed**. Blockers (owner decisions, hard rules): push pdd master (1 commit) → re-lock SystemNix input → `nix run .#deploy` → post-deploy parity check. Without the push, deploying would silently run the old binary (env vars ignored → search paths fall back to `$HOME` = wrong scope, not a crash — the worst failure class).
2. **TODO #37 (socket access story):** the `WithSocketMode`+env knob now exists (this session + PMA's prior option), but the pdd TODO row still says "Not started", README/deploy docs don't cover the new vars, and the 0660+group model is not implemented (0666 is parity, not the target).
3. **PMA client-mode refactor:** deliberately deferred until production parity is proven (crush lesson: land replacement → verify → THEN delete the old path). Not started on purpose.

## c) NOT STARTED (known, sequenced)

1. Push + re-lock + deploy + post-deploy parity verification (socket health via python probe, overview status, PMA status, daemon metrics equivalence).
2. PMA-side glue removal (`internal/discovery/daemon_server.go` + the `WithCacheInvalidator(daemonSrv)` coupling → DaemonClient-based invalidation).
3. Socket hardening 0666 → 0660 + shared group (needs inventory of overview's service user).
4. pdd CHANGELOG entries for `EnvSearchPaths`/`EnvSocketMode`; README env-var table row additions; `deploy/README.md` + systemd unit examples updated for the new knobs; TODO #37 marked.
5. Daemon `/metrics` → textfile collector (system-health pattern) so the daemon's Prometheus surface joins the host monitoring without exposing the socket.

## d) TOTALLY FUCKED UP (brutal honesty — this run)

1. **I ran plain `nix fmt` in pdd AGAIN and it re-locked go-nix-helpers to a broken master tip** — silently breaking pdd's own `nix flake check` until I tripped over the error building SystemNix. This is the SECOND occurrence of the exact trap I wrote up in the previous status report ("applied only retroactively-half"). The mitigation (hard `rev=` pin) is good; the discipline failure is the story. `--no-update-lock-file` is not optional anywhere, ever, for me.
2. **Pipeline masking, third strike:** `nix flake check 2>&1 | tail -3; echo "pdd-flake-check: $?"` printed **0 while the check had FAILED** (the broken-helper error was right there in the tail). I caught it on the follow-up command — but only because I looked. The fix (`>/tmp/log; echo $?`) takes zero extra effort; there is no excuse for the lazy form.
3. **First module shape was wrong:** I wrote a bare NixOS module; this repo's auto-discovery requires the `_: { flake.nixosModules.<name> = ... }` wrapper. dozzle.nix was a 30-line worked example I had already read. Write-after-skim instead of write-after-read.
4. **Tracked-files trap hit again:** new module file untracked → flake source (git-tracked view) lacked it → confusing eval error far from the cause. AGENTS.md documents this exact trap and I had quoted it earlier the same day. `git add` must be step zero for any new file in this repo, before the first eval.
5. **Claim I almost made falsely:** I drafted "SystemNix AGENTS.md still says PMA co-locates the daemon" — grep showed NO such phrase (I was misremembering configuration.nix's comment, which I did update). Caught in verification before writing it here. Reports must be grep-backed, not memory-backed.

## e) WHAT WE SHOULD IMPROVE

1. **Make `rev=`-pinning the default for ALL moving `git+ssh` inputs** (go-nix-helpers proved master tips break mid-session under concurrent agents). The SDK pattern generalized; consider an eval-time warning in go-nix-helpers itself for `ref=master` without `rev=`.
2. **Never run any formatter without `--no-update-lock-file`** — this belongs in both repos' AGENTS.md as a one-line hard rule (pdd's AGENTS.md doesn't have it yet; SystemNix's does).
3. **`git add` new files before first eval** — add to my own pre-flight for this repo (AGENTS.md already implies it; I should follow it).
4. **Always eval-assert new units** (environment JSON, option gating, WatchdogSec) — it caught the watchdog-gate and env wiring in seconds; make it the standard step between "module written" and "full check".
5. **Doc updates belong in the same change as the feature:** CHANGELOG/README/TODO rows for EnvSearchPaths/EnvSocketMode are missing because I treated them as separate work. They are not.
6. Prior-report wins confirmed by others this run: concurrent sessions landed pdd TODO #31 (deploy files), #28 (actionlint), #27 (coverage gate), the 140-lint cleanup, and the CI private-token auth — the shared-tree pipeline works when sessions don't overlap files.

## f) Up to 50 things to do next (first 8 are the flip's own critical path)

1. **Push pdd master** (owner go) — unblocks everything below.
2. Re-lock SystemNix `project-discovery-daemon` input to the pushed rev.
3. **`nix run .#deploy`** (owner go) — single activation carries: standalone service ON, PMA daemon OFF, watchdog timer OFF.
4. Post-deploy parity: python socket probe `/v1/health`; `systemctl is-active` for daemon/overview/PMA; overview dashboard loads; daemon `projects_count` sane (~260 expected, NOT whole-home); metrics endpoint parity.
5. PMA observation window (a day?) → then start the PMA client-mode refactor (DaemonClient + socket-based cache invalidation) in the PMA repo.
6. After PMA refactor: remove `internal/discovery/daemon_server.go` glue + `WithCacheInvalidator(daemonSrv)` coupling.
7. pdd docs: CHANGELOG entries, README env table (+ SEARCH_PATHS/SOCKET_MODE), deploy/README + shipped unit examples with the new knobs.
8. Mark pdd TODO #37 Done (option + env + docs) or split out the 0660+group follow-up.
9. Socket hardening: inventory overview's service user → shared group → tighten `socketMode` to 0660 in SystemNix config.
10. Daemon `/metrics` textfile collector (system-health.nix pattern) — bring the daemon's Prometheus surface into host monitoring.
11. Bump go-nix-helpers pins (pdd + SystemNix follows) once master is fixed; remove the "broken master" comments.
12. Tell the go-nix-helpers owner-session about `2a74b8b4` (undefined `mod`) if not already known — CI there would catch it if CI ran.
13. pdd AGENTS.md: add the `nix fmt --no-update-lock-file` rule + the moving-input `rev=` pin policy.
14. Carry-over from previous report (still open, unchanged): SystemNix oneshot-hardening batch (#3), SystemCallFilter decision (#5), eval-time presence audits (#4), MemoryHigh parser mutation test (#6), taskwarrior pseudo-secret (#7), zfs-vm root password (#8), flake-registry hoist (#9), cv.nix primaryUser (#10), immich backup-dir oneshot (#11), with/rec cleanups (#12–13), pkgs maintainers (#14), freebsd-zfs-vm checksum+port (#15), dms-lock /home/lars fallback (#16), docker.nix pull-unit hardening (#17), mkDesktopNotifyService startLimit (#18), unitConfig.StartLimit normalization (#19), user-service hardenUser gaps (#20), dnsblockd CA dual-source (#21), ssh-config user (#22), uncovered-dirs review (#23), TODO_LIST harvest (#24), monitor365 private-crate blocker revisit (#25).
15. pdd: fix or isolate-and-ticket the `TestHandleTraceSnapshot_AutoTriggerOnSlowRequest` load flake (failed 2 of 4 full-suite runs today under parallel build storms).
16. pdd: `nix flake check --all-systems` / darwin eval sanity (carried over).
17. pdd: go-standard migration (TODO #32) once upstream GOEXPERIMENT support lands — the same go-nix-helpers session could unblock it.
18. SystemNix: consider a tiny VM test for the flip (service up, socket answers, PMA daemon absent) in `tests/` — the repo has the harness; the flip currently relies on host verification only.
19. SystemNix: `quick-go` batch could include the pdd package (FOD breakage pre-deploy enumeration).
20. Both repos: the auto-commit daemon batches my work with concurrent sessions' — a pathspec commit discipline note in AGENTS.md for agents (I used it; make it universal).

## g) Questions I CANNOT figure out myself

1. **Push + deploy go?** pdd master is ahead 1 (the env-var commit). Without pushing, deploying is worse than not deploying (silent wrong-scope discovery). With pushing: re-lock → deploy → verify is ~15 min. Say the word.
2. **Socket access end-state:** keep 0666 parity (any local user can query discovery — matches today exactly) or invest in the 0660 + shared-group model (requires inventorying overview's runtime user and a group change in the same deploy)? Security vs. one more moving part on a live host — your risk call.
3. **Is another session actively fixing go-nix-helpers master** (`2a74b8b4`, undefined `mod` in mkPreparedSource)? I insulated both repos with pins, but I can't see other sessions' queues — if nobody owns it, the next consumer without a pin will hit the same wall.

---

_Arte in Aeternum — report from session memory + grep-verified claims only. Waiting for instructions._
