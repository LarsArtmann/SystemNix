# Lock-float deploy night: cv 16th re-stale, calm-gate phantom lockout, forgejo runner v13 migration gap — fixes + fleet recovery

**Window:** 2026-11-07 20:04 → 2026-11-08 03:05, single agent session (user "fix it all" after their own `nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` died mid-proof).
**Concurrent sessions:** one live all night (dns-blocker/nsfw/mr-sync work; their commits are attributed inline) — two deploy collisions decoded below.

## a. What the user's deploy hit

The 20:04 deploy ran the float-register ceremony (26 drifted inputs from the blanket `nix flake update`) and its proof went RED on `cv-da7f3cb-go-modules.drv`: spec aCVmXAeF, got EKiWDhsV — the SIXTEENTH cv vendorHash re-stale (treadmill class, tracked in cv.nix since 2026-10-12). Registry rows auto-reverted; deploy aborted cleanly. Pressure gate tripped both at 20:04 and on every later run: PSI 28-53% with disks at max 4.8-18% util and the stalled cgroups being `app-niri-ghostty-*.scope` at 60-100% — the **ghostty io_uring CQ-waiter phantom** (2026-10-14 verdict, live re-verified twice tonight with `scripts/io-psi-crosscheck.sh`: empty io.stat + ~100% cgroup PSI + zero D-state). Every forced run tonight was phantom-justified, never blind.

## b. Fix chain (all deployed)

