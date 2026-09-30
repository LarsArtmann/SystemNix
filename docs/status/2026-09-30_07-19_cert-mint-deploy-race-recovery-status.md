# Status: cert-mint First-Deploy Failure, Root Cause, Recovery (deploy-vs-fix-commit race)

**Session window:** 2026-09-30 06:30–07:19 CEST · **Host:** evo-x2 · **Scope:** heal the 05:50 failed deploy + its docs fallout. Per instruction, this report covers ONLY this session's run and what it directly noticed — no other research.

---

## Timeline (all 2026-09-30 CEST)

| Time | Event |
| --- | --- |
| 05:50 | User's `nh os switch` deployed rev `10602885` → exit 4: `dnsblockd-cert-mint` 226/NAMESPACE → `caddy` fail-closed (by design) → `browser-history-agent` + `oauth2-proxy` cascade. **Profile left unanchored** (profile → old `b1sp3h1pk`, `/run/current-system` → new `dz3w03nr`) |
| 06:11 | The cert-mint fix session's commit landed (`d22ccd48`, rode a daemon batch): `RuntimeDirectory = "dnsblockd-certs"` + absolute store paths — **20 min AFTER the deploy snapshot** |
| 06:30–06:35 | This session: root-caused (deployed rev lacked `RuntimeDirectory`; source + fix verified in tree via `nix eval …serviceConfig`); profile-unanchored confirmed |
| 06:37 | Deploy attempt #1 → pressure gate exit 12 (IO PSI some avg10 31.6%, disks 12.2%) |
| 06:41–06:43 | PSI sampled draining (avg10 44.6 → 10-12) → deploy attempt #2 fired into the window |
| 06:46 | Attempt #2 → gate exit 12 again (avg10 46.5%, **busy 0.5%, D-state list EMPTY** — gate's phantom branch fired with zero corpses) |
| 06:48–06:51 | Ground truth: ALL automounts answer real IO; memory pristine (PSI-mem 0, zram 27%, 80G avail); bursty churn storm (avg10 10↔65, avg60 12→50), guard `trips_last_hour=5` → doctrine says queue, not race |
| 06:52 | Asked the owner (force / wait / pause tq pool). **Owner chose `DEPLOY_FORCE_PRESSURE=1` and ran the deploy themselves** |
| 07:00 | Deploy landed: profile **anchored** (`ss2mli9l`, system-805), `/run/dnsblockd-certs` created by RuntimeDirectory, mint succeeded |
| 07:01–07:05 | Live verification (below) all green |
| 06:56–07:07 | Docs fallout landed: AGENTS.md lesson (`7e08861c`), pipeline.md evidence append (`ac472fcb`), CHANGELOG correction (`d4fd0b22`) |

---

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| **Root cause identified**: first live cert-mint activation deployed rev `10602885`, which predated the RuntimeDirectory fix (`d22ccd48`, +20 min) — a **deploy-vs-fix-commit race** on the shared tree, not a code bug | `git show 10602885:modules/nixos/services/caddy.nix` has `ReadWritePaths` but no `RuntimeDirectory`; fix commit diff `d22ccd48` adds 7 lines incl. `RuntimeDirectory` |
| **Fix verified in-tree before redeploy** | `nix eval --json .#nixosConfigurations.evo-x2.config.systemd.services.dnsblockd-cert-mint.serviceConfig` → `"RuntimeDirectory":"dnsblockd-certs"` present |
| **Recovery deployed** (owner-forced through the pressure gate) | profile anchored: `/run/current-system` == `/nix/var/nix/profiles/system` → `ss2mli9l` (system-805) |
| **Dual-zone TLS live-verified** | `auth.home.lan/.well-known/openid-configuration` serves JSON over the minted cert; `dash.larsartmann.cloud` serves the PapDashboard UI over a valid `*.larsartmann.cloud` SAN (LAN-bypass direct render, as designed from the box) |
| **Cascade units converged** | `browser-history-agent`: 07:01:37 "Finished", heartbeat accepted; `oauth2-proxy`: 200 `/ping` to Gatus every 30s since ~07:03 (self-healed via Restart=always) |
| **AGENTS.md lesson recorded** (Net VPN cert-mint bullet): deploy-vs-fix-commit race rule — confirm the deployed rev *contains* the fix commit (`git merge-base --is-ancestor`) before a new unit's first live deploy; cascade-failure semantics; unanchored-profile warning | commit `7e08861c`, content grep-verified in tree |
| **CHANGELOG falsified claim corrected** ("fixed before any evo-x2 deploy" was wrong — the deploy beat the fix) — names both corrected surfaces per the surface rule | commit `d4fd0b22` |
| **Pressure-gate phantom-branch evidence appended** to the EXISTING pipeline.md item (no duplicate queued): both of today's trips fired with an EMPTY D-state list; second trip at busy=0.5% most plausibly the gate's own eval tail | commit `ac472fcb` |
| Session doc edits confirmed daemon-committed (no uncommitted drift) | grep hits 1/1 for both lesson strings; `git status` clean at 07:19 |

