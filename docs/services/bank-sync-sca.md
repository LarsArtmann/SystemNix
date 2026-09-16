# bank-sync — Wise SCA (Strong Customer Authentication) renewal runbook

Wise gates statement endpoints behind SCA for UK/EEA profiles roughly
**every 90 days**: the API answers 403 with an `x-2fa-approval` one-time
token (OTT) header instead of transactions. While blocked, the daemon
silently degrades to the transfers fallback (outgoing transfers only) and
the dashboard shows the **"Wise approval needed"** banner — journald logs
`statements paused pending SCA approval` with `approval_token_issued=true`
(the OTT value is deliberately NEVER logged anywhere).

**Requirements for this procedure** (all landed 2026-09-14/16, ride the
next `nix flake lock --update-input bank-sync` + deploy):

- bank-sync with the dashboard approval flow + the `sca` command
  (wise-go ≥ v0.11.0 pinned)
- the deployed binary and this runbook agree on the dashboard flow and
  `sca status` / `sca approve`

## Renewal procedure — dashboard (primary, since 2026-09-16)

The banner itself is the remedy: the daemon process holds the Wise
credentials, so the whole approval runs where you noticed the block — no
root shell, no env plumbing.

1. Open the dashboard (banksync.<domain> or `http://127.0.0.1:8097` on the
   host) → **Sync State card** → the "Wise approval needed" banner.
2. Click **Approve now** — the panel probes every Wise balance and lists
   the pending challenge(s).
3. Pick a channel (SMS / WhatsApp / voice) → **Send code** — the panel
   shows the obfuscated phone number the code went to.
4. Enter the 6-digit code → **Verify**. On success the panel confirms,
   a toast fires, and a fresh sync runs immediately — panels repaint as
   data lands (SSE). The banner disappears on the next state refresh.

The OTT lives only in the daemon's server-side session (10-minute TTL);
it is never shown, logged, or put in an error. A wrong code re-renders
the form (bounded retries); walking away past the TTL just means clicking
Approve now again (fresh probe).

CLI verification still works as before:
`journalctl -u bank-sync.service --output cat -n 50 | grep -i 'statement\|sca\|error'`
— no new `pending SCA approval` line and the banner is gone = cleared.
If the fallback covered a window while blocked, restore it with the
one-click backfill in the degraded banner or `bank-sync backfill`
(fallback rows are never replaced by statement rows on their own).

## Renewal procedure — CLI (fallback: dashboard unreachable / no browser)

Root shell on evo-x2. The CLI needs the same Wise credentials the daemon
uses:

1. **Check status** (read-only, no DB, exits non-zero while blocked):

   ```bash
   BIN=$(systemctl cat bank-sync.service | sed -n 's/^ExecStart=//p' | awk '{print $1}')
   sudo env "BANK_SYNC_WISE_API_KEY=$(sudo sed -n 's/^BANK_SYNC_WISE_API_KEY=//p' /run/secrets/bank-sync-env)" \
     "$BIN" sca status
   ```

   `OK` per balance — nothing to do. `BLOCKED` — the command prints the
   pending challenges (type, channels, validity) and the OTT as
   `BANK_SYNC_WISE_SCA_APPROVAL_TOKEN=<ott>`. That terminal line is the
   ONLY place the token value ever appears; treat it as a SECRET.

   A plain 403 WITHOUT an SCA challenge is a different problem: a
   personal-token regional restriction (statements are only supported for
   US/CA/AU/NZ/SG/MY profiles on personal tokens). That needs an OAuth
   token or a supported region instead — not this runbook.

2. **Clear it interactively** (same env, needs the TTY for the hidden OTP
   prompt; sends SMS/WhatsApp/voice to the registered phone):

   ```bash
   sudo env "BANK_SYNC_WISE_API_KEY=$(sudo sed -n 's/^BANK_SYNC_WISE_API_KEY=//p' /run/secrets/bank-sync-env)" \
     "$BIN" sca approve
   ```

   Enter the 6-digit OTP when prompted. The command re-probes every
   previously blocked balance and confirms statements serve again. No
   restart: the daemon reconciles on the next 15-min tick (or run the
   dashboard flow to trigger the immediate sync).

## Break-glass without a TTY (appendix)

Only when neither the dashboard nor interactive `sca approve` is possible
(no console, no browser). `sca status` prints the token; carry it for
exactly one sync via a systemd drop-in:

```bash
sudo systemctl edit bank-sync.service
# [Service]
# Environment=BANK_SYNC_WISE_SCA_APPROVAL_TOKEN=<ott>
sudo systemctl restart bank-sync.service   # scheduler syncs immediately on start
# ...one tick later, REMOVE the drop-in line and restart again
```

The OTT is single-use and short-lived — leaving it configured only serves
confusion. (An earlier revision of this runbook grepped the OTT out of
journald and dropped it into /var/lib/bank-sync-sca/token.env; journald no
longer prints the token, and the value now comes from `sca status`.)

## Reference

- bank-sync: `docs/runbooks/sca.md` (dashboard + CLI reference, failure
  modes), `wise.sca_approval_token` config / `BANK_SYNC_WISE_SCA_APPROVAL_TOKEN` env
- wise-go: `WithSCAApprovalToken`, `TriggerOTT`/`VerifyOTT` (v0.11.0)
- Wise docs: "Strong customer authentication and 2FA for API" (OTT flow)
- Root-cause narrative: `docs/status/2026-08-19_05-10_wise-sca-root-cause-wise-go-v061-bank-sync-wiring.md`
  and the 2026-09 silent-degradation incident: bank-sync
  `docs/status/2026-09-04_18-34_*`
