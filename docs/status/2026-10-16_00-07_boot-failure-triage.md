# Boot-Failure Triage — 2026-10-15 23:29 Boot (session report)

**Report time:** 2026-10-16 00:07 CEST · **Session type:** live diagnosis (no code changes)
**Scope:** the 23:29:xx boot of `evo-x2` + self-review of this session's diagnostic work ONLY.
**Trigger:** owner question "What failed on boot?" → "other things?" → root-cause + improvement asks.
**Format note:** written as `.md` at explicit owner demand (status-report skill default is HTML; override honored, flagged).

---

## Verification basis (everything below was probed live this session)

| Claim | Evidence command | Result |
|---|---|---|
| tq-agent-pool gate refusals | `journalctl -b -u tq-agent-pool` | 40× "REFUSING to start: io PSI some avg10=92–96% >= 30%", `start-limit-hit` 23:50:01 |
| IO storm source = concurrent agent session | `/proc/*/io` delta sampling (6s) | pid 239584 `crush -y` ≈ **407 MB/s**; pids 281176/281803/287846 `go test -race -shuffle=on ./...` + linker ≈ 130 MB/s combined; `/proc/pressure/io` still 85–88% at 00:07 |
| gitea-runner CREDENTIALS chicken-and-egg | live unit `/etc/systemd/system/gitea-runner-evo\x2dx2.service:25` | `LoadCredential=token:/run/forgejo-runner/token` — `/run` is tmpfs, systemd's CREDENTIALS step runs **before** the ExecStartPre that creates the token |
| …fails every boot | `journalctl -b -1` | same 5× `Failed at step CREDENTIALS` + `start-limit-hit` at 22:37:18 (prior boot) |
| …why gen-898 looked healed | docs/todo/services.md:511 + journal | 2026-10-15 20:30 session fixed the STATE_DIRECTORY leg and saw a clean 20:22:01 start — but that was a **switch**, `/run` (and the token) survived; the reboot(s) after wiped it and re-broke the unit via the still-live CREDENTIALS leg |
| searx fatal boot fetch | `journalctl -b -u searx.service` | 23:29:48–54 ClearURLs rule fetches fail (`curl: (28) Resolving timed out after 3000ms` ×4) → `init()` raises → exit 1 ×5 → `start-limit-hit` 23:33:37 |
| :8888 listener is NOT searx | `ss -ltnp` + `lib/ports.nix:38` | `signoz-collector-metrics = 8888`; no searx socket unit exists — searx is genuinely down |
| btrbk-data = expected tripwire | journal + `ls /data/.repair-done` | gate self-describes as the documented P0 tripwire; marker absent live |
| Gatus coverage | `journalctl -b -u gatus` | SearXNG alerts fired 11×, tq alerted 23:55; runner only covered by the generic `node_systemd_unit_state{state="failed"} == 1` SigNoz rule |
| fail2ban degraded | journal + pgrep | 1.1.1 on python3.14, `filtersystemd` `AttributeError('NoneType'.wait)` loop, idle after 100 errors |
| Kernel clean | `journalctl -k -b -p err` | zero entries; no OOM/watchdog/segfault events |

---

## a) FULLY DONE

1. **Full failed-unit census of the boot** (distilled from journal): tq-agent-pool, gitea-runner-evo-x2, searx, btrbk-data (expected), discordsync (timeout ×2, recovered, `/healthz` 200 verified), home-manager-lars (failed once, self-healed 23:29:56), sway-audio-idle-inhibit (core-dump, user session), plus one-shot noise (service-health-check ×2, nix-build-cleanup, inboxclean-sync, forgejo-github-sync, eventcatalog-pull, openseo, site-monitor, activitywatch-theme) and fail2ban/gkr-pam noise.
2. **Root-caused the live IO storm**: not a service, but a concurrent Crush agent session running `go test -race` batteries (~400 MB/s sustained). The tq PSI gate refusing 40× was correct behavior under this load.
3. **Root-caused gitea-runner as a recurring every-boot failure** (CREDENTIALS-before-ExecStartPre on a tmpfs credential) and reconstructed why the 20:30 gen-898 close-out didn't survive the reboot.
4. **Root-caused searx**: fatal online fetch (ClearURLs rules) inside `init()` under cold-boot DNS; 5 restarts → start-limit; confirmed genuinely down and confirmed Gatus is already alerting.
5. **Verified btrbk-data failure is the documented P0 tripwire** (marker absent, journal self-identifies).
6. **fail2ban degradation characterized** (filter idle since 23:47:02).
7. **Improvement set proposed** (volatile-credential eval gate, searx DNS-gate extension, tq gate/start-limit interaction) — harvested to TODO at report time (see §f).

