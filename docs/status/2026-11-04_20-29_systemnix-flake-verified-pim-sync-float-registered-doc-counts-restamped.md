# Status: SystemNix flake config verified — pim-sync float registered, doc-counts re-stamped

**2026-11-04 20:29 CET — session report (verification + two real fixes; no deploy run).**

**Scope line — what this session VERIFIED (fresh commands, this session):**

- `nix eval .#nixosConfigurations.{evo-x2,rpi3-dns,zfs-vm}.config.system.build.toplevel.drvPath` → all three evaluate to toplevel derivations (evo-x2 `n4lcyhsz9…26.11.20261015.fe13242.drv`).
- `nix eval .#nixosConfigurations.evo-x2.config.services.forgejo.canonicalRepos --json` → 11 entries incl. `fine-tune` + `pim-sync` (the 19:14 session's edit resolves through the module system, not just parse).
- 5 audit checks built green: `lock-audit-selftest`, `flake-lock-audit-selftest`, `forgejo-family-condition-selftest`, `forgejo-scripts-fixture`, `lock-float-selftest` — the last of these retires 19:14-report task #22 (forgejo fixtures unaffected by the new canonicalRepos entries).
- Full evo-x2 toplevel **BUILD** rc=0 (float-register proof log `~/.cache/lockfloat/float-proof-20261104-202212.log`) — also serves as the pim-sync vendorHash FOD probe the wave plan required at eval scale.
- Post-fix `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --dry-run` → deploy plan resolves (pim-sync provision units → system-units → toplevel), lock-float audit silent.
- **NOT verified:** a real deploy (owner action, IO-quiet window — now unblocked); full `nix flake check` (≈170 checks × all systems, too heavy for this session; the targeted battery + real toplevel build stand in); whether pim-sync's wrapper module is correct at runtime (enable=false, unexercised by design).

## What was broken (two instances, both fixed)

1. **19:14-reported lock-audit blocker (`go-nix-helpers_3` deep treefmt)** — already fixed by the parallel session before this one started: commit `1d5a549a2` added the `docs-gates.inputs.erraudit.inputs.go-nix-helpers.inputs.treefmt-nix.follows` deep override (same regrowth class, different edge) and `322a1d83c` regenerated the lock so the root `go-nix-helpers_3` node follows root flake-parts/treefmt-nix/nixpkgs. Verified by eval + the lock-audit selftests. Nothing to do.
2. **pim-sync wave left the float ceremony's last leg undone** — the ~20:19 executor added the `pim-sync` input + follows + wrapper module + tombstones ("prove-then-commit lock+registry together (float-register protocol)" was in its own task text) but `flake/expected-locks.nix` had NO `pim-sync` row → the lock-float audit failed every HOST-CONFIG eval/build → deploys blocked again. Fixed by running the documented ceremony (`scripts/float-register.sh`): registry row `pim-sync = "115328707de4…"` regenerated from the lock, **full evo-x2 toplevel build proof rc=0**, daemon-race fallback verified the lock+registry pair consistent (`b67179833` swept the lock; registry staged for the daemon). Local pim-sync HEAD == locked rev (ahead by 0) — the unpushed-local-work trap did not apply.
3. **doc-counts gate blocked the ceremony's commit** — `README nixosModules asserts 144, eval truth is 145` (the wave's `modules/nixos/services/pim-sync.nix`). The gate threw at its first stale anchor, masking whether the other three anchors were also stale — checked all four manually: gatus 280 ✓, packages 49 ✓, modules 144→145 stale in BOTH README and FEATURES. Re-stamped per the house convention (dated chronicle fragment + FEATURES re-derive note, 150 non-helper files counted to match 145+5); `.#checks.x86_64-linux.doc-counts` now builds green.

## Remaining (owner-gated, unblocks queued work)

- **Deploy SystemNix** (19:14-report f#2/#3): everything is green and landable now; the deploy attaches phase-5 push mirrors for fine-tune/pim-sync AND brings the pim-sync wrapper (enable=false) into the fleet. Deploy script runs float-register itself (FLOAT_REGISTER=0 opts out) — expected instant exit (registry matches lock).
- Known eval warnings untouched deliberately (tracked backlog): catalog integration-subdomains without catalog entries (T-0265/T-0519, warning-by-design until `dns-local.nix` deletion), caddy ghost subdomain `llama` (registryBlindSubdomains class), ZFS deprecation pair on zfs-vm (`latestCompatibleLinuxPackages`, `forceImportRoot` default) — kernel-policy decisions, not drive-by fixes.
- pim-sync owner ladder unchanged (sops values → dry-run timer review → live flip) per the wave plan.

## Notes for the next session

- The float ceremony's daemon-race fallback checks `git diff --quiet` (unstaged only); a staged-but-uncommitted registry passes it. Benign here (daemon sweeps), but if the daemon ever stalls, a manual `git commit` of the staged pair is the completion step.
- `nix build` + parallel evals contend on the eval-cache SQLite ("busy" warnings, ignored, non-fatal) — run the heavy evals sequentially when practical.

*Report per `status-report` skill; no commit performed — the auto-commit daemon sweeps this file.*
