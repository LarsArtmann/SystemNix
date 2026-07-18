# ADR-004: Secrets Management with sops-nix

## Status

**Accepted** - Revisit if secret management needs grow

## Date

2026-03-29

## Context

### Problem Statement

The NixOS configuration manages secrets (API tokens, service credentials) via plain-text files like `~/.config/gitea-sync.env`. This approach:

- Cannot be committed to version control
- Has no encryption at rest
- Lacks audit trail or rotation capabilities
- Requires manual setup on each machine

### Alternatives Considered

| Solution      | Type             | Self-Hosted    | NixOS Native  | Offline | Resource Overhead           |
| ------------- | ---------------- | -------------- | ------------- | ------- | --------------------------- |
| **sops-nix**  | File encryption  | N/A            | Yes (module)  | Yes     | Negligible                  |
| **agenix**    | File encryption  | N/A            | Yes (module)  | Yes     | Negligible                  |
| **Infisical** | Secrets platform | Yes            | No (CLI only) | No      | 4GB+ RAM, PostgreSQL, Redis |
| **Doppler**   | Secrets platform | No (SaaS only) | No (CLI only) | No      | N/A                         |

### Evaluation

**sops-nix** selected over agenix:

- Supports age, GPG, and SSH key encryption (agenix is age-only)
- First-class `EnvironmentFile` integration with systemd (matches existing Gitea pattern)
- Supports dotenv, YAML, JSON, INI, and binary formats
- Template support for embedding secrets into config files
- Multi-recipient encryption (one encrypted file, multiple machines)
- Larger community adoption and more mature codebase

**Infisical deferred** for potential future use:

- Web UI, secret rotation, audit logs, RBAC, and SDKs are compelling features
- Self-hostable but requires PostgreSQL, Redis, and 4GB+ RAM
- Adds a running service dependency for secret access (offline-unfriendly)
- Appropriate if needs grow to team collaboration, CI/CD integration, or many services
- Can coexist alongside sops-nix if adopted later

**Doppler eliminated**:

- No self-hosting option (SaaS only)
- Not suitable for local/offline infrastructure

## Decision

**Use sops-nix** as the secrets management solution for NixOS configurations.

**Consider Infisical** if any of the following emerge:

- Multiple users needing secret access
- CI/CD pipelines requiring dynamic secret injection
- Need for secret rotation or audit logging
- More than ~20 services requiring managed secrets
- Desire for a web UI to browse and manage secrets

## Consequences

### Positive

- Secrets encrypted at rest in the git repository
- Decryption happens at `nixos-rebuild` time (no running services needed)
- Works offline with no external dependencies
- Maps directly to existing `EnvironmentFile` patterns in systemd units
- age keys derivable from SSH host keys (minimal key management)

### Critical: SSH Host Key Backup Requirement

**The SSH host key `/etc/ssh/ssh_host_ed25519_key` is the master decryption key for ALL sops-nix secrets. Loss of this key means ALL secrets become permanently undecryptable.**

A **3-2-1 backup** must be established:

| Rule                  | Requirement             | Implementation                             |
| --------------------- | ----------------------- | ------------------------------------------ |
| **3** copies          | Production + 2 backups  | evo-x2 machine + USB drive + cloud storage |
| **2** different media | Different storage types | Local SSD + USB/Cloud                      |
| **1** offsite         | Geographic separation   | Cloud storage (e.g., Backblaze B2, S3)     |

Files to back up:

- `/etc/ssh/ssh_host_ed25519_key` (private key — **NEVER commit to git**)
- `/etc/ssh/ssh_host_ed25519_key.pub` (public key — for reference)

**Status: NOT YET IMPLEMENTED** — Must be completed before relying on sops-nix for production secrets.

### Negative

- No secret rotation (must re-encrypt manually)
- No web UI for browsing secrets
- No audit logging of secret access
- Single-user focused (no collaboration features)

### Migration Path

1. Add `sops-nix` as flake input
2. Generate age key from SSH host key
3. Create `.sops.yaml` with creation rules
4. Migrate `~/.config/gitea-sync.env` to encrypted sops file
5. Update Gitea systemd service to use `config.sops.secrets.*.path`
6. Repeat for other services as needed

## References

- [sops-nix GitHub](https://github.com/Mic92/sops-nix)
- [Infisical Self-Hosting Docs](https://infisical.com/docs/self-hosting/overview)
- [NixOS Wiki: Secret Management Comparison](https://wiki.nixos.org/wiki/Comparison_of_secret_managing_schemes)

## Related Decisions

- ADR-001: Home Manager for Cross-Platform Configuration
- ADR-003: Ban OpenZFS on macOS (platform-specific scoping precedent)

---

**Decision Record Owner:** SystemNix Architecture Team
**Last Updated:** 2026-03-29
**Next Review:** When secret management needs exceed single-user file-based workflow
