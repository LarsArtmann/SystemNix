# ADR-005: Discord Notification Channel for SigNoz Alerts

**Date:** 2026-05-11
**Status:** Accepted

## Context

SigNoz alert rules need a notification channel to deliver alerts when metrics cross thresholds. The system already has Discord configured for various integrations. SigNoz supports multiple notification channels (Slack, PagerDuty, webhook, Discord) and provisions them via API.

The provision script (`provision-signoz.sh`) creates a Discord channel via `POST /api/v1/channels` with a webhook URL stored in sops-encrypted secrets. Alert rules reference the channel by name (`"Discord Alerts"`) in their `preferredChannels` field.

## Decision

Use Discord as the sole notification channel for all SigNoz alerts:

1. Discord webhook URL stored in sops (`signoz.yaml` → `discord_webhook_url`)
2. Sops template renders to `/run/signoz/discord-env` at activation
3. Provision script reads the URL from the env file and creates the channel via API
4. Alert rules reference `"Discord Alerts"` as `preferredChannels`
5. Channel name is a convention, not configurable — all alerts go to one Discord channel

## Alternatives Considered

- **Slack**: Team doesn't use Slack actively
- **PagerDuty**: Overkill for a home lab; cost-prohibitive
- **Webhook only**: Loses Discord-specific formatting (embeds, mentions)
- **Multiple channels per severity**: Not yet needed; can add later

## Consequences

- Single point of notification — if Discord is down, alerts are lost (mitigated by SigNoz's internal alert state)
- Easy to add severity-based routing later via additional channels
- The provision script is idempotent — re-running creates the channel only once
