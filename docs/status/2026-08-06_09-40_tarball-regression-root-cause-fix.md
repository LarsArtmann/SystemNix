# nixpkgs Tarball Regression: Root Cause Found and Fixed

**Date:** 2026-08-06 09:40
**Session goal:** Investigate logs to fix the recurring tarball regression properly
**Outcome:** Root cause identified and eliminated at the source. Verified with controlled tests.

---

## The Root Cause (Finally)

The global flake registry at `channels.nixos.org/flake-registry.json` contains `exact: true` entries that map ALL nixpkgs refs to channel tarballs:

```json
{
  "from": {"id": "nixpkgs", "type": "indirect", "ref": "nixos-unstable"},
  "exact": true,
  "to": {"type": "tarball", "url": "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz"}
}
```

When `nix flake update` runs with `use-registries = true`, it consults these entries and rewrites the flake.lock nixpkgs `original` field from `type: github` to `type: tarball`.

### Why the Previous Override Failed

The NixOS config had:
```nix
nix.registry."nixpkgs/nixos-unstable" = { to = { type = "github"; ... }; };
```

This creates a registry entry with `from.id = "nixpkgs/nixos-unstable"` — a **combined string**. But the global registry uses `from.id = "nixpkgs"` + `from.ref = "nixos-unstable"` — **separate fields**. These are DIFFERENT registry keys. The override never matched the global entry it was supposed to override.

Confirmed via `nix registry list` (before fix):
```
system flake:nixpkgs path:/nix/store/...                    ← override for bare nixpkgs (worked)
global flake:nixpkgs/nixos-unstable channels.nixos.org/...   ← tarball entry (NOT overridden!)
```

### The PMA Daemon's Role (Corrected)

The PMA daemon is **NOT** the root cause — it's a **force multiplier**. It's a file watcher + auto-committer (`pma-daemon/` in `projects-management-automation`). It does NOT run `nix flake update`. It watches `/home/lars/projects/*` for file changes and commits them. When something else runs `nix flake update` (user, CI, direvn), the daemon commits the resulting lockfile changes — including the tarball regression.

---

## The Fix (Two Layers)

### Layer 1: Eliminate the Source

```nix
nix.settings.flake-registry = builtins.toFile "empty-flake-registry.json" ''
  {"flakes":[],"version":2}
'';
```

Points the `flake-registry` setting at a local empty file instead of `channels.nixos.org`. Nix never downloads the global registry, so the tarball entries never exist. System + user registries still resolve indirect refs.

### Layer 2: Correct-Format Overrides

```nix
nix.registry.nixpkgs-nixos-unstable = {
  from = { type = "indirect"; id = "nixpkgs"; ref = "nixos-unstable"; };
  to = { type = "github"; owner = "NixOS"; repo = "nixpkgs"; ref = "nixos-unstable"; };
  exact = true;
};
```

Uses explicit `from = { id = "nixpkgs"; ref = "nixos-unstable"; }` — matching the global registry's key format. Even if the global registry is somehow restored, this override takes priority (system > global).

Both fixes applied to `platforms/nixos/system/configuration.nix` and `platforms/darwin/nix/settings.nix`.

---

## Verification

| Test | Before Fix | After Fix |
|------|-----------|-----------|
| `nix registry list \| grep nixpkgs` | 8 `global` entries (7 tarball) | 0 `global` entries |
| `nix flake update nixpkgs` | rewrites to `type: tarball` | stays `type: github` ✓ |
| `nix flake lock --update-input nixpkgs` | rewrites to `type: tarball` | stays `type: github` ✓ |
| `nix flake check --no-build` | passes (guard catches tarball) | passes (no tarball to catch) ✓ |
| Deploy + post-deploy smoke test | N/A | 29 PASS, 0 FAIL, 2 SKIP ✓ |

---

## Additional Work

### fix-nixpkgs-lock.sh Testing

- **`--latest` mode**: TESTED and WORKING. Converts tarball → github using `nix flake prefetch`. However, the `--latest` update can pull a newer nixpkgs rev with breaking package changes (e.g., `libdisplay-info_0_2` removal). The script's `nix flake check --no-build` verification correctly catches this.
- **Re-lock step** (`nix flake lock --no-use-registries`): SAFE with the empty flake-registry. Before the fix, this step could re-tarball nixpkgs. Now it cannot — the global registry is empty.
- **`nix run .#fix-nixpkgs-lock`**: Still DOES NOT WORK when the lockfile is broken (flake eval fails before the app is found). Must use `bash scripts/fix-nixpkgs-lock.sh` directly. This is documented in AGENTS.md.

### Health-Check Cleanup

Added 3 missing active services to `platforms/nixos/scripts/service-health-check`:
- `discordsync` (system service)
- `searx` (system service — SearXNG)
- `qmd-mcp` (user service — qmd MCP)

### AGENTS.md Updated

Replaced the 4-line "RECURRING" tarball regression entry with a comprehensive root cause explanation, including: the global registry `exact: true` mechanism, why the previous override format failed, the two-layer fix, and the correct recovery command (`bash scripts/fix-nixpkgs-lock.sh`, NOT `nix run .#fix-nixpkgs-lock`).

---

## Defense-in-Depth Inventory (Updated)

| Layer | Location | Status | Notes |
|-------|----------|--------|-------|
| **Empty flake-registry** | `configuration.nix` | ✅ ACTIVE | Eliminates ALL global tarball entries at source |
| **Correct-format overrides** | `configuration.nix` | ✅ ACTIVE | `from = { id; ref; }` matches global registry key format |
| **Darwin mirror** | `platforms/darwin/nix/settings.nix` | ✅ COMMITTED | Needs `nix run .#deploy` on macOS to activate |
| Eval-time guard | `flake.nix:519-534` | ✅ ACTIVE | Last line of defense — catches if regression somehow recurs |
| Pre-commit hook | `.githooks/pre-commit` | ✅ ACTIVE | Catches manual commits (daemon bypasses hooks) |
| CI normalization | `.github/workflows/flake-update.yml` | ✅ COMMITTED | Runs fix script after update, creates PR |
| Recovery script | `scripts/fix-nixpkgs-lock.sh` | ✅ TESTED | Both pin-current and `--latest` modes verified |

---

## Remaining Items

1. **Reboot evo-x2** — NOT needed for the registry fix (it's already active via `nh os switch`). But a reboot would clear any stale nix daemon state. Low priority.
2. **Deploy to macOS** — activate Darwin registry override (`nix run .#deploy` on macOS)
3. **Run `nix-collect-garbage --delete-older-than 3d`** — after confirming new profile works for a day
4. **DiscordSync Turso quota** — external cloud sync plan limit, not caused by this work
