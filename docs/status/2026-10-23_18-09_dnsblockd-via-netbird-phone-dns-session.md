# Status: dnsblockd-via-NetBird phone DNS path (single-session report)

**Session window:** 2026-10-23 ~16:30 – 18:09 CEST (this Crush instance only)
**Scope discipline:** per owner instruction, this report covers ONLY what this session did and noticed — no repo-wide sweep. The concurrent deploy-recovery session (its own report: `2026-10-23_17-13_deploy-recovery-full-session.md`) is explicitly OUT of scope; overlap noted where it collided with this session.
**Trigger:** owner connected their phone to NetBird and asked how to use dnsblockd (evo-x2's blocking resolver) from it via the VPN.

---

## TL;DR

The owner's goal — phone uses dnsblockd over NetBird — is **server-side ready and one dashboard step away**, but the session's originally-planned mechanism ("push evo-x2's tunnel IP `100.112.252.86` as the phone's nameserver, widen the dnsblockd ACL") turned out to be **dead by NetBird's design**: the netbird client hijacks every `:53` packet destined to the tunnel IP and refuses everything outside its dashboard-configured matched domains. The ratified plan's original design (nameserver group → LAN VRRP address `192.168.1.53`) is the ONLY working path. One ACL hardening change was implemented, deployed, and verified live — but its original premise ("unlock 100.x recursion") was solving a layer that was never the blocker.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| A1 | **Root-caused why the phone cannot use dnsblockd via the tunnel IP** — NetBird client DNS-management intercepts `:53` destined to the tunnel address; embedded resolver serves only dashboard matched-domains, REFUSES the rest | Proof matrix (all live `dig`): `src=.150 → dst=100.112.252.86 example.com` = **REFUSED** (source-independent); `src=100.112.252.86 → dst=192.168.1.200 example.com` = **NOERROR + recursion** (destination-dependent); netbird journal `client/internal/dns/server.go:779` DNS-management updates firing 07:39→17:36 |
| A2 | **dnsblockd ACL widened with the NetBird CGNAT range** `100.64.0.0/10` in `platforms/nixos/system/dns-blocker-config.nix:202` | Edit + eval OK (`1jxdrvjz…` drv); deployed inside toplevel `z38nwdb…`; live config verified: `/nix/store/cgfqigbz…-dnsblockd-config.yaml` contains `dns_allowed_networks:[…,"100.64.0.0/10"]`; running dnsblockd (pid 770308, started 17:38:45) uses it; daemon-committed as `8ac29818a` |
| A3 | **Deployed to evo-x2** — `readlink /run/current-system` = `z38nwdb…` (anchor-verified) | Switch executed ~17:38 by the concurrent session's deploy (shared working tree carried this session's edit — verified post-switch); dnsblockd restarted cleanly ("startup complete" 17:39:01, 15.4s) |
| A4 | **Corrected the session's own first answer with a live-probe ACL semantics map** — `dns_allowed_networks` gates RECURSION only; local-zone records (`home.lan` incl. wildcard, `larsartmann.cloud` aliases) are served to ANY source | Probes: `gc.home.lan`, `random-unknown.home.lan` (wildcard), `dnsblock.larsartmann.cloud` all answered via the 100.x source; `example.com` REFUSED pre-change |
| A5 | **Re-validated the ratified plan's D5 decision with live evidence** — VRRP DNS VIP `192.168.1.53` held by evo-x2 (fib_trie) and answering recursion (`example.com` NOERROR); routed+masqueraded VPN queries reach dnsblockd as source `.150` (ACL-trusted) | `dig @192.168.1.53 example.com` NOERROR; netbird module `useRoutingFeatures = "both"` (modules/nixos/services/netbird.nix:96) |
| A6 | **Documented the NetBird :53 hijack** as a new section in `docs/services/dnsblockd.md` (proof matrix, consequences a/b/c, netbird v0.77.1 + dnsblockd 8d8aa82 versions) | File committed via daemon sweep by 18:10 (working tree clean) |

## b) PARTIALLY DONE

