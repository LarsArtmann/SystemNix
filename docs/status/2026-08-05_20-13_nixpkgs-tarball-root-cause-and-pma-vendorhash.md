# Status: nixpkgs Tarball Root-Cause Fix + PMA vendorHash Mismatch (In Progress)

**Date:** 2026-08-05 20:13  
**Session scope:** Fix the recurring `nixpkgs flake.lock regression: original type is "tarball"` error, get all inputs on latest, and unblock `nix run .#deploy` / `nh os switch`.  
**Overall verdict:** nixpkgs lock regression is fixed at the root cause (NixOS system registry override). All inputs are updated to latest. Deploy is still blocked by a PMA vendorHash mismatch that surfaced after moving nixpkks to current GitHub.

---

## What the user reported

```
error: nixpkgs flake.lock regression: original type is "tarball", expected "github".
The nix global registry rewrote nixpkgs to a tarball which may be stale.
Fix: manually edit flake.lock nodes.nixpkgs.original to type "github".
```

This was blocking `nh os switch` and every `nix flake` / `nix eval` / `nix build` command.

---

## What I did (chronological)

| Step | What | Verdict |
|------|------|---------|
| 1 | Read `flake.lock`; confirmed `nodes.nixpkgs` is `type: "tarball"` pointing to `channels.nixos.org` / stale Jan 2026 rev `3497aa5`. | OK |
| 2 | Verified the global Nix registry is the root cause: `global flake:nixpkgs/nixos-unstable https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz`. | OK |
| 3 | Searched public code for similar issues; confirmed Renovate/Nix tooling recognizes this `channels.nixos.org` tarball pattern but no upstream fix exists. | OK |
| 4 | Manually fixed `flake.lock` `nodes.nixpkgs` to latest GitHub `nixos-unstable` (`e72e4f299401`, `lastModified: 1785828668`, `narHash: sha256-8fsyqeO+mJqvIzeO4xIpgJe/f7MTbbVTEC6RT6WSXNs=`). | OK |
| 5 | Discovered `nix flake update` (with or without `--no-use-registries`, `--override-flake`, or `--override-input`) immediately reverts `nixpkgs` to tarball because the registry rewrite happens during lock refresh. | Root cause confirmed |
| 6 | Added a NixOS system registry override so `nixpkgs/nixos-unstable` resolves to GitHub directly in `platforms/nixos/system/configuration.nix`. | OK |
| 7 | Ran `nix flake update` to update the remaining inputs, then programmatically restored only the `nodes.nixpkgs` node to GitHub. | OK |
| 8 | Ran `nix flake check --no-build`; guard passes, but `packages.x86_64-linux.projects-management-automation` fails with a vendorHash mismatch. | New blocker |
| 9 | Diagnosed the vendorHash mismatch: with current nixpkgs the expected `vendorHash` for PMA is `sha256-mWaqAUTxYHEqXiZdGS3bIFllLxC+3REpyjwJIrXvjf4=` vs. the upstream `sha256-3LYbR/K12onY6rNEntu8GV3JXSG0Bl9tTqkaYnfWCCk=`. | OK |
| 10 | Edited `~/projects/projects-management-automation/flake.nix` to the new vendorHash. | Done locally, not yet committed/pushed |

The auto-commit daemon already committed the SystemNix-side changes:

- `cbe9fd85` — `chore(flake): update nixpkgs and switch source to GitHub`
- `61d3f699` — `fix(nixos): force nixpkgs/nixos-unstable registry to resolve from GitHub directly`
- `4d2969ab` — `chore(flake): update hermes-agent and homebrew-cask lockfile inputs`

---

## A) FULLY DONE

1. **nixpkgs tarball regression fixed.** `flake.lock` `nodes.nixpkgs` is now `type: "github"` at current `nixos-unstable`.
2. **Root cause addressed.** Added NixOS system registry override so `nixpkgs/nixos-unstable` resolves directly to GitHub instead of `channels.nixos.org` tarball.
3. **All flake inputs refreshed.** Inputs that had newer versions were updated (art-dupl, discordsync, hermes-agent, homebrew-cask, NUR, projects-management-automation, etc.).
4. **nixpkgsTarballGuard passes.** `nix flake` / `nix eval` no longer fails with the tarball assertion.

---

## B) PARTIALLY DONE

1. **PMA vendorHash fix.** The correct hash is known (`sha256-mWaqAUTxYHEqXiZdGS3bIFllLxC+3REpyjwJIrXvjf4=`) and the upstream `flake.nix` is edited, but it is not yet committed, pushed, or consumed by SystemNix.

---

## C) STILL BROKEN / BLOCKING

1. **`nix flake check --no-build` fails** on `packages.x86_64-linux.projects-management-automation` with:

   ```
   error: hash mismatch in fixed-output derivation '...-projects-management-automation-ef18f2c-go-modules.drv':
            specified: sha256-3LYbR/K12onY6rNEntu8GV3JXSG0Bl9tTqkaYnfWCCk=
               got:    sha256-mWaqAUTxYHEqXiZdGS3bIFllLxC+3REpyjwJIrXvjf4=
   ```

   This prevents `nix run .#deploy` / `nh os switch` from completing.
2. **Darwin registry override not added.** The `nix.registry` override is only in the NixOS config. macOS will still use the global tarball registry until a parallel fix is added to `platforms/darwin/nix/settings.nix` (or nix-darwin is configured via `nix.registry` if supported).
3. **No automated defense against future tarball regressions.** A pre-commit or eval-time check that rejects tarball-type `nixpkgs` nodes would catch this before the daemon commits it. Currently only the `nixpkgsTarballGuard` assertion exists, which fires after the lock is already corrupted.

---

## D) NEXT STEPS (requires your go/no-go)

1. **Commit and push the PMA vendorHash fix** in `~/projects/projects-management-automation` (the file is already edited). I will not commit upstream without explicit instruction.
2. **Update SystemNix `flake.lock`** to the new PMA rev (via `nix flake lock --update-input projects-management-automation`).
3. **Re-run `nix flake check --no-build`** and `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` to confirm the deploy path is clear.
4. **Deploy** with `nix run .#deploy` so the NixOS registry override takes effect on the host.
5. **(Optional but recommended)** Add the same registry override for macOS, and add a pre-commit guard that refuses to commit a tarball-type `nixpkgs` node.

---

## E) DECISIONS / UNBLOCKERS NEEDED FROM YOU

1. **May I commit and push the PMA vendorHash change upstream?** The file is already edited at `~/projects/projects-management-automation/flake.nix`. This is the correct upstream fix per AGENTS.md (application build bugs go upstream, not SystemNix patches).
2. **Do you want the macOS registry override added now?** It requires checking whether nix-darwin supports `nix.registry` or an equivalent.
3. **Do you want a pre-commit tarball guard added now?** This would prevent the auto-commit daemon from ever committing a tarball `nixpkgs` node again.

---

## F) KEY DISCOVERIES

- The global Nix registry entry `flake:nixpkgs/nixos-unstable → https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz` is what rewrites the lockfile. It is not a SystemNix bug and cannot be disabled by `nix flake update` flags (`--no-use-registries`, `--override-flake`, `--override-input` all failed in testing).
- The only reliable fix is a **system registry override** deployed via NixOS `nix.registry."nixpkgs/nixos-unstable"`. After it is deployed, future `nix flake update` runs will keep nixpkgs on GitHub.
- The upstream `projects-management-automation` vendorHash is stale relative to current `nixos-unstable`; this is a normal consequence of updating nixpkgs after a long stale period.
