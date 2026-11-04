# pim-sync → SystemNix integration wave (designed 2026-11-04 ~19:35, NOT executed)

**Status:** AUTHORED — execution queued `[ready]` (TODO_LIST.md + docs/todo/services.md), gated on
shared-tree quiescence. At authoring time a parallel float wave (`e9b353742` 19:01 refresh +
float-register with the toplevel proof still running at 19:35) owned `flake.lock` / `flake.nix` /
`flake/expected-locks.nix` (its lock+registry landed unproven in daemon commit `1d5a549a2` 19:29 —
the 2026-10-29 "never commit an unproven float" class, owned by that session), and a parallel
session was actively editing `~/projects/pim-sync` (4 dirty files, mtimes 19:18, go tests running).

**Quiescence gate (do not execute while either holds the tree):** no `float-register` /
`nixosConfigurations` build procs (`pgrep -af`), SystemNix tree clean or carrying only own files,
no eval-relevant file (`modules/ platforms/ flake* lib/ pkgs/`) with mtime < 5 min across ≥3
consecutive 60 s polls (2026-10-25 deploy-vs-executor pattern), and pim-sync HEAD == pushed
origin/master (`git -C ~/projects/pim-sync status -sb`).

## What this wave delivers (T21 SystemNix host half)

pim-sync's upstream side is DONE and green (20 packages, `go build` + full suite verified live
2026-11-04 19:1x): `nix/module.nix` exports `services.pim-sync` (oneshot + jittered timer,
hardening, dry-run default), `flake.nixosModules.default`, `packages.x86_64-linux.default`.
What is missing is exactly the SystemNix host half pim-sync's own status deferred
(pim-sync `docs/status/2026-10-30_00-47` §3): flake input, host import, sops rendering, OnFailure.

### 1. flake.nix input (alphabetical slot; private-repo cv/crm/monitor365/quotaboard pattern)

```nix
pim-sync = {
  url = "git+ssh://git@github.com/LarsArtmann/pim-sync?ref=refs/heads/master";
};
```

- PRIVATE repo (gh-verified `isPrivate: true`, 2026-11-04) → `git+ssh` URL, never `github:`
  (tarball fetch would fail auth).
- Default branch `master` — verified via `gh repo view` 2026-11-04 (the 422-class check).

### 2. infra-follows group (END of the inputs attrset — the audit REQUIRES infra follows for new root inputs; quotaboard precedent flake.nix ~228-229)

```nix
pim-sync.inputs.flake-parts.follows = "flake-parts";
pim-sync.inputs.go-nix-helpers.follows = "go-nix-helpers";
pim-sync.inputs.go-nix-helpers.inputs.treefmt-nix.follows = "treefmt-nix";
pim-sync.inputs.nixpkgs.follows = "nixpkgs";
```

- The go-nix-helpers follow kills pim-sync's own deep `treefmt-nix` copy — the deep-treefmt audit
  leg fails eval otherwise (the exact regrowth class the 19:14 report hit on `go-nix-helpers_3`).
  Deep-override precedent: `journal.inputs.go-nix-helpers.inputs.treefmt-nix.follows` /
  `papdashboard.inputs.go-nix-helpers.inputs.treefmt-nix.follows`.
