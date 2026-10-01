# nix-email (Stalwart + DMARC monitoring) — Agent Notes

> Module: `modules/nixos/services/nix-email.nix`. Body migrated verbatim from AGENTS.md on 2026-10-01 (restructure) — treat the section below as authoritative agent notes for this service.

## nix-email (Stalwart mail + DMARC monitoring, 2026-09-29)

**Module:** `modules/nixos/services/nix-email.nix` wraps upstream `inputs.nix-email` (`github:LarsArtmann/nix-email?ref=master`; `nixpkgs.follows` REQUIRED — `checks.nix-email-contract` evals upstream's modules against OUR `services.stalwart` on every flake check, that IS the compat doctrine, not a shared rev).

- **dmarc-monitor on evo-x2: fully wired, `enable = false`** in configuration.nix. Flipping it before the `dmarc@larsartmann.cloud` mailbox exists on the VPS = permanently-failing parsedmarc unit = exit-4 deploys + un-anchored profile. The flip is the FINAL step of pbx-artmann `docs/runbooks/mail-go-live.md`; then paste the real `dmarc-imap-password` (sops `platforms/nixos/secrets/nix-email.yaml`, placeholder shipped). The mailbox must be created with its ADDRESS as the Stalwart principal name (IMAP LOGIN resolves by principal NAME, not by alias). **Collector domain is larsartmann.cloud, NOT artmann.tech (owner decision 2026-09-30): artmann.tech's MX points at Google Workspace, so a Stalwart-side dmarc@artmann.tech would receive NOTHING; larsartmann.cloud is the only fleet domain whose MX is ours (added 2026-09-30 in the domains repo, together with per-domain rua → dmarc@larsartmann.cloud + 16 RFC 7489 §7.1 external-destination verification TXTs).**
- **mail-server (Stalwart) lives on pbx-artmann**, NOT here — that repo consumes the upstream module directly (runtime-file secrets doctrine, no sops). This wrapper's mail-server half stays for any future sops-based host; eval-verified by `tests/test-nix-email.nix` (mock-sops).
- Stalwart local domains/accounts/DKIM keys are STORE data provisioned via the webadmin/API — config.toml cannot declare them (fresh-domain SMTP traffic poisons the directory negative cache for 1h; the upstream `directoryCacheTtlNegative` option exists for exactly that bring-up window).

