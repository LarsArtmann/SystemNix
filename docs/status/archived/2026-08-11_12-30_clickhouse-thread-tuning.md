# Status: ClickHouse Thread & Background Pool Tuning

> **⚠️ ANNOTATION (2026-08-13):** `background_pool_size=2` was REVERTED in commit `116051ee`. It triggered cascading ClickHouse `MergeTreeSettingsImpl::sanityCheck()` failures that caused exit code 36 and start-limit-hit, blocking all deploys. The sanity checks validate that `number_of_free_entries_in_pool_*` settings (defaults: 20, 8, 25) must be less than `background_pool_size * concurrency_ratio` (2*2=4). An eval-time assertion was added to `signoz.nix` to prevent recurrence. The other 5 pool reductions remain in effect and are safe. See `docs/status/2026-08-13_01-50_clickhouse-merge-tree-sanity-check-fix.md` for full details.

**Date:** 2026-08-11 12:30
**Session scope:** Reduce ClickHouse CPU/thread footprint on evo-x2 (shared homelab box)
**Status:** Config written and evaluated. NOT deployed. Diff is surgical (15 lines added, zero formatting churn).

---

## a) FULLY DONE

1. **Researched the nixpkgs clickhouse module** — Fetched the actual module source from the locked nixpkgs rev (`f13ff45`). Discovered it exposes four options: `serverConfig` (YAML), `usersConfig` (YAML), `extraServerConfig` (raw XML → `config.d/200-*.xml`), `extraUsersConfig` (raw XML → `users.d/200-*.xml`).

2. **Correctly identified the config-file split** — The single most important correctness decision:
   - `background_pool_size` and the other `*_pool_size` settings are **server-level** → `extraServerConfig` (`config.xml`)
   - `max_threads` is a **user/profile** setting → `extraUsersConfig` (`users.xml` `<profiles><default>`)
   - Putting `max_threads` in `extraServerConfig` silently does nothing.

3. **Inspected the running process (PID 1318)** — 434 threads. Broke down by thread prefix:
   - `MergeMutate`: 16 (default `background_pool_size=16`)
   - `BgSchPool`: 37 (default `background_schedule_pool_size=128`)
   - `Fetch`: 16 (default `background_fetches_pool_size=8` — **zero replicas exist!**)
   - `BgBufSchPool`: 16, `BgMBSchPool`: 16, `BgDistSchPool`: 16, `BgStrmSchPool`: 16
   - `Move`: 8 (default `background_move_pool_size=8` — single NVMe, minimal TTL moves)
   - `ThreadPool`: 192 (general query execution pool)

4. **Corrected my own mistake** — Initially claimed background schedule pools "don't pre-allocate threads." The 434-thread count proved this wrong — ClickHouse pre-creates pool threads at startup. The idle pools (Fetch, Move, BgBuf) hold ~76 threads doing nothing on a single-node setup.

5. **Applied all 6 settings** to `modules/nixos/services/signoz.nix`:

   | Setting                                      | Default      | New | File         | Kills                           |
   | -------------------------------------------- | ------------ | --- | ------------ | ------------------------------- |
   | `background_pool_size`                       | 16           | 2   | `config.xml` | 14 MergeMutate threads          |
   | `background_schedule_pool_size`              | 128          | 8   | `config.xml` | ~29 BgSchPool threads           |
   | `background_buffer_flush_schedule_pool_size` | 16           | 4   | `config.xml` | 12 BgBufSchPool threads         |
   | `background_move_pool_size`                  | 8            | 2   | `config.xml` | 6 Move threads                  |
   | `background_fetches_pool_size`               | 8            | 1   | `config.xml` | 15 Fetch threads (no replicas!) |
   | `max_threads`                                | (auto=cores) | 2   | `users.xml`  | Caps per-query parallelism      |

   **Expected result:** ~76 idle threads eliminated from background pools + 14 from merge pool = **~90 threads gone, 434 → ~344**.

6. **Verified config evaluates** — `nix eval --raw` confirms all 5 server settings and the users profile setting are present with correct values and port interpolation (9181, 9234).

7. **Diff is surgical** — 15 lines added, 0 deleted, 0 formatting churn. The earlier `nix fmt` run reformatted the entire 800-line file (alejandra style drift) and was correctly reverted.

---

## b) PARTIALLY DONE

Nothing — config is complete, just not deployed or validated at runtime.

---

