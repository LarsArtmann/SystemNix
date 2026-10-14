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

Step 0 (prerequisite, learned 2026-10-07): **CAN you receive an SMS/WhatsApp/voice code
at the phone number Wise currently holds?** If not, stop — no approval path can complete
until the number is fixed inside Wise (Settings → Personal details; Wise Support + ID if
old-number verification blocks it). The Send-code panel reveals the obfuscated number as
evidence. If the number was JUST changed, jump to the failure-mode section below first.

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

## Failure mode — registered phone changed or unreachable → `bank.empty_sca_token` everywhere

Two distinct classes share the "no code arrives" symptom; the journal separates them in
one grep (`journalctl -u bank-sync.service --output cat | grep -c 'sca send'`):

1. **Wrong/unreachable number, challenge healthy** (2026-09-30..10-09 class): `sca send`
   lines EXIST — codes went to the number Wise holds. If that number is dead, no approval
   path can complete until the number is corrected inside Wise. TOTP is not an API option:
   wise-go `ott.go` offers only SMS/WhatsApp/Voice.
2. **Number was just CHANGED → no OTT issued at all** (2026-10-09 20:31 onset class): every
   balance sync errors `[rejection] bank.empty_sca_token: approval token is empty`
   (`op: sca_fallback_token`), and the dashboard "Approve now"/"Send code" probes fail with
   the same error. Wise 403s the statement call with the `x-2fa-approval-result` verdict
   header but NO `x-2fa-approval` OTT — wise-go's `isSCAChallenge` fires on either header,
   so the challenge looks real but carries nothing to approve with. Changing the phone
   resets the profile's 2FA/SCA enrollment; until a fresh challenge is issued, Wise serves
   no token for ANY profile/balance (all 5 profiles / 20 balances failed simultaneously).
   The transfers fallback deliberately refuses loudly on a token-less challenge (bank-sync
   `adapter.go`: "an SCA fallback without a token is a provider anomaly"), so whole cycles
   fail instead of degrading — `bank_sync_sync_consecutive_failures` climbs while
   `bank_sync_sca_approval_pending` stays **0** (the gauge counts ApprovalBlocked verdicts,
   which require a token — classification gap, queued upstream).

**Remedy for class 2** (user hands, ~5 min):

1. wise.com: log in and confirm the NEW number receives login 2FA codes.
2. wise.com: open any balance → view/download a statement → complete the web 2FA
   challenge (code → NEW number). This re-arms OTT issuance for the API.
3. Dashboard → Sync State → "Wise approval needed" → Approve now — the probe should now
   get a fresh OTT → Send code (NEW number) → enter OTP → Verify → auto-sync fires. If the
   probe still errors `empty_sca_token`, repeat step 2 immediately before re-probing, and
   check `sca status` (its token line is the sanctioned OTT surface).
4. Backfill the statement gap (one-click backfill in the degraded banner or
   `bank-sync backfill`) — the transfers fallback covered only outgoing transfers from the
   change moment until approval. Note: the backfill button CORRECTLY refuses while SCA is
   still blocked (`backfill.degraded_source_refused`) — that refusal is expected, not a bug.
5. One post-approval restart clears the restart-cumulative `bank_sync_sync_errors_total`
   the deploy smoke reads.

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