1. **cv shim SIXTEENTH RE-STALE** (cv.nix): aCVmXAeF → EKiWDhsV at cv@da7f3cbc, first-hand keep-going evidence `~/.cache/lockfloat/float-proof-20261107-200453.log`. Ceremony re-run GREEN (float-proof-20261107-202945.log rc=0, lock fingerprint 017361b09067 = committed lock); the daemon had already swept lock+registry (d6112b3e0) and cv.nix (dd19923a5) mid-proof — content verified post-sweep.
2. **My 20:38 deploy** (quiescence-polled 4×60s, force-justified): switch + anchor self-repair landed at 21:5x; battery exit 3 with exactly ONE new fail — llama.cpp Embeddings.
3. **llama-embeddings root cause NOT the nixpkgs float**: the service consumes the PINNED llama-cpp-0.3.0 build (nixpkgs-llama-rag pin did its job). It was down because **post-crash-calm-gate REFUSED admission**: raw io-PSI 82-91% vs the 40 band for its full 60-min/241-probe budget (22:59-23:00 journal), then exit 1 at 23:00:39 → Requires cascade took llama-embeddings + nsfw-classifier down. The measured storm was the same ghostty phantom (disks idle throughout). nsfw-classifier recovered ~450 s cold-load after manual admission; /health 200; real /v1/embeddings vectors verified.
4. **Anchor + mirror**: the dns-blocker session's **raw `switch-to-configuration test` at 22:00:32** (sudo journal, pts/24, NO deploy log — outside `nix run .#deploy` per the standing rule) flipped current-system to xywfvd7mc leaving profile at gen 986 — repaired 00:30 per doctrine (profile → gen 987 = running system, `stc boot`, boot-mirror-sync restarted, 313 M mirrored, pre-reboot-check flipped BLOCKED → SAFE TO REBOOT). Their activation's restart wave also crash-looped indexer-web ("event store not ready within 10s" ×5 → start-limit); it started clean once reset-failed (00:34, re-confirmed active post-switch).
5. **Missing hot-tier subvols**: `home-lars-tmp.mount` + `home-lars-.cache-golangci-lint.mount` failed mount-exit-32 — `users/lars/tmp` (migrate-user-tmp-hot.sh never ran) and `users/lars/cache/golangci-lint` (NO creation script anywhere) simply didn't exist on the tlc toplevel. Created both via `btrfs subvolume create` on /mnt/hot 00:4x (tmp empty, cache disposable — shadow-safe; both automounts active, §18 shadow-split gate PASSes all four cache rows).
6. **forgejo runner (the deploy's core fix)**: dead since the 2026-11-06 state-dir recreation. Chain: 6164fc7b1's v13 migration added `ExecStartPre = mkForce [...]` which **displaces the preStart sugar entry** — the rendered unit lost the connection-config.yaml render leg entirely (systemctl cat: only the two `+` legs). Fixed in 49066bc92 (render folded into the mkForce list as a root leg; stale merge-order comment replaced). Deploy of that fix hit two more gates: (a) `checks.x86_64-linux.nsfw-classifier` eval error — the sibling session's unconditional gatus exemption (8b5f6a423) defined an option the test's reduced module set never declares → imported gatus-coverage-audit into tests/test-nsfw-classifier.nix (1a36aec98), which then surfaced a STALE assertion (TimeoutStartSec moved unitConfig→serviceConfig 2026-11-05; CI's eval-only check never built it) — assertion updated same commit; (b) doc-counts README stamp 280→279 re-stamped (16a6a8592, nsfw registry-readiness rework retired the raw-port endpoint).
7. **v13 dual-connection conflict**: the deployed render leg worked but the daemon then rejected the legacy `.runner` ("server connection conflict between .runner and config"). Provision's presence check reads `.uuid`/`.token` (present), so the legacy file is dead weight — moved out of the state dir 02:35 (loss-free: pair duplicated) → **runner ACTIVE, "declared successfully" v13.2.1** (first green since 2026-11-06). Durable fix committed 49066bc92 (render leg `rm -f ./.runner`), rides the next deploy wave.

## c. Deploy-vs-executor collisions (decoded, not caused)

- 20:59:50 deploy attempt: exit 13, correctly refused by the flock (mine held it).
- 00:49 deploy: ingested the sibling session's UNCOMMITTED flake.nix edit (their allowPorts-8104 experiment) mid-eval → same-store-path error at 00:49 and 00:55; gone from the tree by 00:56 (they reverted). Re-deployed after a fresh eval probe.
- 01:15 deploy: switched 02:32, anchor self-repaired ✓, exit 3 — the ONLY new battery fail was "Service Sanity CPU" = the sibling session's live golangci-lint run at 300%+ CPU (transient, clears with their cycle).

## d. Deployed system state (03:05)

Anchor clean (current-system == newest gen, hf6a5dssk). cv 200 (zero SIGSEGVs). llama-embeddings active on 8848. indexer-web active. forgejo runner active/declared. dnsblockd, §22 CA parity, §23 filter-proxy all green in-battery. **nsfw-classifier intentionally GONE from the new gen** — the sibling session commented `nsfw-classifier.enable` out at 22:07 (4a1c54ded) as part of their nsfw rework; hub /readyz stays 503 until THEY prune the nsfw remote from the hub config (their wave, not touched). Memory-guard trips overnight (23:51) were phantom-inflated too — btrbk's 23:30 failure is the DESIGNED /data-EIO tripwire (docs/todo/storage.md P0), unrelated.

## e. Pre-existing baseline (verified unchanged, NOT touched tonight)

SearXNG engine-init fail, Offsite Borg tripwire binary (getExe/meta.mainProgram), buildcache-gc 1250 lines/min journal rate, tq dlq/fold warns, monitor365-server 1.69 M MemoryHigh watermark hits.

## f. Follow-ups (all self-harvested at authoring time)

- **Calm-gate + memory-guard phantom blindness** → queued [ready] in TODO_LIST.md + docs/todo/stability.md (device-truth crosscheck leg for maintenance-entry-gate; also blocks the guard's io-PSI<20 restore bar indefinitely while ghostty windows are open).
- **Subvol creation script coverage** (users/lars/tmp + golangci-lint) → queued [ready] in TODO_LIST.md + docs/todo/storage.md.
- **mkForce-displaces-preStart gotcha** → recorded in docs/agents/systemd.md unit-script lessons.
- **llama-embeddings inactivity + 8848/8849 ownership rows** (15-10 report) → CLOSED with tonight's evidence on both surfaces (gate refusal + rogue class died tonight; durable-guard design stays owner-decision row 673).
- **forgejo-runner `.runner` retirement** rides the next deploy (49066bc92, committed) — no emergency deploy; the running system is converged via the state fix.
- Deliberately NOT harvested: mr-sync-dashboard-prep missing IO tier (the sibling session's live refactor broke tree eval at 02:37 — their hot file, they're mid-flight); hub nsfw remote pruning (same wave's cleanup).
