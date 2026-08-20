# bank-sync — Wise SCA (Strong Customer Authentication) renewal runbook

Wise gates some endpoints behind SCA for UK/EEA profiles — notably
`GET /v1/profiles/{id}/balance-statements/{id}/statement.json`, which
bank-sync uses to reconcile balances. The challenge looks like this:

- HTTP **403 with an EMPTY body** (no JSON error object)
- Response headers carry the verdict and the one-time token (OTT):
  - `x-2fa-approval-result: REJECTED`
  - `x-2fa-approval: <OTT>`

wise-go v0.6.1+ surfaces this as a `wise.sca_challenge` error whose
message prints the verdict, the OTT, and these instructions. Until the
challenge is cleared, balance reconciliation silently syncs zero
statements (transactions still flow — only statements are gated).

The challenge recurs roughly **every 90 days** (viewing a statement in
the Wise app/web also satisfies it).

## Renewal procedure (root shell on evo-x2)

1. **See the challenge + OTT** — the journal prints it on the next sync
   (every 15 min):

   ```bash
   journalctl -u bank-sync.service --output cat | grep -i 'sca\|403' | tail
   ```

   Expected line: `wise: sca challenge (403): ... x-2fa-approval="<OTT>" ...`

   A plain 403 WITHOUT any `x-2fa-approval` header is a different
   problem: a personal-token regional restriction (statements are only
   supported for US/CA/AU/NZ/SG/MY profiles on personal tokens). That
   needs an OAuth token or a supported region instead — not this runbook.

2. **Approve in the Wise app** — open Wise on your phone
   (Settings → Security and privacy → Approvals, or the push
   notification if one arrived) and approve the pending access request.

3. **Drop the OTT into the env file** (single use, expires fast — do
   this right after approving):

   ```bash
   sudo install -d -m 0750 /var/lib/bank-sync-sca
   echo 'BANK_SYNC_WISE_SCA_APPROVAL_TOKEN=<OTT>' | sudo tee /var/lib/bank-sync-sca/token.env
   sudo chmod 0400 /var/lib/bank-sync-sca/token.env
   ```

4. **Restart for exactly one token-carrying sync** (the scheduler runs
   an initial sync immediately on start):

   ```bash
   sudo systemctl restart bank-sync.service
   ```

5. **Verify** the statement call went through and new data landed:

   ```bash
   journalctl -u bank-sync.service --output cat -n 50 | grep -i 'statement\|sca\|error'
   ```

   No new `sca challenge` line = cleared.

6. **Remove the token** (it is single-use; leaving it only serves
   confusion):

   ```bash
   sudo rm /var/lib/bank-sync-sca/token.env
   ```

   The next restart/sync runs without it (`-`-prefixed EnvironmentFile —
   absence is a no-op).

## Why a plain file (not sops)

The OTT is single-use, human-approved, and changes every cycle. A sops
secret would demand an encrypt + template edit + full redeploy per
renewal for a value that must be deleted minutes later. systemd reads
`EnvironmentFile` as PID 1 before dropping privileges, so a root-owned
0400 file under `/var/lib/bank-sync-sca/` delivers the token to the
sandboxed service without ever touching the nix store or sops state.

## Reference

- Wise docs: "Strong customer authentication and 2FA for API" (OTT flow)
- wise-go: `WithSCAApprovalToken` option, `SCAChallengeError` (v0.6.1)
- bank-sync: `wise.sca_approval_token` config / `BANK_SYNC_WISE_SCA_APPROVAL_TOKEN` env
- Root-cause narrative: `docs/status/2026-08-19_05-10_wise-sca-root-cause-wise-go-v061-bank-sync-wiring.md`
