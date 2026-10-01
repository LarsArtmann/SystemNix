# EMEET PIXY (webcam daemon) — Agent Notes

> Module: `modules/nixos/services/emeet-pixyd.nix`. Body migrated verbatim from AGENTS.md on 2026-10-01 (restructure) — treat the section below as authoritative agent notes for this service.

## EMEET PIXY (webcam auto-activation daemon, registry-wired 2026-09-30)

**Module:** `modules/nixos/services/emeet-pixyd.nix` — SystemNix wrapper importing upstream `inputs.emeet-pixyd.nixosModules.default` (the import MOVED here from `systems/evo-x2.nix`, cv.nix pattern; the wrapper was surface-verified unit-byte-identical at the move). Upstream owns everything: the graphical-session USER unit (`emeet-pixyd.service`), the v4l2 daemon, loopback `127.0.0.1:${ports.emeet-pixyd}` (8090) with web panel + control API. The wrapper layers ONLY the registry wiring: `services.integration.emeet-pixyd` (vHost `emeet-pixyd.home.lan` Layer 2 protected — the API carries webcam CONTROL endpoints with no native auth; cloud domain mirrors automatically), DNS subdomain, two Gatus endpoint checks, Infrastructure dashboard tile, unconditional catalog entry (`healthPath /api/health`).

- **The endpoint checks are DELIBERATELY SILENT (`alert = ""`) and `monitored = false`** — the daemon is a graphical-session user unit: down during reboots and SSH-only periods is EXPECTED state, so a paging HTTP check would false-page Discord on every reboot (niri session-aware doctrine). Paging is owned by the session-aware meta check in `gatus-config.nix` (`system_emeet_pixyd_expected_down`, fires only when niri runs but the daemon doesn't). Do NOT "fix" the silent checks into alerting ones. `/api/health` answers 503 "offline" when the webcam is unplugged but the daemon is alive — hence `[STATUS] < 500`, not `== 200`, on the liveness check.
