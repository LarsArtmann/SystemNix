# Memory Emergency Guard regression: llama-embeddings thrash and stall

**Dispatch:** task queue `000001a214f51c65edfb3756006300000000` (REGRESSION of `000001a21402bb6ab7cc4d8fbae700000000`). Error: Gatus `Monitoring/Memory Emergency Guard` failing, first seen 2026-11-25 19:36 CET.

## Verdict

- The previous fix task never landed a fix: both its attempts died at the 30-min deadline in a zai 429 storm (dead-lettered 21:40:50, zero changes). Nothing regressed; nothing had been fixed.
- The check fails because the guard trips Zone 6 continuously (IO PSI some avg60 34-71 % since 19:30, trips #13331 to #13476 by 07:50). Every trip logs `NO eligible headless tree matched the attribution`.
- Landed: `llama-rag.nix` `memoryMax` 2G -> 4G (auto-commit `37c9f5e25`). NOT deployed: sudo is dead in the agent shell (NNP), and sibling sessions owned the deploy lock at 07:20 and 07:29. NOT live-verified.

## Evidence (read-only, unprivileged)

| # | Finding | Command |
| - | ------- | ------- |
| 1 | The guard is alive; every trip is Zone 6 with nothing pausable | `journalctl -u memory-emergency-guard --since '2026-11-25 11:06'` |
| 2 | `llama-embeddings.service` pinned at MemoryHigh 1638 MiB: 10.8M `high` events in 10.5 h (19:36 run), 782k in 35 min (06:58 run), 1.32e9 major faults, 5 TB anon refaults, 362-704 MiB swapped | `/sys/fs/cgroup/system.slice/llama-embeddings.service/memory.{current,high,events.local,stat}` |
| 3 | Its D-state share equals the system IO PSI: 42 % vs 40-48 % (05:5x), 49 % vs 40 % (07:36), 100 samples each | `/proc/<pid>/task/*/stat` state sampling |
| 4 | The guard's own IO-TOP names the unit and cannot act: `llama-embeddings.service @31MB/s [no pattern]` | guard journal 07:50:17, trip #13476 |
| 5 | A real embedding request to `:8848` timed out after 25 s (07:44) | python3 urllib POST `/v1/embeddings` |
| 6 | The working set exceeds even the old hard cap: RSS 1643 MiB + 704 MiB swap; the 19:05 run peaked at 2G + 667M swap | `smaps_rollup`, unit journal |

The old option text claimed "568M-param models need <1 GB; 2G gives headroom". The GGUF alone is 1.08 GiB and the 8192-token KV cache is about 0.77 GiB, so the premise was false.

## What is NOT proven

- That 4G is sufficient. An uncapped control probe (same binary and arguments, port 18448, no memory limit, `VmSwap 0`) did not finish loading the model in 95 s and sat 55 % in D state: model file reads were still crawling (140 MB resident). A second stall driver outside the cgroup limit therefore exists (page reads on `/data`, or the KFD GPUVM path the 07:10 session described). Needs root-level tracing (`/proc/<pid>/task/<tid>/stack`), which agents cannot run.
- The sibling fix `--parallel 1` (auto-commit `0792bfa75`, live since the 06:58 restart) did not stop the thrash: finding 2 is from AFTER that restart.

## Follow-ups (deliberately not harvested: the dispatch budget expired at authoring time; next session harvests into TODO_LIST.md + docs/todo/stability.md)

1. Deploy the 4G ceiling and close out with the question the item asked: IO PSI some avg60 under 40 % and zero Zone-6 trips for 30 min, measured AFTER the switch, not predicted.
2. Trace the uncapped model-load stall with root tooling before touching the ceiling again.
3. Decide whether `llama-embeddings.service` joins the guard's pause patterns (it is a headless llama-server consumer like `llama-chat.service`); the guard currently names it as the IO driver and then reports nothing pausable.
4. The pipeline mislabels a dead-lettered task as "completed, then regressed" (REGRESSION prio 150 from a task with zero changes).
