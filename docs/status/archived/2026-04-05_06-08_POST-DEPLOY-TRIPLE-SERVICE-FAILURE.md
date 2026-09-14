# Post-Deploy Triple Service Failure — Incident & Fix Report

**Date:** 2026-04-05 06:08
**Trigger:** `just switch` on evo-x2 (generation `26.05.20260402.8d8c1fa`)
**Result:** Activation failed (exit 4) — 3 services crashed, 1 dependency cascaded
**Status:** Fixed, Nixified, validated (`just test-fast` passes), pending `just switch`

---

## Timeline

| Time     | Event                                                          |
| -------- | -------------------------------------------------------------- |
| 06:05    | `just switch` begins building new generation                   |
| 06:06    | Activation starts — old units stopped, new units activated     |
| 06:06:53 | `clickhouse.service` fails → `signoz.service` dependency fails |
| 06:06:56 | `dnsblockd.service` fails (restart loop, counter 32)           |
| 06:06:58 | `authelia-main.service` fails (config validation)              |
| 06:08    | Activation exits with code 4                                   |

---

## Root Causes & Fixes

### 1. Authelia 4.39 Breaking Configuration Changes

**Service:** `authelia-main.service`
**File:** `modules/nixos/services/authelia.nix`

Authelia upgraded to **4.39.12** which introduced strict config validation. Five errors + one deprecation warning:

| # | Error                                                 | Fix                                      |
| - | ----------------------------------------------------- | ---------------------------------------- |
| 1 | `notifier.filesystem.path` unexpected                 | → `filesystem.filename`                  |
| 2 | `server.endpoints.enable.enable_expvars` unexpected   | → `endpoints.enable_expvars`             |
| 3 | `server.endpoints.enable.enable_pprof` unexpected     | → `endpoints.enable_pprof`               |
| 4 | `domain 'lan'` not valid cookie domain                | Domain migration (see below)             |
| 5 | `notifier: filesystem: option 'filename' is required` | Same as #1                               |
| ⚠ | `webauthn.user_verification` deprecated               | → `selection_criteria.user_verification` |

### 2. ClickHouse XML Parse Error

**Service:** `clickhouse.service` → cascaded to `signoz.service`
**File:** `modules/nixos/services/signoz.nix`

`extraServerConfig` had two sibling XML elements without a wrapping root. ClickHouse's config merger requires a single root element in standalone XML files.

**Fix:** Wrapped in `<clickhouse>` root element.

### 3. dnsblockd sops Secret Race Condition

**Service:** `dnsblockd.service`
**File:** `platforms/nixos/modules/dns-blocker.nix`

dnsblockd started before sops-nix decrypted TLS secrets. Added `sops-nix.service` to `after`/`wants`.

### 4. Gitea `ROOT_URL` Protocol Bug (pre-existing)

`ROOT_URL` was `http://gitea.lan/` but Caddy serves it over TLS. Fixed to `https://`.

---

## Nixification: Domain & IP as Single Source of Truth

Instead of hardcoding `.home.lan` and `192.168.1.150` across 11 files, everything now derives from NixOS config.

### Architecture

```
networking.domain = "home.lan"            ← ONE definition in networking.nix
         │
         ├── authelia.nix    → config.networking.domain
         ├── caddy.nix       → config.networking.domain
         ├── homepage.nix    → config.networking.domain
         ├── immich.nix      → config.networking.domain
         ├── gitea.nix       → config.networking.domain
         └── dns-blocker-config.nix → config.networking.domain
                                       + config.networking.interfaces.eno1 (IP)
```

### What was Nixified

| Before (hardcoded)            | After (derived)                                                           | File                     |
| ----------------------------- | ------------------------------------------------------------------------- | ------------------------ |
| `"home.lan"` x7 files         | `config.networking.domain`                                                | all service modules      |
| `"192.168.1.150"`             | `builtins.head config.networking.interfaces.eno1.ipv4.addresses).address` | `dns-blocker-config.nix` |
| 7 copy-pasted Caddy vhosts    | `protectedVHost` function                                                 | `caddy.nix`              |
| 14 hardcoded URLs in homepage | `svcUrl` helper function                                                  | `homepage.nix`           |
| 7 hardcoded DNS records       | `map` over subdomain list                                                 | `dns-blocker-config.nix` |

### DRY Patterns Introduced

**caddy.nix** — `protectedVHost` helper:

```nix
protectedVHost = subdomain: port: {
  extraConfig = ''
    ${tlsConfig}
    ${forwardAuth}
    reverse_proxy localhost:${toString port}
  '';
};
"signoz.${domain}" = protectedVHost "signoz" 8080;
```

**homepage.nix** — `svcUrl` helper:

```nix
svcUrl = subdomain: "https://${subdomain}.${domain}";
```

**dns-blocker-config.nix** — mapped DNS records:

```nix
local-data = map
  (subdomain: ''"${subdomain}.${domain}. IN A ${serverIP}"'')
  ["auth" "immich" "gitea" "dash" "photomap" "unsloth" "signoz"];
```

---

## Files Changed

| File                                                         | Changes                                                     |
| ------------------------------------------------------------ | ----------------------------------------------------------- |
| `platforms/nixos/system/networking.nix`                      | Added `networking.domain = "home.lan"`                      |
| `modules/nixos/services/authelia.nix`                        | Domain from config, 4.39 schema fixes, `selection_criteria` |
| `modules/nixos/services/caddy.nix`                           | `protectedVHost` helper, all domains from config            |
| `modules/nixos/services/homepage.nix`                        | `svcUrl` helper, all URLs from config                       |
| `modules/nixos/services/immich.nix`                          | `issuerUrl` from config                                     |
| `modules/nixos/services/gitea.nix`                           | `ROOT_URL`/`DOMAIN` from config, http→https fix             |
| `modules/nixos/services/signoz.nix`                          | ClickHouse XML root element fix                             |
| `platforms/nixos/system/dns-blocker-config.nix`              | Domain + IP from config, `map` for DNS records              |
| `platforms/nixos/modules/dns-blocker.nix`                    | `sops-nix.service` dependency                               |
| `README.md`, `AGENTS.md`, `IMMICH-BULL-BOARD-PATCH-GUIDE.md` | Domain references                                           |

## Validation

```
$ just test-fast
✅ Fast configuration test passed
```

## Next Steps

1. `just switch` — deploy
2. Verify all services start
3. Update browser bookmarks (`*.lan` → `*.home.lan`)
