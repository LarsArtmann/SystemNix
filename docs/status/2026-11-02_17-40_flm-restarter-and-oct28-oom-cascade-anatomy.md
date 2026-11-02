# flm-real alive-at-kill restarter + Oct-28 10:14–10:15 OOM cascade anatomy (freeze-#38 boot `b0d70d73`)

Session: 2026-11-02, task-queue batch `000001a19d0445939f0e5c51d75400000000` (items 1 + 2).
Evidence: live `journalctl -b b0d70d73d1f14ee6954915145e26e46e` (full 32-hex id), kernel -k excerpts,
`/var/log/systemnix-deploys/2026-10-29_*.log` + `2026-10-30_01-33-07.log`, fastflowlm.nix unit config.

## Item 1 — who restarted fastflowlm despite the 01:28:19 socket+unit stop

**Verdict: the zero-restore-lines observation is CORRECT — the guard never restored. TWO distinct
restarters, neither a guard restore:**

1. **Oct 29 22:20:58 kill — the unit's own `Restart = "on-failure"` (fastflowlm.nix:449, RestartSec=60,
   backoff steps).** flm was in a crash-loop era all evening (core-dump failures 20:35:19 → 23:43, ~9 ×
   `Failed with result 'core-dump'`, each followed ~40–100 s later by `Started … backend` with NO
   `Listening on FastFlowLM` line — socket was closed 21:49:56, so these are in-unit restarts, not
   socket activation). The 22:02:34 core-dump failure's restart landed 22:04:17, cold-loaded 25.8 GiB
   total-vm, and was alive at the global OOM kill (`oom-kill … task_memcg=/system.slice/fastflowlm.service,
   task=flm-real, pid=2342482`).
2. **Oct 30 03:20:19 kill — the 01:33:07 deploy's `switch-to-configuration test` re-armed the
   stopped-but-enabled socket mid-transaction** (the documented 2026-09-09 17:19:33 stc re-arm class).
   Timeline: guard trip #4874 zone-1 sockets+sacrifice stop ran 01:26:15 ("action taken" line 01:28:19)
   → deploy launched 01:33:07, stc executed 01:40:26–01:40:30, `Listening on FastFlowLM` 01:40:30
   MID-TRANSACTION → first client connection started the backend 01:43:38 → alive through the kernel
   kill 03:20:19. The deploy's FastFlowLM wedged-backend guard did NOT re-stop after the switch:
   `no recent flm bind errors — backend not in the corpse class` (deploy log 2026-10-30_01-33-07.log)
   — the guard only re-stops in the EADDRINUSE corpse class, so the stc re-arm survived.

Same-day corroboration: the Oct 29 23:37:41 socket re-arm also followed a switch-to-configuration run
(23:32:24 deploy, stc reload lines 23:37:30, `Listening` 23:37:41). **Pattern: owner/guard stops of
fastflowlm.socket survive neither deploys NOR reboots (freeze-#40 strike 4 generalization); the
post-switch guard's corpse-class trigger does not cover the healthy-stopped case.**

**Gap close options (not implemented — policy decision):** (a) extend the deploy post-switch FastFlowLM
guard to also re-stop when the unit was stopped pre-switch (carry a marker file like the corpse guard),
or (b) mask the socket for the boot in the guard sacrifice branch. Queued as follow-up.

## Item 2 — Oct-28 10:14:05–10:15:23 OOM cascade anatomy (9 kill-lines, 78 s)

Trigger context: **global OOM (CONSTRAINT_NONE), free swap 0 kB of 62 GiB**, invoker kswapd0 (×5
invocations) + `tq` (1 invocation, killed the llama-chat victim). Victim table:

| # | time | victim | unit / memcg | total-vm | adj | note |
|---|------|--------|--------------|----------|-----|------|
| 1 | 10:14:05 | bun 3639162 | user@1000.service/app.slice/run-p3639162-i3650853.scope | 6.46 GiB | 1000 | tq-agent-pool era agent scope |
| 2 | 10:14:05 | bun 3403769 | user@1000.service/app.slice/run-p3403769-i3304710.scope | 6.46 GiB | 1000 | same class, second session |
| 3 | 10:14:05 | llama-server 1453 | /system.slice/llama-chat.service (invoker: tq) | 41.7 GiB | 300 | mmap'd model; same victim #38 + #34 killed later |
| 4 | 10:15:23 | chromium 44547 uid 975 | user@975.service/app.slice/**hermes-worker-cron**-f59d5d8cfb7b-exec-….scope | **1.414 TiB** | 300 | the §f.20 class: hermes cron chromium 1.45 TiB reservation |
| 5 | 10:15:23 | chromium 3392891 | user-1000.slice/session-74.scope | **1.414 TiB** | 300 | interactive session scope |
| 6 | 10:15:23 | chrome-headless 3595707 | (same kswapd0 pass as #5 → session-74.scope) | **1.414 TiB** | 300 | |
| 7 | 10:15:23 | chrome-headless 3592942 | (same kswapd0 pass as #5 → session-74.scope) | **1.414 TiB** | 300 | |
| 8 | 10:15:23 | llama-server 2627055 | /system.slice/llama-embeddings.service | 11 MB | 300 | killed at startup, adj-ranked |
| 9 | 10:15:23 | helium 7854 | app.slice/app-org.chromium.Chromium-7854.scope | 53.6 GiB | 200 | the owner's browser |

Feed to §f.20 (hermes-worker-cron chromium anatomy): **4 MORE ~1.45 TiB reservations in this cascade**
(#4 explicit hermes cron exec scope; #5–#7 same total-vm signature in session-74.scope); anon-rss of
all four was ≤1 MB — they were killed on RESERVATION pressure during the swap-exhausted reclaim, not
on resident usage; the reservation mechanism (guard-page mapping pattern) is NOT verified from this
dump and needs a chromium-side anatomy row to pin.

Note the kernel memory-profiling block in the dump: 79.5 GiB folio_prealloc + 14.8 GiB zsmalloc +
7.6 GiB ttm — RAM itself was nearly full before the reservations landed.
