# Sops-Nix Certificate Migration — Full Status Report

**Date:** 2026-04-01 05:09
**Session Scope:** Migrate dnsblockd CA cert/key from world-readable nix store to sops-nix
**Build Status:** PASSING (`nix flake check --no-build` clean, `nixos-rebuild build` succeeds)
**Commits:** 6 commits (c588847..3e2d27d), pushed to origin/master

---

## A. FULLY DONE (8 items)

| #   | Task                                                                                                                                                                                             | Commit    | Files Changed                                                            |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- | ------------------------------------------------------------------------ |
| 1   | **Create sops-encrypted cert file** — `dnsblockd-certs.yaml` with CA cert, CA key, server cert, server key encrypted with age                                                                    | `c588847` | `platforms/nixos/secrets/dnsblockd-certs.yaml` (new)                     |
| 2   | **Store plain CA cert for eval-time access** — needed by `security.pki.certificateFiles`, Firefox policies, NSS import                                                                           | `5deab04` | `platforms/nixos/secrets/dnsblockd-ca.crt`, `dnsblockd-server.crt` (new) |
| 3   | **Declare 4 sops secrets with ownership** — `dnsblockd_ca_cert` (root), `dnsblockd_ca_key` (root, mode 0400), `dnsblockd_server_cert` (caddy), `dnsblockd_server_key` (caddy, mode 0400)         | `7a4d32f` | `modules/nixos/services/sops.nix` (+23 lines)                            |
| 4   | **Update dns-blocker.nix** — replaced `pkgs.dnsblockd-cert` with plain cert file + sops runtime paths                                                                                            | `0d82e8a` | `platforms/nixos/modules/dns-blocker.nix` (5 edits)                      |
| 5   | **Update caddy.nix** — replaced `pkgs.dnsblockd-cert` with sops-decrypted server cert/key paths                                                                                                  | `7e4518d` | `modules/nixos/services/caddy.nix` (full rewrite)                        |
| 6   | **Remove dnsblockd-cert from overlay** — no longer consumed by any module                                                                                                                        | `3e2d27d` | `flake.nix` (-1 line)                                                    |
| 7   | **Verify build** — `nix flake check --no-build` passes, `nixos-rebuild build --flake .#evo-x2` succeeds                                                                                          | —         | —                                                                        |
| 8   | **Verify generated config** — dnsblockd.service uses `/run/secrets/dnsblockd_ca_cert` + `_key`; caddy uses `/run/secrets/dnsblockd_server_cert` + `_key`; CA cert present in system trust bundle | —         | —                                                                        |

### Architecture After Migration

```
platforms/nixos/secrets/
├── secrets.yaml              # Grafana, Gitea, GitHub tokens (sops-encrypted)
├── dnsblockd-certs.yaml      # CA cert+key, server cert+key (sops-encrypted)
├── dnsblockd-ca.crt          # Plain CA cert (for eval-time: security.pki, Firefox, NSS)
└── dnsblockd-server.crt      # Plain server cert (reference copy, public info)

At runtime (sops-nix decrypts to):
/run/secrets/dnsblockd_ca_cert        ← dnsblockd reads for TLS signing
/run/secrets/dnsblockd_ca_key         ← dnsblockd reads (mode 0400, root only)
/run/secrets/dnsblockd_server_cert    ← caddy reads for *.lan TLS
/run/secrets/dnsblockd_server_key     ← caddy reads (mode 0400, caddy:caddy)

In nix store (eval-time):
/nix/store/.../dnsblockd-ca.crt       ← security.pki.certificateFiles, Firefox policy, NSS import
```

### Security Improvement

| Before                                                   | After                                                                                                    |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `dnsblockd-ca.key` world-readable in `/nix/store`        | Encrypted in `dnsblockd-certs.yaml`, decrypted to `/run/secrets/` with mode 0400                         |
| `dnsblockd-server.key` world-readable in `/nix/store`    | Encrypted in `dnsblockd-certs.yaml`, decrypted to `/run/secrets/` with mode 0400, owned by `caddy:caddy` |
| Certs regenerated on every rebuild (different each time) | Stable certs (same key material across rebuilds)                                                         |
| Any local user could forge trusted TLS certificates      | Only root can read CA key, only caddy can read server key                                                |

---

## B. PARTIALLY DONE (1 item)

| #   | Task                     | Status                                                                | Remaining                                                                                             |
| --- | ------------------------ | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 1   | **On-target deployment** | Build succeeds but `nixos-rebuild switch` not yet run (requires root) | Run `sudo nixos-rebuild switch --flake .#evo-x2` and verify dnsblockd + caddy start with sops secrets |

---

## C. NOT STARTED

