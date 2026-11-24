# Monitoring tq batch — IPv6 exposure inventory + mail-relay-verdicts live-verify; two landmines fixed; twin-commit footer repair

**Date:** 2026-11-17 18:53 CET · **Scope:** THIS session only (tq batch `000001a1e25b5e0c2310c80ad36c00000000`, 2 items, unsupervised) · **Wall-clock span:** 2026-11-16 04:2x → 2026-11-17 18:5x (long gaps; parallel sessions active the whole time)
**Repos touched:** SystemNix (cwd) · **Instance:** Crush (glm-5.3-flash)
**Tree state at report time:** HEAD `bca66b787`, clean; ~20+ local commits unpushed; foreign takeout + immich sessions landed on top of mine mid-session.

---

## What this session was

One dispatch-queue batch, two items, expected to be a documentation pass + a live verify. Item 1 (IPv6 exposure inventory) was exactly that. Item 2 (deploy + live-verify the mail-relay-verdicts collector wave) turned into a live-verify that found the deployed collector's fail-closed gauge pinned at 1 since the day it shipped, a fixture selftest that had never once built green, and a foreign check breaking every commit's flake-check walk — plus a twin-session commit race that landed my work footerless and needed an attribution repair. All work is landed; the verdict is recorded via `tq verdict`.

---

## a) FULLY DONE

1. **Item 1 — IPv6 exposure inventory, both sites** (`001bc0322`, footer intact): live-probed evo-x2 via procfs (`/proc/net/if_inet6`, `/proc/net/ipv6_route`, `disable_ipv6` sysctls — `ip` is guard-blocked): **no global v6 anywhere** — eno1 fe80-only, `nb-evox2` carries one `fd65:b780:e7dc:d37e::/64` ULA (NetBird overlay, never internet-routable), NO default v6 route, stack ENABLED (so the absence is the router's, not the host's). pbx-artmann read from its repo (no-SSH-from-assistant rule): Hetzner /64 deliberately UNPINNED since the 2026-09-16 recreate (panel-only data; paste-shape recipe lives in hosts/pbx/default.nix) with unconditional `ip6tables DROP` for 5060/5061 pre-staged. rpi3-dns config-corroborated (`dnsIPv6Enabled = false` on both hosts, "no global IPv6" comment). Landed as a new "External-exposure posture (IPv6 inventory)" section in docs/agents/monitoring.md + an agent re-probe recipe + the AGENTS.md routing row extended. **Headline: Shodan Monitor has zero v6 prefixes to register today; per-site wake-up conditions documented.**
2. **Item 2 deploy leg — verified already satisfied**: the wave is LIVE since the 2026-11-13 natural deploy (unit first ran 10:27, journal-verified). No deploy was needed for the wave itself.
3. **Live-verify condition 1 — prom counters sane**: `mail-relay-verdicts.prom` written every 2 min; sent 0 / bounced 48 cumulative (journal-correct) / deferred 0 / window 0 / threshold 0 / last_outcome 3 (no traffic). EXCEPT the one defective gauge — see a.4.
4. **Landmine 1 fixed — the postqueue leg removed** (work commit `007b66a6d`): the leg failed EVERY run since deploy (`postqueue: fatal: Connect to the Postfix showq service: Permission denied`) because postfix's showq socket sits under `/var/lib/postfix/queue/public`, a `drwx--x--- postfix:postdrop` directory the root unit (CapabilityBoundingSet = CAP_FOWNER ONLY — no DAC_OVERRIDE) can never traverse → `node_mail_relay_scrape_errors` was pinned at 1 permanently, i.e. the fail-closed signal was false-alarming forever and masking real failures. Queue depth is already owned by the sibling mail-relay-metrics unit (`mail_relay_queue_messages`, read AS the postfix user, errors=0) — the leg contradicted the module's own one-owner-per-concern split doctrine. Removed from collector + selftest + unit PATH (pkgs.postfix dropped); a regression leg now asserts the metric is ABSENT; zero consumers ever read `node_mail_queue_held_count` (grepped repo-wide before removal).
5. **Landmine 2 fixed — the selftest now BUILDS green**: `mail-relay-verdicts-selftest` was RED in the nix sandbox since 2026-11-12 (14/17 assertions) — this nix sandbox has **NO `/usr/bin/env`**, so the fake journalctl the collector direct-execs died rc=126 (`bad interpreter`). Fakes now use `#!/bin/sh` (sandbox-guaranteed); check builds green (`adxzsfi1m5nw`). It stayed invisible because hook/CI walks are eval-only (`--no-build`) and the commits were unpushed, so CI never ran the build leg. The usb-flap test had already learned this lesson (absolute-bash comment at scripts/test-usb-flap-collector.sh:36) — the 2026-11-12 session missed it.
6. **Foreign blocker fixed on sight**: `prom-tmp-janitor-selftest` (landed by a parallel session earlier 2026-11-16) referenced `pkgs.systemd` unconditionally — systemd refuses to eval on aarch64-darwin, which broke the WHOLE darwin leg of `nix flake check --all-systems`, i.e. the pre-commit hook's walk aborted for EVERY commit in the repo (mine included). Linux-gated it with a named no-op on darwin; both legs eval-verified.
7. **Live-verify condition 2 — SigNoz rule live**: "Outbound Mail Bounced at Relay" found in the live v3 rule set (62 rules): id `01a1d58c-0b99-7499-a997-77496fac5be7`, `ruleType: promql_rule`, `state: inactive` (correct — increase[10m]=0), `disabled: false`. Discovered en route and wrote back to monitoring.md: v3 rule objects carry the name inside the `alert` string and have NO top-level `name` (three jq probe rounds died on `.name` = null before I switched to python3 + raw grep — lesson recorded in §d.3, doc note landed with the report commit).
8. **Twin-commit footer repair** (`3dab2daa1`): a parallel session committed my in-flight item-2 working tree as `007b66a6d` — content complete and honestly messaged, but WITHOUT the Task-Queue-ID footer. Rewriting a mid-stack shared-history commit is off-limits, so a small close-out commit carries the footer and points both queue surfaces at the real work commit. Footer-grep now returns `001bc0322` + `3dab2daa1`.
9. **Follow-up discovered, premise build-verified, queued** (`732eff001`): `migrate-user-tmp-fixture` is sandbox-RED (`USER: unbound variable` at scripts/test-migrate-user-tmp-hot.sh:46 — runCommand has no USER env; `set -u` kills it). Sibling migrate fixtures (hot-db, caddy-logs) + sops-predeploy-selftest build-verified GREEN before queueing. Row landed in TODO_LIST storage + docs/todo/storage.md (edit-both honored).
10. **Verdict recorded** via `tq verdict --file /tmp/tq-verdict-595804869.json` (confirmed 506 bytes) — the only channel.
11. **Self-harvest at authoring time**: the rpi3-dns DNS anomaly found during item 1's probing was premise-verified with a garbage-name control probe and queued into TODO_LIST services + docs/todo/services.md (this commit) — see §d.2.

