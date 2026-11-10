# Gateway new-flow-ICMP policing — diagnosis design (2026-11-10, owner-gated evening execution)

Status: DESIGN (not executing — needs an owner evening window + optional switch mirror-port access).
Queue surface: [docs/todo/monitoring.md](../todo/monitoring.md) watch row "Gateway new-flow-ICMP policing" (the banner-symptom lane is CLOSED — this designs the underlying-loss diagnosis only).
Context evidence: 2026-09 evening journal (206 false-OFFLINE shows / 8 h), the 2026-11-09 21:49-21:51 probe-loss window, and [docs/reviews/2026-10-29_19-40_router-configuration-review.md](../reviews/2026-10-29_19-40_router-configuration-review.md) (Compal/Vodafone gateway 192.168.1.1: 1.75-267 ms echo jitter, drops first-ping-after-idle ~1/3).

## The question

Single ICMP echo probes to external hosts (9.9.9.9) drop ~30-50 % during evening windows while dense single-flow bursts pass 100 % and TCP/DNS legs stay instant. The banner ladder already makes this harmless (silent degraded strip), but the LOSS itself is undiagnosed. "New-flow policing" is the working hypothesis, not a finding.

## Hypotheses (falsifiable, cheapest discriminator first)

- **H1 — gateway new-flow ICMP rate-limit** (per-source-IP bucket, stateful): the FIRST echo(s) of a dormant 5-tuple/flow get dropped or deprioritized; an established ping stream is exempt. Falsifier: losses correlate with first-probe-after-idle across MANY external IPs, never mid-stream.
- **H2 — ISP/DOCSIS-side policing or CPE congestion** (upstream of the Compal): loss pattern identical regardless of destination IP and visible in DOCSIS counters (utilization,errored codewords) at loss instants. Falsifier: the mirror leg (below) shows the echo REQUEST leaving but the reply absent at the WAN edge, AND loss correlates with evening utilization peaks.
- **H3 — local NIC/driver (eno1) RX drops**: losses accompanied by kernel `rx_no_dma`/`rx_missed` counters or ethtool drop increments; ping stream from a second LAN device to the same external target is clean at the same instants. Falsifier: second-device control ping is loss-free while eno1 drops rise.
- **H4 — off-path packet-size/DSCP handling** (rare): specific DF/size/DSCP classes dropped. Falsifier: sized/DF-marked probes reproduce loss deterministically.

## Capture plan (one evening window, ~30 min, two concurrent legs)

**Leg A — evo-x2 (no privileged setup needed beyond sudo for tcpdump):**
1. `tcpdump -ni eno1 -w /mnt/hot/icmp-capture.pcap 'icmp and host 9.9.9.9'` (or the probeHost du jour) running continuously.
2. Drive the probe pattern the banner actually uses: a script alternating 5 s single pings (the banner cadence) with 60 s idle gaps and periodic 50-burst streams, for ~20 min.
3. Simultaneously record: `ethtool -S eno1` snapshot before/after, `ip -s link show eno1` (RX errors/drops), conntrack presence of the icmp pseudo-flow, and the gateway-reachability echo series to 192.168.1.1 (is the LAN side clean while WAN probes drop?).

**Leg B — mirror port (owner-dependent, strongest discriminator):**
- Mirror the switch port facing the gateway (or the gateway's LAN port) to a capture host: `tcpdump -ni <mirror-if> -w mirror.pcap icmp`.
- If the mirror shows the echo REQUEST leaving for loss instances but no REPLY → loss is upstream of evo-x2 (H1 verdict narrows to gateway-vs-ISP via Leg B position: mirrored at the evo-x2 access port, a missing reply means the gateway or beyond; mirrored at the gateway's WAN side — if the owner can — gateway vs ISP separates cleanly).
- If the mirror shows request AND reply but eno1 missed them → H3 (local RX drop).

**No-mirror-port fallback (pure Leg A):** the request/reply asymmetry is still decidable from evo-x2 alone by timing: a dropped reply means the request LEFT (kernel sent it — `tcpdump` sees it outbound) and nothing came back; a kernel-level drop means nothing outbound. Combined with the second-device control ping (H3 falsifier) this separates H1/H2 from H3 without touching the switch.

## Metrics to extract (post-capture, jq/tshark one-liners — scriptify once)

- Loss rate: single-probe vs burst-probe vs first-after-idle, per 5-min bucket.
- First-ping-after-idle loss rate vs mid-stream loss rate (the H1 signature — the review's ~1/3 number).
- Reply latency distribution on losses-adjacent successes (policing usually manifests as drop OR timeout-stretch).
- Correlation of loss instants with DOCSIS/gateway utilization if the owner can read the Compal's status page (screenshot/manual note is enough for a design-level verdict).

## Exit criteria

- A verdict row in docs/todo/monitoring.md naming the winner hypothesis + the evidence file paths (pcaps land under /mnt/hot/, NOT the repo).
- If H1 confirmed: decision point for the owner — accept (the banner already absorbs it; legs+ladder exist for exactly this) vs attempt a gateway-side mitigation ONLY IF the Compal exposes a rate-limit knob (the 10-29 review is the inventory of what it exposes; no config changes without owner approval).
- If H3 confirmed: NIC/driver lane (ethtool offloads, kernel bump) — separate TODO row.
- If inconclusive after one window: re-run ONCE with the mirror leg before spending more; two windows is the budget (the banner symptom is already closed — this is curiosity with a cap).

## Safety

- Read-only captures; no gateway config changes from this design; pcaps contain only ICMP headers + LAN IPs — still keep them off the repo (size + privacy hygiene).
- The banner keeps running throughout — the capture must not disable the probe cadence (it IS the stimulus).
