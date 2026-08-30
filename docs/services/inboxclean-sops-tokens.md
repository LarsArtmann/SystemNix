# InboxClean — sops-managed OAuth tokens: draft and rotation caveat

**Status:** DRAFT ONLY — not wired into the module (2026-08-30). Read the
caveat before activating.

## Why this is a draft and not a deploy

Google OAuth **refresh tokens rotate**: on some accounts/scopes Google issues
a new refresh token on each exchange, and the old one is invalidated. The
InboxClean service persists those rotated tokens back to the state dir
(`/var/lib/inboxclean/token*.json`) at runtime.

A sops secret decrypts to a **read-only, static** file owned by root at every
activation. If Google rotates the token, the sops copy silently goes stale:
the service keeps working off the runtime file until the next redeploy
re-seeds the stale one, and re-auth then fails with `invalid_grant` in a way
that is painful to diagnose.

sops is the right home for **static** secrets — that is why
`inboxclean_gmail_credentials` (the OAuth *client* credentials.json, which
never rotates) is already sops-managed. Rotating tokens belong in writable
service state, which is where the current module puts them (seeding is
only-if-absent; the runbook in `modules/nixos/services/inboxclean.nix`
documents the one-time auth flow).

## If activation is still wanted

1. Add to `platforms/nixos/secrets/inboxclean.yaml`:

```yaml
inboxclean_gmail_token:
    description: >
        main-account Gmail OAuth refresh token (JSON, format of
        ~/.inboxclean/token.json). WARNING: Google may rotate refresh
        tokens; a rotated token invalidates this static copy on the next
        redeploy. Re-encrypt after every auth flow.
    inboxclean_gmail_token: |
        {
          "access_token": "ya29.…",
          "refresh_token": "1//…",
          "token_type": "Bearer",
          "expiry": "2026-08-30T00:00:00Z"
        }
inboxclean_gmail_token_work:
    description: >
        work-account (Workspace) OAuth refresh token, same format and same
        rotation caveat. Re-encrypt after every `auth --account work` flow.
    inboxclean_gmail_token_work: |
        { … }
```

2. Module wiring (`modules/nixos/services/inboxclean.nix`, inside
   `config = lib.mkIf cfg.enable`):

```nix
sops.secrets.inboxclean_gmail_token = {
    sopsFile = lib.path.append secretsDir "inboxclean.yaml";
    owner = "inboxclean";
    restartUnits = [ "inboxclean-web.service" ];
};
sops.secrets.inboxclean_gmail_token_work = {
    sopsFile = lib.path.append secretsDir "inboxclean.yaml";
    owner = "inboxclean";
    restartUnits = [ "inboxclean-web.service" ];
};

services.inboxclean = {
    gmailTokenFile = lib.mkDefault config.sops.secrets.inboxclean_gmail_token.path;
    extraAccounts = [
        {
            name = "work";
            credentialsFile = config.sops.secrets.inboxclean_gmail_credentials.path;
            tokenFile = config.sops.secrets.inboxclean_gmail_token_work.path;
        }
    ];
};
```

3. Re-encrypt cadence: after EVERY `inboxclean auth [--account …]` run and
   after any Google-side rotation, re-run `sops` on the YAML with the new
   token content and redeploy. Without this discipline the setup degrades
   into intermittent `invalid_grant` failures.

4. Verify: `systemctl restart sops-nix.service &&
   ls -la /run/secrets/inboxclean_gmail_token*` — files must land `0600`
   owned by `inboxclean`, and `/health` must show both accounts
   `connected`.

## Recommendation

Keep tokens in the state dir (current behavior). Revisit only if the tokens
must survive a wiped `/var/lib/inboxclean` or be reprovisionable to a second
machine — and pair that with re-encryption automation, not a manual YAML.
