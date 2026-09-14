# dnsblockd OIDC SSO — secret recovery runbook

The dnsblockd dashboard SSO consumes the Pocket ID client secret through a
bridge unit, not a static file. This runbook covers the two failure modes and
their recovery procedures.

## How the secret flows

```
pocket-id-provision.service
  └─ writes /var/lib/pocket-id/client-secrets/dnsblockd
dnsblockd-oidc-secret.service (oneshot, LoadCredential)
  └─ writes /var/lib/dnsblockd-oidc/client-secret.env
       (DNSBLOCKD_OIDC_CLIENT_SECRET=…)
dnsblockd.service
  └─ EnvironmentFile= that env file (only when oidcIssuerURL is set)
```

**Fail-closed by design:** when the Pocket ID secret file is missing or empty,
`dnsblockd-oidc-secret` exits 0 WITHOUT writing the env file (and removes a
stale one). dnsblockd then starts with SSO disabled — the auth token still
works, DNS is never impacted. A deliberately failing unit was rejected because
the `before = dnsblockd.service` ordering would drag the DNS path down with it.
Sign-in breakage is surfaced observably instead: dnsblockd's
`dnsblockd_oidc_discovery_failures_total` counter feeds the
`DnsblockdOIDCDiscoveryFailing` Prometheus alert.

## Symptom: "Sign in with SSO" missing, or login fails with provider errors

### 1. Check the bridge unit

```bash
systemctl status dnsblockd-oidc-secret.service
journalctl -u dnsblockd-oidc-secret.service -n 30
```

- `client secret written` → bridge is fine; continue with step 3.
- `Pocket ID secret not found — removing env file` → the Pocket ID
  client-secrets file is missing; continue with step 2.

### 2. Secret file missing (Pocket ID provision ran without creating it)

Check the client exists in the Pocket ID admin UI (Clients → `dnsblockd`).
It is provisioned declaratively by `services.pocket-id-config.provision.oidcClients`.
If the client exists but the secret file does not:

```bash
systemctl restart pocket-id-provision.service
systemctl restart dnsblockd-oidc-secret.service
systemctl restart dnsblockd.service
```

Verify: `ls -la /var/lib/pocket-id/client-secrets/dnsblockd` and the bridge
journal says `client secret written`.

### 3. Secret desync (file exists, value does not match Pocket ID's database)

Symptom: bridge writes the env file, but every SSO login fails at the token
exchange (`dnsblockd_oidc_login_failures_total{oidc_failure_reason="exchange"}`
climbs; login page shows the exchange error copy).

Force-regenerate the secret via the provision module:

```nix
services.pocket-id-config.provision.regenerateSecretsFor = [ "dnsblockd" ];
```

Deploy once, confirm login works, then REMOVE the entry — leaving it in would
rotate the secret on every subsequent provision run, invalidating the previous
secret each time.

### 4. dnsblockd cannot reach the issuer

dnsblockd resolves `auth.<domain>` itself; a broken resolver path to the IdP
host keeps `dnsblockd_oidc_provider_ready` at 0. Check
`https://dnsblock.<domain>/health` → `oidcProviderReady`, and the
`DnsblockdOIDCDiscoveryFailing` alert. Fix DNS/routing for the auth host;
discovery retries automatically on every login attempt (no restart needed).