## c) NOT STARTED

1. ~~**Deploy** — Requires ClickHouse restart. `nix run .#deploy`.~~ done at `b81e5094`
2. ~~**Post-deploy runtime verification**~~ done at `b81e5094` — `clickhouse-client -q "SELECT name, value, changed FROM system.settings WHERE name IN (...)"` to confirm settings applied.
3. ~~**Thread count re-check**~~ done at `b81e5094` — After deploy, `ls /proc/$(pidof clickhouse-serv)/task | wc -l` to confirm thread reduction.
4. **24-48h monitoring for `Too many parts`** — Merge starvation signal if `background_pool_size=2` can't keep up with ingestion.
5. **AGENTS.md gotcha entry** — ClickHouse config-file split.

---

## d) TOTALLY FUCKED UP

1. **`nix fmt` reformatted the entire 800-line file** — First time running `nix fmt` in this session, it reformatted signoz.nix from its existing style to alejandra's preferred style (410 insertions, 409 deletions). This would have destroyed git blame for the entire file. **Caught and reverted** — `git checkout HEAD -- modules/nixos/services/signoz.nix` then re-applied only the surgical edits. Lesson: `nix fmt` is a project-wide formatter, not a per-edit tool. For surgical changes, match surrounding style manually and skip the formatter.

---

## e) WHAT WE SHOULD IMPROVE (self-critique)

1. **`nix fmt` is dangerous for surgical changes** — It reformats every file that doesn't match alejandra's current preferred style, even files unchanged in years. For targeted edits, skip it or use a more targeted formatter.

2. **No `nix flake check --no-build`** — Still haven't run it. `nix eval` on individual options passes, but the full system config check is more thorough.

3. **No Gatus monitoring for query latency regression** — If `max_threads=2` makes SigNoz dashboards slow, there's no alert.

4. **Did NOT consider `max_concurrent_queries`** — The actual query-concurrency limiter (default 100). Matters more than `max_threads` for multi-query CPU bounding.

5. **`background_fetches_pool_size=1` not 0** — Set to 1 to avoid potential zero-size pool edge cases. Unverified.

---

## f) Up to 50 things we should get done next

> **Note:** Items below were harvested into TODO_LIST.md / ROADMAP.md where actionable. Done items are struck through.

### Immediate (this change)

1. ~~Run `nix flake check --no-build` for full syntax validation~~ done at `b81e5094`
2. ~~Deploy: `nix run .#deploy`~~ done at `b81e5094`
3. ~~Post-deploy: `clickhouse-client -q "SELECT name, value, changed FROM system.settings WHERE name IN (...)"` to verify
4. ~~Post-deploy: Re-check thread count~~ done at `b81e5094`: `ls /proc/$(pidof clickhouse-serv)/task | wc -l`
5. ~~Post-deploy: Check logs:~~ done at `b81e5094` `journalctl -u clickhouse -n 50 --no-pager`
6. Watch for `Too many parts` errors over 24-48h
7. Add AGENTS.md gotcha entry: ClickHouse config-file split

### ClickHouse tuning (deeper)

8. Consider `max_concurrent_queries` (default 100 → 16 for single-user SigNoz)
9. Consider `max_memory_usage` per-query cap
10. Consider `max_execution_time` to prevent runaway queries
11. Review SigNoz data retention TTLs
12. Check ClickHouse disk usage breakdown

### Monitoring & alerting

13. Add Gatus check for SigNoz query latency (not just liveness)
14. Add Gatus/log alert for ClickHouse `Too many parts` errors
15. Add Gatus check for ClickHouse merge backlog
16. Monitor thread count as a Prometheus metric after the change

### Tooling lessons

17. Document the `nix fmt` danger in AGENTS.md — it reformats entire files
18. Verify pre-commit hook handles formatting correctly

---

## g) Questions I CANNOT figure out myself

1. **What's the actual SigNoz query latency today?** I don't know if dashboards are already slow or snappy. You'd need to open SigNoz and time a dashboard load. This determines if `max_threads=2` is aggressive or conservative.

2. **Do you want me to deploy this now?** Restarting ClickHouse causes a brief SigNoz outage. The settings only apply on restart. I need your go-ahead.

3. **Is `nix fmt` supposed to be run on every change, or only as a separate cleanup pass?** It reformatted 800 lines of unchanged code. Is the repo mid-migration to alejandra style, or should I never run it on surgical edits?
