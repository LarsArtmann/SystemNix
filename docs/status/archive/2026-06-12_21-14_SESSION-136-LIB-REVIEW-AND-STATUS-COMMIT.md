# Session 136 — Comprehensive Status Update (2026-06-12 21:14 CEST)

**Date:** 2026-06-12 21:14 CEST / 2026-06-12 19:14 UTC
**Status:** ✅ `just test-fast` passes; one uncommitted zellij fix in working tree
**Scope:** Full SystemNix project status after session 135 SDK-daemon/PMA build fix

---

## Summary

SystemNix is in a stable, eval-clean state on x86_64-linux. The big win from session 135 (SDK discovery daemon integration, PMA build fix, cmdguard `MustNewCommand` shim, `crush-daily` module fix) is deployed via `nh os boot` and awaiting reboot. Four local commits are ahead of `origin/master` and still need to be pushed. The only working-tree change is a small zellij keybinding correction.

In this session we also completed a focused `nix-review` of the shared `lib/` helpers, identifying several minor hardening/consistency gaps but no build breakers.

---

## a) FULLY DONE ✅

### 1. Session 135 Deployed
- SDK discovery daemon wired between PMA and Overview
- `enrichment/meta` sub-module committed and tracked
- cmdguard `MustNewCommand`/`MustNewCommandParent` shim restored
- PMA `branching-flow` linter key renames applied
- `crush-daily.nix` module evaluation fixed (pkgs scope)
- `flake.lock` updated for overview, PMA, cmdguard, project-discovery-sdk
- `AGENTS.md` updated with new gotchas

### 2. Build & Eval Health
- `just test-fast` (== `nix flake check --no-build`) passes
- All 40 NixOS modules evaluate
- All packages evaluate (29 custom packages)
- Darwin config evaluates (aarch64-darwin omitted from `--no-build`)

### 3. `lib/` Review
- Read all 8 files in `lib/`
- Verified no critical/build-breaking issues
- Reported structural/consistency/hardening gaps (see section e)

### 4. Documentation
- This status report written

---

## b) PARTIALLY DONE ⚠️

### 1. SDK Daemon Socket Verification
- Config deployed via `nh os boot`
- Awaiting reboot to verify:
  - `/run/project-discovery/daemon.sock` exists
  - PMA creates the socket
  - Overview probes and delegates to daemon
  - No race where Overview starts before the socket exists

### 2. Push to Origin
- 4 commits ahead of `origin/master`
- Not pushed yet (need explicit approval per workflow)

### 3. Zellij Keybinding Fix
- Working tree contains fix for `SwitchToMode "rename"` → `SwitchToMode "RenameTab"; TabNameInput 0;`
- Not committed yet (will be committed with this status report)

### 4. Immich OAuth End-to-End
- Pocket ID OIDC client provisioned in session 134
- Still needs login test after reboot

---

## c) NOT STARTED ❌

### 1. Reboot evo-x2
- Needed to activate session 135 changes and validate boot time target (~35 s)

### 2. Pocket ID Email Verification
- SMTP wired; needs test email/login notification

### 3. Reset Monitor365 Failed State
- `systemctl --user reset-failed monitor365-server` after deploy

### 4. Twenty CRM 502 Diagnosis
- Container OOM or PG connection exhaustion suspected
- Need `docker logs twenty-server-1 --tail=100`

### 5. Gatus Health Check Audit
- 6 services possibly misconfigured

### 6. BTRFS `/data` Subvolume Migration
- `just snapshot-migrate-data` — currently toplevel, no snapshots

### 7. TODO_LIST.md Refresh
- Last updated session 132; many items now stale or completed

### 8. Archive Old Status Reports
- 187 files in `docs/status/`, 374 in `docs/status/archive/`

### 9. ROADMAP.md / CHANGELOG.md
- Long-term docs still missing

---

## d) TOTALLY FUCKED UP 💥

### 1. Disk Pressure on `/`
- `/dev/nvme0n1p6`: **93% used** (462G / 512G)
- Only 36G free on root filesystem
- Risk: builds can fail mid-way; Nix GC needed but can be slow/dangerous on constrained disk

### 2. Manual VendorHash Cascade
- Each upstream Go repo change cascades through 3-5 consumers
- Still doing `vendorHash = ""` → build → `got:` → commit → update lock manually
- Caused 4 iterations in session 135

### 3. 45 Open TODOs vs. 35 Completed
- TODO_LIST.md is growing faster than it is being closed
- Many items are long-term/upstream wishlist, diluting focus

### 4. Status Report Bloat
- 187 top-level status files (plus 374 archived)
- Hard to find signal in noise

---

## e) WHAT WE SHOULD IMPROVE 🔧

