# Freeze #27 unit-level IO attribution — boot -2 (ebad051b, cut Oct 11 11:07:59)

Per-unit/per-PID attribution for the three IO actors the trip-line top-3 deltas could only name as cgroups (trip-line evidence: docs/status/tasks/2026-10-13_00-37_freeze-27-autopsy-evidence.md). Method: `journalctl -b -2` greps per unit/comm in the named trip windows. Pulled 2026-10-13 while boot -2 was still on disk.

## (a) user.slice / session-1386.scope +41.5 GB (trip #2669, window 10:28:44→10:38:56)

- **session-1386 = an SSH login**: `sshd-session[2231466]` accepted lars (ED25519, uid 1000) from **192.168.1.62** port 61665 at **09:00:59**, `Starting session: shell on pts/74` — class `user`, type `tty`. It stayed open to the cut.
- During the trip window, 192.168.1.62 opened **7 more parallel SSH shells** (pts 15/19/23/38/72/49/53, 10:29:31→10:36:41) — the parallel-shell fingerprint of agent/IDE work remoted in from the MacBook.
- **User-side nix clients were hammering the daemon inside the window**: `nix-daemon` logged repeated `accepted connection from pid ..., user lars` (10:29:17, 10:29:31 ×3, 10:30:20…) followed by client aborts — `unexpected Nix daemon error: error: interrupted by the user` (10:30:25, 10:30:41, 10:30:49, 10:36:54). Interrupted flake evals re-run repeatedly = heavy store reads attributed to the session scope.
- **gopls churn**: `stale-lsp-cleanup` killed 6 stale gopls instances (PIDs 820795/820840/833901/833947/857218/857250, running 6–8 min each) at 10:35:41 in the window — language servers indexing large Go trees from those same shells.
- Verdict: the final-hour 41.5 GB writer was **interactive/agent work in the owner's SSH session** (nix client evals + gopls indexing), not a system daemon.

## (b) inboxclean-web 39 GB (07:36) and 64 GB/105-min (09:21) windows

- The unit's journal shows **no large scheduled job** in either window — instead an **IMAP reconnect storm**: first `account reconnected account=main` at **07:46:14** (just after the 07:36 trip window), then continuous churn — **575 reconnects** over the rest of the boot, including **42 in 09:10–09:25** (the 64 GB window).
- Each cycle also shows `GET /health status=503 duration≈8.0s` + `failed to encode health response error="http: Handler timeout"` — the health handler was timing out because the worker loop was IO-saturated; the connection loop kept re-full-syncing the account on every reconnect.
- Verdict: inboxclean-web's IO windows are the **07:46-onward IMAP reconnect/resync loop** (reconnect → resync → timeout → reconnect), starting between the 07:36 and 09:21 trips. Root cause of the initial disconnect not in the journal (no error line before 07:46:14).

## (c) overnight system.slice 27–206 GB/10-min writer (trips #2640–#2660)

- The trip lines already name the per-unit breakdown inside system.slice for the big windows: **tq-agent-pool.service** +146792/+155362/+170928/+182559/+212933/**+389456 MB** (trips #2643–#2659, 00:48→03:54) — this IS the overnight writer; `system.slice` aggregates it.
- tq-agent-pool's own journal explains the volume: **`harvest tick done repos=3 items=1605 enqueued=0 skipped=1605` every ~5 min all night** (47 harvest ticks 00:00–04:00, plus sidecar/review/status sweeps). Every tick rescans all 1605 pool items even though 100% are skipped — a full-state rescan loop burning tens-to-hundreds of GB per window depending on trip spacing (up to 30-min windows: 479 GB).
- Secondary contributors in other windows: **nix-daemon** (+17775/+29020/+27522/+15490/+25103/+26350/+19472 MB, trips #2641/#2646/#2650/#2651/#2653/#2655/#2662 — overnight builds/gc, incl. nix-gc firing INTO the storm at 00:00, already covered by the admission-gate row).

## Follow-on findings

- tq-agent-pool's harvest tick should early-exit on `enqueued=0` history or batch its state read; the rescan-everything-every-5-min pattern alone sustained zone-6 for the whole boot. (Queued in TODO_LIST.)
- inboxclean-web needs reconnect backoff + the health-timeout symptom investigated as an IO-saturation canary. (Queued in TODO_LIST.)

— Session: task 000001a132640f21ff8f7f35197300000000, item 2.