## b) PARTIALLY DONE

1. **gitea-runner fix**: designed (persistent `tokenFile` under `/var/lib/forgejo`, mode 600 — current write is chmod **644** on a live registration token, `_forgejo-scripts.nix:1478`) but NOT implemented; offered to owner, not executed.
2. **searx recovery**: procedure known (`reset-failed` + start once DNS warm) but agent shells cannot run systemctl — owner action pending.
3. **fail2ban**: recommended jail-backend impact audit; not performed.
4. **Cross-boot recurrence check for searx**: checked runner across boots, only inferred searx's (DNS-cold-boot dependence); not verified per-boot.

## c) NOT STARTED

1. The runner tokenFile code change + deploy + first-boot verification.
2. searxng mitigation beyond restart (vendored rules / DNS-gate extension / upstream issue — upstream work must pass verify-before-filing).
3. Eval-time lint for volatile `/run` credential sources.
4. tq gate-vs-StartLimit design (gate refusals burning the start budget until the unit is stuck).
5. fail2ban filter recovery or backend switch.
6. Any CHANGELOG rows (none earned — no tree changes beyond this report + TODO harvest).

## d) TOTALLY FUCKED UP (self-review, honest)

1. **I contradicted evidence I had already seen.** First reply claimed tq-agent-pool would "come up on its own retry too" — the same journal output showed `start-limit-hit` at 23:50:01. It CANNOT self-recover; it needs `reset-failed` (or a reboot). Textbook violation of the repo's "assert WHICH question your evidence answers" rule; corrected only at 00:0x during report verification.
2. **Knowledge-routing violation**: I never opened `docs/services/searxng.md` / `forgejo.md` runbooks before proposing fixes. The searxng runbook (line 22) already documents this exact class ("Engine init never retried … DNS-gate `mkDnsGate` in ExecStartPre ensures DNS is ready") — my "going forward" proposal partly re-invented an existing mitigation instead of identifying the gap in it (the gate didn't cover the tracker-pattern fetch path / passed while resolution still timed out).
3. **Two broken measurement one-liners before a correct one**: (a) cgroup `io.stat` awk produced all-zeros (wrong field parsing), (b) `/proc/*/io` join sorted on the wrong key, printing cumulative bytes as deltas. No wrong number reached the owner, but two round trips burned and the first outputs looked plausible enough to mislead.
4. **Speculation before verification**: initially floated "socket activation masks searx" for the :8888 listener before checking ownership (it is signoz-collector-metrics). Resolved in-turn, but it is the 2026-10-05 "a verified label must cover every fact asserted" anti-pattern.
5. **Session-start context debt**: the 20:30 gen-898 runner report (services.md:511) was only found at report time. A content-pin (`git log --stat` since last known rev) per the multi-agent write discipline would have surfaced it in turn 1 and sharpened every claim about "fails every boot".
6. Minor: used `cat`/grep pipes on unit files instead of the view tool.

## e) WHAT WE SHOULD IMPROVE

1. **Volatile-credential eval gate**: the eval layer catches sops-key misses but not `LoadCredential=` sources under `/run/` whose writer is the unit's own ExecStartPre (chicken-and-egg). A mount-gating-audit-style lint would have caught the runner class at eval.
2. **Gate refusals vs start-limit**: a healthy PSI gate turned into a stuck-failed unit after 40 refusals. Gated refusals should not consume the restart budget (raise `StartLimitBurst` for gate-refusing units, or add a PSI-clear reset path).
3. **Boot-time external fetches stay fatal** in searxng; the existing DNS gate needs to cover (or make non-fatal) the tracker-rules path, or rules should be vendored.
4. **Boot-failure digest**: this entire triage ran because the owner asked. A tiny failed-units-diff-vs-previous-boot digest (post-boot oneshot → journal/Discord) would surface start-limit units (searx, runner, tq) without an owner question.
5. **Secret hygiene**: a live runner registration token written mode 644 — credentials generated at runtime should default 600.
6. **Session discipline**: runbook read BEFORE proposing (routing table), content-pin at session start, verify claims against already-fetched output before sending.

## f) Next things to get done (session-derived; 1–9 harvested at report time, 10+ pre-existing cross-refs)

1. **[ready→harvested] gitea-runner persistent tokenFile** (kill the every-boot CREDENTIALS failure; chmod 644→600).
2. **[blocked:deploy] Deploy + first-boot verify the runner fix** (restart, `journalctl -u gitea-runner` clean, runner declares).
3. **[blocked:user] tq-agent-pool: `systemctl reset-failed tq-agent-pool && systemctl start tq-agent-pool`** once io PSI avg10 < 30% (agent shells can't systemctl).
4. **[blocked:user] searx recovery**: `systemctl reset-failed searx && systemctl start searx` once DNS warm; verify Gatus SearXNG resolves.
5. **[ready→harvested] searxng boot-fetch mitigation design** (extend mkDnsGate coverage / vendor ClearURLs rules / non-fatal init) + cross-boot recurrence check.
6. **[ready→harvested] Eval lint: volatile LoadCredential/EnvironmentFile sources** with same-unit ExecStartPre writers.
7. **[ready→harvested] tq gate/start-limit interaction design** (burst exemption or PSI-clear reset path).
8. **[ready→harvested] fail2ban audit**: which jails ride the systemd backend while the filter is idle; do bans still fire; upstream compat check (verify-before-filing if an issue is drafted).
9. **[ready→harvested] Codify the live PSI-storm attribution probes** (/proc/pressure, /proc/*/io deltas, cgroup io.stat) into docs/agents/stability.md — this session's method, reusable.
10. Pre-existing, do not duplicate: CHANGELOG row for gen-898 wave2 (services.md:511) — this report's findings extend it with the CREDENTIALS leg.
11. Pre-existing: STATE_DIRECTORY colon-list hardening sweep (services.md:512).
12. Pre-existing: eval-time forgejo-family marker-condition assertion (services.md:327) — same "structurally close the class" spirit as f.6.
13. Verify the generic failed-units SigNoz rule actually pages on runner-class failures (it evaluated `node_systemd_unit_state{state="failed"} == 1` every minute this boot — confirm the alert condition, not just the query).
14. Boot failed-units digest oneshot (§e.4) — decision on channel first.
15. `docs/services/tq.md`: document that gate refusals count against start-limit (found the hard way, §d.1).
16. Consider RestartSec/start-budget tuning guidance for any future PSI-gated service.
17. If the concurrent `go test -race` session is routine, consider running heavy agent test batteries with `ionice`/cgroup IO limits so they stop tripping the tq gate for hours.
18. fail2ban: if the systemd backend proves broken on python3.14, decide backend=file vs upstream pin.
19. Re-check searx on a warm-DNS reboot to confirm the failure is boot-order-only (fold into f.5 verification).
20. Owner decision: bundle the runner fix into the next planned deploy window vs immediate.

## g) Questions I cannot answer myself

1. **Is the concurrent `crush -y` / `go test -race` session (pid 239584 + children, ~400 MB/s) yours and expected?** Wait it out, throttle it, or kill it — it is the entire reason tq stays gated and deploys would pressure-block.
2. **Deploy now or bundle?** Implement the runner tokenFile fix and deploy immediately, or hold for the next planned window (the runner has been boot-dead since at least the 22:37 boot)?
3. **fail2ban posture**: tolerate the idle systemd-filter (jails unaffected pending f.8 audit), or preemptively switch the affected jails to a file backend?

---

*Self-harvest executed at authoring time: TODO_LIST.md (### services ×5, ### stability ×1) + docs/todo/services.md (7 rows incl. 2 [blocked:user], 1 folded [blocked:deploy]) + docs/todo/stability.md (1 row). No tree/code changes were made this session — diagnosis only. Waiting for instructions.*
