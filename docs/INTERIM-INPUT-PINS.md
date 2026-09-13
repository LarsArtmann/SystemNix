# INTERIM INPUT PINS — REVERT AFTER UPSTREAM PUSH

**Created:** 2026-09-13 (deploy-failure triage repair)

Three `flake.nix` inputs are pinned to **local `git+file://` checkout commits**
because their fixes exist only as unpushed commits (private repos have no CI,
and `github:`/`git+ssh:` inputs cannot fetch unpublished commits). Every pin is
marked `# INTERIM` inline in `flake.nix`.

**These pins break CI and any other machine's build.** Revert each to its
upstream URL the moment the fix is pushed.

| Input | Pin | Upstream URL to restore | Fix |
|-------|-----|-------------------------|-----|
| `go-cqrs-lite` | `git+file:///home/lars/worktrees/go-cqrs-lite-hashfix?rev=d84e4d6a42b2ed368a7d7110b716448d0c4093f9` | `git+ssh://git@github.com/LarsArtmann/go-cqrs-lite?ref=master` | cqrs-lint vendorHash refresh (stale at upstream HEAD `5cc025c42`) |
| `branching-flow` | `git+file:///home/lars/projects/branching-flow?rev=46000f38ab44a35692bcdb39d0d061501750dd74` | `github:LarsArtmann/branching-flow?ref=master` | `publicDeps = [ samber-linter ]` + vendorHash refresh |
| `art-dupl` | `git+file:///home/lars/projects/art-dupl?rev=9c370324dfcfaef23fa60079af0d9ebfcf84a489` | `github:LarsArtmann/art-dupl?ref=fork` | vendorHash refresh (source-only churn) |

`dnsblockd` is **not** pinned — its cosmetic fix landed on origin/master and the
input re-locked normally to `3be58aa`.

## Why local pins (not a lock rollback)

The failures were genuine upstream breakage at fresh HEADs, discovered by the
2026-09-13 `nix flake update`. Rolling the lock back would re-introduce
arbitrarily old revisions across the whole dependency graph; pinning each fixed
commit is surgical and keeps every other bump.

## Cleanup checklist

1. Push each fix commit upstream (go-cqrs-lite: the worktree commit is on a
   throwaway branch — cherry-pick or re-apply to `master` first).
2. Flip each URL in `flake.nix` back to the upstream form above.
3. `nix flake lock` (full, so the stale `go-cqrs-lite_6` orphan node is dropped).
4. `nix flake check --no-build`.
5. Delete this file and remove the TODO_LIST entry.
