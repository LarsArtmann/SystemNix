# Status report — AI fleet demand profile (spiky vs continuous classification)

**Window:** 2026-11-14 ~06:15-07:00 CET, session task 000001a1d5d871644a2dac5d586a00000000 (item 4).
**Method:** ClickHouse HTTP (:8123, `signoz_metrics.samples_v4 ⋈ time_series_v4`) — per-day and
per-hour request deltas of `ai_meter_requests_total` over 2026-10-17→11-08 (full retained window,
longer than the asked 7 days). This also ANSWERS the research follow-up premise ("ai-meter meters
the API proxy, maybe not local llama-server traffic"): local services routed through the proxy
(paperless→llama-embeddings, paperless-gpt→llama-chat/flm) ARE metered; the browser extension's
direct :8104 nsfw traffic is NOT.

## Verdict table

| service | baseline | burst | classification | residency verdict |
| --- | --- | --- | --- | --- |
| llama-embeddings (:8848) | 8-11 req/h continuous trickle | ~1,500 req/h sustained 14h days; 18,127 peak hour (2026-11-05 20:00); daily totals 154-700 normally vs 13,415-18,205 on backlog days (11-05/06/07) | **spiky, burst = re-embed backlog** | keep resident; extract the burst into the calm-window batch job (design landed same session: docs/planning/2026-11-14_06-15_re-embed-calm-window-batch-design.md); the query trickle never justifies a cold reload |
| llama-chat (:8850) | ~0/h most hours | tens-hundreds/day (800 max, 2026-10-31) | **spiky / idle-dominant** | socket-activation/idle-stop is mechanically justified BUT the 23.4 GB cold load makes idle-stop a ~20 GB re-read per wake — the standing disable-or-pin owner decision owns this; demand data does not force a change |
| fastflowlm (flm) | ~950/day on 2026-10-19/20 only | — | **no live demand** (unit disabled since the crash-loop class; paperless-gpt's flm lane stopped 2026-10-20) | stays disabled; socket-activation already the design if re-enabled |
| nsfw-classifier (:8104) | **unmeasured** | — | premise CONFIRMED: extension hits :8104 directly, no ai-meter coverage — journal/ai-meter cannot yield its rate | boot-resident + timer-batch unchanged; metering needs a proxy route or a collector (not queued — polish) |
| crush→zai (cloud, control) | 2k-12k/day, 37k peak hour (11-02) | — | continuous agent demand | irrelevant to residency (remote upstream) |

## Verdict for the fleet

**llama-embeddings is the only resident whose demand shape argues a change — and the change is the
batch-job extraction, not socket-activation**: its 8-11 req/h baseline keeps the server resident,
while its 1,500 req/h backlog bursts are the storm engine (they coincide exactly with the
645 GB-write window of the attribution report, same session). llama-chat's idle profile is
dominated by its cold-load cost, an owner tradeoff already queued as a decision row.
