# llama-vlm-cap: live treadmill cycle + swap-overuse verdict (owner ask session)

**Scope line — VERIFIED this session (live commands):** S-0035 probe set (PSI bracket + pid-keyed 6 s IO delta + cgroup `io.stat` ranking), two `/proc/vmstat` swap-rate windows (20 s + 15 s), per-cgroup `memory.swap.current` ranking, `mm_stat` fill, `busctl get-property` unit states, bounded `journalctl -u` tails (≤30 lines), `readlink /run/current-system` + deployed-unit grep, newest deploy-log tail. Boot `783f2d13-346c-4239-b7ba-5692fc513d41` pinned (the freeze-#56 recovery boot, ~4.6 h uptime at probe time).

## a. The treadmill re-fired LIVE on the undeployed config

Journal timeline (`journalctl -u llama-vlm-cap.service -n 30`):

- 19:12:14 — cap started (prior cycle); lifecycle Consumed line at stop: **29 min 41 s wall, 15.5 s CPU total, 11.5 G memory peak, 9.1 G read from disk, 63.4 M memory swap peak** — near-zero CPU over 29 min = the model sat resident while visionreviewd's 10-min `/v1/models` probes kept it "used" for systemd but not for the idle check.
- 19:41:55 — `llama-vlm-cap-idle` TTL stopped the backend (no "processing task" in the keepAlive window; the live-bridge check missed the probes: each probe starts AND finishes a bridge between two 5-min idle-check runs).
- 19:42:14 — a probe re-activated it **19 s later**; the deployed (Nov 7 gen) psi-wait-gate began WAIT-ing: **21 consecutive checks at IO PSI some avg10 81-99 %** (630+ s of the 900 s budget consumed at capture time, ~19:52).
- Deployed unit confirmed WITHOUT the refuse flag: `grep ExecStartPre /etc/systemd/system/llama-vlm-cap.service` → `--psi-max 30 --max-wait-sec 900` (no `--on-exhausted refuse`). At budget exhaustion (~19:57) the deployed behavior **proceeds**: a 9.1 G GGUF read into a pinned-99 %-PSI storm — the exact freeze-#56 fatal step (13:10:49 reload, 35→75 % PSI), ~4 h 45 m after the freeze.
- e4b cycles the same treadmill: loaded 15:44:42 → idle-stopped 15:56:47 (12 min resident, **8 G read**, 248 KB swap peak, 6 s CPU).

## b. Attribution snapshot at ~19:5x (the box was NOT calm)

`/proc/pressure/io`: some avg10 99.0 / avg60 98.7 / avg300 97.7 (sustained ≥5 min through the whole probe window). Pid-keyed 6 s deltas: `nix` pid 3382356 **279.9 MB/s** (argv: `nix flake check --no-build` — a live eval walk from a concurrent session/tq leg, the AGENTS.md-known 20 GB-RSS/4-7 min class), `crush -y` sessions 77.4 + 20.8 + 8.7 MB/s (sibling agent sessions), `cvagent` 23.2 MB/s. tq: 0.2 MB/s — the owner's "not tq" hypothesis is confirmed for this window too. llama-vlm-cap contributed **zero** IO at probe time (held in start-pre; its damage is the cyclical 8-9 G bursts in §a, not a continuous reader). Both drivers are true at once: the treadmill adds a 9 G burst every ~30-40 min on top of whatever the session fleet is doing, and during reload phases under contention the load itself stretches to 26 min of maximum-rate reads.

## c. Swap verdict — the owner's "are we over-using swap?"

Numbers at ~19:5x, boot 4.6 h:

- zram fill **91.8 %** (57.3/62 GiB used; `mm_stat` orig 61.2 GB, compressed 23.1 GB, physical 23.5 GiB, ratio 2.65×) — above the 90 % Gatus ZRAM-Fill alert line (Discord has been firing).
- Live churn is THRASH, not cold storage: `pswpin` **60.7 → 79.3 MiB/s** and `pswpout` **66.5 → 59.5 MiB/s** across two windows (~130-139 MiB/s aggregate in+out simultaneously), while memory PSI some avg10 only 2.9-4.8 % / avg300 7.5 % and MemAvailable 49.6 GiB.
- Holders (`memory.swap.current`): **user-1000.slice 49.1 GiB (85 % of all swap)** — the interactive agent-session fleet (crush -y heaps, helium, niri, dms); tq-agent-pool 6.3 GiB; geometrikks 1.8 GiB; monitor365-server 1.2 GiB; llama-vlm-cap/e4b negligible (63 MB / 248 KB swap peaks — the models live anon-resident and exit clean).
- Verdict: **yes — the box is over-using swap in the churn sense, and the victim class is the user slice, not the AI stack.** The 2026-09-02 precedent (97 % fill healthy) had PSI ~0.26 and NO churn; today's 91.8 % rides 130+ MiB/s round-trips and freeze-#54's exact lineage (user slice swapped 60 G at peak). The designed fix — `MemorySwapMax=48G` on user-1000.slice — landed in-tree 2026-11-14 and is **undeployed** (deployed gen = `26.11.20261107.f4a03c0`, Nov 7): the running kernel carries NO swap cap on the fleet that holds 85 % of the swap. Two stacked fix waves (freeze-54 + freeze-56) sit behind the pressure-gated deploy while the storm both fuels and is fueled by them. zram sizing itself is NOT the problem (generous zram is free; compression holds at 2.65×); the cliff class is zram-full + resident model (freeze #1) — at 91.8 % fill with an 11.5 G-anon cold load scheduled every ~30-40 min, that margin is thin.

## d. Fix landed this session (local fallback half of the treadmill fix)

`modules/nixos/services/llama-vlm.nix` idleCheck: a new leg counts ANY bridge-unit journal line inside the keepAlive window as keep-alive (`journalctl -u 'llama-vlm-<name>@*.service' --since "<keepAlive> ago" -n 1`), so visionreviewd's 10-min probes keep the model resident instead of cycling it. This is the documented local fallback (fix-wave closeout finding 9) for the `[blocked:push]` upstream leg (docs/todo/stability.md row 52, extended; deploy-verify leg 3 added to row 48). Verification: `nix eval` of the rendered `llama-vlm-cap-idle` ExecStart rc=0; idle-check derivation built (shellcheck green); rendered script carries the leg verbatim (`--since "2h ago"` for cap). Deploy-gated with the refuse-mode wave — until it deploys, the deployed gate still proceeds after budget.

## f. Follow-ups + harvest dispositions

1. **Deploy the two stacked fix waves in the first calm window** (refuse mode + idle-check widening + freeze-54 MemorySwapMax + .prom publish gate). Existing rows own it (row 48 `[blocked:deploy]`, row 322 re-run rule). Agent cost: one `nix run .#deploy` at IO PSI some avg10 < 20 sustained. NOT re-harvested — rows 48/322 already carry it; this report extends row 48's verify list.
2. **Owner immediate action (expires once refuse deploys):** while the storm persists, `sudo systemctl stop llama-vlm-cap.socket llama-vlm-cap.service` (and e4b) stops the reload cycle at the socket — the 2026-08-22 lesson: the sacrifice is not real until the SOCKET is down; stopping the service alone lets the next probe re-arm. Owner-gated (agent shells hold no systemd mutation rights; busctl mutations polkit-denied; sudo dead in agent shells 2026-11-17 restated). Deliberately not queued as a durable row — it self-expires at deploy time.
3. **Upstream visionreviewd PR** (probe = keep-alive or backoff while unhealthy): row 52 `[blocked:push]` — unchanged, still the origin-level fix.
4. **`nix flake check --no-build` during a pinned-99 % PSI storm** (280 MB/s pid 3382356): a live instance of the freeze-#56 §f.34 build-battery question (PSI-aware dispatch gate `[decision]` row) — a flake check is an eval-class battery, the row's ask covers it; noted there via this report's citation rather than a new row (the decision row already names the layering question).
