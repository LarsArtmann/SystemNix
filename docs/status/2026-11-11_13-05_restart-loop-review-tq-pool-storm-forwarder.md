# Restart-loop review: dnsblockd verdict, live tq-agent-pool loop, the storm behind both, and the 4.5h forwarder blind spot

**When:** 2026-11-11 ~12:3x→13:3x CET · **Session scope:** owner ask "Review the reported restart loop that is breaking our IO!" — full review of the overnight dnsblockd loop (01-15 report), its fix, its residue rows (08-30 report §f), plus live-state verification. **Three NEW live findings shipped to the owner mid-session: a second restart loop (tq-agent-pool, bounded but page-fatiguing), an ACTIVE Branch-C storm (report-only containment per runbook), and a 4.5h upstream-forwarder outage that NO monitor saw.**

---

## Verdict summary

| Subject | Verdict | Evidence |
|---|---|---|
| Overnight dnsblockd restart loop (the "reported" one) | **FIXED + verified end-to-end** | 600s/660s budget live on deployed unit (`TimeoutStartSec=660s`, current-system AND system-1000-link) + `:-600` default inside the deployed wait-listener script binary; three clean starts today (162.2/129.9/105.7s, all 5/5 phases, NRestarts=0); :53 on UDP+TCP |
| The IO breakage itself | **NOT the loop — a standing multi-session storm** | 10s /proc/*/io delta: buildflow ~37 GB/s combined (write-dominated), 5 concurrent crush sessions (2.5-25 GB/s each), crm-server 17.6, qemu 1.4, gdd 1.2; load 103, CPU PSI 53-64%, IO PSI 40-66%, k10temp 98-99°C with DEEP THROTTLE ENTER live, SEV1 banner (warn-seen) since the tq loop tripped it |
| tq-agent-pool "crash loop" (SEV1 banner since ~08:05) | **Bounded-by-design retry-until-calm, NOT an IO driver** | 183 scheduled restarts since 06:00, gate-refused every time (`maintenance-entry-gate: REFUSE … PSI ≥30%`), ~55ms CPU per attempt (gate refuses pre-start); StartLimitBurst=40/IntervalSec=1800s verified on the rendered unit; the journal "Unknown key 'startLimitBurst' in [Service]" warnings are the KNOWN upstream passthrough bug (services.md row 139, re-confirmed live today) |
| dnsblockd upstream DoT forwarder | **WAS BROKEN 08:23→~12:50 (~4.5h), recovering** | 5177 `forwarder query failed … dial tcp {1.1.1.1,9.9.9.9}:853: i/o timeout` journal lines; live-probed mechanism: cached names answered (google.com via 127.0.0.1 fine) while cold queries and DIRECT egress to 9.9.9.9:53/853 timed out intermittently — 443 to the same IPs worked; intermittent packet loss under load, not a port filter |
| Page fatigue (08-30 report §f.5) | **Already solved — no action** | ~35 OnFailure template fires overnight → exactly **3 Discord sends** (00:51/01:55/02:59): the notify-failure-p0 1/h rate limit worked as designed (journal "sends" ≠ "fires"; counting template starts overstates pages) |
| VRRP failover claim (08-30 §f.3, unverified then) | **Probed: the .53 VIP answers** | `dig @192.168.1.53 auth.home.lan` → 192.168.1.150, rc=0 (mechanism proven; client experience remains owner-only ground truth) |
| Budget-env render (08-30 §f.10) | **Closed as design misread** | `DNSBLOCKD_LISTENER_WAIT_BUDGET` is a TEST SEAM in the script (`${DNSBLOCKD_LISTENER_WAIT_BUDGET:-600}`); production uses the baked default — verified `:-600` in the deployed binary |

## a) What this session did (all verified with fresh commands)

1. **Full live-state verification of the overnight fix** (table above) — including the render legs the 08-30 report left open (§f.10 closed, §f.1 deploy half ticked+reframed to `[watch]` in BOTH queue surfaces).
2. **Found and attributed the live storm** per the Build-Storm Runbook (attribution FIRST, no waiting): pressure bracket → 10s pid-keyed read+write delta → cgroup `io.stat` ranking. Top churners are sibling agent sessions (buildflow, crush ×5, crm-server) + qemu + gdd. tq-agent-pool's 4.4TB R / 4.5TB W boot-cumulative io.stat is its MORNING run (720G/737G over 8h21m, ended 08:05), not current — the gate has refused every start since.
3. **Diagnosed the tq-agent-pool loop chain**: 07:46 gen-999 switch (daemon-reload re-warned the known upstream startLimit keys) → 08:05 deploy-stop: stop-sigterm timed out mid-agent-drain → SIGKILL main → `KillMode=process` leaves ALL children (by design) → gate refuses every restart into the ongoing storm → Restart=on-failure 30s cadence, bounded 40/1800s. Orphans: counterkey mariadbd + 5 postgres wrappers + agent shells, ppid=1, inside the pool cgroup (~8G RAM + 32.7G swap peaks; the 07:20 memcg OOM inside the unit is this class).
4. **Found the 4.5h forwarder outage + its monitoring blind spot**, root-shaped it (cache masks upstream death; "Upstream DNS (Quad9)" carries no alerts), and **landed the durable fix in-tree**: "DNS Forwarder Cold" gatus check (`gatus-cold-probe.example.com` NOERROR probe through 127.0.0.1, 60s, discordAlert; live-verified NOERROR+NODATA via both 127.0.0.1 and 1.1.1.1 before writing it). Targeted eval green (endpoint present in the merged list; alert text passes the no-quotes/backslashes audit by construction).
5. **Closed the residue rows** from the 08-30 report that were answerable today: §f.1 (both surfaces, deploy half ticked, remainder reframed `[watch]`), §f.2 (resolution addenda: 01-15 report + runbook gate section — final count ten, self-heal 03:34@192.7s, fstrim end 04:02/3h32m, budget live, 3 sends, VRRP probe), §f.3 (probed), §f.5 (3 sends, rate limit works — no action), §f.10 (design misread, closed).
6. **Queue hygiene per the no-drift rule**: reframed row + 2 new rows (tq orphans `[blocked:user]`, forwarder check `[blocked:deploy]`) in TODO_LIST AND services.md; todo-system gate PASS.

## b) The storm RIGHT NOW (owner awareness — report-only per runbook §3)

Branch-C conditions are LIVE as of 13:0x: IO PSI some avg10 40-66% (fluctuating with the sibling sessions), CPU PSI ~55%, k10temp 98-99°C with `DEEP THROTTLE ENTER` at 12:48 (60% freq cap, 6 hot ticks in guided), load spiking 103→17 (bursty). The IO-PAUSE guard is DISARMED (1186+ no-match trips — the writers are outside every pausable pattern; the sev1 bridge says so verbatim). **This is the freeze-#39..#50 family recipe.** Per the Build-Storm Runbook containment is report/recommend-only for agents: the named writers are buildflow (pid 1155885), crush ×5 (1023056, 21264, 3593780, 1897723, 3711420/1736455), crm-server, qemu, gdd — kill/stagger decisions belong to the owner (explicit PIDs; never pkill -f). No deploy was attempted from this session (the pressure gate would refuse; forcing into this band is the exact class that killed freezes #40/#49). The dnsblockd loop fix is NOT deploy-urgent — it is already live; today's in-tree additions (the gatus check) ride the next calm-window deploy.

## c) The forwarder outage — mechanism and coverage (the new blind-spot class)

- **Symptom:** 08:23:04 first `forwarder query failed` (google.com via 1.1.1.1:853), 5177 failures through ~12:50; zero successes logged while it lasted; recovering by ~12:5x (cold NXDOMAIN/NOERROR answers resumed).
- **Mechanism (live-probed):** egress to public DNS ports degraded — UDP/53 to 9.9.9.9 AND TCP/853 to 1.1.1.1 timed out while TCP/443 to the SAME IPs completed TLS handshakes; ICMP to 1.1.1.1 100% loss; minutes later UDP/53 to 1.1.1.1 answered. Intermittent, multi-destination, DNS-port-heavy — consistent with storm-driven packet processing starvation (softirq/conntrack under CPU PSI 55-64% + load 100+), NOT a local firewall change (no nft events in the journal; no repo rule matches; the 08:23 onset precedes both today's deploys).
- **User impact:** `*.home.lan` + blocklist answers kept working; PUBLIC cold lookups through evo-x2's resolver failed for hours (browsers degraded for anything uncached; cached popular names masked it).
- **Coverage gap (now fixed in-tree):** "DNS Resolver" (google.com) is cache-blind by construction; "Upstream DNS (Quad9)" has no alerts. The new "DNS Forwarder Cold" check asks a nonexistent subdomain only an upstream round-trip can answer (never positively cacheable; worst case one negative-TTL of detection latency).

## d) NOT done / deliberately not done

1. **No deploy** — storm-gated by policy (§b); all in-tree changes (gatus check) ride the next calm window; the `[blocked:deploy]` row carries the verify steps.
2. **No PID kills, no SIGSTOPs** — runbook report-only containment; the orphaned DBs and storm writers are owner calls (rows queued with explicit PIDs).
3. **Full `nix flake check` not run** — the box is in an active storm (a full check costs ~20GB RSS/4-7min of exactly the load class making it worse); the targeted endpoint-list eval is green and the pre-commit hook will run the eval-relevant gates at commit. Residual risk: none identified beyond the audited alert-text constraint (checked).
4. **gatus OIDC-gate collateral re-count (08-30 §f.19)** — not re-verified this session; the forwarder probe supersedes it in value.
5. **23:34 deploy smoke forensics (08-30 §f.4)** — untouched; row already exists upstream of this session.

## e) Session self-review (the misses)

1. My first IO-attribution pipeline printed NOTHING (second snapshot file empty — loop bug) and I nearly read "no output" as "no churners"; the PSI reading said otherwise and I rebuilt the script. Same class as the 09-26 report's §d.3 mangled-delta incident — the robust rewrite is now in `~/.cache/ioaudit/snap.sh` if anyone wants it.
2. I initially read "35 notify-failure-p0 lines" as 35 PAGES and drafted a dedup proposal — the rate limiter already existed and actual sends were 3. Counting template STARTS instead of script SENDS was the exact "which question does the evidence answer" trap.
3. Two edit-tool calls REPLACED adjacent rows instead of inserting after them (TODO_LIST watch row, services.md startLimit row) — both caught and restored within one step by grepping the target text before moving on. The lesson re-learned: new_string must CONTAIN the anchor row, not follow it.
4. The egress investigation detoured through a "port filter" theory (443-vs-853 same-IP) before the intermittent-success datapoint reframed it as loss-under-load. One more probe round up front (repeat-each-target ×3) would have shown the flakiness immediately.
5. Typed `rg -rln` once (the replace-flag trap) — blocked by the hook before any damage; third-strike banner noted.

## f) Open items (owner-gated, in priority order)

1. **The storm (§b):** shed/stagger the named writer sessions or let them finish; the box is riding 98-99°C with the guard disarmed — freeze-family risk is live.
2. **Orphaned counterkey DBs + KillMode ruling** (row, `[blocked:user]`): kill the mariadbd/postgres orphans once the go-taskqueue session that spawned them is done; rule on a reaper/cleanup contract for deploy-stop orphans.
3. **Next calm-window deploy** carries the gatus check; verify first fire (row, `[blocked:deploy]`).
4. **[watch] rows:** first storm-window dnsblockd start >300s (the budget's first save) — reframed row; server_init-vs-journal.db growth — existing row.

## Harvest record (self-harvest, done at authoring time)

- Reframed the dnsblockd deploy row → `[watch]` in TODO_LIST:3458 + services.md (deploy half DONE + verified; >300s proof open).
- NEW row `[blocked:user]` (TODO_LIST:3459 + services.md tq cluster): orphan reap + KillMode ruling + go-taskqueue dirty-tree note.
- NEW row `[blocked:deploy]` (TODO_LIST:3460 + services.md dnsblockd cluster): forwarder-cold check verify.
- Runbook gate section + 01-15 report resolution addenda (the 08-30 report §f.2 obligation, discharged).
- services.md row 139 gained the live 2026-11-11 re-confirmation (the "Unknown key" warnings at the 07:46 switch; `[Unit]` bound held).
- **Deliberately NOT harvested:** §f.1 owner-storm decision (§f/§b here is the record; no row can act for the owner), the egress-loss upstream question (needs a calm-window re-probe first — if loss persists on a quiet box, THEN it becomes a router/ISP row).
