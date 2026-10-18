# Shodan External-Exposure Monitoring — Advisory Session Status

**Date:** 2026-10-19 01:40 CEST · **Scope:** THIS session only (4 user turns, pure advisory Q&A across two repos) · **Instance:** Crush (glm-5.3-flash)
**Repos touched:** SystemNix (cwd, read-only until this report) + `~/projects/pbx-artmann` (read-only)
**Tree state at report time:** HEAD `692ee0095`; parallel session ACTIVE (dirty `docs/todo/monitoring.md`, `flake.lock`, `bank-sync.nix`, `networking.nix`, its own 01-33 report) — none of it touched by this session.

---

## What this session was

Owner asked how to use Shodan / monitor.shodan.io (or similar) to monitor own infra, then narrowed: "nixos?", then "/home/lars/projects/pbx-artmann ?". Deliverables were four advisory answers. **No implementation was requested and none was performed** — every deliverable so far is prose + verification. The only files this session wrote are this report and the §f direct-follow-up harvest rows (queue + library, per the TODO-system contract).

## a) FULLY DONE

1. **Homelab Shodan advisory (turn 1)** — external-perspective framing delivered: what Shodan can/cannot see for a LAN-bound homelab (`*.home.lan`, Caddy on 192.168.1.x → invisible; value = catching accidental exposure), Monitor setup steps, trigger set, notifier options, CLI commands (`shodan host/alert/stream/scan submit`), caveats (port sampling ≠ full 65,535; CGNAT 100.64.0.0/10 → nothing visible), complements (external nmap, Censys, internal sweeps vs the existing `port-registry-audit.nix`/`gatus-coverage-audit.nix` layers).
2. **Fact verification layer** — repo pre-read confirmed NO prior Shodan/exposure plan in SystemNix docs (41 grep hits, all unrelated "attack surface" prose). `monitor.shodan.io` fetched RAW (notifiers list: Email/Slack/MS Teams/Discord/Telegram/Gitter/PagerDuty/Webhook; Network-Alerts-stream basis; on-demand scans; IP-allowance question deferred to developer dashboard). Deep facts verified against Shodan's own docs (book.shodan.io, help.shodan.io, developer.shodan.io): free tier monitors **0 IPs** (Membership required), triggers incl. `new_service`/`open_database`/`ssl_expired`/`vulnerable`/`malware`/`iot`/`internet_scanner`/`ai`, webhook POST shape, CLI alert/stream surface, curated-port-list scanning + 2025 expansion, monitored-asset daily rescans. Sources + verify date cited in the answer.
3. **pbx-artmann grounding (turn 3)** — repo read before advising: AGENTS.md:1-120 (private repo, Hetzner hel1, **no-SSH-from-assistant**, runtime-file secrets under `/var/lib/telephony-secrets/` + push-secrets.sh sync rule, NetBird control plane + client, Pocket ID SSO, per-action gates), `hosts/pbx/surface-health.nix` read in full (5-min public-probe → `pbx-alert@` relay pattern — the exact pattern to mirror), Wazuh verdict (`docs/reviews/2026-10-16_wazuh-review-verdict.md`: NO for this host; names the REAL gap = the dangling alert-sink row, pbx `TODO_LIST.md` line 297), pbx TODO lines 295-325 read.
4. **Package-attr verification (turn 4, live eval 2026-10-19)** — `nixpkgs#python3Packages.shodan` = **1.31.0** EXISTS; top-level `nixpkgs#shodan` does NOT (error + did-you-mean list proves it). Delivered in the answer with the pin-check caveat.
5. **Zero-damage guarantee** — no file in either repo was modified by this session before this report. Parallel-session dirty state observed, flagged, left alone (concurrent-tree discipline).

## b) PARTIALLY DONE

