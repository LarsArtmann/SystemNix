# Monitor365 — Agent Notes (DISABLED)

> Module: `modules/nixos/services/monitor365.nix`. Body migrated verbatim from AGENTS.md on 2026-10-01 (restructure) — treat the section below as authoritative agent notes for this service.

## Monitor365

**DISABLED since 2026-08-12** (`enable = false` in configuration.nix, agent + server): the vendored `wireguard-collector` crate lives in a PRIVATE LarsArtmann repo — the Nix build can never fetch it ("could not read Username", 404 on sum.golang-class fetch). Re-enable requires an owner decision: publish the crate to crates.io, make the repo public, or vendor it into the monitor365 workspace. Post-deploy checks auto-SKIP when the units are absent; Gatus checks are enable-gated.

- **Package alias trap** — `pkgs.monitor365` = agent (CLI), NOT server. Server is `monitor365-server` (symlinkJoin with WASM UI).
- **No JIT SSO provisioning** — Users MUST be pre-provisioned via bootstrap or `create-admin` CLI. SSO login fails if email doesn't match existing user.
- **DuckDB not SQLite** — Uses `.duckdb` extension. `normalize_db_path` converts `.db` → `.duckdb` as safety net.
- **Daily event limit override** — `monitor365-schema-migrate` runs `UPDATE tenants SET max_events_per_day = 1000000000` on every boot. Do NOT remove — server re-syncs upstream default on bootstrap.
- **DuckDB WAL corruption self-heal** — `ExecStartPre` removes `.wal` on every startup (always means unclean shutdown). Restores from backup if main DB missing.
- **DuckDB pool deadlock watchdog** — `monitor365-server-watchdog` (every 5min) checks `/health` + counts "pool acquire failed" journal errors. `Restart=always` only covers process exit — degraded-but-alive states need active health probes. **Must use `journalctl --grep` + `-n` cap** — the naive `journalctl | grep -c` pattern serialized 270+ MB and burned 98% CPU every 5 minutes because it piped every journal entry through grep. `--grep` filters inside journalctl; `-n 21` enables early termination
- **Graphical collectors need** — `input`/`video` groups, `ProtectProc = "default"` (not `invisible`), `%t` (not `$XDG_RUNTIME_DIR`) in ExecStart.
- **utoipa-swagger-ui overlay** — `overlays/linux.nix` deletes 0444 zip between cargo check/build. Remove when upstream fixes `fs::copy`.
- **libspa-sys vendored Cargo.tomls** — ALWAYS strip `[lints]` sections when regenerating vendor patches. `workspace = true` fails in sandbox.

