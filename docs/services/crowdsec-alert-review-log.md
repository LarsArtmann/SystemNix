# CrowdSec Alert-Review Log (stage-3 gate)

Weekly review per the runbook §Alert-review cadence
([crowdsec.md](crowdsec.md)). Stage 3 (firewall bouncer) unlocks after
**7 consecutive clean-informed days**; one LAN false-positive resets the
window. Never paste secret values here; counts and scenario names are fine.

| Date | Alerts (7d) | Decisions active | Top scenarios | Verdict | Reviewer |
| ---- | ----------- | ---------------- | ------------- | ------- | -------- |
| 2026-10-16 | (baseline entry — see below) | — | — | window OPENED | agent (plan T16) |

**2026-10-16 baseline:** stage 1 detection live since 00:54:55 (LAN
whitelist active, RFC1918/loopback un-bannable by design); caddy acquis
still DARK on the running generation (fix in-tree, verify-pending deploy)
and `sshd-success-logs` unparsed (hub PR crowdsecurity/hub#1943 pending) —
detection coverage is PARTIAL during this window, which the stage-3 decision
must weigh: clean days under blind parsers are weaker evidence than clean
days under full coverage.
