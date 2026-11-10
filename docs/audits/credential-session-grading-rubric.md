# Credential & session management — grading rubric

_Why this exists: the 2026-11-09 CV audit graded its subject with a
self-invented rubric, making "superb" unauditable and cross-service claims
incomparable. This rubric fixes the dimensions, weights, and evidence
classes ONCE so future audits (quarterly cadence, see
`docs/todo/services.md`) score against the same yardstick._

## Dimensions (weight)

| # | Dimension | Weight | Question it answers |
| --- | --- | --- | --- |
| D1 | Single home + sealing at rest | 20 | Does every credential live in exactly one place, sealed, readable only by the process that needs it? |
| D2 | Proactive refresh | 20 | Is a session refreshed BEFORE it dies (condition-driven), not on a calendar? |
| D3 | No divergent copies | 15 | Is there one session store of record (no shadow copies drifting stale)? |
| D4 | Says-when-it-cannot | 15 | Does the system expose unseeded/invalid/drifted states OUTSIDE the journal (metric/check/alert)? |
| D5 | Claims pinned by tests | 15 | Can every claim FAIL a test (VM leg, eval guard, build check)? |
| D6 | Human operability | 15 | Can a human seed/rotate/restore in under a minute without touching a shell secret? |

Score each dimension 0–10, multiply by weight, sum → /100.

- **9–10**: holds TODAY with a test that would catch the regression.
- **7–8**: holds today, proof is ephemeral (journal/run evidence only).
- **4–6**: design exists, operation does not (inert/not wired).
- **0–3**: neither design nor operation.

## Evidence classes (every grade must name one)

- **read**: claim verified from source/config text only.
- **ran**: the mechanism was executed in this session (command + rc captured).
- **probed**: live state observed on the host/journal/metric surface.
- **pinned**: a committed test/check fails on regression (highest class;
  D5 requires this class for a 9–10).

A "verified" label must cover EVERY fact asserted, not just the ones
checked (the 2026-10-05 dnsblockd lesson). Grades quoting numbers must
sanity-check one known value through the same pipeline first
(the 2026-10-26 quote-scrutiny rule).

## Baseline scores (2026-11-09, CV at gen-992 → plan P1–P11)

| Dimension | 19:30 audit | After the SUPERB plan (pending deploy verify) |
| --- | --- | --- |
| D1 | 5 (key in 4-reader cv-env) | 8 (key scoped to 2 readers; pinned by env check) |
| D2 | 0 (expiry display-only) | 9 (expiry-gated daily loop; pinned by VM leg) |
| D3 | 3 (three session homes) | 4 (decision pack filed; owner gate open) |
| D4 | 2 (journal-only) | 8 (metrics + SigNoz drafts + post-deploy leg) |
| D5 | 0 (zero pins) | 8 (VM leg + 2 eval checks + negative proof) |
| D6 | 6 (UI works; no walkthrough) | 8 (walkthrough + restore drill documented; no CLI rotate yet) |

_The "after" column is OFFICIAL since 2026-11-10 02:24 (gen-995 switch;
live battery 05:22): D1/D2/D4 now carry evidence class `probed` (key-split
verified per live unit file + cv-env keyless grep + store boot on the
scoped key; daily 09:11 timer + unseeded exit-10 semantics + per-platform
journal lines observed; textfile metrics scraped with the post-deploy
smoke leg PASS), D5 keeps `pinned` (VM legs + eval checks, negative-proven),
D6 keeps `ran` (drills). D3 stays owner-gated (single-source-of-truth
decision pack §10)._