| # | Item | Works now | Open gap | Blocker / effort |
|---|------|-----------|----------|------------------|
| B1 | **Phone → dnsblockd feature end-to-end** | Server side fully ready: dnsblockd answers recursion from any routed VPN source; `.53` VRRP target verified | The actual dashboard nameserver group (target `192.168.1.53`, scope, distribution to the phone's peer group) is management-plane — NOT configurable from this repo/session; phone end-to-end (roaming, ad-block live) untested | Owner dashboard action + a 5-min phone test (S) |
| B2 | **The "option 1" the owner approved** | ACL widening landed, deployed, live (A2) — defensible as no-masquerade hardening | Its stated purpose ("make the 100.112.252.86 nameserver path work") is MOOT — that path is netbird-hijacked regardless of dnsblockd's ACL; keep-vs-revert decision open | Owner preference; keep is recommended (S) |
| B3 | **Per-device attribution in dnsblockd dashboard** (the original motivation for the 100.x path) | Not achieved via tunnel IP (dead path) | Under masquerade every VPN client collapses into the `.150`/evo-x2 row and shares its 50 q/s rate-limit bucket; no alternative implemented | Accept the loss, or future: per-peer sources require masquerade OFF + ACL 100.x (now possible) + netbird DNS-interception bypass (hard) (M) |
| B4 | **NetBird host-manager journal noise** | Diagnosed: `server.go:779` ERRO on every DNS update (cannot back up read-only NixOS `/etc/resolv.conf`) — harmless, interception works via the firewall path | Not silenced (journal filter / SigNoz rule) — it will fire on every future dashboard DNS edit and looks alarming | M; candidate for a SigNoz log filter or docs-only acceptance |
| B5 | **Post-deploy verification** | Targeted probes done (dnsblockd restart, ACL behavior, `.53` resolver) | Full `scripts/post-deploy-check.sh` battery NOT run by this session | The concurrent session actively owns deploy-recovery tooling right now — deliberately not double-run (S when quiescent) |

## c) NOT STARTED

| # | Item | Why not started | Priority |
|---|------|-----------------|----------|
| C1 | Dashboard nameserver group configuration (see B1) | Management plane; owner-gated by definition | Critical — the whole feature |
| C2 | Phone-side verification: roaming test, `*.home.lan` + `*.larsartmann.cloud` resolution, ad-block evidence in dnsblockd dashboard | Requires C1 + the phone in hand | High |
| C3 | **Android "Private DNS" (DoT) bypass check** — if the phone has Private DNS configured, it can bypass the NetBird DNS push SILENTLY (tunnel still routes, DNS goes DoT to a third party) | Only visible on the phone; asked owner (§g Q2) | High — silent-failure class |
| C4 | `docs/services/netbird.md` service runbook — does not exist; the netbird client's DNS-management layer is now a load-bearing, hard-to-discover behavior | Out of this session's ask; discovered gap | Medium |
| C5 | Harvest of this report's §f into `TODO_LIST.md` + domain libraries | **Deliberately deferred**: (a) owner said "THEN WAIT FOR INSTRUCTIONS"; (b) `TODO_LIST.md` + `docs/todo/stability.md` are mid-edit by the concurrent deploy-recovery session — appending rows now risks clobbering. Recorded here per the AGENTS.md self-harvest escape hatch | Medium — after quiesce |
| C6 | Gatus coverage for the VPN DNS path (plan §"long-term": VPN-side DNS forwarding checks) — noticed absent (no vpn/dnsblock-via-tunnel checks in gatus-config.nix) | Plan marks it long-term; not this session's ask | Low |
| C7 | Second nameserver (`192.168.1.151` rpi3) in the dashboard group for VPN-path DNS failover | Needs C1 first | Medium |

## d) TOTALLY FUCKED UP

| # | What | Severity | Root cause | Mitigation |
|---|------|----------|------------|------------|
| D1 | **The session's FIRST answer asserted unverified behavior**: "queries arriving with a 100.x peer source would be refused by the ACL" — half-wrong (true only for recursion; local records served to anyone). Direct violation of the repo's live-verify doctrine ("never assert a service capability from a doc claim alone"). Caught only because the owner pushed back ("why can't it go via 100.*?") | Medium — wrong model shipped to the owner, cost one turn | Answered from config reading + option-description inference without a single `dig` | None needed — corrected next turn with the probe table (A4). Lesson recorded in §e |
| D2 | **"Option 1" was recommended with a false premise**: sold the ACL widening as the enabler for using `100.112.252.86` as the phone's nameserver. The owner approved and it was implemented — but that path is hijacked by netbird's own resolver at a layer BELOW dnsblockd, so the change never enabled what it claimed | Medium — one unnecessary-but-harmless config change + deploy churn (~50 min wall) | Proposed the fix BEFORE proving where the refusal came from; the early `dig` evidence ("local names answer via 100.x, external REFUSED") was consistent with BOTH hypotheses (source-ACL vs client-interception) and this session picked the wrong one | Change kept as defensible hardening; §e has the process fix |
| D3 | **Over-narrow journal grep hid the answer for ~40 minutes**: the first netbird journal sweep used pattern `nameserver|DNS management|update.*DNS|dns server|custom DNS` — the smoking-gun lines say `failed to apply DNS host manager update…`, which matches NONE of those. A plain case-insensitive `rg -i 'dns'` (run at 17:5x, after the discrimination matrix) found them instantly, timestamps showing DNS config had been active since 07:39 | Medium — the single most costly miss of the session; the root cause was greppable from turn 1 | Pattern tunnel-vision; trusted a hand-picked synonym list over a broad sweep | None — §e item E2 |
| D4 | **Wasted attribution steps during deploy-gate racing**: (a) used LIFETIME `/proc/*/io` counters and nearly concluded the storm was long-running crush sessions (misleading by construction); (b) the live-delta sampler had a pid-path bug (`/proc//proc/N`) that ate one more cycle | Low — ~5 min + noise | Rushed diagnostics while the gate kept refusing; didn't sanity-check counter semantics before citing them | Corrected with a 6s delta sample; storm was parallel nix work from other sessions |
| D5 | **Five deploy attempts over ~50 min for a one-line change**, repeatedly racing the I/O-pressure gate (single-sample polls hit troughs, deploys hit bursts), plus two lock collisions with the concurrent session's deploy | Low — time burn, no harm; gate discipline was correctly never overridden | Waited in single-sample loops instead of requiring a sustained-quiet window from the start; didn't ask the owner (who was present) about the concurrent deploy until late | Sustained-quiet polling (4 consecutive <20% PSI) adopted mid-session; the final switch rode the other session's deploy — acceptable but accidental |

## e) WHAT WE SHOULD IMPROVE

1. **Verify-before-proposing for ANY "why won't X work" answer**: run the discriminating probe BEFORE presenting options, not after the owner picks one. This session's §d D1+D2 are both that one failure. Concretely: when a refusal/timeout is observed, immediately map the source/destination matrix (`dig -b`) — it discriminates client-side interception vs server-side ACL in one command and was decisive here.
2. **Journal sweeps start BROAD**: `-i '<single keyword>'` first, then narrow. Hand-built synonym alternations (`a|b|c`) silently miss the real phrasing (D3). The repo already learned a sibling lesson (`rg -r` flag corruption) — this is the grep-pattern half of "trust your own flags/query before the source".
3. **Treat "REFUSED" as a positive signal early**: a DNS REFUSED means a DNS server actively answered — that fact alone (available from the second probe of the session) excludes firewall drops and points at a resolver that owns the address. Exploited ~40 min late.
4. **VPN client-side interception must be a first-class hypothesis**: whenever a VPN client is in the path (NetBird/Tailscale/etc.), the client may hijack traffic addressed to ITS interface (DNS :53 hijack is a netbird/tailscale-standard pattern). Check the client's management-plane state (journal, dashboard config) before blaming the server-side service.
5. **Sustained-quiet gating for deploys under PSI storms**: single PSI samples race bursts (two refused deploys proved it). Pattern that worked: 4 consecutive sub-threshold samples 15s apart, then fire. Candidate for the deploy script itself — BUT the concurrent session is actively rewriting deploy-recovery tooling; coordinate, don't duplicate.
6. **Deploy-lock courtesy**: when the lock holder is a deploy of the SAME shared tree, follow it instead of re-running (this session lost ~15 min re-running what the other deploy would carry anyway). Candidate: deploy script could detect "holder is alive AND building the same flake" and say so.
7. **Lifetime counters are not rate evidence**: `/proc/*/io` read_bytes/write_bytes are since-process-start. Any IO attribution must be delta-based. (Should be a one-line note in docs/agents/stability.md if not already there.)
8. **Answer-speed vs correctness**: the first turn's answer was fast, structured, and confident — and half wrong. For "why does X not work" questions, the honest first response is the probe plan, not the conclusion.

## f) NEXT TASKS (up to 50, ranked by impact; harvest-deferred per C5)

Legend: Impact / Effort (S<30min, M 30min-2h, L>2h) / Category. Owner-gated items marked 🔒 (management plane or phone-in-hand).

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | 🔒 Dashboard: create/point the NetBird nameserver group at `192.168.1.53` (NOT the tunnel IP — hijacked), distribute to the phone's peer group | Critical | S | Feature |
| 2 | 🔒 Decide nameserver-group scope: "All domains" (full ad-block everywhere) vs matched `home.lan`+`larsartmann.cloud` only (plan D5 default) — see §g Q3 | Critical | S | Decision |
| 3 | 🔒 Verify the NetBird dashboard "Networks" route `192.168.1.0/24` exists with evo-x2 as routing peer AND masquerade ON (never verified from this host; without it `.53` is unreachable from cellular) | Critical | S | Feature |
| 4 | 🔒 Check/disable Android Private DNS (DoT) + any always-on adblock VPN on the phone — silent-bypass class that defeats the whole push (see §g Q2) | High | S | Bug-prevention |
| 5 | 🔒 Phone roaming end-to-end test: cellular → `gc.home.lan`, `dnsblock.larsartmann.cloud`, an ad domain (blocked), `example.com` (resolved via dnsblockd) | High | S | Verification |
| 6 | Confirm in the NetBird dashboard what DNS config was already created today (client applied DNS-management updates 07:39→17:36 — something IS configured; what?) — see §g Q1 | High | S | Verification |
| 7 | 🔒 Import dnsblockd CA on the phone (plan D7) so `dnsblock.larsartmann.cloud` dashboard works from cellular without TLS errors | Medium | S | Feature |
| 8 | Add `192.168.1.151` (rpi3) as second nameserver in the dashboard group → VPN-path DNS failover survives evo-x2 downtime | Medium | S | Feature |
| 9 | Decide keep-vs-revert of the `100.64.0.0/10` ACL entry (§g-adjacent; recommendation: KEEP as no-masquerade hardening) and record the decision in dns-blocker-config.nix-adjacent docs | Medium | S | Decision |
| 10 | Document expected DNS dead-window: all-domains push = phone DNS fully dies when evo-x2 is rebooting (dnsblockd needs ~2-4 min blocklist load after restart) — write into the dashboard-config notes or netbird runbook | Medium | S | Documentation |
| 11 | Silencing decision for netbird `server.go:779` ERRO noise (harmless NixOS resolv.conf conflict; fires on every dashboard DNS edit): SigNoz log filter or documented-acceptance row | Medium | M | Quality |
| 12 | Create `docs/services/netbird.md` runbook (absent today): client DNS-management hijack layer, host-manager ERRO noise, login oneshot mechanics, routing-peer role — links to dnsblockd.md section | Medium | M | Documentation |
| 13 | After the concurrent deploy-recovery session quiesces: harvest §f rows into `TODO_LIST.md` + `docs/todo/{monitoring,services}.md` (C5) | Medium | S | Cleanup |
| 14 | After quiesce: run the full `scripts/post-deploy-check.sh` battery to close this deploy formally (targeted probes already green) | Medium | S | Verification |
| 15 | Verify the daemon commit `8ac29818a` actually contains the ACL line (spot-check `git show` — daemon sweeps are heuristic) | Medium | S | Verification |
| 16 | Rate-limit watch: under masquerade the phone shares evo-x2's 50 q/s dnsblockd bucket — check `dns_rate_limit` counters after a week of phone usage | Low | S | Verification |
| 17 | dnsblockd dashboard "Top Clients" will show all VPN traffic as the evo-x2 `.150` row — either accept and note it, or revisit per-device attribution if a real need emerges (B3) | Low | S | Decision |
| 18 | Sanity-test VRRP interaction: force rpi3 to win `.53` once and verify phone DNS still works via the route (both hosts in-subnet) | Low | S | Verification |
| 19 | Gatus check idea (plan long-term): probe dnsblockd from a wt0-source address (`dig -b 100.112.252.86 @192.168.1.200`) to pin the routed-VPN DNS path in monitoring | Low | M | Monitoring |
| 20 | Consider making the deploy script's pressure gate require sustained-quiet (see §e E5) — COORDINATE with the concurrent session's deploy-recovery work first | Medium | M | Quality |
| 21 | Consider deploy-lock "same-tree holder → follow it" detection (see §e E6) — same coordination caveat | Low | M | Quality |
| 22 | Add the delta-sampling + destination-matrix probes to the dnsblockd troubleshooting section of docs/services/dnsblockd.md (the exact commands that cracked this session) | Low | S | Documentation |
| 23 | Record cross-project lesson (crush-config `references/lessons.md`, by commit): "VPN client DNS interception — probe destination-dependence before blaming server ACLs; journal greps start broad" | Low | S | Documentation |
| 24 | NetBird version note: client runs v0.77.1 (from journal); check upstream changelog for DNS-layer behavior changes before any future netbird bump | Low | S | Maintenance |
| 25 | When the phone group lands: verify dnsblockd OIDC dashboard login works from cellular (Pocket ID passkey + CA trust chain, plan D7 closure) | Low | S | Verification |
| 26 | Consider documenting the phone's expected namespace: plan C7 says `larsartmann.cloud` replaces `home.lan` going forward — confirm which namespace the phone bookmarks should use | Low | S | Decision |
| 27 | NetBird "always-on" app setting on the phone for the DNS push to survive reboots/standby — UX guidance note (phone-side, owner-gated) | Low | S | Documentation |
| 28 | Cross-link this report with the concurrent session's `2026-10-23_17-13_deploy-recovery-full-session.md` after quiesce (shared-tree attribution: their switch carried this session's ACL change) | Low | S | Documentation |
| 29 | If per-device attribution ever becomes a requirement: investigate netbird DNS-interception bypass (query dnsblockd directly at `.200` from the phone browser as a bookmark workaround: `http://192.168.1.200:80` block page reachable via route) | Low | L | Feature |
| 30 | Repo hygiene: knowledge-routing table in AGENTS.md has no netbird row — add one when C4 (netbird.md) exists | Low | S | Documentation |