1. **The "nixos?" question is only half-answered.** Turn 2 loaded the sops skill and started the homelab-side declarative answer; the turn-3 redirect to pbx-artmann cut it. The PBX half (oneshot+timer mirroring `surface-health.nix`, runtime-file key, push-secrets row, UDP caveat, division-of-labor table) was delivered; the **homelab-side NixOS sketch (sops `shodan_api_key`, timer on evo-x2, signal path into textfile-collector/SigNoz) was never delivered**. Closed as harvest row §f.B.1.
2. **Verification is raw only where it matters most but not everywhere.** monitor.shodan.io = raw-fetch verified. Pricing/limits ($49 Membership / 16 IPs) went through the AI-summarizer fetch — per verify-external-claims that is paraphrase, not evidence; hedged with "~" and source attribution in the answer, raw re-check owed before any purchase decision.
3. **Pin compatibility unproven.** 1.31.0 verified on the CURRENT nixpkgs registry only. SystemNix's pinned rev(s) (`fe13242…`/`42966a9…` — attribution to the `nixpkgs` input itself unclear from a quick grep) and pbx's `55bfb4d` (the rev the Wazuh verdict cites) were NOT evaluated.
4. **Self-harvest is happening in this closing pass**, not continuously — the AGENTS.md rule wants §f follow-ups landed at authoring time; they are landed NOW (queue `### monitoring` + `docs/todo/monitoring.md`), so the report and surfaces do not drift, but the latency is the finding, not the compliance.

## c) NOT STARTED

- Any Shodan account-side action (signup, IP adds, triggers, notifier) — owner-gated.
- Any module/unit draft in either repo (offered twice; awaiting word).
- sops secret entry (SystemNix) / `push-secrets.sh` + `generate.sh` row (pbx).
- **IPv6 handling — absent from BOTH answers** (found in self-review; Hetzner hands a /64, home v6 is the classic leak path, Shodan Monitor needs v6 prefixes added separately). Now queued as §f.D.37.
- External nmap sweep, Censys second-opinion, CT-log review, UPnP check — recommended in prose, nothing executed.
- Memory write-back at discovery time (AGENTS.md aggressive-update protocol) — the `python3Packages.shodan` fact and Shodan facts lived only in chat until this report.

## d) TOTALLY FUCKED UP

Nothing was destroyed — the session wrote nothing until this report, so there is no damage class. But called honestly:

1. **The dropped "nixos?" thread.** A directly asked question was silently abandoned mid-answer when the user redirected. The user had to steer ("pbx-artmann ?") to unstick it; the homelab half only gets delivered via this report's harvest row. Class: attention/discipline, zero data damage.
2. **Failed grep silently dropped.** `timers\."` against `modules/nixos/services` returned nothing because the pattern doesn't match Nix's `systemd.timers.<name>` attr form — and instead of re-running with a correct pattern I moved on. The miss cost nothing in the end (surface-health.nix served as the pattern source) but the behavior is the bug.

## e) WHAT WE SHOULD IMPROVE

