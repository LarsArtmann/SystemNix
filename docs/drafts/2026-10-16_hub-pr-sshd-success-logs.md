# PR draft — crowdsecurity/hub — sshd-success-logs sshd-session filter

**Title:** `fix(parsers): accept sshd-session program name in sshd-success-logs`

**Status:** fixtures verified locally (`cscli hubtest run sshd-success-logs` green, crowdsec v1.8.1) before filing.

---

> [!NOTE]
> This PR was drafted by GLM-5.3-flash via Crush from an AI-run investigation, not at my request.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

TL;DR: on OpenSSH ≥ 9.8 the per-connection process logs as `sshd-session`, so the `crowdsecurity/sshd-success-logs` filter (`evt.Parsed.program == 'sshd'`) silently drops every successful login and `auth_success` is never set. This PR applies the same filter shape #1093 already shipped for the sibling `sshd-logs` parser, plus a fixture line.

## Problem

#1093 updated `parsers/s01-parse/crowdsecurity/sshd-logs.yaml` to `filter: "evt.Parsed.program in ['sshd-session', 'sshd']"` but missed its sibling `parsers/s01-parse/crowdsecurity/sshd-success-logs.yaml` (still `== 'sshd'` on master today).

For an `Accepted ...` line the failure matters because `sshd-logs` only carries failure-pattern groks, so the success line falls through the stage to `sshd-success-logs` — whose filter then rejects it (program is `sshd-session`). The line ends up unparsed: no `log_type: auth_success`, no `source_ip`/`user` metas. Observed on our host (NixOS, OpenSSH 10.x): 182 accepted-publickey logins, zero ok-hits on the parser.

## What changed

- `parsers/s01-parse/crowdsecurity/sshd-success-logs.yaml`: filter → `"evt.Parsed.program in ['sshd-session', 'sshd']"` (exact shape of #1093).
- `.tests/sshd-success-logs/sshd-success-logs.log`: one `sshd-session` Accepted-publickey line added.
- `.tests/sshd-success-logs/parser.assert`: event counts 4 → 5 with the index-4 entries across s00-raw / s01-parse / s02-enrich.

## Testing

`cscli hubtest run sshd-success-logs` with crowdsec v1.8.1 — all assertions pass.

💘 Generated with Crush