## b) PARTIALLY DONE

| Item | Works | Open | Blocker | Effort |
| --- | --- | --- | --- | --- |
| **Pressure-gate classifier fix** (multi-sample busy% before "corpse-pile" attribution) | Item exists in `docs/todo/pipeline.md` (harvested from the 05:43 report); today's double-trip evidence appended | The fix itself (3×2s io_ticks sampling in `scripts/pre-deploy-check.sh`) is NOT implemented — nothing dispatched | Queued `[ready]`, not agent-dispatched yet | S |
| **Post-recovery monitoring sweep** | The endpoints I probed directly are green (caddy, oauth2-proxy, agent, both TLS zones) | Gatus check set (caddy-metrics :2019, CV :8098, the three outage-red checks) not individually re-verified green — they self-heal on interval, but nobody looked | Low value once intervals elapse; no blocker | S |
| **NetBird Phase 2 readiness** (the deploy's headline feature this cert work serves) | Gated client module evals + `checks.cloud-domain` green; cloud zone DNS + TLS + mirror vHosts now LIVE-proven end-to-end | NetBird client itself stays OFF until the Phase-2 setup key exists in sops (`netbird_setup_key`) — owner-gated | Owner must create the setup key | S once key exists |

## c) NOT STARTED

| Item | Why not started | Still wanted? |
| --- | --- | --- |
| Per-zone split for `trips_last_hour` (I could not tell WHICH zones fired in the last hour — zone counters are cumulative only) | Observability gap noticed at 06:51, not built | Yes — cheap, high diagnostic value (S) |
| Gate self-eval-tail attribution (sample PSI immediately before AND after §1's eval to distinguish the gate's own churn) | Folded into the existing classifier item's scope; not implemented | Yes (S) |
| External (non-LAN) verification of the oauth2-proxy forward-auth path + cloud vHosts | Impossible from the box (LAN bypass by source IP); needs a client outside 192.168.1.0/24 | Yes — owner's Mac is the natural probe (S) |
| Standing agent-deploy policy after gate trips (today's force was an ad-hoc owner decision) | Waiting on owner decision (see g3) | Yes — policy, not code |

## d) TOTALLY FUCKED UP

**Nothing in this session.** This session HEALED the fucked-up thing:

- **The 05:50 deploy** (not this session's work) shipped a rev missing the fix its own verification session had already validated locally — web stack dark ~70 min, unanchored profile (reboot-revertible window) 05:50→07:00. Root cause is a **process gap, not a code defect**: nothing checks "does the rev I'm deploying contain the commits my fix sessions just landed". Mitigation now: AGENTS.md race rule + the re-deploy; the check is still manual (see f-items).

## e) WHAT WE SHOULD IMPROVE

1. **Deploy-vs-fix-commit race is undetectable today.** §1c prints "deploying HEAD" but nothing compares HEAD against fix commits landed minutes earlier by parallel sessions. Suggested: after any same-day "first live deploy of a new unit", a one-line `git merge-base --is-ancestor <fix> <deployed-rev>` habit — or a deploy.sh WARN when HEAD advanced within the last 15 min while a new unit's first activation is in the diff.
2. **The pressure gate's phantom branch fires on evidence-free attribution.** Both trips today printed an EMPTY D-state list while claiming "corpse-pile signature" — the second at busy=0.5% while the gate's own multi-minute eval had just churned the box. A mislabeled attribution costs an operator round-trip (it did, twice). Fix: multi-sample + require an actual corpse to use the word "corpse".
3. **"VM/RUNTIME-verified" claims must carry a deploy-timeline caveat.** The 05:42 status report + CHANGELOG said "fixed before any evo-x2 deploy" — falsified within 10 minutes. A close-out cannot know a deploy is coming; the claim should be scoped ("as of <time>, no deploy has carried the pre-fix rev") or the deploy should be awaited.
4. **Cascade units pollute the §6 failed-units review.** 6 generic WARN rows, of which 5 were symptoms of one root cause. A root-cause-aware grouping (down-dependency detection) would shrink the review surface at exactly the moments pressure is highest.
5. **nh-direct deploys skip every deploy.sh guard** (reset-failed, provisioner restarts, pressure gate, anchoring check, smoke). Today that worked out, but the anchoring failure mode is exactly what deploy.sh detects and nh-direct does not. Decide: bless nh passthrough or document it as emergency-only.
6. **Canonical textfile-collector path cost a failed grep.** `/var/lib/prometheus-node-exporter/textfile_collectors` is nowhere in AGENTS.md; I probed two wrong paths first. One line in AGENTS.md ends that class.

## f) Next tasks (up to 50, session-grounded, ranked; ★ = queue-worthy, rest are ROADMAP fuel)

| # | Task | Impact | Effort | Category |
| --- | --- | --- | --- | --- |
| 1 | ★ Pressure-gate: 3×2s io_ticks multi-sample before any "corpse-pile" attribution; empty D-state list must downgrade the wording to "unattributed churn" (evidence appended to existing row) | High | S | Bug |
| 2 | ★ Zone-split `trips_last_hour` (per-zone gauges with a 1h window) in memory-emergency-guard — today's triage couldn't tell Zone 6 from memory zones | High | S | Feature |
| 3 | ★ AGENTS.md one-liner: canonical textfile dir `/var/lib/prometheus-node-exporter/textfile_collectors` (in the monitoring gotcha area) | Low | S | Documentation |
| 4 | ★ deploy.sh: WARN when a first-activation new unit is in the diff AND HEAD moved <15 min ago (deploy-vs-fix-commit race detector — codifies today's lesson) | High | M | Feature |
| 5 | ★ NetBird Phase 2 go-live: create setup key → sops `netbird_setup_key` → flip `services.netbird-client` → deploy → verify tunnel (owner-gated; cloud zone now proven) | High | S | Feature |
| 6 | ★ External-path verification: from the Mac, hit `https://dash.larsartmann.cloud` + one protected vHost to prove oauth2-proxy external forward-auth + cloud whitelist end-to-end | Medium | S | Quality |
| 7 | ★ Sweep Gatus to all-green post-outage (caddy-metrics, CV, and the outage-red set); file anything stuck red | Medium | S | Quality |
| 8 | ★ §6 failed-units review: group cascade units under their root dependency (down-caddy detection) to shrink deploy-time review noise | Medium | M | Quality |
| 9 | Decide standing agent-deploy policy post-gate-trip: never-force / force-on-outage / ask-first (today's precedent) | High | S | Decision |
| 10 | Decide nh-direct deploy stance: bless, or document as emergency-only with the anchoring caveat | Medium | S | Decision |
| 11 | CONTRIBUTING: add the deploy-vs-fix-commit race to the Daemon-race commit policy section (cross-link the AGENTS.md rule) | Medium | S | Documentation |
| 12 | Close-out template: forbid unsScoped "before any deploy" claims; require deploy-timeline-anchored phrasing | Medium | S | Documentation |
| 13 | §12 "ExecStart binary not built yet" warnings: pre-build unit-script derivations before §12 or drop the 3 known-benign rows | Low | S | Quality |
| 14 | §11 vendorHash probe: detect buildGoModule-ness properly instead of 6 permanent "unable to determine" WARNs | Low | S | Quality |
| 15 | Gate trip message: don't print an empty "top D-state processes:" header; print "none found" | Low | S | Polish |
| 16 | Geometrikks post-deploy smoke (timescaledb_toolkit + postgres restart rode this deploy; geometrikks.service started new — nobody smoke-checked it after) | Medium | S | Quality |
| 17 | Gitea-runner post-restart check (PATH-contract change rode the same window; runner registration unverified since) | Medium | S | Quality |
| 18 | Pocket-ID full client-login flow probe post-restart (discovery verified; an actual OIDC round-trip wasn't) | Medium | M | Quality |
| 19 | Quiescent-deploy guidance: daemon commits landed DURING the 05:50 eval — document the (rare) mixed-eval risk + "let the daemon batch settle" habit | Low | S | Documentation |
| 20 | `notify-failure@`: collapse cascade storms into one root-cause page (today: 3 units × rate-limited pages for one broken mint) | Low | M | Feature |
| 21 | Cert-mint deploy.sh wiring decision: document why it is NOT in the provisioner list (boot + caddy-wants converge it) or add an is-active-gated block | Low | S | Documentation |
| 22 | Observe the minted cert rotation at the NEXT reboot once (365d leaf, first reboot-mint on the anchored gen) — one-time checklist line in net-vpn.md | Low | S | Documentation |
| 23 | Consider `boot.binfmt.preferStaticEmulators = true` (the AGENTS.md flagged follow-up that removes the `/run/binfmt` sandbox dependency — resurfaced by today's §1 warnings about eval-environment fragility) | Medium | S | Feature |
| 24 | ROADMAP: per-incident "deploy ledger" (rev + fix-commit containment check) so first-live-deploy incidents are structurally improbable | Low | M | Feature |
| 25 | ROADMAP: IO-churn observability — per-session/per-cgroup IO attribution on a 5-min cadence (today's attribution was cumulative-counter archaeology) | Medium | L | Feature |
| 26 | ROADMAP: tq pool quiet-hours scheduling option (shifts agent churn off interactive hours; owner decision) | Low | M | Feature |
| 27 | ROADMAP: gate classifier v2 — require corroborating evidence (D-state OR real disk busy) before ANY attribution label, not just the corpse-pile one | Low | M | Quality |
| 28 | ROADMAP: post-deploy "prior-incident recovered" probe — when §6 listed failed units pre-switch, post-deploy smoke re-probes exactly those units | Low | M | Feature |
| 29 | ROADMAP: `nix eval` self-churn marker (the gate's own eval can spike PSI; a before/after sample pair would self-attribute) — merged with #1 if implemented together | Low | S | Quality |
| 30 | Verify nothing else rode the unanchored window: `last -x` + journal for any 05:50–07:00 reboot attempt (none expected; one-liner audit) | Low | S | Quality |
| 31 | Add `dash.larsartmann.cloud` (and 2-3 sibling cloud vHosts) to post-deploy-check §smoke as TLS+body probes (the mirror has no smoke today) | Medium | S | Quality |
| 32 | dnsblockd: confirm `*.larsartmann.cloud` resolves on rpi3 too (failover parity was the design; only evo-x2 was live-verified today) | Medium | S | Quality |
| 33 | CHANGELOG/AGENTS drift check on the cert-mint lesson in 2 weeks (docs-health VERIFY pass — the race rule is new and unexercised) | Low | S | Documentation |
| 34 | If the gate classifier fix (#1) lands, add the 2026-09-30 06:37/06:46 double-trip as its regression fixture | Low | S | Quality |
| 35 | Run `checks.caddy-mint` once more from THIS tree before the next deploy (fix verified live, but the check hasn't re-run since `d22ccd48`'s test tweak) | Medium | S | Quality |
| 36 | Consider surfacing `trips_last_hour` on the sev1 notify tier boundary (5/hour is storm-adjacent; today nobody was notified) | Low | M | Feature |
| 37 | Document in net-vpn.md: what a 226/NAMESPACE cert-mint failure looks like in `nh` output (symptom → root cause → recovery, 5 lines) | Low | S | Documentation |
| 38 | Audit whether any OTHER ReadWritePaths-without-RuntimeDirectory units exist fleet-wide (grep the module tree; the eval-time audit may already cover it — verify, don't assume) | Medium | M | Quality |
| 39 | Gatus: add a check that fails when `dnsblockd-cert-mint` result != success (currently only caddy-down + OnFailure see it) | Low | S | Feature |
| 40 | cert expiry metric (365d leaf — emit `system_caddy_cert_days_left` from the textfile collector so the boot-mint dependency stays visible) | Low | S | Feature |
| 41 | ROADMAP: single "web-stack health" composite (caddy + cert + oauth2-proxy + one vHost per zone) to shorten outage triage | Low | M | Feature |
| 42 | Re-check profile anchoring after the NEXT natural deploy (today's was forced; confirm the unanchored class didn't leave residue in boot entries) | Low | S | Quality |
| 43 | `nix run .#pre-reboot-check` before the next planned reboot (the unanchored window is closed, but the audit is cheap insurance) | Low | S | Quality |
| 44 | Harvest this report: items ★1-★8 into TODO_LIST + their domain libraries; the rest stay here as ROADMAP fuel (docs-health HARVEST, on instruction) | Medium | S | Documentation |
| 45 | CHANGELOG: the corrected cert-mint entry should get its final "recovered + live-verified" status confirmed at the next docs pass (it currently ends at 07:00 recovery) | Low | S | Documentation |
| 46 | ROADMAP: explore IO-cost attribution for `nix flake check` in the gate (§1 eval vs measured PSI; informs #29 and the gate's self-noise) | Low | L | Feature |
| 47 | Tighten the AGENTS.md race rule with the positive command (`git merge-base --is-ancestor d22ccd48 10602885`-style example) — it currently names the verb only | Low | S | Documentation |
| 48 | Verify the daemon committed the CHANGELOG correction cleanly (it landed as `d4fd0b22` mid-session; confirm no later sweep rewrote it) | Low | S | Quality |
| 49 | ROADMAP: pressure-gate escape UX — when the operator overrides, auto-record the override + PSI context into a state file for forensics (today's rationale lives only in this report) | Low | M | Feature |
| 50 | Sleep on it: re-read this report tomorrow and prune items that were storm-night anxiety, not signal (the skill's own advice against entombing noise) | Low | S | Cleanup |

**Harvest note:** per the status-report skill, (f) is HARVEST input. NOT harvested yet — instruction was to wait. ★-marked items are the queue-worthy subset; the rest route to ROADMAP or die here.

## g) Questions I cannot answer myself

1. **Was the 05:50 deploy knowingly raced ahead of the in-flight cert-mint fix session?** You pushed `10602885` and deployed while that session was still verifying (its fix landed 06:11, and the session's own CHANGELOG line believed "no deploy had happened"). If the deploy timing was intentional, the fix is a hard rule (never deploy while a verification session owns the tree); if accidental, the fix is the deploy.sh HEAD-drift detector (f4). I cannot infer which.
2. **Are the recurring IO churn bursts (today: avg10 10↔65%, guard trips_last_hour=5, driver = tq pool + parallel crush sessions) acceptable steady state** — or do you want the tq pool's max-per-tick (currently 3) / daily budget tuned, or quiet-hours scheduling? Stability-vs-agent-throughput is your call; I can only measure it.
3. **What is the standing agent-deploy policy after a pressure-gate trip?** Today you forced through (right call for a 70-min web-stack outage, and it landed clean). Should agents (a) never force, (b) force on user-facing-outage class, or (c) always ask first (today's pattern)? This decides how the next gate trip ends.

---

*Evidence: deployed rev `10602885` (broken), fix `d22ccd48`, lesson `7e08861c`, gate-evidence `ac472fcb`, CHANGELOG correction `d4fd0b22`, recovered generation `ss2mli9l` (system-805). Verification probes: `auth.home.lan` OIDC discovery (TLS), `dash.larsartmann.cloud` (TLS + render), `browser-history-agent` journal 07:01:37 Finished, `oauth2-proxy` /ping 200s, `/run/dnsblockd-certs` 0750 caddy:caddy, profile anchor readlink equality.*