- nixpkgs follow toolchain safety: root pinned nixpkgs (fe13242) ships go 1.27.3 (live-observed:
  the box's running `/nix/store/*-go-1.27.3/bin/go test` processes) ≥ pim-sync's go.mod floor
  1.27.2. pim-sync has NO private Go deps (upstream flake comment: every
  github.com/larsartmann/* dep is public, proxy-verified 2026-10-30) — no deps map, no GOPRIVATE.
- **FOD probe REQUIRED after locking** (pim-sync's vendorHash was measured against its OWN
  nixpkgs): lock-free probe at the locked rev —
  `nix build --impure --no-link --expr 'let f = builtins.getFlake "git+ssh://git@github.com/LarsArtmann/pim-sync?rev=<FULL_REV>"; in f.packages.x86_64-linux.default.goModules'`
  On a got-mismatch: fix UPSTREAM first (paste the fresh hash into pim-sync's flake.nix, push,
  re-lock); a downstream `overrideAttrs { vendorHash = …; }` shim is documented-interim only
  (drift-treadmill doctrine). If the nixpkgs follow genuinely cannot hold, fall back to a
  documented non-follow + `deliberate` entry in lib/lock-audit.nix (bank-sync precedent).

### 3. Lock + registry protocol

`flake/expected-locks.nix` via the float-register flow: prove FIRST
(`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going --no-link`,
log captured to a file — never piped through tail), then commit flake.lock + registry TOGETHER.
Never commit unproven rows; after any float-register run, verify the registry actually committed
(the 2026-10-29 green-but-staged trap).

### 4. `modules/nixos/services/pim-sync.nix` (thin wrapper, monitor365 pattern — upstream owns the heavy lifting)

```nix
imports = [ inputs.pim-sync.nixosModules.default ];
```

- **Initial posture: `enable = false` (flip-ready).** WHY NOT enabled: `discoverAccounts` ERRORS
  on an empty tokensDir (`pim-sync: no token files in … (run … first)`, cmd/pim-sync/sync.go:359)
  → enabled-without-secrets = every-5-min failed oneshot + OnFailure alert storm. There is NO
  graceful zero-account idle no-op upstream.
- Layer SystemNix-only concerns (integration-registry "what to layer"):
  - sops wiring STUBS only until secrets exist — declaring sops keys without values fails the
    sops-key-audit eval gate. `environmentFile` / `secretFile` / `tokenSeedDir` stay `null` with
    pointer comments to the flip ladder.
  - OnFailure Discord routing (lib `onFailure` / the attic+bank-sync unitConfig pattern).
  - `services.integration.pim-sync` entry with `subdomain = null` (no vHost, no tile, no HTTP
    check — not web-facing, so the tile-coverage assertion is N/A) + `monitored = true` so
    system-health watches the unit (safe: pim-sync is not in the default monitoredServices list,
    no duplicate-series risk).
  - `metricsFile` wiring DEFERRED to the live flip: dry-run never settles
    `pimsync_leg_last_success_unix` (0 = never), so a freshness check would red permanently under
    the dry-run posture. Textfile dir precedent: `/var/lib/prometheus-node-exporter/textfile_collectors`
    (btrfs-health.nix:42).
  - Catalog entry (unconditional inline-imports module, cv.nix pattern) — verify the catalog
    option's subdomain/port nullability at wiring time; pim-sync exposes no HTTP endpoint.
- Module head note: service modules receive `inputs` via host-assembly specialArgs (monitor365.nix:363
  uses bare `inputs.`).

### 5. configuration.nix + docs

- `services.pim-sync.enable = false;` with a comment pointing at this plan's flip ladder.
- `docs/services/pim-sync.md` runbook written in the same wave (Status: DISABLED/flip-ready).
- AGENTS.md needs NO new routing row (service docs own per-service state).

### 6. Verification + landing

`nix fmt -- <paths>` (scoped form) → targeted eval `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`
→ the keep-going proof (step 3) → pre-commit green → PATHSPEC commit. **Do NOT deploy** — deploy
is owner-gated and needs the IO-quiet protocol.

## Flip ladder (owner-gated, after this wave deploys)

1. 🧑 GCP OAuth client secret (In production publishing mode — the InboxClean 7-day-token lesson)
   + Stalwart DAV creds (PIMSYNC_DAV_USER/PASS) + per-account browser consent tokens.
   Path contract: pim-sync `docs/oauth-setup.md`. sops declarations land ONLY together with the
   values (sops-key-audit throws on declared-but-missing keys).
2. agent: `enable = true`, `live = false` (dry-run timer), `tokenSeedDir` wired → deploy → first
   dry-run journal review 🧑 (the 7.5 owner gate from the Stalwart-single-truth plan).
3. 🧑 GO → agent: `live = true` + `maxChanges` cap + `metricsFile` + Gatus freshness check on
   `pimsync_leg_last_success_unix` (anchored-pat doctrine) + catalog.
4. Real Twenty import stays its own owner gate (docs/todo/services.md:375 unchanged).

## Source

- Owner question 2026-11-04 ~19:30: "What is stopping you from integrating ~/projects/pim-sync
  superbly?" — answer: (a) the live float wave on the shared tree, (b) the live parallel session
  inside pim-sync, (c) the owner gates above. This plan clears (a)+(b) as a quiescence-gated
  execution; (c) stays with the owner.
- pim-sync app state: docs/status/2026-10-29_23-55_pim-sync-bidirectional-contacts-complete-status.md
  + ~/projects/pim-sync docs/status/README.md (T17–T27.5 delivered; remainder owner-gated).
- Forgejo-canonical provisioning (mirrors pending the same unblock): docs/status/2026-11-04_19-14_forgejo-canonical-repos-provisioned-fine-tune-pim-sync.md