1. **Automate vendorHash updates** — single `just update-hash <pkg>` command
2. **CI for upstream Go repos** — catch untracked sub-modules and stale `go.sum`
3. **Add NixOS test for SDK daemon integration** — verify socket + Overview probe
4. **Reclaim disk on `/`** — run `nix-collect-garbage` or move store paths to `/data`
5. **Standardize `RestrictAddressFamilies`** for Docker services in `lib/docker.nix`
6. **Harden helper services** (`imagePull`, `db-backup`) in `lib/docker.nix`
7. **Pin all container image digests** in `lib/images.nix`
8. **Refactor `rec` in `lib/images.nix` and `lib/rocm.nix`** to `let ... in`
9. **Document why `ProtectHome = false` / `NoNewPrivileges = false`** in `mkDesktopNotifyService`
10. **Review `KillMode = "process"`** in `lib/docker.nix` for orphan-container risk
11. **Consolidate socket path** for project-discovery daemon across PMA and Overview modules
12. **Push open commits** to origin master
13. **Reboot and verify** all session 135 changes
14. **Archive or delete** pre-session-100 status reports
15. **Split oversized modules** — `monitor365.nix` (716L), `signoz.nix` (705L), `forgejo.nix` (583L)
16. **Add auth/permissions** to world-readable daemon socket (`0o666`)
17. **Make Overview re-probe daemon** periodically instead of only at startup
18. **Create `ROADMAP.md`** for long-term direction
19. **Create `CHANGELOG.md`** for user-facing changes
20. **Re-enable or remove** disabled services (`voice-agents`, `minecraft`, `photomap`)

---

## f) TOP 25 THINGS TO DO NEXT

| # | Priority | Task | Impact | Effort |
|---|----------|------|--------|--------|
| 1 | P0 | **Reboot evo-x2** and verify SDK daemon socket, Overview probe, Caddy boot order, Pocket ID SMTP | Critical | 10 min |
| 2 | P0 | **Push 4 local commits** to origin master (after user approval) | Critical | 1 min |
| 3 | P0 | **Commit zellij keybinding fix** and push | Low | 2 min |
| 4 | P1 | **Run `nix-collect-garbage`** to reclaim `/` disk (93% full) | High | 30 min |
| 5 | P1 | **Write `just update-hash <pkg>`** automation for vendorHash cascades | High | 30 min |
| 6 | P1 | **Update TODO_LIST.md** — mark completed items, archive long-term wishlist | High | 30 min |
| 7 | P1 | **Fix Twenty CRM 502s** — inspect Docker logs / memory limits | High | 1 h |
| 8 | P1 | **Audit Gatus health checks** — correct URLs / expectations | High | 1 h |
| 9 | P1 | **Reset failed Monitor365 state** and verify server/agent health | Med | 10 min |
| 10 | P1 | **Test Immich OAuth login** via Pocket ID end-to-end | High | 20 min |
| 11 | P2 | **Apply `lib/docker.nix` hardening fixes** from section e | Med | 1 h |
| 12 | P2 | **Pin remaining image digests** in `lib/images.nix` | Med | 30 min |
| 13 | P2 | **Refactor `rec` → `let ... in`** in `lib/images.nix` and `lib/rocm.nix` | Low | 20 min |
| 14 | P2 | **Add NixOS test for daemon integration** | High | 2 h |
| 15 | P2 | **Archive old status reports** pre-session-100 | Low | 30 min |
| 16 | P2 | **Create `ROADMAP.md`** | Med | 1 h |
| 17 | P2 | **Create `CHANGELOG.md`** | Med | 2 h |
| 18 | P2 | **Split oversized modules** (`monitor365`, `signoz`, `forgejo`) | Med | 4 h |
| 19 | P3 | **Add daemon socket auth / permissions** | Med | 1 h |
| 20 | P3 | **Make Overview re-probe daemon** periodically | Med | 1 h |
| 21 | P3 | **BTRFS `/data` subvolume migration** | High | 2 h |
| 22 | P3 | **Triage disabled services** (`voice-agents`, `minecraft`, `photomap`) | Low | 30 min |
| 23 | P3 | **PMA API catch-up** — migrate to `NewCommand` error handling | Med | 2 h |
| 24 | P3 | **CI for LarsArtmann Go repos** | High | 4 h |
| 25 | P3 | **Add daemon metrics / health endpoint** | Low | 1 h |

---

## g) TOP QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**Should we immediately push the 4 local commits + zellij fix to `origin/master` before rebooting, or wait until after reboot verification?**

Arguments for pushing now:
- All checks pass (`just test-fast`)
- Commits are already deployed via `nh os boot`
- Keeps origin/master in sync with deployed state
- The zellij fix is tiny and unrelated to daemon work

Arguments for waiting:
- If reboot reveals a critical bug, we avoid pushing broken code to main
- Session 135 had a lot of moving parts (SDK, cmdguard, PMA, Overview, crush-daily)
- Safer to verify runtime behavior first

I don't have the project's risk tolerance / deploy policy, so I need a human decision before pushing.

---

## System State Snapshot

| Metric | Value |
|--------|-------|
| Branch | `master` |
| Ahead of origin | **4 commits** |
| Build | ✅ `just test-fast` passes |
| Uncommitted changes | `platforms/nixos/programs/zellij.nix` |
| NixOS modules | 40 |
| Custom packages | 29 |
| Open TODOs | 45 |
| Completed TODOs | 35 |
| Disk `/` | 93% used (462G / 512G, 36G free) |
| Disk `/data` | 77% used (786G / 1.0T, 238G free) |
| `flake.lock` age | ~11.5 hours |

## Repos Modified Recently

- `SystemNix` — 4 commits local, awaiting push
- `project-discovery-sdk` — `WithSocketMode`, `enrichment/meta`
- `cmdguard` — `MustNewCommand` shim
- `projects-management-automation` — daemon server, branching-flow fixes
- `overview` — daemon probe, sub-modules

---

_Waiting for instructions._
