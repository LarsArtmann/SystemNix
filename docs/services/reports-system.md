# reports-system (report management web app)

**Owning module:** `modules/nixos/services/reports-system.nix` (the SystemNix layer) over the upstream portable module `nixosModules.reports-system` (flake input `reports-system`, repo `github:LarsArtmann/testing`, **PRIVATE**; `nix/module.nix`). The upstream module owns the options, the unit, the system user, the state directory and the portable hardening; the SystemNix layer adds port, secrets, backup, and the registry entry.

## What it is

`reports-system` is a report management web app (Go, templ/HTMX) with its own login and **no OIDC**. Binary `server`, unit `reports-system.service`, system user `reports-system`, state under `/var/lib/reports-system`.

## Architecture

| Piece   | Value                                                                                                          |
| ------- | -------------------------------------------------------------------------------------------------------------- |
| Listen  | `127.0.0.1:8113` (`lib/ports.nix` `reports-system`; the upstream module default is 8080, overridden here)       |
| vHost   | `https://reports.home.lan`, registry layer **protected**: oauth2-proxy forward auth for clients outside the LAN, LAN bypass. Because the app has no OIDC, external clients authenticate twice (gateway, then the app's own login). |
| Runs as | system user `reports-system` (`StateDirectory = reports-system`); SystemNix hardening on top (`harden`, `MemoryMax = 1G`, `ProtectSystem = "strict"`, `ioTier.background`, `onFailure` alert routing) |
| Truth   | two SQLite stores in `/var/lib/reports-system`: `reports.db` and `cqrs.db` (accounts and sessions live in the cqrs journal) |
| Backup  | `reports-system-backup.timer`, nightly 03:25 local + up to 5 min random delay, `Persistent`                     |
| Monitoring | three Gatus checks (see below); NOT in signoz-coverage: the binary ships no OTLP exporter (upstream `tracing.endpoint` is a dead config key) |

## Secrets

`sops` file `platforms/nixos/secrets/reports-system.yaml` with keys `reports_system_session_secret` and `reports_system_jwt_secret` (each a random 64 hex chars, minimum 32). They are rendered by the sops template `reports-system-env` (owner root, mode 0400) into `services.reports-system.environmentFile`; systemd (PID 1) reads it as `EnvironmentFile` and injects `REPORTS_SECURITY_SESSION_SECRET` and `REPORTS_SECURITY_JWT_SECRET` into the service process, so the service user never needs file access. Without them the server refuses to start ("session secret must be at least 32 characters").

Rotation: the values are never typed on a command line. Follow `.crush/skills/sops-secret-management/SKILL.md` for the recipe; the safe pattern is:

```bash
VALUE=$(openssl rand -hex 32)  # runtime variable, never an inline literal
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
  sops --set '["reports_system_session_secret"] "'"${VALUE}"'"' platforms/nixos/secrets/reports-system.yaml
```

Rotation restarts `reports-system.service` automatically (`restartUnits` on both secrets and the template).

## First run after deploy

Registration is the upstream default `auto`, which resolves to `bootstrap` outside development (`services.reports-system.registration`, upstream options `auto|open|bootstrap|closed`): exactly ONE account can register, it becomes the administrator, and registration then closes (403 `REGISTRATION_CLOSED`; `/auth/register` answers a 303 redirect to the login page).

Until that account exists, anyone who can reach the app can take the admin account. So the first-run step after a deploy is: open https://reports.home.lan and register the owner account immediately.

## State and backups

Truth: `reports.db` and `cqrs.db` in `/var/lib/reports-system`. Reports live in `reports.db`; accounts and sessions live in the `cqrs.db` journal. Both must be restored together, a restore of only one store is not supported.

Backup: `reports-system-backup.timer` fires nightly at 03:25 local time plus up to 5 minutes random delay, `Persistent`. The `reports-system-backup` oneshot runs as the service user, takes an online sqlite `.backup` of each store (3 attempts, `.timeout 30000`), gates on `PRAGMA quick_check`, gzips, and writes:

- `/mnt/pool/backups/reports-system/reports-db-<YYYY-MM-DD>.db.gz`
- `/mnt/pool/backups/reports-system/cqrs-db-<YYYY-MM-DD>.db.gz`

Retention 14 days. The registry entry declares backup freshness (pattern `*-db-*.db.gz`, max age 25 h). The directory is created by `reports-system-backup-dir` (owned by `reports-system`, mode 0750) and the backup unit requires the pool mount (`RequiresMountsFor`).

Restore procedure:

1. `systemctl stop reports-system`
2. `gunzip -c /mnt/pool/backups/reports-system/reports-db-<date>.db.gz > /var/lib/reports-system/reports.db` and likewise `cqrs-db-<date>.db.gz` into `/var/lib/reports-system/cqrs.db`
3. `chown reports-system:reports-system` both files, `chmod 0600`
4. `systemctl start reports-system`

## Monitoring

| Check              | Path       | Interval | Proves                                                     |
| ------------------ | ---------- | -------- | ---------------------------------------------------------- |
| Reports live       | `/live`    | 30s      | process up, vHost reachable                                |
| Reports ready      | `/ready`   | 60s      | the database check passes: readiness answers 503 when it fails, and the body must name the service (`"service":"reports-system"`) |
| Reports version    | `/version` | 5m       | build metadata is stamped and the serving binary is reports-system (body pattern `reports-system *`) |

## Troubleshooting

- `journalctl -u reports-system -n 50` is the first look.
- "session secret must be at least 32 characters": the sops secrets are missing or short. Check the rendered template and the two keys in the sops file; rotating/fixing them restarts the unit automatically.
- Missing `REPORTS_SECURITY_*` variables (the environment file did not render): same look, same fix.
- 403 `REGISTRATION_CLOSED` on register (and a 303 from `/auth/register` to the login page) is NOT an error: registration is closed because the administrator account already exists. If the admin account exists and you still need a change, that is an app-level operation, not a module knob.
- For application bugs: fix UPSTREAM in `/home/lars/projects/testing` with tests, never patched in SystemNix (see `docs/agents/integration-registry.md`, section "Consuming LarsArtmann Flakes").

## Ownership and doctrine

- The code lives upstream in the private flake input `reports-system` (`github:LarsArtmann/testing`, `git+ssh`). The `lib/lock-audit.nix` `deliberate` entry `"reports-system.nixpkgs"` records that the input deliberately does NOT follow root nixpkgs (its vendorHash is baked upstream; following would re-tool the go-modules FOD on every root-nixpkgs bump).
- Dashboard tile: "Reports" (Productivity group, generic `text-document.png` glyph, the project ships no brand mark).

## Open items

- CI deploy key: the flake input is a private git+ssh repo, so GitHub Actions needs a read-only deploy key appended to the bundle (bundle 2 recipe in `docs/agents/go-ecosystem.md`, "Bundle recipe for CI-private flake inputs"). This is an OPEN owner step; row in `docs/todo/services.md`.

## Related

- [timesheets.md](./timesheets.md) and [invoices-dashboard.md](./invoices-dashboard.md) — sibling loopback-behind-protected-vHost services with the same nightly sqlite dump shape
- [../agents/integration-registry.md](../agents/integration-registry.md) — how the vHost/checks/tile/backup fan-out works
- [../agents/data-ownership.md](../agents/data-ownership.md) — the two-store truth classification
