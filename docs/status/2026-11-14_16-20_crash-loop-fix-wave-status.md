# Crash-loop fix wave: every live loop attributed + fixed in-tree (deploy storm-gated)

**Session:** 2026-11-14 ~15:4x → 16:2x CET. Scope: owner ask "Review all crash loop reports and fix them!" — full sweep of crash-loop reports (docs/status + restart-loop reviews) cross-referenced against LIVE unit state, then fix everything fixable.

**TL;DR:** four crash-loop classes root-caused and fixed in-tree with eval-verified renders, two stale queue rows closed with first-hand attribution, one "already fixed in-tree but never deployed" finding (bank-sync) proven. The deploy carrying them all is storm-gated (IO PSI 54 % at session close, two freezes already today) — the wave rides the next calm window via the queued `[blocked:deploy]` verification row.

---

## a) LIVE crash-loop census (attributed, journal-first)

| Loop | Cadence | Root cause | Fix |
|---|---|---|---|
| `audiblesync.service` start-limit-hit | every boot + every restart (10 today) | `Environment=AUDIBLESYNC_SYNC_CMD=/path {asin}` — systemd `Environment=` is a space-separated assignment list; unquoted value splits, app's template validation (`must contain {asin}`, executor.go) sees bare path → exit 1 | inner-quoted env value (`"… {asin}"`) in audiblesync.nix |
| `immich-api-key-provision.service` 226/NAMESPACE | every start since first deploy (13:55, 14:55, boot 15:41) | `ReadWritePaths=/var/lib/immich-api-keys` references a dir nothing creates; the script's own mkdir runs only AFTER namespace setup (google-sync class) | `StateDirectory=immich-api-keys` in immich.nix |
| `monitor365.service` dmesg SIGSYS | once per agent start (14:49, 15:01, 15:43 — live at session start) | coredumpctl attribution: the AGENT (freeze-#46 guessed `monitor365-server-backup` — wrong, that unit runs green nightly). Host-hardening collector's dmesg fallback (selinux.rs; fires because /var/log/audit + kern.log don't exist here) dies SIGSYS syscall 103: upstream `ProtectKernelLogs=true` + `@system-service` both deny syslog(2); `kernel.dmesg_restrict=1` additionally requires CAP_SYSLOG | monitor365.nix agent block: `ProtectKernelLogs=mkForce false` + `SystemCallFilter=mkForce ["@system-service" "syslog"]` + `CAP_SYSLOG` (Ambient+Bounding, mkForce repeating upstream's CAP_NET_RAW/CAP_SYS_PTRACE) — all three move together or the read still fails |
| `bank-sync.service` exit-65 | 39 restarts today, loop live | NOT a new break: the 14:55 gen-1007 deploy started before the 14:39 repin commit (aff08e220) and still runs floated `93ead5fc` (verified: live ExecStart store path) — the known cqrs key-rendering divergence vs the PROD journal | already fixed in-tree (lock at `ad8a90c9`, current tree evals `bank-sync-ad8a90c9…`); heals on this wave's deploy, zero data risk |

**Deliberate non-loops (verified, no action):** tq-agent-pool's gate-refusal retry (84 restarts — bounded-by-design per the 2026-11-11 verdict), single-restart post-deploy settles (helium/miniflux/etc. counters all at 1).

## b) Fixed additionally (dormant class)

- **llama-chat RestartSteps=5 / RestartMaxDelaySec=15min** (llama-chat.nix) — the queued [ready] row; the 2026-11-02 OOM→restart→re-OOM pile-driver. Unit is config-disabled pending the owner's disable-or-pin ruling, so the render was proven via the documented throwaway `extendModules` probe (`{"maxDelay":"15min","steps":5}`), never a tree force-enable.

## c) Verification

- Targeted renders eval'd green for all four (audiblesync Environment, StateDirectory, monitor365 caps/filters, llama-chat extendModules).
- Full evo-x2 toplevel eval green at the fixed tree (`/nix/store/vkblm3462…-nixos-system-evo-x2-….drv`); only pre-existing ghost-dns warning (nsfw, llama).
- Full `nix flake check --no-build` deliberately deferred to the commit hook (storm doctrine — the check is exactly the wrong load class at PSI 54; pre-commit runs it on eval-relevant paths).

## d) NOT done / deliberately not done

1. **No deploy** — IO PSI some avg10 = 54 % into the gate's ≥20 refusal band, two freezes (#52/#53) already today; forcing is the freeze-#40/#49 class and DEPLOY_FORCE_PRESSURE authority is still owner-unruled. The wave + bank-sync repin ride the next calm window; verification battery queued (services.md + TODO_LIST `[blocked:deploy]` row).
2. **Crash-loop alert leg (restarts ≥N/h escalation, TODO_LIST:598)** — assessed, NOT implemented: needs a textfile collector + rule surface (the niri_crash_loop pattern is niri-specific); this wave removes all four CURRENT loops, and the monitor365 attribution shows the SEV1 bridge already fires on coredump classes. Left queued.
3. **monitor365 upstream relaxation** (agent module ships the kernel-log grant itself) — queued as a note in the resolved row; SystemNix-side override is the deployable-now fix.

## e) Session self-review

1. First restart-count aggregation (`awk '{print $NF}'`) printed counter values, not units — rebuilt with `-oE` before drawing conclusions.
2. The audiblesync root cause had a decoy: the LIVE unit file shows `{asin}` present in the Environment line — only reading upstream main.go (flag default = `os.Getenv`) + systemd's assignment-list semantics separated "rendered value" from "received value".
3. extendModules probe needed `mkForce true` (configuration.nix holds a plain `enable = false` — the raw probe dies on multiple-definition priority, not the documented form's failure mode; worth a line in nix-flakes.md's pattern one day).

## Harvest record (self-harvest, done at authoring time)

- TODO_LIST: llama-chat backoff row ticked [x] (both-surface note in ai-stack.md line 13); monitor365 SECCOMP row ticked [x] with attribution; NEW `[blocked:deploy]` wave-verification row (queue + services.md).
- services.md: SECCOMP row resolved with full mechanism; new [blocked:deploy] library entry (the full battery incl. bank-sync repin verification).
- Runbooks: audiblesync.md (env-quoting trap), immich.md (StateDirectory + custom-keyFile caveat), monitor365.md (kernel-log grant section).
- CHANGELOG: wave entry. Deliberately NOT harvested: the alert-leg row (already exists at TODO_LIST:598), the storm/deploy decision (no row can act for the owner).

## Addendum (17:10, follow-up session) — census orphans attributed + deploy coordination

### c) Census-orphan attribution (closed)

1. **x2dx2 (14 restarts) = `forgejo-runner-evo\x2dx2.service` start-pre timeout loop** — since 13:58 (0 attempts yesterday), 27+ by 16:31, CI runner down all day: genToken + provision legs finish in ~1s (`provision: connection identity present — nothing to do`), then the `+forgejo-provision-runner-cache` leg's `chgrp -R gitea-runner-cache /mnt/buildcache/ci-runner-cache/{ec-hub,gf-logs}` walk starves under the IO storm and hits `TimeoutStartSec=3min` → `Failed with result 'timeout'` → the 5-min ensure timer refires. Caught in-flight (PID 2476106, chgrp mid-walk). Storm-collateral with a structural flaw (unbounded-TIME walk inside the timeout-budgeted start chain) → `[ready]` row in TODO_LIST + services.md.
2. **cvagent (4 restarts) = systemd-oomd kills** (13:21/13:43 + exit-2 at 14:04/15:27; 897 MB peak, 157 GB disk reads lifetime) — freeze-#54-session collateral, their P0 row owns the fix (their 15:41 line is the boot re-arm per their own correction note). Corroborated, not re-filed.
3. **User-manager failed sweep (census blind spot)**: `nextd-refresh.service` = the nextd daemon's `/refresh` returns 500 on every 15-min tick since its 15:33 watchdog SIGABRT (main goroutine blocked in select 363 min) → `[watch]` row, fix lives in the nextd repo. `push-stall-watch.service` = BY-DESIGN stall detector firing on the 26+ unpushed owner-gated commits — working as intended, resolves with the owner's push ruling.
4. **`systemd-analyze syscall-filter @system-service` verification**: `syslog` is NOT a member (exact-list grep rc=1; full dump shows it only under `@known`) — the monitor365.nix comment stands as written, no correction needed. Battery item closed.
5. **bank-sync pre-start backup sizing**: upstream design is `cp -f` onto a single rolling `data.db.pre-start.bak` (207 MB, overwritten every start — /home/lars/projects/bank-sync/deploy/nixos/bank-sync.nix:283-300) — the 39-restart loop grew NOTHING. The 4 dated pre-qonto-import .baks (~408 MB) remain owner-reclaim (existing services.md decision row updated with this verification + the 750 permission-blind note).

### Deploy coordination (open)

The parallel freeze-#54 session's armed calm-window waiter (`~/.cache/band-deploy2.log`, io<20 ∧ mem<20 ∧ trip-free ≥15 min) owns the next deploy — the same master tree carries this wave, so the waiter's fire deploys the fixes + the bank-sync repin. Takeover condition (this session): if the storm drains but the waiter log goes stale past its horizon without a fire, this session re-arms and fires per the standard protocol. Storm evidence at 17:05: 96 ld.mold linkers, IDENTICAL PID set across 3 min (zero completions), sdb aggregate write ~495 KB/s — the session-26 SSH build battery (monitor365 cargo-nextest, started 15:46:58 post-boot) is crawling in write-starvation; owner stop/let-finish ruling (freeze-#54 session §g.1) gates every deploy. The verification battery stays queued in the `[blocked:deploy]` row.
