# ADR-006: Gatus Secret Injection via Environment File

**Date:** 2026-05-11
**Status:** Accepted

## Context

Gatus needs a Discord webhook URL for alert notifications. The URL is a secret stored in sops. Gatus configuration is declarative YAML written via `settingsFile` in the nixpkgs module.

Previous approach used an `ExecStartPre` script that ran `sed` to replace a placeholder string in the Gatus config file with the webhook URL at service start. This required `gnused`, a `/run/gatus/` directory, and a fragile string-replacement pipeline.

## Decision

Use the nixpkgs Gatus module's native `environmentFile` option combined with Gatus's built-in environment variable interpolation:

1. Sops template (`sops.templates."gatus-env"`) renders the webhook URL to `/run/gatus/gatus.env`
2. The nixpkgs `services.gatus.settingsFile` contains `$DISCORD_WEBHOOK_URL` or `${DISCORD_WEBHOOK_URL}` placeholders
3. `services.gatus.environmentFile` points to the sops-rendered env file
4. Gatus natively interpolates `${VAR}` in its config at startup

## Alternatives Considered

- **Sops template for full gatus.yaml**: Would require generating the entire Gatus config as a sops template, duplicating all the declarative Nix config into a template. Fragile and defeats the purpose of the nixpkgs module.
- **sed ExecStartPre** (previous): Required `gnused`, `coreutils` in PATH, `/run/gatus/` tmpfiles, and a preStart script. Fragile and added unnecessary complexity.
- **Systemd `Environment=`**: The webhook URL is too long for systemd's `Environment=` line limits and would expose it in `systemctl show`.

## Consequences

- Clean separation: Nix defines structure, sops provides secrets, Gatus interpolates at runtime
- No custom scripts or `gnused` dependency
- The env file approach is standard for nixpkgs service modules
- Gatus's `${VAR}` interpolation supports the full URL in any config field