1. **Close every asked question before pivoting** — a redirect answers "where", not "did you answer the last thing".
2. **Re-run failed searches with a corrected pattern** instead of moving on (`systemd.timers`, not `timers\."`).
3. **Raw-fetch exact-string claims** (prices, limits) — one extra fetch closes the paraphrase gap the verify-external-claims skill explicitly warns about.
4. **IPv6 belongs in EVERY exposure answer.** Both answers missed it; self-review caught it. Make it a checklist item for any attack-surface/exposure work.
5. **Memory write-back at discovery time** — learned facts should land in project docs/queue when discovered, not at report time.
6. **Keep the Q&A-mode discipline** (explained, didn't auto-implement; correct for a "how" question in an owner-deploys repo) — but surface the concrete artifact offer earlier in the answer, not as the last line.

## f) Up to 50 things we should get done next

Brainstorm list (session-derived only, per instruction) — sorted by impact within groups. Only the **§f direct follow-ups marked ★** were harvested into `TODO_LIST.md` + `docs/todo/monitoring.md` (see §harvest); the rest are ROADMAP-class and deliberately not queued.

### A. Shodan SaaS layer (owner-gated)
| # | Task |
|---|---|
| 1 | Decide: buy Shodan Membership (~$49 one-time, 16 IPs — summarizer-verified figure) vs skip and lean on Censys-free + periodic external nmap |
| 2 | Confirm homelab WAN is public IPv4 vs CGNAT (router check, 100.64.0.0/10) BEFORE buying — CGNAT makes the home half of Monitor a no-op |
| 3 | If buying: signup + 2FA on the Shodan account (the account itself becomes an inventory of your assets) |
| 4 | Add pbx IP `/32` to Monitor |
| 5 | Add homelab IP `/32` (only if #2 says public) |
| 6 | Enable triggers: `new_service`, `open_database`, `ssl_expired`, `vulnerable`, `malware`, `iot`, `internet_scanner` |
| 7 | Pick notifier (Email/Discord/Telegram) — align with the still-dangling pbx alert-sink row (pbx TODO line 297) |
| 8 | Baseline the first crawl: export/screenshot the known-good external surface for diffing |
| 9 | Optionally add domain assets (artmann.tech, larsartmann.cloud) for subdomain watching |
| 10 | End-to-end test the alert path (force a `new_service` event via `scan submit` on a temporarily opened port, then close it) |
| 11 | After 1-2 weeks: tune trigger noise, document FP classes in the runbook |

### B. SystemNix homelab declarative (agent-actionable)
| # | Task |
|---|---|
| ★12 | Deliver the MISSING homelab-side NixOS answer (close turn-2's dropped thread) |
| ★13 | Draft the `shodan-audit` oneshot+timer module for evo-x2 (read `docs/agents/*` routing first; SystemNix module conventions) |
| 14 | sops: add `shodan_api_key` (value via sops editor / one-liner pattern; key in yaml AND sops.nix with `optionalAttrs` guard — the 2026-10-17 `sops-key-audit` eval gate catches one-sided adds) |
| 15 | Verify `python3Packages.shodan` at SystemNix's pinned nixpkgs rev (first resolve which locked rev is the `nixpkgs` input) |
| 16 | Decide signal path: textfile collector → SigNoz/Gatus vs plain journald + exit-1 relay |
| 17 | Keep the unit outbound-only; run `port-registry-audit` (no new port literals) |
| 18 | `nix flake check` → owner deploy → post-deploy verify (fresh marker) |
| 19 | One-off internal nmap sweep of 192.168.1.0/24 (the LAN half Shodan cannot see) |
| 20 | Cross-check sweep output vs `lib/ports.nix` + gatus coverage audit |
| 21 | Decide periodicity/ownership of the internal sweep (timer vs manual) `[decision]` |
| 22 | Document the homelab exposure posture (monitoring domain doc) |
| 23 | UPnP/NAT-PMP check on the router (the accidental-forward class) |
| 24 | Router admin-surface review (the one thing Shodan WILL see on a home IP) |
| 25 | rpi3-dns: is 53/udp forwarded publicly? If yes, justify in docs or close it `[decision]` |

### C. pbx-artmann (that repo owns its queue — rows recorded here, drafted from this session's context)
| # | Task |
|---|---|
| 26 | Draft the pbx `shodan-audit` module mirroring `surface-health.nix` (probe → `pbx-alert@`, diff vs `/var/lib/shodan-audit/last.json`, API errors log-only) |
| 27 | Add `shodan_api_key` to `push-secrets.sh` + keep `generate.sh` list in sync (repo rule) |
| 28 | Verify `python3Packages.shodan` at pbx pin `55bfb4d` |
| 29 | External UDP verification of the Telnyx-only SIP/RTP ACL (on-demand `scan submit` or external nmap) — "no 5060 banner from outside" is the proof |
| 30 | Reconcile Shodan-visible set vs `port-audit`'s declared set after the first crawl |
| 31 | Resolve the dangling alert-sink decision (line 297); the Shodan notifier should ride the SAME choice |
| 32 | Document NetBird STUN 3479 / coturn 3478 as expected-visible (known-good baseline, not alert noise) |
| 33 | One-shot testssl.sh vs public vhosts (gates, mail, auth) + `ssl_expired` trigger cross-check |
| 34 | External open-relay + SPF/DKIM/DMARC probe of Stalwart (Shodan sees 25/465/993) |
| 35 | Runbook row for the audit unit (docs/runbooks) |
| 36 | Wire the module into pbx CI/checks if convention requires |

### D. Cross-cutting exposure work
| # | Task |
|---|---|
| ★37 | **IPv6 inventory, both sites** (Hetzner /64 + any home v6 prefix; add prefixes to Monitor if present) — MISSING from both session answers |
| 38 | Censys second-opinion account + both IPs |
| 39 | CT-log (crt.sh) review of artmann.tech + larsartmann.cloud subdomain sprawl |
| 40 | Quarterly full-port external nmap (Shodan samples; nmap enumerates) from a VPS |
| 41 | If Membership declined: GitHub-Actions-scheduled nmap against both IPs as the free external vantage `[decision]` |
| 42 | Optional lightweight tripwires (Canarytokens on the pbx) — the post-Wazuh-rejection lightweight class `[decision]` |
| 43 | Gatus freshness check on the audit marker (stale-audit detection; monitor-of-monitor doctrine) |
| 44 | If this workstream grows: brainstorming/planning doc FIRST (Session Discipline: ratified plan outranks fresh design) |

### E. Session-process fixes
| # | Task |
|---|---|
| 45 | Close asked threads before pivoting (process rule, §e.1) |
| 46 | Re-run failed searches with corrected patterns (§e.2) |
| 47 | Raw-fetch exact-string claims before citing (§e.3) |
| 48 | Write learned facts to memory at discovery time (§e.5) |
| 49 | Raw re-verify pricing/limits before any purchase (closes §b.2) |
| 50 | One review pass over both answers' claims when implementation starts (verification decay check) |

## §f harvest record (direct follow-ups only)

Harvested at authoring time into `TODO_LIST.md` (`### monitoring` queue) + `docs/todo/monitoring.md` (library), no drift:

- **[ready]** Draft the external-exposure (Shodan) audit unit for the homelab side (§f.B.12+13)
- **[ready]** IPv6 exposure inventory, both sites (§f.D.37)
- **[blocked:user]** Owner: Shodan Monitor setup (Membership + both IPs + triggers + notifier) (§f.A.1-10) — library only, per queue rules

Deliberately NOT harvested: §f.B.14-25 (dependent on the owner signup decision), §f.C.26-36 (**cross-repo — pbx-artmann owns that queue**; its alert-sink row already exists at line 297 and must not be duplicated), §f.D.38-44 (ROADMAP/decision-class ideas, not actionable asks), §f.E.45-50 (process notes, absorbed by this report's §e).

## g) Questions I can NOT figure out myself (≤3)

1. **Homelab WAN reality:** is the home connection a real public IPv4 (no CGNAT), and are there ANY port-forwards / UPnP mappings open today? I cannot see the router from here — this single fact decides whether the home half of Shodan Monitor is meaningful at all.
2. **Membership + channel:** buy Shodan Membership (~$49 one-time, 16 IPs), and which alert channel should Shodan AND the pbx alert-sink row (pbx TODO line 297) share — Email, Discord, or Telegram?
3. **Scope + sequencing:** should the declarative audit unit land for the homelab first, the pbx first, or both together — and on the pbx, should its diff-alerts ride the existing `pbx-alert@` relay or wait for the unified sink decision?

---

*Report format: `.md` per the user's explicit path instruction (status-report skill's canonical is styled HTML; override honored and flagged in the closing message). Commits: none by this session (harness forbids without explicit request; auto-commit daemon will pick the files up).*
