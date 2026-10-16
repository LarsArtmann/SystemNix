# Draft — NixOS/nixpkgs issue — nixos/crowdsec: three start-failure gaps

**Title:** `nixos/crowdsec: setup start-fails on fresh systems (rootDir not tmpfiles-created, non-idempotent machine add) + CAP_SYSLOG is inert under PrivateUsers`

**Verified against:** nixpkgs master `nixos/modules/services/security/crowdsec.nix` fetched 2026-10-16 (all three present), plus crowdsec v1.8.1 live on NixOS 25.x.

---

> [!NOTE]
> This filing was drafted by GLM-5.3-flash via Crush from an AI-run investigation, not at my request.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

TL;DR: the module can hard-fail `crowdsec.service` at first start three different ways — `/var/lib/crowdsec` is never tmpfiles-created (LAPI credential write EACCES), the `machine add` setup step is non-idempotent after that failure (orphan DB row → permanent "user already exist"), and the shipped `CAP_SYSLOG` cannot work because `PrivateUsers = true` makes ambient capabilities inert for host inodes. Fixes for all three are small; we run them in production.

## Problem

### 1. `systemd.tmpfiles.settings."10-crowdsec"` never creates `rootDir`

The tmpfiles list covers `stateDir`, `hubDir`, `confDir` and the local-* subdirs — but not `/var/lib/crowdsec` itself. systemd-tmpfiles creates missing parents root:root, so on a fresh system the state root materializes `root:root 0755` and the LAPI credential write (setup runs as `cfg.user`) fails with EACCES. Live symptom on our host: first boot's setup failed writing the credentials file; adding a `d`-rule for `rootDir` (which also re-chowns existing dirs on later activations) fixed it.

### 2. `machine add --auto` is non-idempotent after a failed credentials write

Setup guards with:

```bash
if [ ! -s "${cfg.settings.general.api.client.credentials_path}" ]; then
  ${cscli} machine add "${cfg.name}" --auto
fi
```

`cscli machine add` writes the DB row first and the credentials file second. When the file write fails (e.g. via gap 1), the DB keeps an orphan machine while the file stays absent — so the guard passes on every later start and `machine add` fails with `user already exist`, start-failing the unit forever. Workaround we run before the add:

```bash
if [ ! -s "${credentials_path}" ]; then
  cscli machines delete "${cfg.name}" --ignore-missing || true
fi
```

(`--ignore-missing` makes it a no-op on healthy boots; verified against `cmd/crowdsec-cli/climachine/delete.go` v1.8.1 — no confirmation prompt, missing row returns nil.)

### 3. `CAP_SYSLOG` in `CapabilityBoundingSet` cannot work under `PrivateUsers = true`

`crowdsec.service` ships `PrivateUsers = true` together with `CapabilityBoundingSet = [ "" "CAP_SYSLOG" ]`. Capabilities held inside a user namespace do not apply to host inodes, so that CAP_SYSLOG grants nothing; journal reads actually work because of `users.users.${cfg.user}.extraGroups = [ "systemd-journal" ]` — the group mechanism, not the capability. We hit the same wall from the outside: adding `AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ]` to read another service's `0750` log dir silently globbed zero files under `PrivateUsers` (live: `No matching files for pattern` at every start, zero file-source hits in `/metrics`); putting the crowdsec user in the log-owning group via `extraGroups` is the fix, because supplementary gids map through the userns and the DAC group check needs no capability.

Suggestion: drop the inert `CAP_SYSLOG` (or comment why it is dead) and document that additional log sources are accessed via `extraGroups` — anyone following the capability pattern the module itself suggests will silently read nothing.

## Proposed fixes

1. Add `rootDir` to the tmpfiles `d` list.
2. Orphan-machine cleanup before `machine add` (snippet above).
3. Remove/comment `CAP_SYSLOG`; document group-membership as the supported path for extra log sources.

Happy to send a PR for any/all of these.

💘 Generated with Crush
