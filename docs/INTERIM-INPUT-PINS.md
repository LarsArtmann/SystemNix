# INTERIM INPUT PINS — REVERT AFTER UPSTREAM FIXES

**Created/updated:** 2026-09-13 (deploy-failure triage repair)

The automated full `nix flake update` of 2026-09-13 (~11:53, commit `f8f2965e`,
188 lock nodes moved, nixpkgs `c043004d`→`eaad089`) snapped every moving-ref
input to upstream HEAD. Private LarsArtmann repos have had **no CI since
~2026-09-10** (Actions minutes exhausted), so a dozen upstream HEADs shipped
stale `vendorHash`/lockfile state. The `flake.nix` inputs below are pinned to
**known-good revisions** as an interim measure. Every pin is marked `# INTERIM`
inline.

**Pins break CI and other machines' builds.** Revert each as its upstream fix
lands.

## A. Local `git+file` pins (fix exists only as an unpushed local commit)

| Input | Rev | Upstream URL to restore | Fix |
|-------|-----|-------------------------|-----|
| `go-nix-helpers` | `8c87f2654f546bcf22a302833cf0f5d2dfe30ea2` (worktree) | `github:LarsArtmann/go-nix-helpers?ref=master` | `/vN` pseudo-version normalization (`v0.0.0`→`vN.0.0`) |
| `file-and-image-renamer` | `494c9b7a0a80bdda3a2cb31a4b8c8f2ee315f8f3` | `github:LarsArtmann/file-and-image-renamer?ref=master` | vendorHash refresh forced by the `/vN` fix |
| `go-cqrs-lite` | `d84e4d6a42b2ed368a7d7110b716448d0c4093f9` (worktree) | `git+ssh://git@github.com/LarsArtmann/go-cqrs-lite?ref=master` | `cqrs-lint` vendorHash refresh |
| `branching-flow` | `46000f38ab44a35692bcdb39d0d061501750dd74` | `github:LarsArtmann/branching-flow?ref=master` | `samber-linter` publicDep + vendorHash |
| `art-dupl` | `9c370324dfcfaef23fa60079af0d9ebfcf84a489` | `github:LarsArtmann/art-dupl?ref=fork` | vendorHash refresh |

Worktrees: `/home/lars/worktrees/go-nix-helpers-vnfix`,
`/home/lars/worktrees/go-cqrs-lite-hashfix` (throwaway branches; the commits
live in the main repos' object stores).

## B. `github:` pins to last-good revisions (upstream HEAD still broken)

**RESOLVED 2026-09-16..2026-09-18** — every row was re-verified against
upstream HEAD (probe + build) and flipped to `?ref=master`/`?ref=main`; the
locks now track the branches via `nix flake lock --update-input`. Historical
revs kept for reference: todo-list-ai `f9f3b335`, library-policy `1bf02c11`,
go-auto-upgrade `eb97a8b2`, projects-management-automation `9bbc7dfb`,
overview `73738794`, md-go-validator `5b72f894`, signoz-src `e0da06f7`,
signoz-collector-src `b514eb4a`. The signoz pair carries a standing
migration-review obligation on every future bump (see `flake.nix`): new
`pkg/sqlmigration` files run against the metadata sqlite at signoz start and
the collector's ClickHouse schema-migrator runs pre-start — review the delta
before deploying (2026-09-18 bump verdict: one transactional quick-filter
normalization + zero ClickHouse schema changes).

## C. Re-locked to newer, **fixed** origins (no pin needed)

These had advanced past the broken locked rev to a rev whose FODs build:

`dnsblockd` → `3be58aa`, `cv` → `7672132`, `inboxclean` → `f01a628`,
`go-humanize-linter` → `bb155411`, `project-meta` → `a02d74f0`.

## Cleanup checklist

1. Push/land each fix upstream (for worktrees: cherry-pick onto `master` first).
2. Flip each URL in `flake.nix` back to the upstream form above.
3. `nix flake lock` (full, so stale orphan nodes are dropped).
4. `nix flake check --no-build` + full toplevel build.
5. Delete this file and remove the TODO_LIST entry.