(Stopped at 30: items 31-50 would be padding — the remaining ideas are already covered by rows above or belong to the concurrent session's scope.)

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **What exactly did you configure in the NetBird dashboard DNS section today?** The evo-x2 client has been applying DNS-management updates since 07:39 — long before the phone connected at 16:38 — so at least one nameserver group (or zone config) already exists. I cannot see the dashboard: what are its target(s), scope (matched domains vs all), and distribution? This determines whether task #1 is "create" or "edit", and whether the phone is currently getting REFUSED responses for unmatched domains.
2. **Does your phone have Android "Private DNS" (DoT) configured, or any always-on adblock/VPN app besides NetBird?** If yes, it will silently bypass the NetBird DNS push (apps' DNS goes DoT to a third party while everything else routes through the tunnel) and the feature will appear broken for no server-side reason. Only visible on the phone.
3. **Scope call: full resolver or local-names only?** "All domains" = ad/tracker blocking everywhere on the phone, but phone DNS dies entirely whenever evo-x2 (or the route) is down; matched-domains = only `*.home.lan`/`*.larsartmann.cloud` come from home, everything else uses the phone's normal resolver (plan D5 default, no blocking). This is a risk/preference tradeoff I can't make for you.

---

**Commit note:** per the status-report skill the report would normally be committed by its own step — the harness forbids commits without explicit owner request, so the auto-commit daemon picks this file up (same handling as the dnsblockd.md section, swept as part of this session's daemon commits).

**Format note:** skill default is a styled HTML dashboard; owner's explicit `.md` path instruction honored per the skill's override rule.
