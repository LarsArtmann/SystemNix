# SearXNG — Agent Notes

> Module: `modules/nixos/services/searxng.nix`. Body migrated verbatim from AGENTS.md on 2026-10-01 (restructure) — treat the section below as authoritative agent notes for this service.

## SearXNG

- **`enable` infinite recursion** — Wrapper MUST NOT set `services.searx.enable` inside `lib.mkIf cfg.enable` where `cfg = config.services.searx`.
- **No `restartTriggers` in direct server mode** — nixpkgs only sets them for uWSGI mode. SystemNix adds them.
- **Port 8889** (not 8888 — SigNoz OTel collector owns 8888).
- **Engine init never retried** — Engines that fail network during `init()` at boot stay permanently disabled. DNS-gate `mkDnsGate` in `ExecStartPre` ensures DNS is ready.
- **`formats = [ "html" ]`** — Blocks JSON API (403). Deliberate privacy hardening. Test in HTML mode.
- **`autocomplete = "duckduckgo"`** — Google leaked every keystroke.
- **XFF health-check noise is benign** — `/healthz` is exempt from limiter.