| #   | Task                                                                                               | Priority | Effort | Notes                                                                        |
| --- | -------------------------------------------------------------------------------------------------- | -------- | ------ | ---------------------------------------------------------------------------- |
| 1   | Delete `pkgs/dnsblockd-cert.nix` — dead code, no longer referenced                                 | HIGH     | 1 min  | File exists but is never imported; security doc should note it as historical |
| 2   | Remove `dnsblockd-server.crt` from secrets/ — public cert already in sops, plain copy is redundant | MED      | 1 min  | Only `dnsblockd-ca.crt` is needed as plain file (eval-time)                  |
| 3   | Consolidate NixOS module imports — use `default.nix` to aggregate 11 service modules               | MED      | 15 min | Reduces boilerplate in flake.nix from 11 lines to 1                          |
| 4   | Deduplicate dnsblockd/dnsblockd-processor builds — built in overlay AND perSystem.packages         | MED      | 10 min | Remove from `perSystem.packages` or overlay                                  |
| 5   | Add `follows = "nixpkgs"` to nix-colors input                                                      | LOW      | 1 min  | Prevents pulling separate nixpkgs closure                                    |
| 6   | Delete unused `pkgs/gomod2nix.toml`                                                                | LOW      | 1 min  | Never referenced in any build                                                |
| 7   | Wire dnsblockd-processor into systemd timer for automated blocklist updates                        | MED      | 20 min | Blocklists are currently frozen at build time                                |
| 8   | Add NixOS test for dnsblockd HTTP block page                                                       | MED      | 30 min | No automated testing for dns-blocker module                                  |
| 9   | Centralize IP config into a single module                                                          | MED      | 25 min | `192.168.1.150` still hardcoded in multiple files                            |
| 10  | Configure automatic garbage collection schedule                                                    | LOW      | 10 min | Currently manual `just clean`                                                |
| 11  | Fix auditd/AppArmor conflict (security-hardening.nix TODOs)                                        | LOW      | 30 min | Blocked by nixpkgs#483085                                                    |
| 12  | Fix dnsblockd-processor Go lint warnings (gosec G304, cyclomatic)                                  | LOW      | 15 min | 5 warnings total                                                             |
| 13  | Add display brightness keybinding for laptops                                                      | LOW      | 10 min | P3 from previous session                                                     |
| 14  | Add immich backup verification to justfile                                                         | LOW      | 15 min | P3 from previous session                                                     |

---

## D. TOTALLY FUCKED UP (0 items)

Nothing broke this session. All changes compiled and validated on first attempt. The pre-commit hooks caught one unrelated formatting issue in `yazi.nix` (alejandra), which was auto-fixed.

---

## E. WHAT WE SHOULD IMPROVE

### E1. Security

| Issue                                                                          | Severity | Recommendation                                                                                                                              |
| ------------------------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `.sops.yaml` creation rules cover `*.yaml` in `secrets/` but NOT `*.crt` files | LOW      | `.crt` files are public certs, not secrets. Consider moving to a non-secrets directory to avoid confusion. Suggest `platforms/nixos/certs/` |
| `pkgs/dnsblockd-cert.nix` still exists as dead code                            | MED      | Delete it. Its existence is misleading and it documents an insecure pattern (CA key in nix store)                                           |
| No certificate rotation strategy                                               | MED      | Certs are now stable (same material forever). Add a note or justfile recipe for rotation: generate new → update sops → deploy               |

### E2. Architecture

| Issue                                                                                                                                                                                                                                                                                              | Recommendation                                                                                      |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Caddy reads certs at activation time** — Caddy renders its config at build time using `config.sops.secrets.*.path` which evaluates to `/run/secrets/...`. This works because Caddy re-reads certs from disk on each TLS handshake. However, if sops decrypts AFTER caddy starts, there's a race. | Add `after = ["sops-nix.service"]` to caddy unit or use `restartUnits` in sops secret declarations  |
| **dnsblockd cert service named `dnsblockd-cert-import`** — misleading since it now imports from plain file, not the removed package                                                                                                                                                                | Rename to `dnsblockd-ca-nss-import`                                                                 |
| **Plain cert files mixed with encrypted secrets**                                                                                                                                                                                                                                                  | Move `dnsblockd-ca.crt` to `platforms/nixos/certs/` to separate public certs from encrypted secrets |

### E3. Code Quality

| Issue                                                | Recommendation                                                                 |
| ---------------------------------------------------- | ------------------------------------------------------------------------------ |
| dnsblockd built twice (overlay + perSystem.packages) | Remove from `perSystem.packages` since overlay already provides it system-wide |
| 11 service module imports listed individually        | Use `default.nix` pattern to aggregate                                         |
| `nix-colors` input doesn't follow nixpkgs            | Add `inputs.nixpkgs.follows = "nixpkgs"`                                       |

### E4. Documentation

| Issue                                                                          | Recommendation                                                            |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| Previous session status reports mention "configure sops-nix" as P2 not-started | Now DONE — update AGENTS.md with the sops cert architecture               |
| `docs/status/` has no index                                                    | Consider adding a README.md that links all status reports chronologically |

---

## F. Top 25 Things To Do Next

### Critical / High Impact (do first)