## b) PARTIALLY DONE

1. **MacBook v6 live probe** — impossible from the agent: ssh publickey-DENIED from evo-x2 (the Mac does not hold this box's key). Inventory carries the honest inference (same LAN, no RA reaching an always-on host ⇒ no global v6) plus the owner one-liner (`ifconfig en0 | grep inet6`). Owner leg.
2. **Item 2's "selftest green in CI"** — delivered to the agent-reachable maximum: the check BUILDS green locally and is in CI's check set, but CI cannot run while the branch is unpushed (never-push rule). Residual: push-gated, named in the row close-out.
3. **Collector-fix activation** — the leg-removal rides the next natural deploy, same semantics as the original wave. Deploy NOT fired this session: IO PSI avg60 ~62% (the memory-emergency-guard's crash-#3-class heartbeat at 04:34 was still active), and the 00:34 attempt had already been refused at the trip-recency gate demanding `DEPLOY_FORCE_PRESSURE=2` — owner-token territory (freeze-#40: a forced switch died into WDT 9 min later). The live unit still runs the pre-fix collector (scrape_errors still 1 until the fix deploys) — expected state, documented.
4. **rpi3-dns direct probe** — skipped after the host-key mismatch on `rpi3-dns.home.lan`; the probe DID expose the real finding (wrong/wildcard answer, now queued) but the v6 posture itself rests on config corroboration + RA inference, not a direct capture.

## c) NOT STARTED

- Shodan Monitor signup, triggers, notifier, prefix registration — owner-gated (and there is literally no v6 asset to register until a leg flips).
- Router-leg v6 (RA/DHCPv6-PD) enablement — owner.
- pbx /64 pin into hosts/pbx/default.nix + the AAAA record — owner (panel-only data).
- The undeployed tree drift (signoz-frontend configurePhase + cv-8dc0d8b FOD hash mismatch killed the 23:34 attempt; pressure gates killed the 00:34 one) — other sessions' waves; I read the deploy logs only far enough to understand whether MY deploy would pass. The 07:41 session's report claims a deploy blocker fixed — I did not verify their fix.
- Any SigNoz/Gatus consumer for the removed held_count — intentionally none; none existed.

## d) TOTALLY FUCKED UP

1. **The twin-executor race happened AGAIN (the 2026-10-18 class) and I fed the window.** A parallel session committed my multi-file, mid-verify working tree footerless while my own commit was mid-hook-walk. Nothing was lost (content complete; repair cheap), but the exposure was mine to shrink: I accumulated collector + selftest + module + queue-tick changes across a LONG verify loop (fix → build check → debug sandbox failure → foreign-blocker fix) without landing pathspec commits between pieces on a tree with KNOWN live twin activity (two daemon carriers had already absorbed my files earlier that hour — that was the warning shot and I kept batching). Commit-early-per-piece would have made the race a no-op.
2. **The rpi3-dns probe fumble — I accepted a wrong explanation one probe away from the truth.** When `rpi3-dns.home.lan` resolved to 192.168.1.150 (evo-x2's IP, not the rpi3's .151, not the .53 VIP) and SSH failed on a host-key mismatch, I wrote "the VRRP VIP path / probe the real .151 directly" into the inventory and moved on. The actual answer — the name is NOT in the local zone at all and the unknown-name wildcard answers with evo-x2 — was one garbage-name control probe away (`.xyz.home.lan` returns the SAME .150). I only ran it at report time. This is the "an empty/odd read is never evidence — validate one known value through the pipeline" lesson, name-resolution flavor.
3. **Discovery-time doc write-back skipped again** (the §e.5 lesson from THIS batch's own source report): the v3 rules payload shape lived in my head across three failed jq probes; only the report pass pushed it into monitoring.md. The source report literally listed this exact behavior as its own finding to fix, and I re-enacted it.
4. **Minor: three probe scripts went to /tmp** (`/tmp/probe*.sh`, `/tmp/debug-selftest.nix`, `/tmp/envtest.nix`) — single-shot and consumed immediately, so nothing was lost, but the /tmp-volatility rule says pipeline artifacts belong in ~/.cache; habit should be by-default.

## e) WHAT WE SHOULD IMPROVE

1. **Twin-batch discipline needs a concrete pre-check**: before accumulating shared-tree state for a tq item, sweep for a sibling executor (untracked files under docs/status/, newest daemon carriers touching YOUR paths, `pgrep -af` for sibling sessions). The plan-marker rule covers plan files; batches have no equivalent marker.
2. **Commit-early on shared trees**: one pathspec commit per completed piece (fix, test, module, ticks) — each is independently revertable and race-proof; the "one commit per item" queue rule can still be met by stacking, since the footer greps.
3. **Build the checks at landing time**: hook/CI walks are eval-only; "eval green" has shipped two build-red selftests this window. New selftest = run `nix build .#checks.<system>.<name>` once before calling it landed.
4. **Control probes before interpreting anomalies**: one known-value check (garbage name for DNS, head -1 for PSI lines, a known boot id for journalctl) through the SAME pipeline, BEFORE building conclusions on an odd reading.
5. **Sandbox-facts reference for fixture authors**: no /usr/bin/env, no USER, fakes need absolute-interpreter shebangs — currently scattered across code comments (usb-flap) and this report; one docs/agents paragraph would prevent the next instance.
6. **Keep the IPv6-in-every-exposure-answer checklist** — it worked exactly as intended (source report §e.4 → this session closed it), and the new inventory section means the NEXT exposure answer starts from facts, not re-probing.

## f) Up to 50 things we should get done next

Grouped, session-scoped only. **Harvest:** ★ = landed in TODO_LIST + domain library by this session; ⚑ = already carried by existing rows/close-outs (deliberately not duplicated); owner-gated items listed for visibility, not queued.

**Direct follow-ups of this session**

1. ★ **rpi3-dns.home.lan answers with evo-x2 (wildcard, record missing)** — add a real host record (.151; sweep lan-router/macbook), control-probe after. Queued: TODO_LIST services + docs/todo/services.md.
2. ⚑ **Deploy the collector fix** (leg removal) — rides the next natural deploy; carried in the ticked item-2 close-outs (a new row would duplicate the closed item's deploy-gated semantics).
3. ⚑ **Post-deploy re-verify: scrape_errors flips 0** on the first fixed-collector run — part of #2's post-deploy battery, named in the close-out.
4. ⚑ **migrate-user-tmp-fixture fix + selftest host-env sweep** — queued `732eff001`.
5. ⚑ **CI green on next push** — implicit; the check builds green locally; named push-gated in the close-out.
6. **Consider a `selftest-build-all` aggregate check** that nix-builds every selftest check, so eval-only walks stop hiding build-red (cost: CI time; candidate for docs/todo/pipeline.md — NOT queued this session, wants an owner cost call).
7. **One docs/agents paragraph on sandbox facts for fixture authors** (no /usr/bin/env, no USER, absolute-interpreter fakes) — candidate for docs/agents/shell-devtools.md or CONTRIBUTING; NOT queued (wants the right doc home decision).
8. **Contributing note: the attribution-commit pattern** for parallel-landed footerless work (footer carried by a follow-up close-out commit pointing at the work hash) — candidate for docs/CONTRIBUTING.md daemon-race section; NOT queued.

**Owner-gated (visibility only — do NOT nag)**
9. Shodan Monitor signup + asset/triggers/notifier setup (the original G-A row).
10. Router-leg v6 enablement (RA/DHCPv6-PD) → then re-run the inventory + register the LAN /64.
11. pbx /64 pin + AAAA `<prefix>::1` (panel data) → then register the /64 in Shodan Monitor.
12. MacBook `ifconfig en0 | grep inet6` one-liner (or authorize evo-x2's key for direct probes).
13. The undeployed tree drift (signoz-frontend / cv FOD waves) — the 07:41 session claims a fix; deploy when pressure allows.

**Build-health / sandbox class (from this session's findings)**
14. Decide the promote-or-not for the usb-flap absolute-bash fake pattern into CONTRIBUTING's test conventions (overlaps #7).
15. Audit remaining `test-*.sh` fixtures for direct-exec'd env-bash fakes (the crude scan flagged candidates; only build-verification separates red from green — three siblings verified green this session, the sweep beyond them is open).
16. The `migrate-user-tmp-hot.sh` script itself may share the unbound-USER hazard OUTSIDE tests (it reads USER under set -u) — the queued row covers the fixture; the production-script half is worth one look when fixing #4.

**Monitoring surface**
17. After the fix deploys: confirm the node_exporter merge no longer carries `node_mail_queue_held_count` (stale frozen textfile cleanup — the tmpfiles janitor handles orphans, but a one-look is cheap).
18. The v3 payload-shape doc note landed — consider extending the post-deploy-check SigNoz probe to assert rule COUNT stability (61→62 drift caught nothing this time, but silent rule loss is the class) — candidate row, NOT queued.
19. The mail-relay SigNoz rule has never fired live (48 bounces were all pre-collector history; window=0 since). One deliberate test fire (the >256-rune alertname Discord probe trick) would prove the paging path end-to-end — candidate row, NOT queued (touches live Discord).

**DNS (from the d.2 finding)**
20. Beyond the rpi3-dns record: decide whether host names (lan-router, macbook) belong in the local zone at all, or whether the wildcard is the documented contract for unlisted names — folds into the queued row's "deliberately accept + document" branch.
21. The evo-x2 /etc/hosts line resolves evo-x2.home.lan → 127.0.0.2 — harmless locally, but confirm nothing publishes that answer LAN-wide (dnsblockd serves the zone, not the hosts file) — one-probe check when touching the zone (#1).

**Session hygiene (small, self-serve)**
22. Move throwaway probe scripts to ~/.cache by default (the /tmp rule) — habit, no row.
23. When a daemon carrier absorbs files mid-verify, commit immediately instead of continuing to batch (operationalized in §e.2) — habit, no row.
24. The inventory's re-probe recipe exists — the NEXT session touching exposure work should re-run it rather than trust the 2026-11-17 snapshot (dates are in the section header) — no row needed, the doc says so.

(24 items; the remaining slots deliberately left empty — everything else noticed this session was either already rowed elsewhere (node_exporter gather-error check, stray-unit warnings, zfs-vm warnings, cv graphrag keys — all pre-existing, unrelated to this batch) or is pure owner-domain. Padding the list would be noise.)

## g) Questions for the owner (max 3)

1. **Deploy authority for unsupervised sessions:** when the gates are green (no pressure trips, quiescent tree, no flock holder), may a tq session fire `nix run .#deploy` on its own — or do you want deploys owner-initiated for the whole stormy season? (This decides whether item 2's residual AND the accumulated tree drift wait for you or not.)
2. **Push cadence:** ~20+ commits are local-only, which is exactly why two sandbox-red selftests shipped invisibly (CI never ran their build legs). Is there a planned push moment, and should sessions treat "CI has never seen this check" as a standing caveat rather than a footnote?
3. **MacBook SSH leg:** do you want evo-x2's ed25519 key authorized on the Mac so exposure inventories (and future cross-host probes) can read it directly — or is host-side probing on the Mac permanently owner-leg?

## Self-harvest record

- §f.1 (rpi3-dns record) → landed in TODO_LIST services + docs/todo/services.md at authoring time (this commit).
- §f.2/3/5 → deliberately NOT re-queued: deploy-gated semantics + push-gated residuals are already carried in the item-2 close-outs (duplicate rows would describe this batch's own work — prohibited).
- §f.4 → already queued (`732eff001`).
- §f.6/7/8/18/19 → deliberately NOT queued: each wants an owner cost/scope call first (listed above for that decision); harvesting them unchecked would park decisions in the dispatch queue where the tq pool would fire them prematurely.
- Everything else: owner-gated visibility only.