| #   | Task                                                                                                                    | Effort | Impact                                                |
| --- | ----------------------------------------------------------------------------------------------------------------------- | ------ | ----------------------------------------------------- |
| 1   | **Deploy to evo-x2** — `sudo nixos-rebuild switch --flake .#evo-x2` and verify dnsblockd + caddy work with sops secrets | 5 min  | CRITICAL — all changes are theoretical until deployed |
| 2   | **Delete `pkgs/dnsblockd-cert.nix`** — dead code, documents insecure pattern                                            | 1 min  | Removes security risk documentation                   |
| 3   | **Move plain certs out of secrets/** — `platforms/nixos/certs/dnsblockd-ca.crt`                                         | 5 min  | Cleaner separation of public vs secret                |
| 4   | **Remove `dnsblockd-server.crt` from plain files** — redundant, only needed in sops                                     | 1 min  | Reduces confusion                                     |
| 5   | **Add sops service ordering** — ensure caddy/dnsblockd start after sops decrypts                                        | 5 min  | Prevents race condition on first boot                 |
| 6   | **Rename `dnsblockd-cert-import` → `dnsblockd-ca-nss-import`**                                                          | 2 min  | Accurate naming                                       |

### Medium Impact (do soon)

| #   | Task                                                                               | Effort | Impact                               |
| --- | ---------------------------------------------------------------------------------- | ------ | ------------------------------------ |
| 7   | **Consolidate service module imports via default.nix**                             | 15 min | Reduces flake.nix boilerplate        |
| 8   | **Deduplicate dnsblockd builds** — remove from perSystem.packages or overlay       | 10 min | Faster builds                        |
| 9   | **Add `follows = "nixpkgs"` to nix-colors**                                        | 1 min  | Smaller closure                      |
| 10  | **Wire dnsblockd-processor into systemd timer** for automated blocklist updates    | 20 min | Fresh blocklists without rebuilds    |
| 11  | **Centralize IP config** — single module with `config.networking.lanIP` or similar | 25 min | No more hardcoded IPs                |
| 12  | **Add NixOS test for dns-blocker module**                                          | 30 min | Catch regressions early              |
| 13  | **Add cert rotation justfile recipe**                                              | 10 min | Documented process for key rotation  |
| 14  | **Update AGENTS.md** with sops cert architecture                                   | 15 min | Future sessions have correct context |
| 15  | **Fix dnsblockd-processor Go lint warnings**                                       | 15 min | Clean `golangci-lint` output         |

### Lower Impact (backlog)

| #   | Task                                                             | Effort | Impact                  |
| --- | ---------------------------------------------------------------- | ------ | ----------------------- |
| 16  | **Delete `pkgs/gomod2nix.toml`** — unused                        | 1 min  | Cleanup                 |
| 17  | **Configure automatic garbage collection**                       | 10 min | Less manual maintenance |
| 18  | **Fix auditd/AppArmor conflict** (blocked by nixpkgs#483085)     | 30 min | Security hardening      |
| 19  | **Add display brightness keybinding for laptops**                | 10 min | Usability               |
| 20  | **Add immich backup verification to justfile**                   | 15 min | Data safety             |
| 21  | **Add docs/status/README.md index**                              | 10 min | Navigation              |
| 22  | **Remove darwin-only inputs from Linux builds**                  | 20 min | Smaller eval on evo-x2  |
| 23  | **Add niri keybinding cheatsheet to docs**                       | 15 min | Usability               |
| 24  | **Test photomap service after all cert changes**                 | 5 min  | Verify nothing broke    |
| 25  | **Add healthcheck endpoints to dnsblockd** (already has /health) | 10 min | Monitoring integration  |

---

## G. Top #1 Question I Cannot Figure Out Myself

**Will the sops-nix age key derivation work on the actual evo-x2 host at boot time?**

The sops secrets are encrypted to age key `age133ckftlye8snhzga95fnl4np7npjry90qr3g84ya0kddctecx5hsx9uyh6`, which is derived from `/etc/ssh/ssh_host_ed25519_key`. The config specifies `age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]`.

I verified on the live system that `ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub` produces the correct age public key. But:

- Can `sops-nix` actually read the SSH host private key at activation time? (it's root-owned, mode 0600)
- Is the `ssh-to-age` binary available during early boot / activation?
- If the SSH host key is regenerated (e.g., `nixos-generate-config`), all sops secrets become undecryptable

**This can only be verified by running `sudo nixos-rebuild switch --flake .#evo-x2`.**

---

## Session Metrics

| Metric                   | Value                                                                           |
| ------------------------ | ------------------------------------------------------------------------------- |
| Commits                  | 6 (c588847..3e2d27d)                                                            |
| Files changed            | 11                                                                              |
| Lines added              | +525                                                                            |
| Lines removed            | -20                                                                             |
| Build time               | ~3 min (full nixos-rebuild build)                                               |
| Pre-commit hooks         | All passing (gitleaks, deadnix, statix, alejandra, flake check)                 |
| Build artifacts verified | dnsblockd.service (ExecStart paths), caddy config (TLS paths), system CA bundle |
